/// Machine-readable error codes returned by the backend
/// (`backend/src/common/errors/api-error-codes.ts`). Clients branch on the
/// code, never on the message.
abstract final class ApiErrorCodes {
  static const validationFailed = 'VALIDATION_FAILED';
  static const malformedRequest = 'MALFORMED_REQUEST';
  static const unauthenticated = 'UNAUTHENTICATED';
  static const tokenExpired = 'TOKEN_EXPIRED';
  static const invalidCredentials = 'INVALID_CREDENTIALS';
  static const otpInvalid = 'OTP_INVALID';
  static const mfaInvalid = 'MFA_INVALID';
  static const permissionsChanged = 'PERMISSIONS_CHANGED';
  static const permissionDenied = 'PERMISSION_DENIED';
  static const accountDisabled = 'ACCOUNT_DISABLED';
  static const mfaEnrollmentRequired = 'MFA_ENROLLMENT_REQUIRED';
  static const resourceNotFound = 'RESOURCE_NOT_FOUND';
  static const alreadyRegistered = 'ALREADY_REGISTERED';
  static const resourceInUse = 'RESOURCE_IN_USE';
  static const invalidStateTransition = 'INVALID_STATE_TRANSITION';
  static const accountLocked = 'ACCOUNT_LOCKED';
  static const rateLimited = 'RATE_LIMITED';
  static const internalError = 'INTERNAL_ERROR';
  static const serviceUnavailable = 'SERVICE_UNAVAILABLE';
  static const maintenanceMode = 'MAINTENANCE_MODE';
}
