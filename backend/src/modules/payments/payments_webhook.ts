import { Controller, Headers, HttpCode, Post, Req } from '@nestjs/common';
import { ApiOperation, ApiTags } from '@nestjs/swagger';
import { type Request } from 'express';
import { PublicEndpoint } from '../../common/decorators/public-endpoint.decorator';
import { PaymentsCustomerService } from './payments_customer.service';

/** Where the payment gateway reports what happened to a payment, even when the customer closed the app. */
@ApiTags('payments')
@PublicEndpoint()
@Controller('webhooks/payments')
export class PaymentsWebhookController {
  constructor(private readonly payments: PaymentsCustomerService) {}

  @Post('razorpay')
  @HttpCode(200)
  @ApiOperation({
    summary: 'Payment gateway webhook',
    description:
      'Public, but every call must carry a valid signature over the exact body (X-Razorpay-Signature). ' +
      'A bad signature is refused (401). An event seen before is answered 200 and does nothing. ' +
      'A captured payment confirms the booking through the same checks as the app report.',
  })
  receive(
    @Req() request: Request & { rawBody?: Buffer },
    @Headers('x-razorpay-signature') signature?: string,
    @Headers('x-razorpay-event-id') eventId?: string,
  ): Promise<{ received: true; outcome: string }> {
    return this.payments.handleWebhook(request.rawBody, signature, eventId);
  }
}
