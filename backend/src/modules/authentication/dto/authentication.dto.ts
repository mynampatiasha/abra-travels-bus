import { z } from 'zod';
import { createZodDto } from '../../../common/pipes/zod-dto.factory';
import { emailSchema, phoneNumberSchema } from '../../../common/validation/contact-identifiers';
import { SESSION_CLIENT_TYPES } from '../../sessions/schemas/auth-session.schema';
import { OTP_PURPOSES } from '../schemas/otp-challenge.schema';
import { newPasswordSchema, PASSWORD_MAX_LENGTH } from '../services/password-policy';

/** Which kind of client is signing in, and a label the user recognises in their device list. */
const deviceSchema = z
  .object({
    clientType: z.enum(SESSION_CLIENT_TYPES).default('MOBILE'),
    deviceName: z.string().trim().min(1).max(80).optional(),
  })
  .strict()
  .default({ clientType: 'MOBILE' });

const otpCodeSchema = z.string().regex(/^\d{4,8}$/, 'must be the numeric code from the SMS');
const totpCodeSchema = z.string().regex(/^\d{6}$/, 'must be the 6-digit code from the app');
const recoveryCodeSchema = z.string().trim().min(10).max(16);
const refreshTokenSchema = z.string().min(20).max(128);

export class RequestOtpDto extends createZodDto(
  z.object({
    phone: phoneNumberSchema,
    purpose: z.enum(OTP_PURPOSES).default('SIGN_IN'),
  }),
) {}

export class VerifyOtpDto extends createZodDto(
  z.object({ phone: phoneNumberSchema, code: otpCodeSchema, device: deviceSchema }),
) {}

export class RegisterCustomerDto extends createZodDto(
  z.object({
    phone: phoneNumberSchema,
    code: otpCodeSchema,
    name: z.string().trim().min(2).max(120),
    email: emailSchema.optional(),
    password: newPasswordSchema.optional(),
    preferredLanguage: z
      .string()
      .regex(/^[a-z]{2}(-[A-Z]{2})?$/, 'must be a language code such as "en" or "kn"')
      .optional(),
    /** Terms of service and privacy policy must be accepted to create an account. */
    acceptTerms: z.literal(true, 'the terms and privacy policy must be accepted'),
    marketingConsent: z.boolean().default(false),
    device: deviceSchema,
  }),
) {}

export class PasswordLoginDto extends createZodDto(
  z.object({
    /** Email address or phone number. */
    identifier: z.string().trim().min(3).max(254),
    password: z.string().min(1).max(PASSWORD_MAX_LENGTH),
    device: deviceSchema,
  }),
) {}

export class CompleteMfaLoginDto extends createZodDto(
  z.object({
    mfaToken: z.string().min(20).max(2048),
    code: totpCodeSchema.optional(),
    recoveryCode: recoveryCodeSchema.optional(),
    device: deviceSchema,
  }),
) {}

/** Mobile clients send the refresh token in the body; web clients send it as the HttpOnly cookie. */
export class RefreshTokenDto extends createZodDto(
  z.object({ refreshToken: refreshTokenSchema.optional() }),
) {}

export class LogoutDto extends createZodDto(
  z.object({ refreshToken: refreshTokenSchema.optional() }),
) {}

export class ResetPasswordDto extends createZodDto(
  z.object({ phone: phoneNumberSchema, code: otpCodeSchema, newPassword: newPasswordSchema }),
) {}

export class ChangePasswordDto extends createZodDto(
  z.object({
    /** Required when the account already has a password. */
    currentPassword: z.string().min(1).max(PASSWORD_MAX_LENGTH).optional(),
    newPassword: newPasswordSchema,
  }),
) {}

export class ActivateTotpDto extends createZodDto(z.object({ code: totpCodeSchema })) {}

export class DisableTotpDto extends createZodDto(
  z.object({ code: totpCodeSchema.optional(), recoveryCode: recoveryCodeSchema.optional() }),
) {}
