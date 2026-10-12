import { Schema, type Types } from 'mongoose';

export const EMAIL_SETTINGS_MODEL = 'EmailSettings';

/** There is one email (SMTP) configuration for the platform. */
export const EMAIL_SETTINGS_KEY = 'default';

/**
 * How the connection to the mail server is secured. SSL: encrypted from the first byte (usually
 * port 465). STARTTLS: starts plain and upgrades to encrypted (usually port 587), and refuses to
 * continue when the server cannot. NONE: no encryption (only for a trusted local relay).
 */
export const SMTP_SECURITY_MODES = ['SSL', 'STARTTLS', 'NONE'] as const;
export type SmtpSecurity = (typeof SMTP_SECURITY_MODES)[number];

/**
 * SMTP settings managed by administrators. Any SMTP provider works (Brevo, Resend, Gmail,
 * Outlook, a company mail server). The password is stored encrypted (FieldEncryptionService) and
 * cannot be read back; unlike an access token, not even its last characters are kept.
 */
export interface EmailSettings {
  key: typeof EMAIL_SETTINGS_KEY;
  /** False stops all email without removing the settings. */
  enabled?: boolean;
  host?: string | null;
  port?: number | null;
  security?: SmtpSecurity;
  username?: string | null;
  passwordEncrypted?: string | null;
  fromName?: string | null;
  fromAddress?: string | null;
  replyTo?: string | null;
  updatedByUserId?: Types.ObjectId;
  createdAt?: Date;
  updatedAt?: Date;
}

/** `email_settings` — a single document. */
export const emailSettingsSchema = new Schema<EmailSettings>(
  {
    key: { type: String, required: true, enum: [EMAIL_SETTINGS_KEY] },
    enabled: { type: Boolean },
    host: { type: String, maxlength: 253, default: null },
    port: { type: Number, min: 1, max: 65535, default: null },
    security: { type: String, enum: SMTP_SECURITY_MODES },
    username: { type: String, maxlength: 320, default: null },
    passwordEncrypted: { type: String, default: null },
    fromName: { type: String, maxlength: 100, default: null },
    fromAddress: { type: String, maxlength: 320, default: null },
    replyTo: { type: String, maxlength: 320, default: null },
    updatedByUserId: { type: Schema.Types.ObjectId },
  },
  { collection: 'email_settings', timestamps: true, versionKey: false },
);

emailSettingsSchema.index({ key: 1 }, { unique: true });
