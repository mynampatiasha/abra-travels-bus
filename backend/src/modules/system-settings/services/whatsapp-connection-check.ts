import { type SettingsTestResult } from './email-settings-admin.service';

const GRAPH_API_ORIGIN = 'https://graph.facebook.com';
const TIMEOUT_MS = 10_000;

export interface WhatsAppConnectionInput {
  accessToken: string | undefined;
  phoneNumberId: string | undefined;
  apiVersion: string | undefined;
}

interface MetaPhoneNumber {
  display_phone_number?: unknown;
  verified_name?: unknown;
  quality_rating?: unknown;
  code_verification_status?: unknown;
}

interface MetaError {
  error?: { code?: unknown };
}

type FetchFunction = typeof fetch;

/** A readable reason for the error number Meta answered with. */
function reasonOfMetaError(status: number, code: unknown): string {
  switch (code) {
    case 190:
      return 'Meta rejected the access token. It is wrong, expired or was revoked. Create a new permanent token and save it.';
    case 100:
      return 'Meta could not find this phone number ID, or the token has no access to it. Check the phone number ID.';
    case 10:
    case 200:
    case 294:
      return 'The token does not have permission for WhatsApp. It needs the whatsapp_business_messaging permission.';
    case 4:
    case 80007:
    case 130429:
      return 'Meta is limiting requests right now. Wait a few minutes and try again.';
    default:
      return `Meta refused the request (HTTP ${status}${typeof code === 'number' ? `, error ${code}` : ''}).`;
  }
}

/**
 * Asks Meta about the saved phone number. A valid answer proves the access token and the phone
 * number ID work together, without sending any message. The result carries only what is useful
 * to an administrator (the number, its name and quality), never the token.
 */
export async function checkWhatsAppConnection(
  input: WhatsAppConnectionInput,
  fetchFn: FetchFunction = fetch,
): Promise<SettingsTestResult> {
  const { accessToken, phoneNumberId, apiVersion } = input;
  if (!accessToken) return { ok: false, message: 'Save the access token first.' };
  if (!phoneNumberId) return { ok: false, message: 'Save the phone number ID first.' };
  if (!apiVersion) return { ok: false, message: 'The Graph API version is not configured.' };

  let response: Response;
  try {
    response = await fetchFn(
      `${GRAPH_API_ORIGIN}/${apiVersion}/${phoneNumberId}?fields=display_phone_number,verified_name,quality_rating,code_verification_status`,
      {
        headers: { Authorization: `Bearer ${accessToken}` },
        signal: AbortSignal.timeout(TIMEOUT_MS),
      },
    );
  } catch (error) {
    const timedOut = error instanceof Error && error.name === 'TimeoutError';
    return {
      ok: false,
      message: timedOut
        ? 'Meta did not answer in time. Try again.'
        : 'Could not reach Meta. Check the internet connection of the server.',
    };
  }

  const body: unknown = await response.json().catch(() => undefined);
  if (!response.ok) {
    return {
      ok: false,
      message: reasonOfMetaError(response.status, (body as MetaError | undefined)?.error?.code),
    };
  }
  const phone = (body ?? {}) as MetaPhoneNumber;
  const text = (value: unknown): string | undefined =>
    typeof value === 'string' ? value : undefined;
  const number = text(phone.display_phone_number);
  const name = text(phone.verified_name);
  const quality = text(phone.quality_rating);
  const parts = [
    number ? `number ${number}` : undefined,
    name ? `name "${name}"` : undefined,
    quality ? `quality ${quality.toLowerCase()}` : undefined,
  ].filter(Boolean);
  return {
    ok: true,
    message: `Connected to WhatsApp${parts.length > 0 ? `: ${parts.join(', ')}` : ''}.`,
  };
}
