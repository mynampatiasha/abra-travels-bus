import { Types } from 'mongoose';
import {
  type AuthTestContext,
  bearer,
  client,
  createAuthTestApp,
  dataOf,
  errorCodeOf,
  type Tokens,
} from '../../authentication/tests/auth-e2e.harness';
import { seedAndSignIn } from '../../rbac/tests/rbac-e2e.harness';
import {
  MAX_SEATS_PER_HOLD,
  SEAT_HOLD_SECONDS,
  SeatLocksService,
  placeSeats,
} from '../seat_locks_customer.service';

const API = '/api/v1';
interface Caller { tokens: Tokens }
interface SeatMap {
  berthType: string;
  aisleAfterColumn: number;
  seats: Array<{ id: string; deck: string; row: number; column: number; status: string; farePaise: number }>;
}
interface Hold { lockId: string; tripId: string; seatIds: string[]; expiresAt: string; holdSeconds: number }

describe('Seat map and seat hold e2e (abra_supply_test)', () => {
  let context: AuthTestContext;
  let tripId: Types.ObjectId;
  let sleeperTripId: Types.ObjectId;
  let anna: Caller;
  let ben: Caller;
  let service: SeatLocksService;
  const operatorId = new Types.ObjectId();

  const auth = (caller: Caller) => bearer(caller.tokens);
  const seats = () => context.connection.collection('seat_inventory');
  const trips = () => context.connection.collection('trips');

  async function makeTrip(berthType: string, count: number, withPoints = false): Promise<Types.ObjectId> {
    const id = new Types.ObjectId();
    const point = () => ({ pointId: new Types.ObjectId() });
    await trips().insertOne({
      _id: id,
      operatorId,
      status: 'SCHEDULED',
      departureAt: new Date(Date.now() + 3 * 86_400_000),
      bus: { berthType },
      boardingPoints: withPoints ? [point()] : [],
      droppingPoints: withPoints ? [point()] : [],
      seatCounts: { total: count, available: count, locked: 0, booked: 0, blocked: 0 },
    });
    await seats().insertMany(
      Array.from({ length: count }, (_, index) => ({
        tripId: id,
        operatorId,
        seatNumber: String(index + 1),
        deck: 'LOWER',
        seatType: berthType,
        status: 'AVAILABLE',
        pricePaise: 85_000,
      })),
    );
    return id;
  }

  const lock = (caller: Caller, trip: Types.ObjectId, seatIds: string[], key?: string) => {
    const request = client(context).post(`${API}/trips/${trip.toHexString()}/seat-locks`).set(...auth(caller));
    if (key) request.set('Idempotency-Key', key);
    return request.send({ seatIds });
  };
  const map = async (trip: Types.ObjectId): Promise<SeatMap> =>
    dataOf<SeatMap>(await client(context).get(`${API}/trips/${trip.toHexString()}/seats`).expect(200));
  const statusOf = (m: SeatMap, id: string) => m.seats.find((s) => s.id === id)?.status;

  beforeAll(async () => {
    context = await createAuthTestApp({ MONGODB_URI: 'mongodb://localhost:27017/abra_supply_test?directConnection=true' });
    service = context.app.get(SeatLocksService);
    anna = await seedAndSignIn(context, { roleKeys: ['CUSTOMER'] });
    ben = await seedAndSignIn(context, { roleKeys: ['CUSTOMER'] });
    tripId = await makeTrip('SEATER', 40);
    sleeperTripId = await makeTrip('SLEEPER', 30);
  }, 180_000);

  afterAll(async () => {
    const ids = [tripId, sleeperTripId];
    await seats().deleteMany({ tripId: { $in: ids } });
    await trips().deleteMany({ _id: { $in: ids } });
    await context.connection.collection('seat_lock_groups').deleteMany({ tripId: { $in: ids } });
    await context.close();
  }, 60_000);

  it('places seats in a 2 + 2 grid, and sleeper berths in two decks of 2 + 1', async () => {
    const seater = await map(tripId);
    expect(seater.berthType).toBe('SEATER');
    expect(seater.aisleAfterColumn).toBe(1);
    expect(seater.seats).toHaveLength(40);
    expect(seater.seats.find((s) => s.id === '1')).toMatchObject({ deck: 'LOWER', row: 0, column: 0, status: 'AVAILABLE', farePaise: 85_000 });
    expect(seater.seats.find((s) => s.id === '4')).toMatchObject({ row: 0, column: 3 });
    expect(seater.seats.find((s) => s.id === '5')).toMatchObject({ row: 1, column: 0 });
    expect(Math.max(...seater.seats.map((s) => s.column))).toBe(3);

    const sleeper = await map(sleeperTripId);
    expect(sleeper.seats.filter((s) => s.deck === 'LOWER')).toHaveLength(15);
    expect(sleeper.seats.filter((s) => s.deck === 'UPPER')).toHaveLength(15);
    expect(Math.max(...sleeper.seats.map((s) => s.column))).toBe(2);
  });

  it('shows no map for a trip that is not on sale', async () => {
    const draft = new Types.ObjectId();
    await trips().insertOne({ _id: draft, operatorId, status: 'DRAFT', departureAt: new Date(Date.now() + 86_400_000) });
    await client(context).get(`${API}/trips/${draft.toHexString()}/seats`).expect(404);
    await trips().deleteOne({ _id: draft });
    await client(context).get(`${API}/trips/not-an-id/seats`).expect(404);
  });

  it('holds seats for 10 minutes and shows them as taken to everyone else', async () => {
    const res = await lock(anna, tripId, ['2', '3']).expect(201);
    const hold = dataOf<Hold>(res);
    expect(hold.seatIds).toEqual(['2', '3']);
    expect(hold.holdSeconds).toBe(SEAT_HOLD_SECONDS);
    const left = new Date(hold.expiresAt).getTime() - Date.now();
    expect(left).toBeGreaterThan(9 * 60_000);
    expect(left).toBeLessThanOrEqual(10 * 60_000);

    const m = await map(tripId);
    expect(statusOf(m, '2')).toBe('BOOKED');
    expect(statusOf(m, '3')).toBe('BOOKED');
    expect(statusOf(m, '4')).toBe('AVAILABLE');
    const trip = await trips().findOne({ _id: tripId });
    expect(trip?.seatCounts).toMatchObject({ total: 40, locked: 2, available: 38 });
  });

  it('is all or nothing: one taken seat means no seat is held', async () => {
    const res = await lock(ben, tripId, ['3', '6']).expect(409);
    expect(errorCodeOf(res)).toBe('SEAT_NOT_AVAILABLE');
    expect((res.body as { error: { details: unknown } }).error.details).toMatchObject({ seatId: '3' });
    expect(statusOf(await map(tripId), '6')).toBe('AVAILABLE');
  });

  it('refuses nothing chosen, too many seats, a guest, and someone who is not a customer', async () => {
    await lock(ben, tripId, []).expect(400);
    const many = Array.from({ length: MAX_SEATS_PER_HOLD + 1 }, (_, i) => String(10 + i));
    await lock(ben, tripId, many).expect(400);
    await client(context).post(`${API}/trips/${tripId.toHexString()}/seat-locks`).send({ seatIds: ['7'] }).expect(401);
    const admin = await seedAndSignIn(context, { roleKeys: ['SUPER_ADMIN'] });
    await lock(admin, tripId, ['7']).expect(403);
  });

  it('returns the same hold for the same request key', async () => {
    const first = dataOf<Hold>(await lock(ben, tripId, ['8'], 'key-1').expect(201));
    const again = dataOf<Hold>(await lock(ben, tripId, ['8'], 'key-1').expect(201));
    expect(again.lockId).toBe(first.lockId);
    expect(again.expiresAt).toBe(first.expiresAt);
  });

  it('lets a customer change their mind: seats not asked for again go back on sale', async () => {
    await lock(ben, tripId, ['8', '9']).expect(201);
    await lock(ben, tripId, ['9', '12']).expect(201);
    const m = await map(tripId);
    expect(statusOf(m, '8')).toBe('AVAILABLE');
    expect(statusOf(m, '9')).toBe('BOOKED');
    expect(statusOf(m, '12')).toBe('BOOKED');
  });

  it('releases a hold at once, and only for its holder', async () => {
    const hold = dataOf<Hold>(await lock(anna, tripId, ['20']).expect(201));
    await client(context).delete(`${API}/seat-locks/${hold.lockId}`).set(...auth(ben)).expect(404);
    await client(context).delete(`${API}/seat-locks/${hold.lockId}`).set(...auth(anna)).expect(200);
    expect(statusOf(await map(tripId), '20')).toBe('AVAILABLE');
    await lock(ben, tripId, ['20']).expect(201);
  });

  it('treats a hold that has run out as free, and the expiry job tidies it up', async () => {
    const hold = dataOf<Hold>(await lock(anna, tripId, ['30']).expect(201));
    const past = new Date(Date.now() - 1000);
    await seats().updateMany({ tripId, 'lock.lockId': hold.lockId }, { $set: { 'lock.expiresAt': past } });
    await context.connection.collection('seat_lock_groups').updateOne({ lockId: hold.lockId }, { $set: { expiresAt: past } });
    // Free at once, before any job ran
    expect(statusOf(await map(tripId), '30')).toBe('AVAILABLE');
    const result = await service.expireOverdue();
    expect(result.groups).toBeGreaterThanOrEqual(1);
    const row = await seats().findOne({ tripId, seatNumber: '30' });
    expect(row?.status).toBe('AVAILABLE');
    expect(row?.lock).toBeUndefined();
    const group = await context.connection.collection('seat_lock_groups').findOne({ lockId: hold.lockId });
    expect(group?.status).toBe('EXPIRED');
    await lock(ben, tripId, ['30']).expect(201);
  });

  it('checks the boarding and dropping points when the trip has them', async () => {
    const withPoints = await makeTrip('SEATER', 8, true);
    try {
      await lock(anna, withPoints, ['1']).expect(400);
      const trip = await trips().findOne({ _id: withPoints });
      const boarding = (trip?.boardingPoints as Array<{ pointId: Types.ObjectId }>)[0]?.pointId.toHexString();
      const dropping = (trip?.droppingPoints as Array<{ pointId: Types.ObjectId }>)[0]?.pointId.toHexString();
      await client(context)
        .post(`${API}/trips/${withPoints.toHexString()}/seat-locks`)
        .set(...auth(anna))
        .send({ seatIds: ['1'], boardingPointId: boarding, droppingPointId: dropping })
        .expect(201);
    } finally {
      await seats().deleteMany({ tripId: withPoints });
      await trips().deleteOne({ _id: withPoints });
      await context.connection.collection('seat_lock_groups').deleteMany({ tripId: withPoints });
    }
  });

  it('gives exactly one winner when many customers ask for the same seat at once', async () => {
    const racers: Caller[] = [];
    for (let i = 0; i < 10; i++) racers.push(await seedAndSignIn(context, { roleKeys: ['CUSTOMER'] }));
    const results = await Promise.all(racers.map((racer) => lock(racer, sleeperTripId, ['5', '6'])));
    const winners = results.filter((r) => r.status === 201);
    const losers = results.filter((r) => r.status === 409);
    expect(winners).toHaveLength(1);
    expect(losers).toHaveLength(9);
    const held = await seats().find({ tripId: sleeperTripId, status: 'LOCKED' }).toArray();
    expect(held.map((s) => String(s.seatNumber)).sort()).toEqual(['5', '6']);
    expect(new Set(held.map((s) => String((s.lock as { lockId: string }).lockId))).size).toBe(1);
  }, 120_000);

  it('places seats without a layout in order, whatever the status', () => {
    const rows = placeSeats(
      [
        { _id: new Types.ObjectId(), tripId, seatNumber: '10', status: 'AVAILABLE', pricePaise: 1 },
        { _id: new Types.ObjectId(), tripId, seatNumber: '2', status: 'BLOCKED', pricePaise: 1 },
        { _id: new Types.ObjectId(), tripId, seatNumber: '1', status: 'BOOKED', pricePaise: 1 },
      ],
      'SEATER',
    );
    expect(rows.map((r) => r.id)).toEqual(['1', '2', '10']);
    expect(rows.map((r) => r.status)).toEqual(['BOOKED', 'BLOCKED', 'AVAILABLE']);
  });
});
