import { Body, Controller, Delete, Get, Headers, HttpCode, Param, Post } from '@nestjs/common';
import { ApiOperation, ApiResponse, ApiTags } from '@nestjs/swagger';
import { z } from 'zod';
import { AuthenticatedOnly } from '../../common/decorators/authenticated-only.decorator';
import { CurrentActor } from '../../common/decorators/current-actor.decorator';
import { PublicEndpoint } from '../../common/decorators/public-endpoint.decorator';
import { ZodApiBody } from '../../common/openapi/zod-api-body';
import { createZodDto } from '../../common/pipes/zod-dto.factory';
import { type AuthenticatedUserActor } from '../../common/request-context/request-actor';
import {
  MAX_SEATS_PER_HOLD,
  type SeatLockView,
  SeatLocksService,
  type SeatMapView,
} from './seat_locks_customer.service';

class SeatLockBodyDto extends createZodDto(
  z.object({
    seatIds: z.array(z.string().trim().min(1).max(20)).min(1).max(MAX_SEATS_PER_HOLD),
    boardingPointId: z.string().trim().max(40).optional(),
    droppingPointId: z.string().trim().max(40).optional(),
  }),
) {}

/** The seats of a trip and which are free. Public: nothing personal in or out. */
@ApiTags('seats')
@PublicEndpoint()
@Controller('trips')
export class SeatMapController {
  constructor(private readonly seatLocks: SeatLocksService) {}

  @Get(':tripId/seats')
  @ApiOperation({
    summary: 'The seat map of a trip',
    description:
      'Public. Every seat with its place (deck, row, column), its price in paise and whether it ' +
      'can be chosen: AVAILABLE, BOOKED (sold or held by someone else), BLOCKED (not for sale). ' +
      'A hold that has run out shows the seat as AVAILABLE. Only trips on sale have a map.',
  })
  @ApiResponse({ status: 200, description: 'The seat map' })
  @ApiResponse({ status: 404, description: 'RESOURCE_NOT_FOUND (the trip is not on sale)' })
  seatMap(@Param('tripId') tripId: string): Promise<SeatMapView> {
    return this.seatLocks.seatMap(tripId);
  }
}

/** Holding seats for 10 minutes while the customer fills in the booking. */
@ApiTags('seats')
@AuthenticatedOnly()
@Controller()
export class SeatLocksController {
  constructor(private readonly seatLocks: SeatLocksService) {}

  @Post('trips/:tripId/seat-locks')
  @ZodApiBody(SeatLockBodyDto)
  @ApiOperation({
    summary: 'Hold seats for 10 minutes',
    description:
      'Customer. Up to 6 seats of one trip, with the chosen boarding and dropping points. All or ' +
      'nothing: if one seat was just taken, nothing is held (SEAT_NOT_AVAILABLE, details.seatId). ' +
      'Asking again for seats the customer already holds extends the hold and releases the ' +
      'others. The same Idempotency-Key returns the same hold.',
  })
  @ApiResponse({ status: 201, description: 'The hold: lockId, seatIds, expiresAt' })
  @ApiResponse({ status: 409, description: 'SEAT_NOT_AVAILABLE' })
  lock(
    @CurrentActor() actor: AuthenticatedUserActor,
    @Param('tripId') tripId: string,
    @Body() body: SeatLockBodyDto,
    @Headers('idempotency-key') idempotencyKey?: string,
  ): Promise<SeatLockView> {
    return this.seatLocks.lock(actor, tripId, body, idempotencyKey?.trim() || undefined);
  }

  @Delete('seat-locks/:lockId')
  @HttpCode(200)
  @ApiOperation({
    summary: 'Let go of a hold',
    description: 'Customer. Puts the held seats back on sale at once. Only the holder can do it.',
  })
  release(
    @CurrentActor() actor: AuthenticatedUserActor,
    @Param('lockId') lockId: string,
  ): Promise<{ released: boolean }> {
    return this.seatLocks.release(actor, lockId);
  }
}
