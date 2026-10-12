import { Module } from '@nestjs/common';
import { MongooseModule } from '@nestjs/mongoose';
import { EMAIL_SETTINGS_MODEL, emailSettingsSchema } from './email-settings.schema';
import { EmailSettingsStore } from './email-settings.store';
import { EmailService } from './email.service';

/** Outbound email through the SMTP server managed in Settings (documentation/notification-architecture.md). */
@Module({
  imports: [
    MongooseModule.forFeature([{ name: EMAIL_SETTINGS_MODEL, schema: emailSettingsSchema }]),
  ],
  providers: [EmailSettingsStore, EmailService],
  exports: [EmailSettingsStore, EmailService],
})
export class EmailModule {}
