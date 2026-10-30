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
    // 85,000 + GST 4,250 + fee 4,900 - 10,000
    expect(booking.amountPaise).toBe(84_150);

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

  it('shows guests the offers with what they give and the conditions in words', async () => {
    const c = code('GUEST');
    await make({ code: c, title: 'Guest deal', discountType: 'PERCENT', value: 15, maxDiscountPaise: 20_000, minBookingPaise: 100_000, newUsersOnly: true }).expect(201);
    const res = await client(context).get(`${API}/offers`).expect(200);
    const offers = dataOf<Array<{ code: string; description: string; validTill: string; terms: string[] }>>(res);
    const mine = offers.find((o) => o.code === c);
    expect(mine?.description).toBe('15% off up to Rs 200');
    expect(mine?.terms).toEqual([
      'Valid on bookings of Rs 1000 or more.',
      'For your first booking only.',
      'One use for each customer.',
    ]);
    expect(new Date(mine?.validTill ?? '').getTime()).toBeGreaterThan(Date.now());
  });


  describe('changing, deleting, exporting and following a coupon', () => {
    const patch = (id: string, body: Record<string, unknown>, caller: Caller = admin) =>
      client(context).patch(`${API}/admin/coupons/${id}`).set(...auth(caller)).send(body);
    const audit = (id: string, action: string) =>
      context.connection.collection('audit_logs').find({ entityId: new Types.ObjectId(id), action }).toArray();

    it('writes an audit entry for every change', async () => {
      const created = dataOf<CouponView>(await make({ code: code('AUDIT') }).expect(201));
      expect(await audit(created.id, 'coupon.created')).toHaveLength(1);
      await patch(created.id, { title: 'New title' }).expect(200);
      expect(await audit(created.id, 'coupon.updated')).toHaveLength(1);
      await client(context).patch(`${API}/admin/coupons/${created.id}/status`).set(...auth(admin)).send({ status: 'PAUSED' }).expect(200);
      expect(await audit(created.id, 'coupon.status-changed')).toHaveLength(1);
      await client(context).delete(`${API}/admin/coupons/${created.id}`).set(...auth(admin)).expect(200);
      expect(await audit(created.id, 'coupon.deleted')).toHaveLength(1);
    });

    it('changes the title, limits and dates, but not the code or the kind', async () => {
      const created = dataOf<CouponView>(await make({ code: code('EDIT'), usageLimit: 5, value: 10 }).expect(201));
      const changed = dataOf<CouponView>(
        await patch(created.id, { title: 'Longer title', perCustomerLimit: 3, usageLimit: 8, newUsersOnly: true, value: 20, endsAt: day(60) }).expect(200),
      );
      expect(changed).toMatchObject({ code: created.code, discountType: 'PERCENT', title: 'Longer title', perCustomerLimit: 3, usageLimit: 8, newUsersOnly: true, value: 20 });
      await patch(created.id, { value: 150 }).expect(400);
      await patch(created.id, { endsAt: day(-30) }).expect(400);
      await patch(created.id, { code: 'OTHER' }).expect(400); // the code is not something a change can carry
      const row = await context.connection.collection('coupons').findOne({ _id: new Types.ObjectId(created.id) });
      expect(row?.code).toBe(created.code);
      await patch(new Types.ObjectId().toHexString(), { title: 'No such coupon' }).expect(404);
      await patch(created.id, { title: 'Nope' }, anna).expect(403);
    });

    it('keeps the amount fixed once a booking used the coupon, and will not delete it', async () => {
      const c = code('USED');
      const created = dataOf<CouponView>(await make({ code: c, discountType: 'FLAT', value: 5_000 }).expect(201));
      const h = await hold(ben, ['6']);
      await book(ben, h.lockId, '6', c).expect(201);
      const refusedAmount = await patch(created.id, { value: 9_000 }).expect(409);
      expect(errorCodeOf(refusedAmount)).toBe('RESOURCE_IN_USE');
      await patch(created.id, { value: 5_000, title: 'Same amount, new words' }).expect(200);
      // The limit may equal the uses so far, never go below them
      await patch(created.id, { usageLimit: 1 }).expect(200);
      const refusedDelete = await client(context).delete(`${API}/admin/coupons/${created.id}`).set(...auth(admin)).expect(409);
      expect(errorCodeOf(refusedDelete)).toBe('RESOURCE_IN_USE');
      await client(context).delete(`${API}/admin/coupons/${created.id}`).set(...auth(anna)).expect(403);
    });

    it('shows who used a coupon, with each booking and what it took off', async () => {
      const c = code('WHO');
      const created = dataOf<CouponView>(await make({ code: c, discountType: 'FLAT', value: 7_000 }).expect(201));
      const h = await hold(anna, ['7']);
      const booking = dataOf<BookingView>(await book(anna, h.lockId, '7', c).expect(201));
      const usage = dataOf<{ usedCount: number; reserved: number; redeemed: number; items: Array<{ pnr: string; discountPaise: number; status: string }> }>(
        await client(context).get(`${API}/admin/coupons/${created.id}/usage`).set(...auth(admin)).expect(200),
      );
      expect(usage).toMatchObject({ usedCount: 1, reserved: 1, redeemed: 0 });
      expect(usage.items[0]).toMatchObject({ pnr: booking.pnr, discountPaise: 7_000, status: 'RESERVED' });
      await client(context).get(`${API}/admin/coupons/${created.id}/usage`).set(...auth(anna)).expect(403);
      await client(context).get(`${API}/admin/coupons/${new Types.ObjectId().toHexString()}/usage`).set(...auth(admin)).expect(404);
    });

    it('deletes a coupon nobody used, and exports the list with the same filters', async () => {
      const c = code('GONE');
      const created = dataOf<CouponView>(await make({ code: c, title: 'Export me' }).expect(201));
      const csv = await client(context).get(`${API}/admin/coupons/export?search=Export me`).set(...auth(admin)).buffer(true).expect(200);
      expect(csv.headers['content-type']).toContain('text/csv');
      expect(csv.text).toContain('Code');
      expect(csv.text).toContain(c);
      const none = await client(context).get(`${API}/admin/coupons/export?status=PAUSED&search=Export me`).set(...auth(admin)).buffer(true).expect(200);
      expect(none.text).not.toContain(c);
      await client(context).get(`${API}/admin/coupons/export`).set(...auth(anna)).expect(403);
      await client(context).delete(`${API}/admin/coupons/${created.id}`).set(...auth(admin)).expect(200);
      const left = await context.connection.collection('coupons').findOne({ code: c });
      expect(left).toBeNull();
    });
  });

  it('lists the codes on offer for a customer', async () => {
    const res = await client(context).get(`${API}/coupons?tripId=${tripId.toHexString()}`).set(...auth(anna)).expect(200);
    expect(dataOf<CouponView[]>(res).length).toBeGreaterThan(0);
    await client(context).get(`${API}/coupons`).expect(401);
  });
});
