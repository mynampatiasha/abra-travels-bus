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
import { type PaymentOrderView } from '../../payments/payments_customer.service';
import { type AdminBookingDetail, type AdminBookingRow } from '../bookings_admin_manage.service';
import { type BookingView } from '../bookings_customer.service';

const API = '/api/v1';
interface Caller { tokens: Tokens }
interface Page<T> { items: T[]; total: number }

describe('Admin bookings and payments e2e (abra_supply_test)', () => {
  let context: AuthTestContext;
  let tripId: Types.ObjectId;
  let admin: Caller;
  let anna: Caller;
  const operatorId = new Types.ObjectId();
  const hyd = new Types.ObjectId();
  const blr = new Types.ObjectId();
  const auth = (caller: Caller) => bearer(caller.tokens);
  const seats = () => context.connection.collection('seat_inventory');
  const tag = Date.now().toString(36);

  const book = async (seat: string, name: string, pay: boolean) => {
    const h = dataOf<{ lockId: string }>(
      await client(context).post(`${API}/trips/${tripId.toHexString()}/seat-locks`).set(...auth(anna)).send({ seatIds: [seat] }).expect(201),
    );
    const booking = dataOf<BookingView>(
      await client(context)
        .post(`${API}/bookings`)
        .set(...auth(anna))
        .send({
          lockId: h.lockId,
          passengers: [{ seatId: seat, name, age: 30, gender: 'FEMALE' }],
          contact: { mobile: '9876500000', email: `${seat}-${tag}@example.com` },
        })
        .expect(201),
    );
    let paymentId = '';
    if (pay) {
      const order = dataOf<PaymentOrderView>(
        await client(context).post(`${API}/payments/orders`).set(...auth(anna)).send({ bookingId: booking.bookingId }).expect(201),
      );
      paymentId = order.paymentId;
      await client(context).post(`${API}/payments/${order.paymentId}/dev-complete`).set(...auth(anna)).send({ outcome: 'success' }).expect(200);
    }
    return { booking, paymentId };
  };

  beforeAll(async () => {
    context = await createAuthTestApp({ MONGODB_URI: 'mongodb://localhost:27017/abra_supply_test?directConnection=true' });
    admin = await seedAndSignIn(context, { roleKeys: ['SUPER_ADMIN'] });
    anna = await seedAndSignIn(context, { roleKeys: ['CUSTOMER'] });
    tripId = new Types.ObjectId();
    const now = new Date();
    await context.connection.collection('cities').insertMany([
      { _id: hyd, name: 'Hyderabad', slug: `hyd-a-${tag}`, countryCode: 'IN', isActive: true, createdAt: now, updatedAt: now },
      { _id: blr, name: 'Bengaluru', slug: `blr-a-${tag}`, countryCode: 'IN', isActive: true, createdAt: now, updatedAt: now },
    ]);
    await context.connection.collection('operators').insertOne({ _id: operatorId, companyName: 'Admin Test Travels', displayName: 'Admin Test Travels', status: 'ACTIVE' });
    await context.connection.collection('trips').insertOne({
      _id: tripId,
      operatorId,
      status: 'SCHEDULED',
      departureAt: new Date(Date.now() + 3 * 86_400_000),
      originCityId: hyd,
      destinationCityId: blr,
      bus: { berthType: 'SEATER' },
      boardingPoints: [],
      droppingPoints: [],
      seatCounts: { total: 6, available: 6, locked: 0, booked: 0, blocked: 0 },
    });
    await seats().insertMany(
      Array.from({ length: 6 }, (_, index) => ({
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
    await context.connection.collection('bookings').deleteMany({ tripId });
    await context.connection.collection('seat_lock_groups').deleteMany({ tripId });
    await seats().deleteMany({ tripId });
    await context.connection.collection('trips').deleteMany({ _id: tripId });
    await context.connection.collection('operators').deleteMany({ _id: operatorId });
    await context.connection.collection('cities').deleteMany({ _id: { $in: [hyd, blr] } });
    await context.close();
  }, 60_000);

  it('lists bookings with who, where and how much, and filters them', async () => {
    const paid = await book('1', `Meera ${tag}`, true);
    const unpaid = await book('2', `Nikhil ${tag}`, false);
    const list = async (query: string): Promise<Page<AdminBookingRow>> => {
      const res = await client(context).get(`${API}/admin/bookings?${query}`).set(...auth(admin)).expect(200);
      return { items: dataOf<AdminBookingRow[]>(res), total: (res.body as { meta: { total: number } }).meta.total };
    };

    const byName = await list(`search=Meera ${tag}`);
    expect(byName.total).toBe(1);
    expect(byName.items[0]).toMatchObject({
      pnr: paid.booking.pnr,
      status: 'CONFIRMED',
      customerName: `Meera ${tag}`,
      customerPhone: '9876500000',
      route: 'Hyderabad to Bengaluru',
      operatorName: 'Admin Test Travels',
      seats: '1',
      amountPaise: 94_150,
      paymentStatus: 'SUCCESS',
    });
    expect((await list(`search=${unpaid.booking.pnr}`)).items[0]).toMatchObject({ status: 'PAYMENT_PENDING', paymentStatus: 'NONE' });
    expect((await list(`search=${tag}&status=CONFIRMED`)).items.map((i) => i.id)).toEqual([paid.booking.bookingId]);
    expect((await list(`search=${tag}&operatorId=${operatorId.toHexString()}`)).total).toBe(2);
    expect((await list(`search=${tag}&operatorId=${new Types.ObjectId().toHexString()}`)).total).toBe(0);
    await client(context).get(`${API}/admin/bookings?status=NOPE`).set(...auth(admin)).expect(400);
  });

  it('is only for staff with the permission', async () => {
    await client(context).get(`${API}/admin/bookings`).set(...auth(anna)).expect(403);
    await client(context).get(`${API}/admin/bookings`).expect(401);
    await client(context).get(`${API}/admin/payments`).set(...auth(anna)).expect(403);
    await client(context).get(`${API}/admin/bookings/export`).set(...auth(anna)).expect(403);
  });

  it('shows one booking in full with its payments', async () => {
    const { booking, paymentId } = await book('3', `Omkar ${tag}`, true);
    const detail = dataOf<AdminBookingDetail>(
      await client(context).get(`${API}/admin/bookings/${booking.bookingId}`).set(...auth(admin)).expect(200),
    );
    expect(detail).toMatchObject({ baseFarePaise: 85_000, gstPaise: 4_250, convenienceFeePaise: 4_900, discountPaise: 0, amountPaise: 94_150 });
    expect(detail.passengers).toEqual([{ seatId: '3', name: `Omkar ${tag}`, age: 30, gender: 'FEMALE', farePaise: 85_000, status: 'ACTIVE' }]);
    expect(detail.payments[0]).toMatchObject({ id: paymentId, status: 'SUCCESS', amountPaise: 94_150, refundedPaise: 0 });
    await client(context).get(`${API}/admin/bookings/${new Types.ObjectId().toHexString()}`).set(...auth(admin)).expect(404);
    await client(context).get(`${API}/admin/bookings/not-an-id`).set(...auth(admin)).expect(404);
  });

  it('sends the ticket message again for a paid booking, audited, and refuses an unpaid one', async () => {
    const paid = await book('4', `Pooja ${tag}`, true);
    const unpaid = await book('5', `Qadir ${tag}`, false);
    await client(context).post(`${API}/admin/bookings/${paid.booking.bookingId}/resend-ticket`).set(...auth(admin)).expect(200);
    const events = await context.connection
      .collection('outbox_events')
      .find({ aggregateId: paid.booking.bookingId, type: 'booking.confirmed' })
      .toArray();
    expect(events).toHaveLength(2);
    const audit = await context.connection
      .collection('audit_logs')
      .find({ entityId: new Types.ObjectId(paid.booking.bookingId), action: 'booking.ticket-resent' })
      .toArray();
    expect(audit).toHaveLength(1);
    const refused = await client(context).post(`${API}/admin/bookings/${unpaid.booking.bookingId}/resend-ticket`).set(...auth(admin)).expect(409);
    expect(errorCodeOf(refused)).toBe('INVALID_STATE_TRANSITION');
    await client(context).post(`${API}/admin/bookings/${paid.booking.bookingId}/resend-ticket`).set(...auth(anna)).expect(403);
  });

  it('exports the bookings with the same filters, as CSV', async () => {
    const res = await client(context)
      .get(`${API}/admin/bookings/export?search=${tag}&status=CONFIRMED`)
      .set(...auth(admin))
      .buffer(true)
      .expect(200);
    expect(res.headers['content-type']).toContain('text/csv');
    expect(res.headers['content-disposition']).toContain('bookings');
    const text = res.text ?? Buffer.from(res.body as Buffer).toString('utf8');
    expect(text).toContain('PNR');
    expect(text).toContain(`Meera ${tag}`);
    expect(text).not.toContain(`Nikhil ${tag}`);
  });

  it('lists payments with the booking they are for, and exports them', async () => {
    const paymentsRes = await client(context).get(`${API}/admin/payments?search=Meera ${tag}&status=SUCCESS`).set(...auth(admin)).expect(200);
    const page = {
      items: dataOf<Array<{ pnr: string; customerName: string; status: string; amountPaise: number; gateway: string }>>(paymentsRes),
      total: (paymentsRes.body as { meta: { total: number } }).meta.total,
    };
    expect(page.total).toBe(1);
    expect(page.items[0]).toMatchObject({ customerName: `Meera ${tag}`, status: 'SUCCESS', amountPaise: 94_150, gateway: 'development' });
    const detail = dataOf<{ id: string; refunds: unknown[] }>(
      await client(context).get(`${API}/admin/payments/${(page.items[0] as unknown as { id: string }).id}`).set(...auth(admin)).expect(200),
    );
    expect(detail.refunds).toEqual([]);
    const csv = await client(context).get(`${API}/admin/payments/export?search=${tag}`).set(...auth(admin)).buffer(true).expect(200);
    expect(csv.headers['content-type']).toContain('text/csv');
    await client(context).get(`${API}/admin/payments/${new Types.ObjectId().toHexString()}`).set(...auth(admin)).expect(404);
    await client(context).get(`${API}/admin/payments?refundDue=true&search=${tag}`).set(...auth(admin)).expect(200);
  });
});
