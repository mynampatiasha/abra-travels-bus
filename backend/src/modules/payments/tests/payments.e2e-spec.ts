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
import { DevelopmentPaymentGateway, RazorpayPaymentGateway } from '../payment_gateway';
import { PaymentsCustomerService, type PaymentOrderView, type PaymentResultView } from '../payments_customer.service';

const API = '/api/v1';
interface Caller { tokens: Tokens }

describe('Payments e2e (abra_supply_test, development gateway)', () => {
  let context: AuthTestContext;
  let tripId: Types.ObjectId;
  let anna: Caller;
  let ben: Caller;
  let service: PaymentsCustomerService;
  const operatorId = new Types.ObjectId();
  const suffix = Date.now().toString(36).toUpperCase();

  const auth = (caller: Caller) => bearer(caller.tokens);
  const seats = () => context.connection.collection('seat_inventory');
  const status = async (seat: string) => (await seats().findOne({ tripId, seatNumber: seat }))?.status;

  const hold = async (caller: Caller, seatIds: string[]) =>
    dataOf<{ lockId: string }>(
      await client(context).post(`${API}/trips/${tripId.toHexString()}/seat-locks`).set(...auth(caller)).send({ seatIds }).expect(201),
    );
  const book = async (caller: Caller, seatId: string, couponCode?: string) => {
    const h = await hold(caller, [seatId]);
    const res = await client(context)
      .post(`${API}/bookings`)
      .set(...auth(caller))
      .send({
        lockId: h.lockId,
        passengers: [{ seatId, name: 'Asha Rao', age: 31, gender: 'FEMALE' }],
        contact: { mobile: '9876543210', email: 'asha@example.com' },
        ...(couponCode ? { couponCode } : {}),
      })
      .expect(201);
    return dataOf<BookingView>(res);
  };
  const order = async (caller: Caller, bookingId: string) =>
    dataOf<PaymentOrderView>(
      await client(context).post(`${API}/payments/orders`).set(...auth(caller)).send({ bookingId }).expect(201),
    );
  const devComplete = (caller: Caller, paymentId: string, outcome: 'success' | 'failure') =>
    client(context).post(`${API}/payments/${paymentId}/dev-complete`).set(...auth(caller)).send({ outcome });
  const bookingStatus = async (id: string) =>
    (await context.connection.collection('bookings').findOne({ _id: new Types.ObjectId(id) }))?.status;

  beforeAll(async () => {
    context = await createAuthTestApp({ MONGODB_URI: 'mongodb://localhost:27017/abra_supply_test?directConnection=true' });
    service = context.app.get(PaymentsCustomerService);
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
        pricePaise: 85_000,
      })),
    );
  }, 180_000);

  afterAll(async () => {
    const ids = (await context.connection.collection('bookings').find({ tripId }).toArray()).map((b) => b._id);
    await context.connection.collection('payments').deleteMany({ bookingId: { $in: ids } });
    await context.connection.collection('coupon_redemptions').deleteMany({ bookingId: { $in: ids } });
    await context.connection.collection('coupons').deleteMany({ code: { $regex: `${suffix}$` } });
    await seats().deleteMany({ tripId });
    await context.connection.collection('trips').deleteMany({ _id: tripId });
    await context.connection.collection('seat_lock_groups').deleteMany({ tripId });
    await context.connection.collection('bookings').deleteMany({ tripId });
    await context.close();
  }, 60_000);

  it('makes an order for the booking amount, and the same order when asked again', async () => {
    const booking = await book(anna, '1');
    const first = await order(anna, booking.bookingId);
    expect(first.amountPaise).toBe(85_000);
    expect(first.gateway).toBe('development');
    expect(first.gatewayOrderId).toMatch(/^dev_order_/);
    const again = await order(anna, booking.bookingId);
    expect(again.paymentId).toBe(first.paymentId);
    await client(context).post(`${API}/payments/orders`).set(...auth(ben)).send({ bookingId: booking.bookingId }).expect(404);
    await client(context).post(`${API}/payments/orders`).send({ bookingId: booking.bookingId }).expect(401);
  });

  it('confirms the booking and books the seat when the payment is verified', async () => {
    const booking = await book(anna, '2');
    const o = await order(anna, booking.bookingId);
    const res = dataOf<PaymentResultView>(await devComplete(anna, o.paymentId, 'success').expect(200));
    expect(res).toMatchObject({ status: 'SUCCESS', bookingStatus: 'CONFIRMED', refundDue: false });
    expect(await status('2')).toBe('BOOKED');
    const group = await context.connection.collection('seat_lock_groups').findOne({ tripId, seatNumbers: '2' });
    expect(group?.status).toBe('CONSUMED');
    const trip = await context.connection.collection('trips').findOne({ _id: tripId });
    expect((trip?.seatCounts as { booked: number }).booked).toBeGreaterThanOrEqual(1);
    // Reported twice: nothing changes
    const twice = dataOf<PaymentResultView>(await devComplete(anna, o.paymentId, 'success').expect(200));
    expect(twice.status).toBe('SUCCESS');
    // A booked booking cannot be paid again
    await client(context).post(`${API}/payments/orders`).set(...auth(anna)).send({ bookingId: booking.bookingId }).expect(409);
  });

  it('refuses a signature that does not belong to the order', async () => {
    const booking = await book(anna, '3');
    const o = await order(anna, booking.bookingId);
    const res = await client(context)
      .post(`${API}/payments/${o.paymentId}/client-callback`)
      .set(...auth(anna))
      .send({ gatewayPaymentId: 'pay_x', signature: 'a'.repeat(64) })
      .expect(400);
    expect(errorCodeOf(res)).toBe('VALIDATION_FAILED');
    expect(await bookingStatus(booking.bookingId)).toBe('PAYMENT_PENDING');
    expect(await status('3')).toBe('LOCKED');
  });

  it('puts the seat back on sale when the payment fails', async () => {
    const booking = await book(anna, '4');
    const o = await order(anna, booking.bookingId);
    const res = dataOf<PaymentResultView>(await devComplete(anna, o.paymentId, 'failure').expect(200));
    expect(res).toMatchObject({ status: 'FAILED', bookingStatus: 'FAILED' });
    expect(await status('4')).toBe('AVAILABLE');
    // Someone else can now take it
    await book(ben, '4');
  });

  it('gives the coupon use back when the payment fails, so the code can be used again', async () => {
    const code = `BACK${suffix}`.slice(0, 20);
    const admin = await seedAndSignIn(context, { roleKeys: ['SUPER_ADMIN'] });
    await client(context)
      .post(`${API}/admin/coupons`)
      .set(...auth(admin))
      .send({
        code,
        title: 'Back',
        discountType: 'FLAT',
        value: 5_000,
        usageLimit: 1,
        startsAt: new Date(Date.now() - 86_400_000).toISOString(),
        endsAt: new Date(Date.now() + 86_400_000).toISOString(),
      })
      .expect(201);
    const booking = await book(anna, '5', code);
    expect(booking.amountPaise).toBe(80_000);
    expect((await context.connection.collection('coupons').findOne({ code }))?.usedCount).toBe(1);
    const o = await order(anna, booking.bookingId);
    expect(o.amountPaise).toBe(80_000);
    await devComplete(anna, o.paymentId, 'failure').expect(200);
    expect((await context.connection.collection('coupons').findOne({ code }))?.usedCount).toBe(0);
    const redemption = await context.connection.collection('coupon_redemptions').findOne({ bookingId: new Types.ObjectId(booking.bookingId) });
    expect(redemption?.status).toBe('RELEASED');
    // The same customer can use the code again
    await book(anna, '6', code);
  });

  it('expires an unpaid booking when its hold runs out, giving the seat back', async () => {
    const booking = await book(anna, '7');
    const o = await order(anna, booking.bookingId);
    const past = new Date(Date.now() - 1000);
    await context.connection.collection('bookings').updateOne({ _id: new Types.ObjectId(booking.bookingId) }, { $set: { holdExpiresAt: past } });
    const result = await service.expireUnpaid();
    expect(result.bookings).toBeGreaterThanOrEqual(1);
    expect(await bookingStatus(booking.bookingId)).toBe('EXPIRED');
    expect(await status('7')).toBe('AVAILABLE');
    const payment = await context.connection.collection('payments').findOne({ _id: new Types.ObjectId(o.paymentId) });
    // The open payment stays, so a payment that still arrives is a late payment, not a lost one
    expect(payment?.status).toBe('CREATED');
    await client(context).post(`${API}/payments/orders`).set(...auth(anna)).send({ bookingId: booking.bookingId }).expect(409);
  });

  it('keeps the money facts and owes a refund when paid after the seat went to someone else', async () => {
    const booking = await book(anna, '8');
    const o = await order(anna, booking.bookingId);
    // The hold ran out, the job released it, and another customer took the seat
    await context.connection.collection('bookings').updateOne({ _id: new Types.ObjectId(booking.bookingId) }, { $set: { holdExpiresAt: new Date(Date.now() - 1000) } });
    await context.connection.collection('seat_lock_groups').updateMany({ tripId, seatNumbers: '8' }, { $set: { expiresAt: new Date(Date.now() - 1000) } });
    await service.expireUnpaid();
    await book(ben, '8');
    // Late payment for the first booking
    const res = dataOf<PaymentResultView>(await devComplete(anna, o.paymentId, 'success').expect(200));
    expect(res.refundDue).toBe(true);
    expect(res.bookingStatus).toBe('EXPIRED');
    expect(res.status).toBe('SUCCESS');
    expect(await status('8')).toBe('LOCKED');
  });

  it('checks Razorpay signatures the way Razorpay makes them', () => {
    const gateway = new RazorpayPaymentGateway('rzp_test_key', 'secret123');
    const good = (global as unknown as { __sig?: string }).__sig ?? require('node:crypto').createHmac('sha256', 'secret123').update('order_1|pay_1').digest('hex');
    expect(gateway.verifyPaymentSignature('order_1', 'pay_1', good)).toBe(true);
    expect(gateway.verifyPaymentSignature('order_1', 'pay_2', good)).toBe(false);
    expect(gateway.verifyPaymentSignature('order_1', 'pay_1', 'zz')).toBe(false);
    const dev = new DevelopmentPaymentGateway('a-development-secret-of-some-length');
    expect(dev.verifyPaymentSignature('o', 'p', dev.signForDevelopment('o', 'p'))).toBe(true);
    expect(dev.verifyPaymentSignature('o', 'q', dev.signForDevelopment('o', 'p'))).toBe(false);
  });
});
