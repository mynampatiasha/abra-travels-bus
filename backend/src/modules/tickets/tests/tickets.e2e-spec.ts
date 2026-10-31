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
import { AppConfigService } from '../../../config/app-config.service';
import { seedAndSignIn } from '../../rbac/tests/rbac-e2e.harness';
import { type BookingView } from '../../bookings/bookings_customer.service';
import { type PaymentOrderView } from '../../payments/payments_customer.service';
import { buildQr, readQr, type TicketView } from '../tickets_customer.service';

const API = '/api/v1';
interface Caller { tokens: Tokens }

describe('Tickets e2e (abra_supply_test)', () => {
  let context: AuthTestContext;
  let tripId: Types.ObjectId;
  let anna: Caller;
  let ben: Caller;
  const operatorId = new Types.ObjectId();
  const hyd = new Types.ObjectId();
  const blr = new Types.ObjectId();
  const boardingId = new Types.ObjectId();
  const droppingId = new Types.ObjectId();
  const secret = 'x'.repeat(40);

  const auth = (caller: Caller) => bearer(caller.tokens);
  const seats = () => context.connection.collection('seat_inventory');

  const bookAndPay = async (caller: Caller, seatIds: string[], pay: boolean): Promise<BookingView> => {
    const h = dataOf<{ lockId: string }>(
      await client(context)
        .post(`${API}/trips/${tripId.toHexString()}/seat-locks`)
        .set(...auth(caller))
        .send({ seatIds, boardingPointId: boardingId.toHexString(), droppingPointId: droppingId.toHexString() })
        .expect(201),
    );
    const booking = dataOf<BookingView>(
      await client(context)
        .post(`${API}/bookings`)
        .set(...auth(caller))
        .send({
          lockId: h.lockId,
          passengers: seatIds.map((seatId, i) => ({ seatId, name: i === 0 ? 'Asha Rao' : 'Ravi Rao', age: 31 + i, gender: i === 0 ? 'FEMALE' : 'MALE' })),
          contact: { mobile: '9876543210', email: 'asha@example.com' },
        })
        .expect(201),
    );
    if (pay) {
      const order = dataOf<PaymentOrderView>(
        await client(context).post(`${API}/payments/orders`).set(...auth(caller)).send({ bookingId: booking.bookingId }).expect(201),
      );
      await client(context)
        .post(`${API}/payments/${order.paymentId}/dev-complete`)
        .set(...auth(caller))
        .send({ outcome: 'success' })
        .expect(200);
    }
    return booking;
  };
  const ticket = (caller: Caller, bookingId: string) =>
    client(context).get(`${API}/bookings/${bookingId}/ticket`).set(...auth(caller));

  beforeAll(async () => {
    context = await createAuthTestApp({ MONGODB_URI: 'mongodb://localhost:27017/abra_supply_test?directConnection=true' });
    anna = await seedAndSignIn(context, { roleKeys: ['CUSTOMER'] });
    ben = await seedAndSignIn(context, { roleKeys: ['CUSTOMER'] });
    const now = new Date();
    const departureAt = new Date(Date.now() + 3 * 86_400_000);
    const arrivalAt = new Date(departureAt.getTime() + 9 * 3_600_000);
    tripId = new Types.ObjectId();
    await context.connection.collection('cities').insertMany([
      { _id: hyd, name: 'Hyderabad', slug: `hyd-${tripId.toHexString()}`, countryCode: 'IN', isActive: true, createdAt: now, updatedAt: now },
      { _id: blr, name: 'Bengaluru', slug: `blr-${tripId.toHexString()}`, countryCode: 'IN', isActive: true, createdAt: now, updatedAt: now },
    ]);
    await context.connection.collection('operators').insertOne({
      _id: operatorId,
      companyName: 'Demo Travels',
      displayName: 'Demo Travels',
      status: 'ACTIVE',
      contact: { supportPhone: '9000011111' },
    });
    await context.connection.collection('trips').insertOne({
      _id: tripId,
      operatorId,
      status: 'SCHEDULED',
      travelDate: departureAt.toISOString().slice(0, 10),
      timezone: 'Asia/Kolkata',
      departureAt,
      arrivalAt,
      durationMinutes: 540,
      originCityId: hyd,
      destinationCityId: blr,
      bus: { berthType: 'SEATER', busTypeName: 'AC Seater' },
      boardingPoints: [{ pointId: boardingId, cityId: hyd, name: 'Ameerpet Metro', address: 'Ameerpet, Hyderabad', time: departureAt }],
      droppingPoints: [{ pointId: droppingId, cityId: blr, name: 'Majestic', address: 'Majestic, Bengaluru', time: arrivalAt }],
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
    await context.connection.collection('bookings').deleteMany({ tripId });
    await context.connection.collection('seat_lock_groups').deleteMany({ tripId });
    await seats().deleteMany({ tripId });
    await context.connection.collection('trips').deleteMany({ _id: tripId });
    await context.connection.collection('operators').deleteMany({ _id: operatorId });
    await context.connection.collection('cities').deleteMany({ _id: { $in: [hyd, blr] } });
    await context.close();
  }, 60_000);

  it('gives the ticket of a paid booking with everything the e-ticket shows', async () => {
    const booking = await bookAndPay(anna, ['1', '2'], true);
    const t = dataOf<TicketView>(await ticket(anna, booking.bookingId).expect(200));
    expect(t).toMatchObject({
      bookingId: booking.bookingId,
      pnr: booking.pnr,
      status: 'CONFIRMED',
      operatorName: 'Demo Travels',
      operatorPhone: '9000011111',
      busTypeName: 'AC Seater',
      originName: 'Hyderabad',
      destinationName: 'Bengaluru',
      timezone: 'Asia/Kolkata',
      durationMinutes: 540,
      paidPaise: 183_400,
      gstPaise: 8_500,
      convenienceFeePaise: 4_900,
      currency: 'INR',
      contactEmail: 'asha@example.com',
    });
    expect(t.passengers).toEqual([
      { name: 'Asha Rao', seatId: '1', age: 31, gender: 'FEMALE' },
      { name: 'Ravi Rao', seatId: '2', age: 32, gender: 'MALE' },
    ]);
    expect(t.boarding).toMatchObject({ name: 'Ameerpet Metro', address: 'Ameerpet, Hyderabad' });
    expect(t.dropping).toMatchObject({ name: 'Majestic' });
  });

  it('carries a signed QR that proves the booking and the PNR, and refuses a made-up one', async () => {
    const booking = await bookAndPay(anna, ['3'], true);
    const t = dataOf<TicketView>(await ticket(anna, booking.bookingId).expect(200));
    expect(t.qrPayload).toMatch(/^ABR1\.[0-9a-f]{24}\.ABR[A-Z2-9]{7}\.[0-9a-f]{24}$/);
    // The code from the API reads back with the platform secret
    const real = context.app.get(AppConfigService).get('OTP_HASH_SECRET');
    expect(readQr(real, t.qrPayload)).toEqual({ bookingId: booking.bookingId, pnr: booking.pnr });
    // The scanner side: a code made with the same secret reads back; a changed one does not
    const code = buildQr(secret, booking.bookingId, booking.pnr);
    expect(readQr(secret, code)).toEqual({ bookingId: booking.bookingId, pnr: booking.pnr });
    expect(readQr(secret, code.replace(booking.pnr, 'ABRAAAAAAA'))).toBeNull();
    expect(readQr('y'.repeat(40), code)).toBeNull();
    expect(readQr(secret, 'hello')).toBeNull();
    expect(readQr(secret, `ABR1.nothex.${booking.pnr}.abc`)).toBeNull();
  });

  it('gives the ticket as a PDF for the owner after payment, and for nobody else', async () => {
    const paid = await bookAndPay(anna, ['6'], true);
    const pdf = await client(context)
      .get(`${API}/bookings/${paid.bookingId}/ticket/pdf`)
      .set(...auth(anna))
      .buffer(true)
      .parse((res, done) => {
        const parts: Buffer[] = [];
        res.on('data', (chunk: Buffer) => parts.push(chunk));
        res.on('end', () => done(null, Buffer.concat(parts)));
      })
      .expect(200);
    expect(pdf.headers['content-type']).toContain('application/pdf');
    expect(pdf.headers['content-disposition']).toContain(`abra-ticket-${paid.pnr}.pdf`);
    expect((pdf.body as Buffer).subarray(0, 5).toString('latin1')).toBe('%PDF-');
    await client(context).get(`${API}/bookings/${paid.bookingId}/ticket/pdf`).set(...auth(ben)).expect(404);
    await client(context).get(`${API}/bookings/${paid.bookingId}/ticket/pdf`).expect(401);
  }, 60_000);

  it('is only for the owner, and only once the payment is done', async () => {
    const unpaid = await bookAndPay(anna, ['4'], false);
    const res = await ticket(anna, unpaid.bookingId).expect(409);
    expect(errorCodeOf(res)).toBe('INVALID_STATE_TRANSITION');
    const paid = await bookAndPay(anna, ['5'], true);
    await ticket(ben, paid.bookingId).expect(404);
    await ticket(anna, 'not-an-id').expect(404);
    await client(context).get(`${API}/bookings/${paid.bookingId}/ticket`).expect(401);
  });
});
