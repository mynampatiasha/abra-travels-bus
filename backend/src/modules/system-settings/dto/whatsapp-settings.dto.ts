import { z } from 'zod';
import { createZodDto } from '../../../common/pipes/zod-dto.factory';
import { CUSTOMER_MESSAGE_TEMPLATES } from '../../notification-templates/customer_message_templates';

const CUSTOMER_TEMPLATE_KEYS = CUSTOMER_MESSAGE_TEMPLATES.map((template) => template.key) as [
  (typeof CUSTOMER_MESSAGE_TEMPLATES)[number]['key'],
  ...Array<(typeof CUSTOMER_MESSAGE_TEMPLATES)[number]['key']>,
];

const metaId = z.string().regex(/^\d{5,32}$/, 'must be the numeric id shown by Meta');

/**
 * Every field is optional: only the fields that are sent change. `null` clears a field, which
 * returns it to the environment configuration. The access token is write-only.
 */
export class UpdateWhatsAppSettingsDto extends createZodDto(
  z.object({
    enabled: z.boolean().optional(),
    businessAccountId: metaId.nullable().optional(),
    phoneDisplay: z
      .string()
      .trim()
      .min(1)
      .max(40)
      .regex(/^\+?[0-9 ()-]+$/, 'must be a display phone number')
      .nullable()
      .optional(),
    webhookVerifyToken: z
      .string()
      .min(8)
      .max(256)
      .regex(/^[A-Za-z0-9_-]+$/, 'letters, digits, underscores and hyphens only')
      .nullable()
      .optional(),
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
    notificationTemplateName: z
      .string()
      .max(512)
      .regex(/^[a-z0-9_]+$/, 'lowercase letters, digits and underscores only')
      .nullable()
      .optional(),
    notificationTemplateLanguage: z
      .string()
      .regex(/^[a-z]{2,3}(_[A-Z]{2})?$/, 'must look like en or en_US')
      .nullable()
      .optional(),
    /** The whole list of customer templates Meta has approved; sending it replaces the list. */
    approvedTemplateKeys: z
      .array(z.enum(CUSTOMER_TEMPLATE_KEYS))
      .max(CUSTOMER_TEMPLATE_KEYS.length)
      .transform((keys) => [...new Set(keys)])
      .optional(),
    reason: z.string().trim().min(3).max(300),
  }),
) {}
