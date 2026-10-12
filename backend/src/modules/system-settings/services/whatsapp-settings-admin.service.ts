import { Injectable } from '@nestjs/common';
import { Types } from 'mongoose';
import { ApiException } from '../../../common/errors/api-exception';
import { type ClientRequestInfo } from '../../../common/http/client-request-info';
import { type AuthenticatedUserActor } from '../../../common/request-context/request-actor';
import { AppConfigService } from '../../../config/app-config.service';
import { TransactionRunner } from '../../../database/transaction-runner.service';
import { type WhatsAppSettings } from '../../../integrations/whatsapp/whatsapp-settings.schema';
import {
  type SettingSource,
  type WhatsAppSettingsChange,
  WhatsAppSettingsStore,
} from '../../../integrations/whatsapp/whatsapp-settings.store';
import { AuditLogService } from '../../audit-logs/services/audit-log.service';
import { EffectivePermissionsService } from '../../rbac/services/effective-permissions.service';
import { type SettingsTestResult } from './email-settings-admin.service';
import { checkWhatsAppConnection } from './whatsapp-connection-check';

/** READY: can send. DISABLED: turned off by an administrator. INCOMPLETE: something is missing. */
export type WhatsAppStatus = 'READY' | 'DISABLED' | 'INCOMPLETE';

/**
 * What an administrator sees. The access token is never part of it: only whether one is set,
 * where it comes from, and (for a token saved here) its last four characters.
 */
export interface WhatsAppSettingsView {
  /** WHATSAPP_PROVIDER of this deployment: `meta` sends, `development` only records. */
  provider: string;
  status: WhatsAppStatus;
  /** Names of the settings that are missing when status is INCOMPLETE. */
  missing: string[];
  enabled: boolean;
  businessAccountId: string | null;
  phoneDisplay: string | null;
  webhookVerifyToken: { configured: boolean };
  phoneNumberId: string | null;
  accessToken: { configured: boolean; source: SettingSource; lastFour: string | null };
  otpTemplateName: string | null;
  otpTemplateLanguage: string | null;
  otpFallbackToSms: boolean;
  notificationTemplateName: string | null;
  notificationTemplateLanguage: string | null;
  graphApiVersion: string | null;
  updatedAt: string | null;
  updatedByUserId: string | null;
}

const CHANGE_FIELDS = [
  'enabled',
  'businessAccountId',
  'phoneDisplay',
  'webhookVerifyToken',
  'phoneNumberId',
  'accessToken',
  'otpTemplateName',
  'otpTemplateLanguage',
  'otpFallbackToSms',
  'notificationTemplateName',
  'notificationTemplateLanguage',
] as const satisfies ReadonlyArray<keyof WhatsAppSettingsChange>;

/**
 * Administration of the WhatsApp Business settings (the Admin Portal's "WhatsApp" page uses
 * these operations). Credentials go in, never out; every change is audited without the token.
 */
@Injectable()
export class WhatsAppSettingsAdminService {
  constructor(
    private readonly store: WhatsAppSettingsStore,
    private readonly config: AppConfigService,
    private readonly transactions: TransactionRunner,
    private readonly audit: AuditLogService,
    private readonly effectivePermissions: EffectivePermissionsService,
  ) {}

  async describe(): Promise<WhatsAppSettingsView> {
    return this.viewOf(await this.store.stored());
  }

  /** Asks Meta about the saved phone number, to prove the token and the number ID work. */
  async testConnection(): Promise<SettingsTestResult> {
    if (this.config.get('WHATSAPP_PROVIDER') !== 'meta') {
      return {
        ok: false,
        message:
          'This server uses the development WhatsApp adapter, so nothing is sent to Meta. ' +
          'Set WHATSAPP_PROVIDER=meta to use the real service.',
      };
    }
    return checkWhatsAppConnection(await this.store.effective());
  }

  async update(
    actor: AuthenticatedUserActor,
    input: WhatsAppSettingsChange & { reason: string },
    client: ClientRequestInfo,
  ): Promise<WhatsAppSettingsView> {
    const { reason, ...change } = input;
    if (CHANGE_FIELDS.every((field) => change[field] === undefined)) {
      throw new ApiException('VALIDATION_FAILED', 'Nothing to change.');
    }

    const actorRoleKeys = (await this.effectivePermissions.forActor(actor)).roleKeys;
    const saved = await this.transactions.run(async (session) => {
      const before = await this.store.stored(session);
      const after = await this.store.save(change, new Types.ObjectId(actor.userId), session);
      await this.audit.record(
        {
          actor,
          actorRoleKeys,
          action: 'settings.whatsapp.changed',
          entityType: 'whatsapp_settings',
          entityId: after._id,
          before: this.auditStateOf(before),
          after: {
            ...this.auditStateOf(after),
            // Says that the token was replaced or removed, never what it is
            ...(change.accessToken !== undefined ? { accessTokenChanged: true } : {}),
            ...(change.webhookVerifyToken !== undefined ? { webhookVerifyTokenChanged: true } : {}),
          },
          reason,
          client,
        },
        session,
      );
      return after;
    });
    this.store.invalidate();
    return this.viewOf(saved);
  }

  private viewOf(stored: WhatsAppSettings | null): WhatsAppSettingsView {
    const effective = this.store.resolve(stored);
    const provider = this.config.get('WHATSAPP_PROVIDER');
    const missing =
      provider === 'meta'
        ? (
            [
              ['accessToken', effective.accessToken],
              ['phoneNumberId', effective.phoneNumberId],
              ['otpTemplateName', effective.otpTemplateName],
              ['otpTemplateLanguage', effective.otpTemplateLanguage],
            ] as const
          )
            .filter(([, value]) => !value)
            .map(([name]) => name)
        : [];
    return {
      provider,
      status: !effective.enabled ? 'DISABLED' : missing.length > 0 ? 'INCOMPLETE' : 'READY',
      missing,
      enabled: effective.enabled,
      businessAccountId: stored?.businessAccountId ?? null,
      phoneDisplay: stored?.phoneDisplay ?? null,
      webhookVerifyToken: { configured: Boolean(stored?.webhookVerifyTokenEncrypted) },
      phoneNumberId: effective.phoneNumberId ?? null,
      accessToken: {
        configured: effective.accessToken !== undefined,
        source: effective.accessTokenSource,
        lastFour:
          effective.accessTokenSource === 'ADMIN' ? (stored?.accessTokenLastFour ?? null) : null,
      },
      otpTemplateName: effective.otpTemplateName ?? null,
      otpTemplateLanguage: effective.otpTemplateLanguage ?? null,
      otpFallbackToSms: effective.otpFallbackToSms,
      notificationTemplateName: effective.notificationTemplateName ?? null,
      notificationTemplateLanguage: effective.notificationTemplateLanguage ?? null,
      graphApiVersion: effective.apiVersion ?? null,
      updatedAt: stored?.updatedAt?.toISOString() ?? null,
      updatedByUserId: stored?.updatedByUserId?.toHexString() ?? null,
    };
  }

  /** The stored administrator settings as written to the audit trail: no token in any form. */
  private auditStateOf(stored: WhatsAppSettings | null): Record<string, unknown> {
    return {
      enabled: stored?.enabled ?? null,
      businessAccountId: stored?.businessAccountId ?? null,
      phoneDisplay: stored?.phoneDisplay ?? null,
      webhookVerifyTokenSet: Boolean(stored?.webhookVerifyTokenEncrypted),
      phoneNumberId: stored?.phoneNumberId ?? null,
      accessTokenSet: Boolean(stored?.accessTokenEncrypted),
      otpTemplateName: stored?.otpTemplateName ?? null,
      otpTemplateLanguage: stored?.otpTemplateLanguage ?? null,
      otpFallbackToSms: stored?.otpFallbackToSms ?? null,
      notificationTemplateName: stored?.notificationTemplateName ?? null,
      notificationTemplateLanguage: stored?.notificationTemplateLanguage ?? null,
    };
  }
}
