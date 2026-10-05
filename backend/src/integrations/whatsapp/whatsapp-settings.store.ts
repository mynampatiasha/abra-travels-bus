import { Injectable } from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { type ClientSession, type Model, type Types } from 'mongoose';
import { FieldEncryptionService } from '../../common/crypto/field-encryption.service';
import { AppConfigService } from '../../config/app-config.service';
import {
  WHATSAPP_SETTINGS_KEY,
  WHATSAPP_SETTINGS_MODEL,
  type WhatsAppSettings,
} from './whatsapp-settings.schema';

export type StoredWhatsAppSettings = WhatsAppSettings & { _id: Types.ObjectId };

/** Where the value in use comes from. */
export type SettingSource = 'ADMIN' | 'ENVIRONMENT' | 'NONE';

/** What the backend sends with, after administrator settings are laid over the environment. */
export interface EffectiveWhatsAppSettings {
  enabled: boolean;
  otpFallbackToSms: boolean;
  phoneNumberId: string | undefined;
  /** Plain token. Lives in memory only; never returned by an API or written to a log. */
  accessToken: string | undefined;
  accessTokenSource: SettingSource;
  apiVersion: string | undefined;
  otpTemplateName: string | undefined;
  otpTemplateLanguage: string | undefined;
}

/** Fields an administrator can change. `undefined` leaves a field alone, `null` clears it. */
export interface WhatsAppSettingsChange {
  enabled?: boolean | undefined;
  businessAccountId?: string | null | undefined;
  phoneNumberId?: string | null | undefined;
  accessToken?: string | null | undefined;
  otpTemplateName?: string | null | undefined;
  otpTemplateLanguage?: string | null | undefined;
  otpFallbackToSms?: boolean | undefined;
}

const CACHE_MS = 15_000;

/**
 * Reads and writes the administrator-managed WhatsApp settings and resolves the settings in use.
 * The resolved settings are cached briefly so sending a code does not read the database every
 * time; a change made on this instance applies at once, on other instances within CACHE_MS.
 */
@Injectable()
export class WhatsAppSettingsStore {
  private cached: { value: EffectiveWhatsAppSettings; at: number } | undefined;

  constructor(
    @InjectModel(WHATSAPP_SETTINGS_MODEL) private readonly model: Model<WhatsAppSettings>,
    private readonly encryption: FieldEncryptionService,
    private readonly config: AppConfigService,
  ) {}

  stored(session?: ClientSession): Promise<StoredWhatsAppSettings | null> {
    return this.model
      .findOne({ key: WHATSAPP_SETTINGS_KEY })
      .session(session ?? null)
      .lean<StoredWhatsAppSettings>()
      .exec();
  }

  /** Applies `change` and returns the stored document. The token is encrypted before storage. */
  async save(
    change: WhatsAppSettingsChange,
    updatedByUserId: Types.ObjectId,
    session: ClientSession,
  ): Promise<StoredWhatsAppSettings> {
    const { accessToken, ...plain } = change;
    const set: Partial<WhatsAppSettings> = { updatedByUserId };
    for (const [field, value] of Object.entries(plain)) {
      if (value !== undefined) Object.assign(set, { [field]: value });
    }
    if (accessToken !== undefined) {
      set.accessTokenEncrypted = accessToken === null ? null : this.encryption.encrypt(accessToken);
      set.accessTokenLastFour = accessToken === null ? null : accessToken.slice(-4);
    }
    const saved = await this.model
      .findOneAndUpdate(
        { key: WHATSAPP_SETTINGS_KEY },
        { $set: set, $setOnInsert: { key: WHATSAPP_SETTINGS_KEY } },
        { upsert: true, returnDocument: 'after', session },
      )
      .lean<StoredWhatsAppSettings>()
      .exec();
    if (!saved) throw new Error('WhatsApp settings could not be saved');
    return saved;
  }

  /** Call after a committed change so the next message uses the new settings. */
  invalidate(): void {
    this.cached = undefined;
  }

  async effective(): Promise<EffectiveWhatsAppSettings> {
    const now = Date.now();
    if (this.cached && now - this.cached.at < CACHE_MS) return this.cached.value;
    const value = this.resolve(await this.stored());
    this.cached = { value, at: now };
    return value;
  }

  resolve(stored: WhatsAppSettings | null): EffectiveWhatsAppSettings {
    return resolveWhatsAppSettings(stored, this.config, (value) => this.encryption.decrypt(value));
  }
}

/** Administrator settings over the environment configuration, field by field. */
export function resolveWhatsAppSettings(
  stored: WhatsAppSettings | null,
  config: Pick<AppConfigService, 'get'>,
  decrypt: (encrypted: string) => string,
): EffectiveWhatsAppSettings {
  const environmentToken = config.get('WHATSAPP_ACCESS_TOKEN');
  const adminToken = stored?.accessTokenEncrypted
    ? decrypt(stored.accessTokenEncrypted)
    : undefined;
  return {
    enabled: stored?.enabled ?? true,
    otpFallbackToSms: stored?.otpFallbackToSms ?? true,
    phoneNumberId: stored?.phoneNumberId ?? config.get('WHATSAPP_PHONE_NUMBER_ID'),
    accessToken: adminToken ?? environmentToken,
    accessTokenSource: adminToken ? 'ADMIN' : environmentToken ? 'ENVIRONMENT' : 'NONE',
    apiVersion: config.get('WHATSAPP_GRAPH_API_VERSION'),
    otpTemplateName: stored?.otpTemplateName ?? config.get('WHATSAPP_OTP_TEMPLATE_NAME'),
    otpTemplateLanguage:
      stored?.otpTemplateLanguage ?? config.get('WHATSAPP_OTP_TEMPLATE_LANGUAGE'),
  };
}
