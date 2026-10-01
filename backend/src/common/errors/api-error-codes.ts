/**
 * Stable, machine-readable error codes (documentation/api-architecture.md §2).
 * Clients branch on `code`, never on `message`.
 */
export const API_ERROR_STATUS = {
  VALIDATION_FAILED: 400,
  MALFORMED_REQUEST: 400,
  UNAUTHENTICATED: 401,
  TOKEN_EXPIRED: 401,
  /** Wrong identifier or password. The same answer whether or not the account exists. */
  INVALID_CREDENTIALS: 401,
  /** OTP wrong, expired, already used, or out of attempts — deliberately not distinguished. */
  OTP_INVALID: 401,
  MFA_INVALID: 401,
  PERMISSIONS_CHANGED: 401,
  PERMISSION_DENIED: 403,
  ACCOUNT_DISABLED: 403,
  /** The session may only complete MFA enrolment until MFA is enabled. */
  MFA_ENROLLMENT_REQUIRED: 403,
  SCOPE_MISSING: 403,
  RESOURCE_NOT_FOUND: 404,
  METHOD_NOT_ALLOWED: 405,
  SEAT_NOT_AVAILABLE: 409,
  SEAT_LOCK_EXPIRED: 409,
  INVALID_STATE_TRANSITION: 409,
  ALREADY_REGISTERED: 409,
  PAYLOAD_TOO_LARGE: 413,
  UNSUPPORTED_MEDIA_TYPE: 415,
  IDEMPOTENCY_KEY_REUSED: 422,
  /** Too many failed sign-in attempts; `details.retryAfterSeconds` says when to try again. */
  ACCOUNT_LOCKED: 423,
  COUPON_INVALID: 422,
  COUPON_USAGE_EXCEEDED: 422,
  PAYMENT_AMOUNT_MISMATCH: 422,
  RATE_LIMITED: 429,
  INTERNAL_ERROR: 500,
  PAYMENT_PROVIDER_UNAVAILABLE: 502,
  SERVICE_UNAVAILABLE: 503,
  MAINTENANCE_MODE: 503,
} as const;

export type ApiErrorCode = keyof typeof API_ERROR_STATUS;

/**
 * Fallback code when a framework HttpException carries only a status. Input validation always
 * raises ApiException('VALIDATION_FAILED') from the zod pipe, so a bare framework 400 means the
 * request itself could not be parsed (invalid JSON, invalid URL encoding).
 */
export function errorCodeForStatus(status: number): ApiErrorCode {
  switch (status) {
    case 400:
      return 'MALFORMED_REQUEST';
    case 401:
      return 'UNAUTHENTICATED';
    case 403:
      return 'PERMISSION_DENIED';
    case 404:
      return 'RESOURCE_NOT_FOUND';
    case 405:
      return 'METHOD_NOT_ALLOWED';
    case 413:
      return 'PAYLOAD_TOO_LARGE';
    case 415:
      return 'UNSUPPORTED_MEDIA_TYPE';
    case 429:
      return 'RATE_LIMITED';
    case 503:
      return 'SERVICE_UNAVAILABLE';
    default:
      return 'INTERNAL_ERROR';
  }
}
