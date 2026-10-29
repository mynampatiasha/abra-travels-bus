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
import { type BookingView } from '../../bookings/bookings_customer.service';
import { type CouponCheck, type CouponView, discountFor } from '../coupons.service';

const API = '/api/v1';
interface Caller { tokens: Tokens }

describe('Coupons e2e (abra_supply_test)', () => {
  let context: AuthTestContext;
  let tripId: Types.ObjectId;
  let admin: Caller;
  let anna: Caller;
  let ben: Caller;
  const operatorId = new Types.ObjectId();
  const suffix = Date.now().toString(36).toUpperCase();
  const code = (name: string) => `${name}${suffix}`.slice(0, 20);

  const auth = (caller: Caller) => bearer(caller.tokens);
  const seats = () => context.connection.collection('seat_inventory');
  const day = (n: number) => new Date(Date.now() + n * 86_400_000).toISOString();

  const make = (body: Record<string, unknown>) =>
    client(context).post(`${API}/admin/coupons`).set(...auth(admin)).send({
      title: 'Test coupon',
      discountType: 'PERCENT',
      value: 10,
      startsAt: day(-1),
      endsAt: day(30),
      ...body,
    });
  const check = async (caller: Caller, couponCode: string, basePaise = 85_000) =>
    dataOf<CouponCheck>(
      await client(context)
        .post(`${API}/coupons/validate`)
        .set(...auth(caller))
        .send({ tripId: tripId.toHexString(), code: couponCode, basePaise })
        .expect(200),
    );
  const hold = async (caller: Caller, seatIds: string[]) =>
    dataOf<{ lockId: string }>(
      await client(context).post(`${API}/trips/${tripId.toHexString()}/seat-locks`).set(...auth(caller)).send({ seatIds }).expect(201),
    );
  const book = (caller: Caller, lockId: string, seatId: string, couponCode?: string) =>
    client(context)
      .post(`${API}/bookings`)
      .set(...auth(caller))
      .send({
        lockId,
        passengers: [{ seatId, name: 'Asha Rao', age: 31, gender: 'FEMALE' }],
        contact: { mobile: '9876543210', email: 'asha@example.com' },
        ...(couponCode ? { couponCode } : {}),
      });

  beforeAll(async () => {
    context = await createAuthTestApp({ MONGODB_URI: 'mongodb://localhost:27017/abra_supply_test?directConnection=true' });
    admin = await seedAndSignIn(context, { roleKeys: ['SUPER_ADMIN'] });
    anna = await seedAndSignIn(context, { roleKeys: ['CUSTOMER'] });
    ben = await seedAndSignIn(context, { roleKeys: ['CUSTOMER'] });
    tripId = new Types.ObjectId();
    await context.connection.collection('trips').insertOne({
      _id: tripId,
      operatorId,
      status: 'SCHEDULED',
      departureAt: new Date(Date.now() + 3 * 86_400_000),
      bus: { berthType: 'SEATER' },
      boardingPoints: [],
      droppingPoints: [],
      seatCounts: { total: 8, available: 8, locked: 0, booked: 0, blocked: 0 },
    });
    await seats().insertMany(
      Array.from({ length: 8 }, (_, index) => ({
        tripId,
        operatorId,
        seatNumber: String(index + 1),
        deck: 'LOWER',
        seatType: 'SEATER',
        status: 'AVAILABLE',
        pricePaise: 85_000,
      })),
    );
  }, 180_000);

  afterAll(async () => {
    const mine = { code: { $regex: `${suffix}$` } };
    const ids = (await context.connection.collection('coupons').find(mine).toArray()).map((c) => c._id);
    await context.connection.collection('coupon_redemptions').deleteMany({ couponId: { $in: ids } });
    await context.connection.collection('coupons').deleteMany(mine);
    await seats().deleteMany({ tripId });
    await context.connection.collection('trips').deleteMany({ _id: tripId });
    await context.connection.collection('seat_lock_groups').deleteMany({ tripId });
    await context.connection.collection('bookings').deleteMany({ tripId });
    await context.close();
  }, 60_000);

  it('works out percent and flat discounts, capped and never above the fare', () => {
    expect(discountFor({ discountType: 'PERCENT', value: 10 }, 85_000)).toBe(8_500);
    expect(discountFor({ discountType: 'PERCENT', value: 50, maxDiscountPaise: 10_000 }, 85_000)).toBe(10_000);
    expect(discountFor({ discountType: 'FLAT', value: 5_000 }, 85_000)).toBe(5_000);
    expect(discountFor({ discountType: 'FLAT', value: 999_999 }, 85_000)).toBe(85_000);
  });

  it('lets admin make, list and pause a coupon, and only admin', async () => {
    const c = code('SAVE10');
    const created = dataOf<CouponView>(await make({ code: c.toLowerCase() }).expect(201));
    expect(created.code).toBe(c);
    expect((await make({ code: c }).expect(409)).body).toBeDefined();
    await make({ code: code('BAD'), value: 150 }).expect(400);
    await make({ code: code('BAD2'), startsAt: day(5), endsAt: day(1) }).expect(400);
    const listed = dataOf<CouponView[]>(await client(context).get(`${API}/admin/coupons`).set(...auth(admin)).expect(200));
    expect(listed.some((x) => x.code === c)).toBe(true);
    await client(context).get(`${API}/admin/coupons`).set(...auth(anna)).expect(403);
    await client(context).post(`${API}/admin/coupons`).set(...auth(anna)).send({}).expect(403);

    await client(context).patch(`${API}/admin/coupons/${created.id}/status`).set(...auth(admin)).send({ status: 'PAUSED' }).expect(200);
    expect((await check(anna, c)).valid).toBe(false);
    await client(context).patch(`${API}/admin/coupons/${created.id}/status`).set(...auth(admin)).send({ status: 'ACTIVE' }).expect(200);
    expect(await check(anna, c)).toMatchObject({ valid: true, discountPaise: 8_500 });
  });

  it('says why a code does not apply, in words', async () => {
    expect((await check(anna, 'NOSUCHCODE')).reason).toMatch(/not valid/i);
    const early = code('LATER');
    await make({ code: early, startsAt: day(2), endsAt: day(9) }).expect(201);
    expect((await check(anna, early)).reason).toMatch(/not active/i);
    const big = code('BIGONLY');
    await make({ code: big, minBookingPaise: 500_000 }).expect(201);
    expect((await check(anna, big)).reason).toMatch(/at least/i);
    const other = code('OTHEROP');
    await make({ code: other, operatorIds: [new Types.ObjectId().toHexString()] }).expect(201);
    expect((await check(anna, other)).reason).toMatch(/company/i);
  });

  it('takes the discount off the booking, and each customer uses a code once', async () => {
    const c = code('ONCE');
    await make({ code: c, discountType: 'FLAT', value: 10_000 }).expect(201);
    const h = await hold(anna, ['1']);
    const booking = dataOf<BookingView>(await book(anna, h.lockId, '1', c).expect(201));
    expect(booking.baseFarePaise).toBe(85_000);
    expect(booking.discountPaise).toBe(10_000);
    expect(booking.amountPaise).toBe(75_000);

    const second = await hold(anna, ['2']);
    const refused = await book(anna, second.lockId, '2', c).expect(422);
    expect(errorCodeOf(refused)).toBe('COUPON_INVALID');
    expect((await check(anna, c)).valid).toBe(false);
    expect((await check(ben, c)).valid).toBe(true);
  });

  it('refuses an unknown code when booking', async () => {
    const h = await hold(ben, ['3']);
    const res = await book(ben, h.lockId, '3', 'NOPE123').expect(422);
    expect(errorCodeOf(res)).toBe('COUPON_INVALID');
  });

  it('gives the last use of a limited code to one booking only', async () => {
    const c = code('LAST');
    await make({ code: c, usageLimit: 1 }).expect(201);
    const racers = [await seedAndSignIn(context, { roleKeys: ['CUSTOMER'] }), await seedAndSignIn(context, { roleKeys: ['CUSTOMER'] })];
    const holds = [await hold(racers[0] as Caller, ['4']), await hold(racers[1] as Caller, ['5'])];
    const results = await Promise.all([
      book(racers[0] as Caller, (holds[0] as { lockId: string }).lockId, '4', c),
      book(racers[1] as Caller, (holds[1] as { lockId: string }).lockId, '5', c),
    ]);
    expect(results.filter((r) => r.status === 201)).toHaveLength(1);
    expect(results.filter((r) => r.status === 422)).toHaveLength(1);
    const row = await context.connection.collection('coupons').findOne({ code: c });
    expect(row?.usedCount).toBe(1);
  }, 120_000);

  it('lists the codes on offer for a customer', async () => {
    const res = await client(context).get(`${API}/coupons?tripId=${tripId.toHexString()}`).set(...auth(anna)).expect(200);
    expect(dataOf<CouponView[]>(res).length).toBeGreaterThan(0);
    await client(context).get(`${API}/coupons`).expect(401);
  });
});
