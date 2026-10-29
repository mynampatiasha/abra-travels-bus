import { Injectable } from '@nestjs/common';
import { InjectConnection, InjectModel } from '@nestjs/mongoose';
import { type Connection, type Model, Types } from 'mongoose';
import { hmacSha256Hex, safeEqualHex } from '../../common/crypto/secure-hash';
import { ApiException } from '../../common/errors/api-exception';
import { type AuthenticatedUserActor } from '../../common/request-context/request-actor';
import { AppConfigService } from '../../config/app-config.service';
import { BOOKING_MODEL, type BookingRow } from '../bookings/bookings_customer.service';

/*
 * The ticket of a confirmed booking: everything the e-ticket shows, and the QR text the
 * conductor's scanner reads. The QR carries the booking and the PNR with a signature, so a made-up
 * code is refused at check-in without looking anything up.
 */

const QR_PREFIX = 'ABR1';
const TICKET_STATUSES = ['CONFIRMED', 'PARTIALLY_CANCELLED', 'COMPLETED'];

export interface TicketPointView {
  name: string;
  time: string;
  address?: string;
  landmark?: string;
}

export interface TicketView {
  bookingId: string;
  tripId: string;
  pnr: string;
  status: string;
  operatorName: string;
  operatorPhone?: string;
  busTypeName: string;
  originName: string;
  destinationName: string;
  travelDate: string;
  timezone: string;
  departureAt: string;
  arrivalAt: string;
  durationMinutes: number;
  passengers: Array<{ name: string; seatId: string; age: number; gender: string }>;
  boarding: TicketPointView;
  dropping: TicketPointView;
  baseFarePaise: number;
  gstPaise: number;
  convenienceFeePaise: number;
  discountPaise: number;
  paidPaise: number;
  currency: string;
  contactEmail: string;
  qrPayload: string;
}

interface TripPoint {
  pointId: Types.ObjectId;
  cityId?: Types.ObjectId;
  name: string;
  address?: string;
  landmark?: string;
  time: Date;
}

interface TripDoc {
  operatorId?: Types.ObjectId;
  travelDate?: string;
  timezone?: string;
  departureAt: Date;
  arrivalAt?: Date;
  durationMinutes?: number;
  originCityId?: Types.ObjectId;
  destinationCityId?: Types.ObjectId;
  bus?: { busTypeName?: string; name?: string };
  boardingPoints?: TripPoint[];
  droppingPoints?: TripPoint[];
}

export function qrSignature(secret: string, bookingId: string, pnr: string): string {
  return hmacSha256Hex(`${secret}:ticket-qr`, `${bookingId}|${pnr}`).slice(0, 24);
}

export function buildQr(secret: string, bookingId: string, pnr: string): string {
  return `${QR_PREFIX}.${bookingId}.${pnr}.${qrSignature(secret, bookingId, pnr)}`;
}

/** The booking and PNR a scanned code carries, or null when the code is not one of ours. */
export function readQr(secret: string, text: string): { bookingId: string; pnr: string } | null {
  const parts = text.trim().split('.');
  if (parts.length !== 4 || parts[0] !== QR_PREFIX) return null;
  const [, bookingId = '', pnr = '', signature = ''] = parts;
  if (!Types.ObjectId.isValid(bookingId)) return null;
  const expected = qrSignature(secret, bookingId, pnr);
  return safeEqualHex(Buffer.from(expected).toString('hex'), Buffer.from(signature).toString('hex'))
    ? { bookingId, pnr }
    : null;
}

@Injectable()
export class TicketsCustomerService {
  constructor(
    @InjectConnection() private readonly connection: Connection,
    @InjectModel(BOOKING_MODEL) private readonly bookings: Model<BookingRow>,
    private readonly config: AppConfigService,
  ) {}

  async ticket(actor: AuthenticatedUserActor, bookingIdText: string): Promise<TicketView> {
    if (!Types.ObjectId.isValid(bookingIdText)) throw new ApiException('RESOURCE_NOT_FOUND', 'Ticket not found.');
    const booking = await this.bookings
      .findOne({ _id: new Types.ObjectId(bookingIdText), customerId: new Types.ObjectId(actor.userId) })
      .lean<BookingRow & { _id: Types.ObjectId }>()
      .exec();
    if (!booking) throw new ApiException('RESOURCE_NOT_FOUND', 'Ticket not found.');
    if (!TICKET_STATUSES.includes(booking.status)) {
      throw new ApiException('INVALID_STATE_TRANSITION', 'The ticket is ready once the payment is done.');
    }

    const trip = await this.connection.collection<TripDoc>('trips').findOne({ _id: booking.tripId });
    if (!trip) throw new ApiException('RESOURCE_NOT_FOUND', 'Ticket not found.');
    const operator = trip.operatorId
      ? await this.connection
          .collection<{ displayName?: string; companyName?: string; contact?: { supportPhone?: string } }>('operators')
          .findOne({ _id: trip.operatorId })
      : null;
    const cityIds = [trip.originCityId, trip.destinationCityId].filter((id): id is Types.ObjectId => !!id);
    const cities = await this.connection
      .collection<{ _id: Types.ObjectId; name: string }>('cities')
      .find({ _id: { $in: cityIds } })
      .toArray();
    const cityName = (id?: Types.ObjectId) => cities.find((c) => id && c._id.equals(id))?.name ?? '';

    const point = (list: TripPoint[] | undefined, id?: string): TicketPointView => {
      const found = (list ?? []).find((p) => p.pointId.toHexString() === id) ?? (list ?? [])[0];
      if (!found) return { name: '', time: trip.departureAt.toISOString() };
      return {
        name: found.name,
        time: found.time.toISOString(),
        ...(found.address ? { address: found.address } : {}),
        ...(found.landmark ? { landmark: found.landmark } : {}),
      };
    };
    const bookingId = booking._id.toHexString();
    const arrivalAt = trip.arrivalAt ?? trip.departureAt;
    return {
      bookingId,
      tripId: booking.tripId.toHexString(),
      pnr: booking.pnr,
      status: booking.status,
      operatorName: operator?.displayName ?? operator?.companyName ?? 'Operator',
      ...(operator?.contact?.supportPhone ? { operatorPhone: operator.contact.supportPhone } : {}),
      busTypeName: trip.bus?.busTypeName ?? trip.bus?.name ?? '',
      originName: cityName(trip.originCityId),
      destinationName: cityName(trip.destinationCityId),
      travelDate: trip.travelDate ?? trip.departureAt.toISOString().slice(0, 10),
      timezone: trip.timezone ?? 'Asia/Kolkata',
      departureAt: trip.departureAt.toISOString(),
      arrivalAt: arrivalAt.toISOString(),
      durationMinutes: trip.durationMinutes ?? Math.round((arrivalAt.getTime() - trip.departureAt.getTime()) / 60_000),
      passengers: booking.passengers.map((p) => ({ name: p.name, seatId: p.seatId, age: p.age, gender: p.gender })),
      boarding: point(trip.boardingPoints, booking.boardingPointId),
      dropping: point(trip.droppingPoints, booking.droppingPointId),
      baseFarePaise: booking.baseFarePaise,
      gstPaise: booking.gstPaise ?? 0,
      convenienceFeePaise: booking.convenienceFeePaise ?? 0,
      discountPaise: booking.discountPaise,
      paidPaise: booking.amountPaise,
      currency: booking.currency,
      contactEmail: booking.contact.email,
      qrPayload: buildQr(this.config.get('OTP_HASH_SECRET'), bookingId, booking.pnr),
    };
  }
}
