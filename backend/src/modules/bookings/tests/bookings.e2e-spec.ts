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
import { newPnr, type BookingView } from '../bookings_customer.service';

const API = '/api/v1';
interface Caller { tokens: Tokens }
interface Hold { lockId: string; seatIds: string[] }

describe('Booking held seats e2e (abra_supply_test)', () => {
  let context: AuthTestContext;
  let tripId: Types.ObjectId;
  let anna: Caller;
  let ben: Caller;
  const operatorId = new Types.ObjectId();

  const auth = (caller: Caller) => bearer(caller.tokens);
  const seats = () => context.connection.collection('seat_inventory');
  const trips = () => context.connection.collection('trips');

  const passenger = (seatId: string, name = 'Asha Rao') => ({ seatId, name, age: 31, gender: 'FEMALE' });
  const contact = { mobile: '9876543210', email: 'asha@example.com' };

  const hold = async (caller: Caller, seatIds: string[]): Promise<Hold> =>
    dataOf<Hold>(
      await client(context).post(`${API}/trips/${tripId.toHexString()}/seat-locks`).set(...auth(caller)).send({ seatIds }).expect(201),
    );
  const book = (caller: Caller, body: Record<string, unknown>) =>
    client(context).post(`${API}/bookings`).set(...auth(caller)).send(body);

  beforeAll(async () => {
    context = await createAuthTestApp({ MONGODB_URI: 'mongodb://localhost:27017/abra_supply_test?directConnection=true' });
    anna = await seedAndSignIn(context, { roleKeys: ['CUSTOMER'] });
    ben = await seedAndSignIn(context, { roleKeys: ['CUSTOMER'] });
    tripId = new Types.ObjectId();
    await trips().insertOne({
      _id: tripId,
      operatorId,
      status: 'SCHEDULED',
      departureAt: new Date(Date.now() + 3 * 86_400_000),
      bus: { berthType: 'SEATER' },
      boardingPoints: [],
      droppingPoints: [],
      seatCounts: { total: 10, available: 10, locked: 0, booked: 0, blocked: 0 },
    });
    await seats().insertMany(
      Array.from({ length: 10 }, (_, index) => ({
        tripId,
        operatorId,
        seatNumber: String(index + 1),
        deck: 'LOWER',
        seatType: 'SEATER',
        status: 'AVAILABLE',
        pricePaise: 85_000 + (index === 1 ? 5_000 : 0),
      })),
    );
  }, 180_000);

  afterAll(async () => {
    await seats().deleteMany({ tripId });
    await trips().deleteMany({ _id: tripId });
    await context.connection.collection('seat_lock_groups').deleteMany({ tripId });
    await context.connection.collection('bookings').deleteMany({ tripId });
    await context.close();
  }, 60_000);

  it('books the held seats and reads the price from the seats, not from the app', async () => {
    const h = await hold(anna, ['1', '2']);
    const res = await book(anna, {
      lockId: h.lockId,
      passengers: [passenger('1'), passenger('2', 'Ravi Rao')],
      contact,
      expectedAmountPaise: 188_650,
    }).expect(201);
    const booking = dataOf<BookingView>(res);
    expect(booking.status).toBe('PAYMENT_PENDING');
    expect(booking.baseFarePaise).toBe(175_000);
    // 175,000 + 5% GST (8,750) + the Rs 49 fee
    expect(booking.gstPaise).toBe(8_750);
    expect(booking.convenienceFeePaise).toBe(4_900);
    expect(booking.amountPaise).toBe(188_650);
    expect(booking.seatIds.sort()).toEqual(['1', '2']);
    expect(booking.pnr).toMatch(/^ABR[A-Z2-9]{7}$/);

    const read = dataOf<BookingView>(await client(context).get(`${API}/bookings/${booking.bookingId}`).set(...auth(anna)).expect(200));
    expect(read.pnr).toBe(booking.pnr);
    await client(context).get(`${API}/bookings/${booking.bookingId}`).set(...auth(ben)).expect(404);
  });

  it('gives the same booking when the same hold is booked twice', async () => {
    const h = await hold(anna, ['3']);
    const body = { lockId: h.lockId, passengers: [passenger('3')], contact };
    const first = dataOf<BookingView>(await book(anna, body).expect(201));
    const again = dataOf<BookingView>(await book(anna, body).expect(201));
    expect(again.bookingId).toBe(first.bookingId);
    expect(await context.connection.collection('bookings').countDocuments({ lockId: h.lockId })).toBe(1);
  });

  it('refuses a price the customer did not see', async () => {
    const h = await hold(anna, ['4']);
    const res = await book(anna, { lockId: h.lockId, passengers: [passenger('4')], contact, expectedAmountPaise: 1 }).expect(422);
    expect(errorCodeOf(res)).toBe('PAYMENT_AMOUNT_MISMATCH');
  });

  it('wants exactly one passenger for each held seat', async () => {
    const h = await hold(anna, ['5', '6']);
    await book(anna, { lockId: h.lockId, passengers: [passenger('5')], contact }).expect(400);
    await book(anna, { lockId: h.lockId, passengers: [passenger('5'), passenger('9')], contact }).expect(400);
    await book(anna, { lockId: h.lockId, passengers: [passenger('5'), passenger('5')], contact }).expect(400);
  });

  it('checks the passenger and contact details', async () => {
    const h = await hold(anna, ['7']);
    await book(anna, { lockId: h.lockId, passengers: [{ ...passenger('7'), age: 0 }], contact }).expect(400);
    await book(anna, { lockId: h.lockId, passengers: [{ ...passenger('7'), gender: 'X' }], contact }).expect(400);
    await book(anna, { lockId: h.lockId, passengers: [passenger('7')], contact: { ...contact, mobile: '12345' } }).expect(400);
    await book(anna, { lockId: h.lockId, passengers: [passenger('7')], contact: { ...contact, email: 'nope' } }).expect(400);
    await book(anna, { lockId: h.lockId, passengers: [passenger('7')], contact, gst: { gstin: 'bad', company: 'Rao Co' } }).expect(400);
    await book(anna, {
      lockId: h.lockId,
      passengers: [passenger('7')],
      contact,
      gst: { gstin: '36ABCDE1234F1Z5', company: 'Rao Co' },
    }).expect(201);
  });

  it('is only for the customer who holds the seats', async () => {
    const h = await hold(anna, ['8']);
    await book(ben, { lockId: h.lockId, passengers: [passenger('8')], contact }).expect(404);
    await book(ben, { lockId: 'no-such-hold', passengers: [passenger('8')], contact }).expect(404);
    await client(context).post(`${API}/bookings`).send({ lockId: h.lockId, passengers: [passenger('8')], contact }).expect(401);
    const admin = await seedAndSignIn(context, { roleKeys: ['SUPER_ADMIN'] });
    await book(admin, { lockId: h.lockId, passengers: [passenger('8')], contact }).expect(403);
  });

  it('refuses a hold that has run out', async () => {
    const h = await hold(anna, ['9']);
    const past = new Date(Date.now() - 1000);
    await context.connection.collection('seat_lock_groups').updateOne({ lockId: h.lockId }, { $set: { expiresAt: past } });
    const res = await book(anna, { lockId: h.lockId, passengers: [passenger('9')], contact }).expect(409);
    expect(errorCodeOf(res)).toBe('SEAT_LOCK_EXPIRED');
  });

  it('makes booking references that are easy to read out', () => {
    const seen = new Set(Array.from({ length: 200 }, () => newPnr()));
    expect(seen.size).toBe(200);
    for (const pnr of seen) expect(pnr).toMatch(/^ABR[ABCDEFGHJKLMNPQRSTUVWXYZ23456789]{7}$/);
  });
});
