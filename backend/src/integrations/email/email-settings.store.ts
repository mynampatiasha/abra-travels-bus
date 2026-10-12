import { Injectable } from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { type ClientSession, type Model, type Types } from 'mongoose';
import { FieldEncryptionService } from '../../common/crypto/field-encryption.service';
import { AppConfigService } from '../../config/app-config.service';
import {
  EMAIL_SETTINGS_KEY,
  EMAIL_SETTINGS_MODEL,
  type EmailSettings,
  type SmtpSecurity,
} from './email-settings.schema';

export type StoredEmailSettings = EmailSettings & { _id: Types.ObjectId };

/** What the backend sends with. The password is plain and lives in memory only. */
export interface EffectiveEmailSettings {
  enabled: boolean;
  host: string | undefined;
  port: number | undefined;
  security: SmtpSecurity;
  username: string | undefined;
  password: string | undefined;
  fromName: string | undefined;
  /** The administrator's address, otherwise the EMAIL_FROM of the environment. */
  fromAddress: string | undefined;
  replyTo: string | undefined;
}

/** Fields an administrator can change. `undefined` leaves a field alone, `null` clears it. */
export interface EmailSettingsChange {
  enabled?: boolean | undefined;
  host?: string | null | undefined;
  port?: number | null | undefined;
  security?: SmtpSecurity | undefined;
  username?: string | null | undefined;
  password?: string | null | undefined;
  fromName?: string | null | undefined;
  fromAddress?: string | null | undefined;
  replyTo?: string | null | undefined;
}

const CACHE_MS = 15_000;

/**
 * Reads and writes the administrator-managed email settings and resolves the settings in use,
 * with the same short cache as the WhatsApp settings: a change made on this instance applies at
 * once, on other instances within CACHE_MS.
 */
@Injectable()
export class EmailSettingsStore {
  private cached: { value: EffectiveEmailSettings; at: number } | undefined;

  constructor(
    @InjectModel(EMAIL_SETTINGS_MODEL) private readonly model: Model<EmailSettings>,
    private readonly encryption: FieldEncryptionService,
    private readonly config: AppConfigService,
  ) {}

  stored(session?: ClientSession): Promise<StoredEmailSettings | null> {
    return this.model
      .findOne({ key: EMAIL_SETTINGS_KEY })
      .session(session ?? null)
      .lean<StoredEmailSettings>()
      .exec();
  }

  /** Applies `change` and returns the stored document. The password is encrypted first. */
  async save(
    change: EmailSettingsChange,
    updatedByUserId: Types.ObjectId,
    session: ClientSession,
  ): Promise<StoredEmailSettings> {
    const { password, ...plain } = change;
    const set: Partial<EmailSettings> = { updatedByUserId };
    for (const [field, value] of Object.entries(plain)) {
      if (value !== undefined) Object.assign(set, { [field]: value });
    }
    if (password !== undefined) {
      set.passwordEncrypted = password === null ? null : this.encryption.encrypt(password);
    }
    const saved = await this.model
      .findOneAndUpdate(
        { key: EMAIL_SETTINGS_KEY },
        { $set: set, $setOnInsert: { key: EMAIL_SETTINGS_KEY } },
        { upsert: true, returnDocument: 'after', session },
      )
      .lean<StoredEmailSettings>()
      .exec();
    if (!saved) throw new Error('Email settings could not be saved');
    return saved;
  }

  /** Call after a committed change so the next email uses the new settings. */
  invalidate(): void {
    this.cached = undefined;
  }

  async effective(): Promise<EffectiveEmailSettings> {
    const now = Date.now();
    if (this.cached && now - this.cached.at < CACHE_MS) return this.cached.value;
    const value = this.resolve(await this.stored());
    this.cached = { value, at: now };
    return value;
  }

  resolve(stored: EmailSettings | null): EffectiveEmailSettings {
    return {
      enabled: stored?.enabled ?? true,
      host: stored?.host ?? undefined,
      port: stored?.port ?? undefined,
      security: stored?.security ?? 'STARTTLS',
      username: stored?.username ?? undefined,
      password: stored?.passwordEncrypted
        ? this.encryption.decrypt(stored.passwordEncrypted)
        : undefined,
      fromName: stored?.fromName ?? undefined,
      fromAddress: stored?.fromAddress ?? this.config.get('EMAIL_FROM'),
      replyTo: stored?.replyTo ?? undefined,
    };
  }
}
