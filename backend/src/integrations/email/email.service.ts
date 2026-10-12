import { isIP } from 'node:net';
import { Injectable, Logger } from '@nestjs/common';
import { createTransport, type Transporter } from 'nodemailer';
import { AppConfigService } from '../../config/app-config.service';
import { EmailSettingsStore, type EffectiveEmailSettings } from './email-settings.store';

export interface EmailMessage {
  to: string;
  subject: string;
  text: string;
  html?: string | undefined;
}

/** The mail server did not accept the message, or could not be reached. Safe to show. */
export class EmailDeliveryError extends Error {
  constructor(
    message: string,
    readonly code: string,
  ) {
    super(message);
    this.name = 'EmailDeliveryError';
  }
}

/** Settings that must be present before a connection can be tried. */
export interface SmtpConnectionSettings {
  host: string;
  port: number;
  security: EffectiveEmailSettings['security'];
  username: string | undefined;
  password: string | undefined;
}

const PRIVATE_IPV4 =
  /^(10\.|127\.|0\.|169\.254\.|192\.168\.|172\.(1[6-9]|2\d|3[01])\.|100\.(6[4-9]|[7-9]\d|1[01]\d|12[0-7])\.)/;

/**
 * In production the mail server must be a public host: an administrator account must not be able
 * to make the backend connect to machines on its own network. Outside production a local relay
 * (for example a development mail catcher on localhost) is allowed. Only the written host is
 * checked, not what a name resolves to.
 */
export function isHostAllowed(host: string, isProduction: boolean): boolean {
  if (!isProduction) return true;
  const name = host.toLowerCase();
  if (name === 'localhost' || name.endsWith('.local') || name.endsWith('.internal')) return false;
  const version = isIP(name);
  if (version === 4) return !PRIVATE_IPV4.test(name);
  if (version === 6)
    return !(
      name === '::1' ||
      name.startsWith('fc') ||
      name.startsWith('fd') ||
      name.startsWith('fe80')
    );
  return true;
}

/** A readable reason for a failed connection or send. Never contains the password. */
export function describeEmailFailure(
  error: unknown,
  host: string,
  port: number,
): EmailDeliveryError {
  const code = (error as { code?: unknown } | undefined)?.code;
  const kind = typeof code === 'string' ? code : 'UNKNOWN';
  switch (kind) {
    case 'EAUTH':
      return new EmailDeliveryError('The mail server rejected the username or password.', kind);
    case 'ENOTFOUND':
    case 'EDNS':
      return new EmailDeliveryError(`The host name "${host}" could not be found.`, kind);
    case 'ECONNREFUSED':
      return new EmailDeliveryError(`Nothing is accepting connections at ${host}:${port}.`, kind);
    case 'ETIMEDOUT':
    case 'ECONNECTION':
    case 'ESOCKET':
    case 'EHOSTUNREACH':
      return new EmailDeliveryError(
        `Could not connect to ${host}:${port}. Check the host, the port and the security setting.`,
        kind,
      );
    case 'ETLS':
      return new EmailDeliveryError(
        'The secure connection could not be set up. Try the other security option (SSL or STARTTLS).',
        kind,
      );
    case 'EENVELOPE':
      return new EmailDeliveryError('The sender or recipient address was refused.', kind);
    case 'EMESSAGE':
      return new EmailDeliveryError('The mail server refused the message.', kind);
    default:
      return new EmailDeliveryError('The email could not be sent.', kind);
  }
}

function transportOf(settings: SmtpConnectionSettings): Transporter {
  return createTransport({
    host: settings.host,
    port: settings.port,
    secure: settings.security === 'SSL',
    requireTLS: settings.security === 'STARTTLS',
    ignoreTLS: settings.security === 'NONE',
    ...(settings.username
      ? { auth: { user: settings.username, pass: settings.password ?? '' } }
      : {}),
    connectionTimeout: 10_000,
    greetingTimeout: 10_000,
    socketTimeout: 20_000,
  });
}

/**
 * Sends email through the SMTP server an administrator saved in Settings. Business code calls
 * `send`; credentials stay in here. With no server configured, the development adapter only
 * logs that a message would have been sent, and any other deployment refuses to send.
 */
@Injectable()
export class EmailService {
  private readonly logger = new Logger(EmailService.name);

  constructor(
    private readonly settings: EmailSettingsStore,
    private readonly config: AppConfigService,
  ) {}

  async send(message: EmailMessage): Promise<void> {
    const effective = await this.settings.effective();
    if (!effective.enabled) throw new EmailDeliveryError('Email is turned off.', 'DISABLED');
    if (!effective.host || !effective.port || !effective.fromAddress) {
      if (this.config.get('EMAIL_PROVIDER') === 'development' && !this.config.isProduction) {
        this.logger.log(
          { purpose: 'email-development', subject: message.subject },
          'Email recorded, not sent',
        );
        return;
      }
      throw new EmailDeliveryError('Email is not set up yet.', 'NOT_CONFIGURED');
    }
    await this.deliver(effective, message);
  }

  /** Logs in to the saved server without sending anything. */
  async verifyConnection(settings: SmtpConnectionSettings): Promise<void> {
    this.assertHostAllowed(settings.host);
    const transport = transportOf(settings);
    try {
      await transport.verify();
    } catch (error) {
      throw describeEmailFailure(error, settings.host, settings.port);
    } finally {
      transport.close();
    }
  }

  async deliver(effective: EffectiveEmailSettings, message: EmailMessage): Promise<void> {
    const { host, port, fromAddress } = effective;
    if (!host || !port || !fromAddress) {
      throw new EmailDeliveryError('Email is not set up yet.', 'NOT_CONFIGURED');
    }
    this.assertHostAllowed(host);
    const transport = transportOf({ ...effective, host, port });
    try {
      await transport.sendMail({
        from: effective.fromName ? { name: effective.fromName, address: fromAddress } : fromAddress,
        ...(effective.replyTo ? { replyTo: effective.replyTo } : {}),
        to: message.to,
        subject: message.subject,
        text: message.text,
        ...(message.html ? { html: message.html } : {}),
      });
    } catch (error) {
      throw describeEmailFailure(error, host, port);
    } finally {
      transport.close();
    }
  }

  private assertHostAllowed(host: string): void {
    if (!isHostAllowed(host, this.config.isProduction)) {
      throw new EmailDeliveryError('This mail server address is not allowed.', 'HOST_NOT_ALLOWED');
    }
  }
}
