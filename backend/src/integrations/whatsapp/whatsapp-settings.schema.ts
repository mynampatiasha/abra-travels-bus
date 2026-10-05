import { Schema, type Types } from 'mongoose';

export const WHATSAPP_SETTINGS_MODEL = 'WhatsAppSettings';

/** There is one WhatsApp Business configuration for the platform. */
export const WHATSAPP_SETTINGS_KEY = 'default';

/**
 * WhatsApp settings managed by administrators. Every field is optional: a field that is not set
 * falls back to the environment configuration (WHATSAPP_* variables). The access token is stored
 * encrypted (FieldEncryptionService); only its last four characters are kept readable so an
 * administrator can recognise which token is in use.
 */
export interface WhatsAppSettings {
  key: typeof WHATSAPP_SETTINGS_KEY;
  /** False turns WhatsApp off as an OTP channel without removing the credentials. */
  enabled?: boolean;
  /** WhatsApp Business Account (WABA) id. Informational; not needed to send. */
  businessAccountId?: string | null;
  phoneNumberId?: string | null;
  accessTokenEncrypted?: string | null;
  accessTokenLastFour?: string | null;
  otpTemplateName?: string | null;
  otpTemplateLanguage?: string | null;
  /** Whether a code that WhatsApp did not accept is sent by SMS instead. */
  otpFallbackToSms?: boolean;
  updatedByUserId?: Types.ObjectId;
  createdAt?: Date;
  updatedAt?: Date;
}

/** `whatsapp_settings` — a single document. */
export const whatsAppSettingsSchema = new Schema<WhatsAppSettings>(
  {
    key: { type: String, required: true, enum: [WHATSAPP_SETTINGS_KEY] },
    enabled: { type: Boolean },
    businessAccountId: { type: String, maxlength: 32, default: null },
    phoneNumberId: { type: String, maxlength: 32, default: null },
    accessTokenEncrypted: { type: String, default: null },
    accessTokenLastFour: { type: String, maxlength: 4, default: null },
    otpTemplateName: { type: String, maxlength: 512, default: null },
    otpTemplateLanguage: { type: String, maxlength: 8, default: null },
    otpFallbackToSms: { type: Boolean },
    updatedByUserId: { type: Schema.Types.ObjectId },
  },
  { collection: 'whatsapp_settings', timestamps: true, versionKey: false },
);

whatsAppSettingsSchema.index({ key: 1 }, { unique: true });
