import { z } from 'zod';
import { createZodDto } from '../../../common/pipes/zod-dto.factory';

const metaId = z.string().regex(/^\d{5,32}$/, 'must be the numeric id shown by Meta');

/**
 * Every field is optional: only the fields that are sent change. `null` clears a field, which
 * returns it to the environment configuration. The access token is write-only.
 */
export class UpdateWhatsAppSettingsDto extends createZodDto(
  z.object({
    enabled: z.boolean().optional(),
    businessAccountId: metaId.nullable().optional(),
    phoneNumberId: metaId.nullable().optional(),
    accessToken: z
      .string()
      .min(20, 'is too short to be an access token')
      .max(1024)
      .regex(/^\S+$/, 'must not contain spaces')
      .nullable()
      .optional(),
    otpTemplateName: z
      .string()
      .max(512)
      .regex(/^[a-z0-9_]+$/, 'lowercase letters, digits and underscores only')
      .nullable()
      .optional(),
    otpTemplateLanguage: z
      .string()
      .regex(/^[a-z]{2,3}(_[A-Z]{2})?$/, 'must look like en or en_US')
      .nullable()
      .optional(),
    otpFallbackToSms: z.boolean().optional(),
    reason: z.string().trim().min(3).max(300),
  }),
) {}
