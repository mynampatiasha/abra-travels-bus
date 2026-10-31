import { Module } from '@nestjs/common';
import { MongooseModule } from '@nestjs/mongoose';
import { RbacModule } from '../rbac/rbac.module';
import { UsersModule } from '../users/users.module';
import { SupportAdminController } from './support_admin_manage';
import {
  SUPPORT_AGENT_MODEL,
  SUPPORT_CANNED_MODEL,
  SUPPORT_REPLY_MODEL,
  SUPPORT_TICKET_MODEL,
  SupportAdminService,
  supportAgentSchema,
  supportCannedSchema,
  supportReplySchema,
  supportTicketSchema,
} from './support_admin_manage.service';
import { SupportCustomerController } from './support_customer';
import { SupportCustomerService } from './support_customer.service';

/**
 * `support`: tickets raised by customers and answered by staff. Staff work under
 * `/admin/support`; a customer sees only their own under `/customer/support`.
 */
@Module({
  imports: [
    MongooseModule.forFeature([
      { name: SUPPORT_TICKET_MODEL, schema: supportTicketSchema },
      { name: SUPPORT_REPLY_MODEL, schema: supportReplySchema },
      { name: SUPPORT_CANNED_MODEL, schema: supportCannedSchema },
      { name: SUPPORT_AGENT_MODEL, schema: supportAgentSchema },
    ]),
    RbacModule,
    UsersModule,
  ],
  controllers: [SupportAdminController, SupportCustomerController],
  providers: [SupportAdminService, SupportCustomerService],
})
export class SupportModule {}
