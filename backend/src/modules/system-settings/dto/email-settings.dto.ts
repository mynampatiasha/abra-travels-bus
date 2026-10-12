import { z } from 'zod';
import { createZodDto } from '../../../common/pipes/zod-dto.factory';
import { SMTP_SECURITY_MODES } from '../../../integrations/email/email-settings.schema';

const hostName = z
  .string()
  .trim()
  .max(253)
  .regex(
    /^[A-Za-z0-9]([A-Za-z0-9.:-]*[A-Za-z0-9])?$/,
    'must be a host name or address, such as smtp.example.com',
  );

const address = z.email().max(320);

/**
 * Every field is optional: only the fields that are sent change. `null` clears a field. The
 * password is write-only.
 */
export class UpdateEmailSettingsDto extends createZodDto(
  z.object({
    enabled: z.boolean().optional(),
    host: hostName.nullable().optional(),
    port: z.number().int().min(1).max(65535).nullable().optional(),
    security: z.enum(SMTP_SECURITY_MODES).optional(),
    username: z.string().trim().min(1).max(320).nullable().optional(),
    password: z.string().min(1).max(512).nullable().optional(),
    fromName: z.string().trim().min(1).max(100).nullable().optional(),
    fromAddress: address.nullable().optional(),
    replyTo: address.nullable().optional(),
    reason: z.string().trim().min(3).max(300),
  }),
) {}

export class SendTestEmailDto extends createZodDto(z.object({ to: address })) {}
