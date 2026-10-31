import { type Connection, Types } from 'mongoose';
import { type BookingRow } from './bookings_customer.service';

/** What the confirmation message and the operator notice say, in words (one place for the payment and the admin resend). */
export async function confirmationPayload(
  connection: Connection,
  booking: BookingRow & { _id: Types.ObjectId },
): Promise<Record<string, unknown>> {
    const trip = await connection
      .collection<{
        operatorId?: Types.ObjectId;
        departureAt?: Date;
        timezone?: string;
        originCityId?: Types.ObjectId;
        destinationCityId?: Types.ObjectId;
        boardingPoints?: Array<{ pointId: Types.ObjectId; name: string }>;
      }>('trips')
      .findOne({ _id: booking.tripId });
    const cityIds = [trip?.originCityId, trip?.destinationCityId].filter((id): id is Types.ObjectId => !!id);
    const cities = await connection
      .collection<{ _id: Types.ObjectId; name: string }>('cities')
      .find({ _id: { $in: cityIds } })
      .toArray();
    const cityName = (id?: Types.ObjectId) => cities.find((c) => id && c._id.equals(id))?.name ?? '';
    const route = [cityName(trip?.originCityId), cityName(trip?.destinationCityId)].filter(Boolean).join(' to ');
    const boarding = (trip?.boardingPoints ?? []).find((p) => p.pointId.toHexString() === booking.boardingPointId)
      ?? (trip?.boardingPoints ?? [])[0];
    const departureText = trip?.departureAt
      ? new Intl.DateTimeFormat('en-IN', {
          day: 'numeric',
          month: 'short',
          hour: 'numeric',
          minute: '2-digit',
          hour12: true,
          timeZone: trip.timezone ?? 'Asia/Kolkata',
        }).format(trip.departureAt)
      : '';
    const rupees = booking.amountPaise / 100;
    return {
      bookingId: booking._id.toHexString(),
      customerId: booking.customerId.toHexString(),
      ...(trip?.operatorId ? { operatorId: trip.operatorId.toHexString() } : {}),
      pnr: booking.pnr,
      route,
      departureText,
      seatsText: booking.passengers.map((p) => p.seatId).join(', '),
      boardingPoint: boarding?.name ?? '',
      amountText: `Rs ${Number.isInteger(rupees) ? rupees.toLocaleString('en-IN') : rupees.toLocaleString('en-IN', { minimumFractionDigits: 2 })}`,
      contactName: booking.passengers[0]?.name ?? 'Customer',
      // WhatsApp needs the country code: the booking holds the ten digit Indian number
      contactPhone: `+91${booking.contact.mobile}`,
      contactEmail: booking.contact.email,
    };
  }
