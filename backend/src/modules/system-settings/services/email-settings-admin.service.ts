import { Injectable } from '@nestjs/common';
import { Types } from 'mongoose';
import { ApiException } from '../../../common/errors/api-exception';
import { type ClientRequestInfo } from '../../../common/http/client-request-info';
import { type AuthenticatedUserActor } from '../../../common/request-context/request-actor';
import { AppConfigService } from '../../../config/app-config.service';
import { TransactionRunner } from '../../../database/transaction-runner.service';
import {
  type EmailSettings,
  type SmtpSecurity,
} from '../../../integrations/email/email-settings.schema';
import {
  type EmailSettingsChange,
  EmailSettingsStore,
} from '../../../integrations/email/email-settings.store';
import {
  EmailDeliveryError,
  EmailService,
  isHostAllowed,
} from '../../../integrations/email/email.service';
import { AuditLogService } from '../../audit-logs/services/audit-log.service';
import { EffectivePermissionsService } from '../../rbac/services/effective-permissions.service';

/** READY: can send. DISABLED: turned off by an administrator. INCOMPLETE: something is missing. */
export type EmailStatus = 'READY' | 'DISABLED' | 'INCOMPLETE';

/** What an administrator sees. The password is never part of it, only whether one is set. */
export interface EmailSettingsView {
  /** EMAIL_PROVIDER of this deployment: `smtp` sends, `development` only records. */
  provider: string;
  status: EmailStatus;
  /** Names of the settings that are missing when status is INCOMPLETE. */
  missing: string[];
  enabled: boolean;
  host: string | null;
  port: number | null;
  security: SmtpSecurity;
  username: string | null;
  password: { configured: boolean };
  fromName: string | null;
  fromAddress: string | null;
  replyTo: string | null;
  updatedAt: string | null;
  updatedByUserId: string | null;
}

/** The outcome of a test. A failed test is a normal answer (ok false) with the reason. */
export interface SettingsTestResult {
  ok: boolean;
  message: string;
}

const CHANGE_FIELDS = [
  'enabled',
  'host',
  'port',
  'security',
  'username',
  'password',
  'fromName',
  'fromAddress',
  'replyTo',
] as const satisfies ReadonlyArray<keyof EmailSettingsChange>;

/**
 * Administration of the SMTP settings (the Admin Portal's "Email" page uses these operations).
 * Credentials go in, never out; every change is audited without the password.
 */
@Injectable()
export class EmailSettingsAdminService {
  constructor(
    private readonly store: EmailSettingsStore,
    private readonly email: EmailService,
    private readonly config: AppConfigService,
    private readonly transactions: TransactionRunner,
    private readonly audit: AuditLogService,
    private readonly effectivePermissions: EffectivePermissionsService,
  ) {}

  async describe(): Promise<EmailSettingsView> {
    return this.viewOf(await this.store.stored());
  }

  async update(
    actor: AuthenticatedUserActor,
    input: EmailSettingsChange & { reason: string },
    client: ClientRequestInfo,
  ): Promise<EmailSettingsView> {
    const { reason, ...change } = input;
    if (CHANGE_FIELDS.every((field) => change[field] === undefined)) {
      throw new ApiException('VALIDATION_FAILED', 'Nothing to change.');
    }
    if (change.host && !isHostAllowed(change.host, this.config.isProduction)) {
      throw new ApiException('VALIDATION_FAILED', 'This mail server address is not allowed.');
    }

    const actorRoleKeys = (await this.effectivePermissions.forActor(actor)).roleKeys;
    const saved = await this.transactions.run(async (session) => {
      const before = await this.store.stored(session);
      const after = await this.store.save(change, new Types.ObjectId(actor.userId), session);
      await this.audit.record(
        {
          actor,
          actorRoleKeys,
          action: 'settings.email.changed',
          entityType: 'email_settings',
          entityId: after._id,
          before: this.auditStateOf(before),
          after: {
            ...this.auditStateOf(after),
            // Says that the password was replaced or removed, never what it is
            ...(change.password !== undefined ? { passwordChanged: true } : {}),
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

  /** Logs in to the saved server, without sending anything. */
  async testConnection(): Promise<SettingsTestResult> {
    const effective = await this.store.effective();
    if (!effective.host || !effective.port) {
      return { ok: false, message: 'Enter the host and the port and save, then test again.' };
    }
    try {
      await this.email.verifyConnection({
        host: effective.host,
        port: effective.port,
        security: effective.security,
        username: effective.username,
        password: effective.password,
      });
      return {
        ok: true,
        message: `Connected to ${effective.host}:${effective.port} and signed in.`,
      };
    } catch (error) {
      return { ok: false, message: this.reasonOf(error) };
    }
  }

  /** Sends a real message with the saved settings, to prove the whole path works. */
  async sendTestEmail(to: string): Promise<SettingsTestResult> {
    const effective = await this.store.effective();
    if (!effective.host || !effective.port || !effective.fromAddress) {
      return {
        ok: false,
        message: 'Enter the host, the port and the from address and save, then test again.',
      };
    }
    try {
      await this.email.deliver(effective, {
        to,
        subject: 'Abra Travels test email',
        text: 'This is a test email from Abra Travels. Your email settings work.',
      });
      return { ok: true, message: `A test email was sent to ${to}. Check that inbox (and spam).` };
    } catch (error) {
      return { ok: false, message: this.reasonOf(error) };
    }
  }

  private reasonOf(error: unknown): string {
    return error instanceof EmailDeliveryError ? error.message : 'The test could not be completed.';
  }

  private viewOf(stored: EmailSettings | null): EmailSettingsView {
    const effective = this.store.resolve(stored);
    const missing = (
      [
        ['host', effective.host],
        ['port', effective.port],
        ['fromAddress', effective.fromAddress],
        // a login needs both parts
        ...(effective.username ? ([['password', effective.password]] as const) : []),
      ] as const
    )
      .filter(([, value]) => !value)
      .map(([name]) => name);
    return {
      provider: this.config.get('EMAIL_PROVIDER'),
      status: !effective.enabled ? 'DISABLED' : missing.length > 0 ? 'INCOMPLETE' : 'READY',
      missing,
      enabled: effective.enabled,
      host: effective.host ?? null,
      port: effective.port ?? null,
      security: effective.security,
      username: effective.username ?? null,
      password: { configured: effective.password !== undefined },
      fromName: effective.fromName ?? null,
      fromAddress: effective.fromAddress ?? null,
      replyTo: effective.replyTo ?? null,
      updatedAt: stored?.updatedAt?.toISOString() ?? null,
      updatedByUserId: stored?.updatedByUserId?.toHexString() ?? null,
    };
  }

  /** The stored administrator settings as written to the audit trail: no password in any form. */
  private auditStateOf(stored: EmailSettings | null): Record<string, unknown> {
    return {
      enabled: stored?.enabled ?? null,
      host: stored?.host ?? null,
      port: stored?.port ?? null,
      security: stored?.security ?? null,
      username: stored?.username ?? null,
      passwordSet: Boolean(stored?.passwordEncrypted),
      fromName: stored?.fromName ?? null,
      fromAddress: stored?.fromAddress ?? null,
      replyTo: stored?.replyTo ?? null,
    };
  }
}
