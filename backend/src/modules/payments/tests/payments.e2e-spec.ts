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
import { DevelopmentPaymentGateway, PaymentGatewayProvider, RazorpayPaymentGateway } from '../payment_gateway';
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
      seatCounts: { total: 20, available: 20, locked: 0, booked: 0, blocked: 0 },
    });
    await seats().insertMany(
      Array.from({ length: 20 }, (_, index) => ({
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
    await context.connection.collection('outbox_events').deleteMany({ aggregateId: { $in: ids.map((id) => id.toHexString()) } });
    await context.connection.collection('payment_gateway_events').deleteMany({ eventId: { $in: ['evt_1', 'evt_2', 'evt_3', 'evt_4', 'evt_5'] } });
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
    expect(first.amountPaise).toBe(94_150);
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
    // The confirmation message and the operator notice are queued with the same commit, once
    const events = await context.connection
      .collection('outbox_events')
      .find({ aggregateId: booking.bookingId, type: { $in: ['booking.confirmed', 'booking.created'] } })
      .toArray();
    expect(events.map((e) => e.type).sort()).toEqual(['booking.confirmed', 'booking.created']);
    expect(events[0]?.payload).toMatchObject({
      bookingId: booking.bookingId,
      pnr: booking.pnr,
      seatsText: '2',
      amountText: 'Rs 941.50',
      contactPhone: '+919876543210',
      contactEmail: 'asha@example.com',
      customerId: expect.any(String),
    });
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
    expect(booking.amountPaise).toBe(89_150);
    expect((await context.connection.collection('coupons').findOne({ code }))?.usedCount).toBe(1);
    const o = await order(anna, booking.bookingId);
    expect(o.amountPaise).toBe(89_150);
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
    // The money went back at once, through the gateway
    expect(res.refundedPaise).toBe(94_150);
    expect(res.bookingStatus).toBe('EXPIRED');
    expect(res.status).toBe('SUCCESS');
    expect(await status('8')).toBe('LOCKED');
  });


  describe('the gateway webhook', () => {
    let development: DevelopmentPaymentGateway;
    beforeAll(async () => {
      development = (await context.app.get(PaymentGatewayProvider).current()) as DevelopmentPaymentGateway;
    });
    const gateway = () => development;
    const send = (payload: object, options: { eventId?: string; signature?: string } = {}) => {
      const raw = JSON.stringify(payload);
      const request = client(context)
        .post(`${API}/webhooks/payments/razorpay`)
        .set('Content-Type', 'application/json')
        .set('X-Razorpay-Signature', options.signature ?? gateway().signWebhookForDevelopment(Buffer.from(raw)));
      if (options.eventId) request.set('X-Razorpay-Event-Id', options.eventId);
      return request.send(raw);
    };
    const captured = (orderId: string, amount: number, paymentId = 'pay_hook') => ({
      event: 'payment.captured',
      payload: { payment: { entity: { id: paymentId, order_id: orderId, amount, currency: 'INR' } } },
    });

    it('confirms a booking when the customer closed the app after paying', async () => {
      const booking = await book(anna, '9');
      const o = await order(anna, booking.bookingId);
      const res = await send(captured(o.gatewayOrderId, o.amountPaise, 'pay_hook_1'), { eventId: 'evt_1' }).expect(200);
      expect(dataOf<{ outcome: string }>(res).outcome).toBe('CONFIRMED');
      expect(await bookingStatus(booking.bookingId)).toBe('CONFIRMED');
      expect(await status('9')).toBe('BOOKED');
      const payment = await context.connection.collection('payments').findOne({ _id: new Types.ObjectId(o.paymentId) });
      expect(payment).toMatchObject({ status: 'SUCCESS', gatewayPaymentId: 'pay_hook_1' });
    });

    it('does nothing the second time the same event arrives', async () => {
      const booking = await book(anna, '10');
      const o = await order(anna, booking.bookingId);
      const payload = captured(o.gatewayOrderId, o.amountPaise, 'pay_hook_2');
      expect(dataOf<{ outcome: string }>(await send(payload, { eventId: 'evt_2' }).expect(200)).outcome).toBe('CONFIRMED');
      expect(dataOf<{ outcome: string }>(await send(payload, { eventId: 'evt_2' }).expect(200)).outcome).toBe('DUPLICATE');
      expect(await context.connection.collection('payment_gateway_events').countDocuments({ eventId: 'evt_2' })).toBe(1);
    });

    it('refuses a call whose signature does not match the body', async () => {
      const booking = await book(ben, '11');
      const o = await order(ben, booking.bookingId);
      const raw = captured(o.gatewayOrderId, o.amountPaise);
      await send(raw, { signature: 'a'.repeat(64) }).expect(401);
      await client(context).post(`${API}/webhooks/payments/razorpay`).send(raw).expect(401);
      // A signature made for another body is no good for this one
      const other = gateway().signWebhookForDevelopment(Buffer.from('{}'));
      await send(raw, { signature: other }).expect(401);
      expect(await bookingStatus(booking.bookingId)).toBe('PAYMENT_PENDING');
    });

    it('does not confirm when the gateway took a different amount', async () => {
      const booking = await book(ben, '12');
      const o = await order(ben, booking.bookingId);
      const res = await send(captured(o.gatewayOrderId, o.amountPaise - 100, 'pay_hook_3'), { eventId: 'evt_3' }).expect(200);
      expect(dataOf<{ outcome: string }>(res).outcome).toBe('AMOUNT_MISMATCH');
      expect(await bookingStatus(booking.bookingId)).toBe('PAYMENT_PENDING');
      const payment = await context.connection.collection('payments').findOne({ _id: new Types.ObjectId(o.paymentId) });
      expect(payment).toMatchObject({ status: 'FAILED', failureReason: 'AMOUNT_MISMATCH' });
    });

    it('confirms a booking paid by someone else through the shared link', async () => {
      const booking = await book(ben, '17');
      const o = await order(ben, booking.bookingId);
      // The link's payment has the link's own order id; our payment is named in the notes
      const payload = {
        event: 'payment.captured',
        payload: {
          payment: {
            entity: { id: 'pay_link_1', order_id: 'order_of_the_link', amount: o.amountPaise, currency: 'INR', notes: { paymentId: o.paymentId } },
          },
        },
      };
      const res = await send(payload, { eventId: 'evt_link_1' }).expect(200);
      expect(dataOf<{ outcome: string }>(res).outcome).toBe('CONFIRMED');
      expect(await bookingStatus(booking.bookingId)).toBe('CONFIRMED');
      const payment = await context.connection.collection('payments').findOne({ _id: new Types.ObjectId(o.paymentId) });
      expect(payment).toMatchObject({ status: 'SUCCESS', gatewayPaymentId: 'pay_link_1' });
      await context.connection.collection('payment_gateway_events').deleteMany({ eventId: 'evt_link_1' });
    });

    it('ignores a failed attempt and an order it does not know', async () => {
      const booking = await book(ben, '13');
      const o = await order(ben, booking.bookingId);
      const failed = { event: 'payment.failed', payload: { payment: { entity: { id: 'pay_x', order_id: o.gatewayOrderId } } } };
      expect(dataOf<{ outcome: string }>(await send(failed, { eventId: 'evt_4' }).expect(200)).outcome).toBe('IGNORED');
      expect(await bookingStatus(booking.bookingId)).toBe('PAYMENT_PENDING');
      expect(dataOf<{ outcome: string }>(await send(captured('order_nope', 1000), { eventId: 'evt_5' }).expect(200)).outcome).toBe('UNKNOWN_ORDER');
    });
  });

  it('never refunds more than was paid, and a repeated refund for the same reason changes nothing', async () => {
    const booking = await book(ben, '14');
    const o = await order(ben, booking.bookingId);
    await devComplete(ben, o.paymentId, 'success').expect(200);
    const id = new Types.ObjectId(o.paymentId);
    expect(await service.refund(id, 20_000, 'TEST_PART')).toEqual({ refundedPaise: 20_000 });
    expect(await service.refund(id, 20_000, 'TEST_PART')).toEqual({ refundedPaise: 20_000 });
    await expect(service.refund(id, 90_000, 'TEST_TOO_MUCH')).rejects.toMatchObject({ code: 'VALIDATION_FAILED' });
    const payment = await context.connection.collection('payments').findOne({ _id: id });
    expect(payment?.refundedPaise).toBe(20_000);
    expect((payment?.refunds as unknown[]).length).toBe(1);
    // Only a paid payment can be refunded
    const second = await book(ben, '15');
    const o2 = await order(ben, second.bookingId);
    await expect(service.refund(new Types.ObjectId(o2.paymentId), 100, 'TEST_UNPAID')).rejects.toMatchObject({ code: 'INVALID_STATE_TRANSITION' });
  });

  it('makes one link for someone else to pay, for the owner only, until the payment is done', async () => {
    const booking = await book(ben, '18');
    const o = await order(ben, booking.bookingId);
    const make = (caller: Caller, id: string) => client(context).post(`${API}/payments/${id}/share-link`).set(...auth(caller));
    const first = dataOf<{ url: string; amountPaise: number; expiresAt: string }>(await make(ben, o.paymentId).expect(200));
    expect(first.url).toMatch(/^https:\/\//);
    expect(first.amountPaise).toBe(o.amountPaise);
    expect(new Date(first.expiresAt).getTime()).toBeGreaterThan(Date.now());
    const again = dataOf<{ url: string }>(await make(ben, o.paymentId).expect(200));
    expect(again.url).toBe(first.url);
    await make(anna, o.paymentId).expect(404);
    await client(context).post(`${API}/payments/${o.paymentId}/share-link`).expect(401);
    await devComplete(ben, o.paymentId, 'success').expect(200);
    const done = await make(ben, o.paymentId).expect(409);
    expect(errorCodeOf(done)).toBe('INVALID_STATE_TRANSITION');
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
