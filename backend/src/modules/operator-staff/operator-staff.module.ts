import { Module } from '@nestjs/common';
import { MongooseModule } from '@nestjs/mongoose';
import { AuditLogsModule } from '../audit-logs/audit-logs.module';
import { AuthenticationModule } from '../authentication/authentication.module';
import { CatalogueSharedModule } from '../catalogue-shared/catalogue_shared_manage';
import { MessagesModule } from '../messages/messages_admin_manage';
import { RbacModule } from '../rbac/rbac.module';
import {
  STAFF_INVITATION_MODEL,
  staffInvitationSchema,
} from '../rbac/staff_admin_manage.service';
import { AUTH_SESSION_MODEL, authSessionSchema } from '../sessions/schemas/auth-session.schema';
import { SessionsModule } from '../sessions/sessions.module';
import { USER_MODEL, userSchema } from '../users/schemas/user.schema';
import { UsersModule } from '../users/users.module';
import {
  PortalUsersExportController,
  StaffClientManageController,
} from './staff_client_manage';
import { StaffClientManageService } from './staff_client_manage.service';

/**
 * operator-staff — Supply domain (documentation/architecture.md §5).
 * Operator portal users management (master-plan E.20, client/users).
 * Crew (operator_crew) lives in OperatorStaffModule, crew_client_manage.ts.
 */
@Module({
  imports: [
    MongooseModule.forFeature([
      { name: STAFF_INVITATION_MODEL, schema: staffInvitationSchema },
      { name: USER_MODEL, schema: userSchema },
      { name: AUTH_SESSION_MODEL, schema: authSessionSchema },
    ]),
    UsersModule,
    RbacModule,
    AuditLogsModule,
    SessionsModule,
    MessagesModule,
    CatalogueSharedModule,
    AuthenticationModule,
  ],
  controllers: [PortalUsersExportController, StaffClientManageController],
  providers: [StaffClientManageService],
  exports: [StaffClientManageService],
})
export class OperatorPortalUsersModule {}
