import { type IncomingMessage, type ServerResponse } from 'node:http';
import { type Params } from 'nestjs-pino';
import { type AppConfigService } from '../../config/app-config.service';

/**
 * Keys whose values are never written to logs (deployment.md: passwords, tokens, card data and
 * OTPs are never logged). Applies to any object logged at these depths.
 */
export const REDACTED_LOG_PATHS = [
  'req.headers.authorization',
  'req.headers.cookie',
  'req.headers["x-api-key"]',
  'res.headers["set-cookie"]',
  ...[
    'password',
    'passwordHash',
    'otp',
    'otpHash',
    'token',
    'accessToken',
    'refreshToken',
    'secret',
    'apiKey',
    'clientSecret',
    'authorization',
    'cardNumber',
    'cvv',
    'bankAccountNumber',
  ].flatMap((key) => [key, `*.${key}`, `*.*.${key}`]),
];

/** Path only: query strings can carry phone numbers or PNRs. */
function pathWithoutQuery(url: string | undefined): string | undefined {
  return url?.split('?')[0];
}

/** Structured JSON logs with requestId; human-readable output only in local development. */
export function createLoggerOptions(config: AppConfigService): Params {
  const prettyOutput = config.get('NODE_ENV') === 'development';

  return {
    pinoHttp: {
      level: config.get('LOG_LEVEL'),
      genReqId: (request: IncomingMessage) => (request as IncomingMessage & { id: string }).id,
      redact: { paths: REDACTED_LOG_PATHS, censor: '[REDACTED]' },
      serializers: {
        req: (request: IncomingMessage & { id?: string }) => ({
          id: request.id,
          method: request.method,
          path: pathWithoutQuery(request.url),
        }),
        res: (response: ServerResponse) => ({ statusCode: response.statusCode }),
      },
      customLogLevel: (_request, response, error) =>
        error !== undefined || response.statusCode >= 500
          ? 'error'
          : response.statusCode >= 400
            ? 'warn'
            : 'info',
      ...(prettyOutput
        ? { transport: { target: 'pino-pretty', options: { singleLine: true } } }
        : {}),
    },
  };
}
