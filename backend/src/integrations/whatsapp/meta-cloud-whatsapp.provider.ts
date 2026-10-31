import {
  WhatsAppDeliveryError,
  type WhatsAppProvider,
  type WhatsAppTemplateMessage,
} from './whatsapp-provider.interface';

export interface MetaCloudWhatsAppSettings {
  accessToken: string;
  phoneNumberId: string;
  /** Pinned Graph API version, e.g. `v23.0`. */
  apiVersion: string;
  /** Upper bound for one request to Meta. */
  timeoutMs?: number;
}

/** Fixed settings, or a function that resolves the settings in use for each message. */
export type MetaCloudWhatsAppSettingsSource =
  MetaCloudWhatsAppSettings | (() => Promise<MetaCloudWhatsAppSettings>);

type FetchFunction = typeof fetch;

const GRAPH_API_ORIGIN = 'https://graph.facebook.com';
const DEFAULT_TIMEOUT_MS = 10_000;

interface MetaSendResponse {
  messages?: Array<{ id?: unknown }>;
}

interface MetaErrorResponse {
  error?: { code?: unknown; error_subcode?: unknown; type?: unknown };
}

/**
 * WhatsApp Business Cloud API (Meta). Sends approved templates through
 * `POST /{version}/{phone-number-id}/messages` with the system-user access token.
 *
 * Errors carry only Meta's numeric error code and HTTP status, never the request body, the
 * recipient or Meta's free-text message, so a one-time code can never end up in a log line.
 */
export class MetaCloudWhatsAppProvider implements WhatsAppProvider {
  readonly providerKey = 'meta-cloud';

  constructor(
    private readonly settingsSource: MetaCloudWhatsAppSettingsSource,
    private readonly fetchFn: FetchFunction = fetch,
  ) {}

  async sendTemplate(message: WhatsAppTemplateMessage): Promise<void> {
    const settings =
      typeof this.settingsSource === 'function' ? await this.settingsSource() : this.settingsSource;
    const components: Array<Record<string, unknown>> = [
      {
        type: 'body',
        parameters: message.bodyParameters.map((text) => ({ type: 'text', text })),
      },
    ];
    if (message.documentHeader) {
      const mediaId = await this.uploadDocument(settings, message.documentHeader);
      components.unshift({
        type: 'header',
        parameters: [{ type: 'document', document: { id: mediaId, filename: message.documentHeader.filename } }],
      });
    }
    if (message.urlButtonParameter !== undefined) {
      components.push({
        type: 'button',
        sub_type: 'url',
        index: '0',
        parameters: [{ type: 'text', text: message.urlButtonParameter }],
      });
    }

    let response: Response;
    try {
      response = await this.fetchFn(
        `${GRAPH_API_ORIGIN}/${settings.apiVersion}/${settings.phoneNumberId}/messages`,
        {
          method: 'POST',
          headers: {
            Authorization: `Bearer ${settings.accessToken}`,
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({
            messaging_product: 'whatsapp',
            recipient_type: 'individual',
            // Cloud API expects the number in international format without '+'
            to: message.to.replace(/^\+/, ''),
            type: 'template',
            template: {
              name: message.templateName,
              language: { code: message.languageCode },
              components,
            },
          }),
          signal: AbortSignal.timeout(settings.timeoutMs ?? DEFAULT_TIMEOUT_MS),
        },
      );
    } catch (error) {
      const timedOut = error instanceof Error && error.name === 'TimeoutError';
      throw new WhatsAppDeliveryError(
        timedOut ? 'WhatsApp request timed out' : 'WhatsApp request failed',
      );
    }

    const body: unknown = await response.json().catch(() => undefined);
    if (!response.ok) {
      const metaError = (body as MetaErrorResponse | undefined)?.error;
      const code = typeof metaError?.code === 'number' ? metaError.code : 'unknown';
      throw new WhatsAppDeliveryError(
        `WhatsApp rejected the message (HTTP ${response.status}, error ${code})`,
      );
    }
    const messageId = (body as MetaSendResponse | undefined)?.messages?.[0]?.id;
    if (typeof messageId !== 'string' || messageId.length === 0) {
      throw new WhatsAppDeliveryError('WhatsApp did not confirm the message');
    }
  }

  /** Uploads the file to WhatsApp and returns the media id the message refers to. */
  private async uploadDocument(
    settings: { apiVersion: string; phoneNumberId: string; accessToken: string; timeoutMs?: number | undefined },
    file: { filename: string; content: Buffer; contentType: string },
  ): Promise<string> {
    const form = new FormData();
    form.append('messaging_product', 'whatsapp');
    form.append('type', file.contentType);
    form.append('file', new Blob([new Uint8Array(file.content)], { type: file.contentType }), file.filename);
    let response: Response;
    try {
      response = await this.fetchFn(`${GRAPH_API_ORIGIN}/${settings.apiVersion}/${settings.phoneNumberId}/media`, {
        method: 'POST',
        headers: { Authorization: `Bearer ${settings.accessToken}` },
        body: form,
        signal: AbortSignal.timeout(settings.timeoutMs ?? DEFAULT_TIMEOUT_MS),
      });
    } catch {
      throw new WhatsAppDeliveryError('The ticket could not be sent to WhatsApp');
    }
    const body = (await response.json().catch(() => undefined)) as { id?: string } | undefined;
    if (!response.ok || typeof body?.id !== 'string') {
      throw new WhatsAppDeliveryError(`WhatsApp did not accept the ticket file (HTTP ${response.status})`);
    }
    return body.id;
  }
}
