import { Module } from '@nestjs/common';
import { MongooseModule } from '@nestjs/mongoose';
import { EmailModule } from '../../integrations/email/email.module';
import { PushModule } from '../../integrations/push/push.module';
import { WhatsAppModule } from '../../integrations/whatsapp/whatsapp.module';
import { AuthenticationModule } from '../authentication/authentication.module';
import { RbacModule } from '../rbac/rbac.module';
import { UsersModule } from '../users/users.module';
import { NotificationsController } from './controllers/notifications.controller';
import { RealtimeEmitter } from './realtime/realtime';
import {
  NotificationRepository,
  PushTokenRepository,
} from './repositories/notification.repository';
import {
  NOTIFICATION_MODEL,
  PUSH_TOKEN_MODEL,
  notificationSchema,
  pushTokenSchema,
} from './schemas/notification.schema';
import { NotificationDispatcher } from './services/notification-dispatcher.service';
import { NotificationsService } from './services/notifications.service';
import { OnboardingNotificationHandler } from './services/onboarding-notification.handler';

/**
 * `notifications` — Channels domain (documentation/architecture.md §5). Tells people what
 * happened: instantly when the app is open (Socket.IO), by push when it is closed (Firebase),
 * and by email and WhatsApp as guaranteed fallbacks. The in-app list is the record; the channels
 * only announce it (documentation/client-onboarding.md §4).
 */
@Module({
  imports: [
    MongooseModule.forFeature([
      { name: NOTIFICATION_MODEL, schema: notificationSchema },
      { name: PUSH_TOKEN_MODEL, schema: pushTokenSchema },
    ]),
    PushModule,
    EmailModule,
    WhatsAppModule,
    UsersModule,
    RbacModule,
    AuthenticationModule,
  ],
  controllers: [NotificationsController],
  providers: [
    NotificationRepository,
    PushTokenRepository,
    RealtimeEmitter,
    NotificationDispatcher,
    NotificationsService,
    OnboardingNotificationHandler,
  ],
  exports: [NotificationDispatcher, NotificationsService],
})
export class NotificationsModule {}
