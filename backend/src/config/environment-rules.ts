import { type z } from 'zod';
import { type environmentShape } from './environment.schema';

type ParsedEnvironment = z.output<typeof environmentShape>;

/** Settings that select a `Development*` adapter. Forbidden in production (architecture.md rule 8). */
const DEVELOPMENT_ADAPTER_SELECTORS = [
  ['PAYMENT_GATEWAY', 'development'],
  ['WHATSAPP_PROVIDER', 'development'],
  ['SMS_PROVIDER', 'development'],
  ['EMAIL_PROVIDER', 'development'],
  ['PUSH_PROVIDER', 'development'],
  ['MAPS_PROVIDER', 'development'],
  ['AI_PROVIDER', 'development'],
  ['STORAGE_DRIVER', 'local'],
] as const satisfies ReadonlyArray<readonly [keyof ParsedEnvironment, string]>;

/** Credentials a real provider cannot run without. */
const PROVIDER_REQUIREMENTS: ReadonlyArray<{
  when: (env: ParsedEnvironment) => boolean;
  reason: string;
  keys: ReadonlyArray<keyof ParsedEnvironment>;
}> = [
  // Razorpay is not listed: its keys may be saved in the admin app (Settings, Integrations) instead
  // of this file. Without keys anywhere, customers are told payments are not set up yet.
  {
    when: (env) => env.WHATSAPP_PROVIDER === 'meta',
    reason: 'required when WHATSAPP_PROVIDER=meta',
    keys: [
      'WHATSAPP_ACCESS_TOKEN',
      'WHATSAPP_PHONE_NUMBER_ID',
      'WHATSAPP_VERIFY_TOKEN',
      'WHATSAPP_GRAPH_API_VERSION',
      'WHATSAPP_OTP_TEMPLATE_NAME',
      'WHATSAPP_OTP_TEMPLATE_LANGUAGE',
    ],
  },
  {
    when: (env) => env.PUSH_PROVIDER === 'fcm',
    reason: 'required when PUSH_PROVIDER=fcm',
    keys: ['FCM_SERVICE_ACCOUNT_JSON'],
  },
  {
    when: (env) => env.MAPS_PROVIDER === 'google',
    reason: 'required when MAPS_PROVIDER=google',
    keys: ['MAPS_API_KEY'],
  },
  {
    when: (env) => env.AI_PROVIDER === 'anthropic',
    reason: 'required when AI_PROVIDER=anthropic',
    keys: ['ANTHROPIC_API_KEY'],
  },
  {
    when: (env) => env.STORAGE_DRIVER === 's3',
    reason: 'required when STORAGE_DRIVER=s3',
    keys: ['STORAGE_BUCKET', 'STORAGE_REGION', 'STORAGE_ACCESS_KEY', 'STORAGE_SECRET_KEY'],
  },
  {
    // Staging and production sign access tokens with an asymmetric key pair
    when: (env) => env.NODE_ENV === 'staging' || env.NODE_ENV === 'production',
    reason: 'required in staging and production',
    keys: ['JWT_ACCESS_PRIVATE_KEY', 'JWT_ACCESS_PUBLIC_KEY'],
  },
  {
    when: (env) => env.NODE_ENV === 'development' || env.NODE_ENV === 'test',
    reason: 'required in development and test',
    keys: ['JWT_ACCESS_SECRET'],
  },
];

export function applyEnvironmentRules(env: ParsedEnvironment, context: z.RefinementCtx): void {
  if (env.NODE_ENV === 'production') {
    for (const [key, developmentValue] of DEVELOPMENT_ADAPTER_SELECTORS) {
      if (env[key] === developmentValue) {
        context.addIssue({
          code: 'custom',
          path: [key],
          message: `"${developmentValue}" is a development-only adapter and is not allowed in production`,
        });
      }
    }
    if (!env.MFA_REQUIRED_FOR_STAFF) {
      context.addIssue({
        code: 'custom',
        path: ['MFA_REQUIRED_FOR_STAFF'],
        message: 'must be true in production (staff accounts require MFA)',
      });
    }
    if (env.API_DOCS_ENABLED === true) {
      context.addIssue({
        code: 'custom',
        path: ['API_DOCS_ENABLED'],
        message: 'public API documentation must not be enabled in production',
      });
    }
  }

  for (const requirement of PROVIDER_REQUIREMENTS) {
    if (!requirement.when(env)) continue;
    for (const key of requirement.keys) {
      if (env[key] === undefined) {
        context.addIssue({ code: 'custom', path: [key], message: requirement.reason });
      }
    }
  }
}
