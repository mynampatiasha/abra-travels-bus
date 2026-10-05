/// Enumerations whose values travel over the API. Each value carries the
/// exact string the backend uses ([wireValue]). An unrecognised string maps
/// to `unknown`, so an app keeps working when the server adds a value.
library;

/// Kind of account (`users.userType`).
enum UserType {
  staff('STAFF'),
  operatorStaff('OPERATOR_STAFF'),
  driver('DRIVER'),
  partnerUser('PARTNER_USER'),
  customer('CUSTOMER'),
  unknown('UNKNOWN');

  const UserType(this.wireValue);

  final String wireValue;

  static UserType fromWire(String value) =>
      values.firstWhere((v) => v.wireValue == value, orElse: () => unknown);
}

/// Account status (`users.status`).
enum UserStatus {
  active('ACTIVE'),
  invited('INVITED'),
  suspended('SUSPENDED'),
  deactivated('DEACTIVATED'),
  unknown('UNKNOWN');

  const UserStatus(this.wireValue);

  final String wireValue;

  static UserStatus fromWire(String value) =>
      values.firstWhere((v) => v.wireValue == value, orElse: () => unknown);
}

/// Which records a user can reach (documentation/authorization.md §5).
enum DataScopeType {
  all('ALL'),
  ownOperator('OWN_OPERATOR'),
  selectedOperators('SELECTED_OPERATORS'),
  ownPartner('OWN_PARTNER'),
  ownRecords('OWN_RECORDS'),
  assignedRecords('ASSIGNED_RECORDS'),
  unknown('UNKNOWN');

  const DataScopeType(this.wireValue);

  final String wireValue;

  static DataScopeType fromWire(String value) =>
      values.firstWhere((v) => v.wireValue == value, orElse: () => unknown);
}

/// Effect of a user-level permission override.
enum OverrideEffect {
  allow('ALLOW'),
  deny('DENY'),
  unknown('UNKNOWN');

  const OverrideEffect(this.wireValue);

  final String wireValue;

  static OverrideEffect fromWire(String value) =>
      values.firstWhere((v) => v.wireValue == value, orElse: () => unknown);
}

/// Where an effective permission comes from.
enum PermissionSource {
  role('ROLE'),
  allowOverride('ALLOW_OVERRIDE'),
  unknown('UNKNOWN');

  const PermissionSource(this.wireValue);

  final String wireValue;

  static PermissionSource fromWire(String value) =>
      values.firstWhere((v) => v.wireValue == value, orElse: () => unknown);
}

/// Kind of client a session was created from.
enum SessionClientType {
  mobile('MOBILE'),
  web('WEB'),
  unknown('UNKNOWN');

  const SessionClientType(this.wireValue);

  final String wireValue;

  static SessionClientType fromWire(String value) =>
      values.firstWhere((v) => v.wireValue == value, orElse: () => unknown);
}

/// Where the backend sent a one-time code (`OTP_DELIVERY_CHANNELS`).
enum OtpDeliveryChannel {
  whatsApp('WHATSAPP'),
  sms('SMS'),
  unknown('UNKNOWN');

  const OtpDeliveryChannel(this.wireValue);

  final String wireValue;

  static OtpDeliveryChannel fromWire(String value) =>
      values.firstWhere((v) => v.wireValue == value, orElse: () => unknown);
}

/// Purpose of a one-time code.
enum OtpPurpose {
  signIn('SIGN_IN'),
  passwordReset('PASSWORD_RESET');

  const OtpPurpose(this.wireValue);

  final String wireValue;
}
