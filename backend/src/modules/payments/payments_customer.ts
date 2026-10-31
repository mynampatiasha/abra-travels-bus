import { Body, Controller, HttpCode, Param, Post } from '@nestjs/common';
import { ApiOperation, ApiResponse, ApiTags } from '@nestjs/swagger';
import { z } from 'zod';
import { AuthenticatedOnly } from '../../common/decorators/authenticated-only.decorator';
import { CurrentActor } from '../../common/decorators/current-actor.decorator';
import { ZodApiBody } from '../../common/openapi/zod-api-body';
import { createZodDto } from '../../common/pipes/zod-dto.factory';
import { type AuthenticatedUserActor } from '../../common/request-context/request-actor';
import {
  type PaymentOrderView,
  type PaymentResultView,
  PaymentsCustomerService,
  type ShareLinkView,
} from './payments_customer.service';

class CreateOrderDto extends createZodDto(z.object({ bookingId: z.string().trim().min(1).max(40) })) {}
class CallbackDto extends createZodDto(
  z.object({
    gatewayPaymentId: z.string().trim().min(1).max(80),
    signature: z.string().trim().min(1).max(200),
  }),
) {}
class FailedDto extends createZodDto(z.object({ reason: z.string().trim().min(1).max(80).default('CANCELLED') })) {}
class DevCompleteDto extends createZodDto(z.object({ outcome: z.enum(['success', 'failure']) })) {}

/** Paying for a booking. */
@ApiTags('payments')
@AuthenticatedOnly()
@Controller('payments')
export class PaymentsCustomerController {
  constructor(private readonly payments: PaymentsCustomerService) {}

  @Post('orders')
  @ZodApiBody(CreateOrderDto)
  @ApiOperation({
    summary: 'Start paying for a booking',
    description:
      'Customer. Makes the payment order for a booking that waits for payment: the amount is the ' +
      "booking's, never the app's. Asking again while an order is open returns the same order.",
  })
  @ApiResponse({ status: 201, description: 'The order: paymentId, gatewayOrderId, keyId, amountPaise' })
  createOrder(@CurrentActor() actor: AuthenticatedUserActor, @Body() body: CreateOrderDto): Promise<PaymentOrderView> {
    return this.payments.createOrder(actor, body.bookingId);
  }

  @Post(':paymentId/share-link')
  @HttpCode(200)
  @ApiOperation({
    summary: 'A link for someone else to pay',
    description:
      'Customer. A link that anyone can open to pay this order, to share by WhatsApp or any app. One link for each ' +
      'payment (asking again returns it). It stops working when the seat hold ends (Razorpay keeps a link at least ' +
      '15 minutes). A payment made through it confirms the booking like any other.',
  })
  shareLink(
    @CurrentActor() actor: AuthenticatedUserActor,
    @Param('paymentId') paymentId: string,
  ): Promise<ShareLinkView> {
    return this.payments.shareLink(actor, paymentId);
  }

  @Post(':paymentId/client-callback')
  @HttpCode(200)
  @ZodApiBody(CallbackDto)
  @ApiOperation({
    summary: 'The app reports a payment',
    description:
      'Customer. The gateway signature proves the payment; then the booking is confirmed and the ' +
      'seats are booked. Reporting the same payment twice changes nothing.',
  })
  callback(
    @CurrentActor() actor: AuthenticatedUserActor,
    @Param('paymentId') paymentId: string,
    @Body() body: CallbackDto,
  ): Promise<PaymentResultView> {
    return this.payments.clientCallback(actor, paymentId, body);
  }

  @Post(':paymentId/failed')
  @HttpCode(200)
  @ZodApiBody(FailedDto)
  @ApiOperation({
    summary: 'The app reports a failed or cancelled payment',
    description: 'Customer. The booking fails, the seats go back on sale and a coupon use is given back.',
  })
  failed(
    @CurrentActor() actor: AuthenticatedUserActor,
    @Param('paymentId') paymentId: string,
    @Body() body: FailedDto,
  ): Promise<PaymentResultView> {
    return this.payments.clientFailed(actor, paymentId, body.reason);
  }

  @Post(':paymentId/dev-complete')
  @HttpCode(200)
  @ZodApiBody(DevCompleteDto)
  @ApiOperation({
    summary: 'Finish a test payment (development gateway only)',
    description: 'Customer. Only when PAYMENT_GATEWAY=development; any other gateway answers 404.',
  })
  devComplete(
    @CurrentActor() actor: AuthenticatedUserActor,
    @Param('paymentId') paymentId: string,
    @Body() body: DevCompleteDto,
  ): Promise<PaymentResultView> {
    return this.payments.developmentComplete(actor, paymentId, body.outcome);
  }
}
