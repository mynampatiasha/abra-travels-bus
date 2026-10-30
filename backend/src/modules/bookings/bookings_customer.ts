import { Body, Controller, Get, Param, Post, Query } from '@nestjs/common';
import { ApiOperation, ApiResponse, ApiTags } from '@nestjs/swagger';
import { z } from 'zod';
import { AuthenticatedOnly } from '../../common/decorators/authenticated-only.decorator';
import { CurrentActor } from '../../common/decorators/current-actor.decorator';
import { PublicEndpoint } from '../../common/decorators/public-endpoint.decorator';
import { ZodApiBody } from '../../common/openapi/zod-api-body';
import { createZodDto } from '../../common/pipes/zod-dto.factory';
import { type AuthenticatedUserActor } from '../../common/request-context/request-actor';
import { type BookingListItem, type BookingView, BookingsCustomerService } from './bookings_customer.service';

class CreateBookingDto extends createZodDto(
  z.object({
    lockId: z.string().trim().min(1).max(60),
    passengers: z
      .array(
        z.object({
          seatId: z.string().trim().min(1).max(20),
          name: z.string().trim().min(2).max(80),
          age: z.number().int().min(1).max(120),
          gender: z.enum(['MALE', 'FEMALE', 'OTHER']),
        }),
      )
      .min(1)
      .max(6),
    contact: z.object({
      mobile: z.string().trim().regex(/^[6-9]\d{9}$/, 'Enter a 10 digit mobile number'),
      email: z.string().trim().toLowerCase().email().max(120),
    }),
    gst: z
      .object({
        gstin: z.string().trim().toUpperCase().regex(/^\d{2}[A-Z]{5}\d{4}[A-Z][A-Z\d]Z[A-Z\d]$/, 'Enter a valid GSTIN'),
        company: z.string().trim().min(2).max(120),
      })
      .optional(),
    couponCode: z.string().trim().max(40).optional(),
    expectedAmountPaise: z.number().int().min(0).optional(),
  }),
) {}

class ListQueryDto extends createZodDto(
  z.object({
    bucket: z.enum(['upcoming', 'completed', 'cancelled']).default('upcoming'),
    page: z.coerce.number().int().min(1).max(10_000).default(1),
    pageSize: z.coerce.number().int().min(1).max(50).default(20),
  }),
) {}

/** The cancellation policy a customer sees before booking. Public: nothing personal in it. */
@ApiTags('bookings')
@PublicEndpoint()
@Controller('trips')
export class TripPolicyController {
  constructor(private readonly service: BookingsCustomerService) {}

  @Get(':tripId/policy')
  @ApiOperation({
    summary: 'What cancelling costs',
    description: 'Public. The refund windows from the admin refund slabs: from X hours before departure to Y hours, Z percent back.',
  })
  policy(@Param('tripId') _tripId: string) {
    return this.service.policyWindows();
  }
}

/** Booking held seats and reading the booking back. */
@ApiTags('bookings')
@AuthenticatedOnly()
@Controller('bookings')
export class BookingsCustomerController {
  constructor(private readonly service: BookingsCustomerService) {}

  @Post()
  @ZodApiBody(CreateBookingDto)
  @ApiOperation({
    summary: 'Book held seats',
    description:
      'Customer. Takes the hold (lockId) and one passenger per held seat. The server reads the ' +
      'prices itself and returns the booking in PAYMENT_PENDING with the amount to pay. Sending ' +
      'the same lockId again returns the same booking. If expectedAmountPaise is sent and differs, ' +
      'PAYMENT_AMOUNT_MISMATCH tells the new amount.',
  })
  @ApiResponse({ status: 201, description: 'The booking' })
  @ApiResponse({ status: 409, description: 'SEAT_LOCK_EXPIRED' })
  @ApiResponse({ status: 422, description: 'PAYMENT_AMOUNT_MISMATCH' })
  create(@CurrentActor() actor: AuthenticatedUserActor, @Body() body: CreateBookingDto): Promise<BookingView> {
    return this.service.create(actor, body);
  }

  @Get()
  @ApiOperation({
    summary: 'My bookings',
    description: 'Customer. bucket is upcoming (default), completed or cancelled. A booking still waiting for payment is not listed.',
  })
  list(@CurrentActor() actor: AuthenticatedUserActor, @Query() query: ListQueryDto) {
    return this.service.list(actor, query);
  }

  @Get(':bookingId')
  @ApiOperation({ summary: 'One of my bookings', description: 'Customer. Only the owner can read a booking.' })
  read(@CurrentActor() actor: AuthenticatedUserActor, @Param('bookingId') bookingId: string): Promise<BookingView> {
    return this.service.read(actor, bookingId);
  }
}
