/// Keys of the customer app's own messages (`l10n/customer_<locale>.arb`).
///
/// Messages shared by every app are in `AbraStrings` (shared_localization).
/// A test keeps this list identical to `customer_en.arb`.
abstract final class CustomerStrings {
  static const appName = 'appName';
  static const navHome = 'navHome';
  static const navMyTrips = 'navMyTrips';
  static const navSupport = 'navSupport';
  static const navProfile = 'navProfile';
  static const navMainLabel = 'navMainLabel';
  static const startupCheckingSession = 'startupCheckingSession';
  static const startupFailedTitle = 'startupFailedTitle';
  static const startupFailedMessage = 'startupFailedMessage';
  static const languageTitle = 'languageTitle';
  static const languageChangeAction = 'languageChangeAction';
  static const languageSelected = 'languageSelected';
  static const authLoginHeading = 'authLoginHeading';
  static const authLoginSubtitle = 'authLoginSubtitle';
  static const authPhoneLabel = 'authPhoneLabel';
  static const authPhoneCountryCode = 'authPhoneCountryCode';
  static const authSendCode = 'authSendCode';
  static const authSessionEndedNotice = 'authSessionEndedNotice';
  static const authOtpHeading = 'authOtpHeading';
  static const authOtpSentWhatsApp = 'authOtpSentWhatsApp';
  static const authOtpSentSms = 'authOtpSentSms';
  static const authOtpSent = 'authOtpSent';
  static const authOtpCodeLabel = 'authOtpCodeLabel';
  static const authOtpVerify = 'authOtpVerify';
  static const authOtpResend = 'authOtpResend';
  static const authOtpResendIn = 'authOtpResendIn';
  static const authOtpResent = 'authOtpResent';
  static const authOtpChangeNumber = 'authOtpChangeNumber';
  static const authErrorCodeIncorrect = 'authErrorCodeIncorrect';
  static const authErrorCodeExpired = 'authErrorCodeExpired';
  static const authErrorTooManyAttempts = 'authErrorTooManyAttempts';
  static const authErrorNotCustomerAccount = 'authErrorNotCustomerAccount';
  static const authErrorAccountDisabled = 'authErrorAccountDisabled';
  static const authErrorDeliveryFailed = 'authErrorDeliveryFailed';
  static const authErrorTwoStepNotSupported = 'authErrorTwoStepNotSupported';
  static const profileSignedInAs = 'profileSignedInAs';
  static const profileSignOutConfirmTitle = 'profileSignOutConfirmTitle';
  static const profileSignOutConfirmMessage = 'profileSignOutConfirmMessage';
  static const unavailableLabel = 'unavailableLabel';
  static const unavailableMessage = 'unavailableMessage';
  static const routeOnboardingTitle = 'routeOnboardingTitle';
  static const routeLoginTitle = 'routeLoginTitle';
  static const routeOtpTitle = 'routeOtpTitle';
  static const routeSearchTitle = 'routeSearchTitle';
  static const routeSearchResultsTitle = 'routeSearchResultsTitle';
  static const routeBusTitle = 'routeBusTitle';
  static const routeTripTitle = 'routeTripTitle';
  static const routeSeatsTitle = 'routeSeatsTitle';
  static const routePassengerDetailsTitle = 'routePassengerDetailsTitle';
  static const routeBookingReviewTitle = 'routeBookingReviewTitle';
  static const routePaymentTitle = 'routePaymentTitle';
  static const routeBookingSuccessTitle = 'routeBookingSuccessTitle';
  static const routeTicketTitle = 'routeTicketTitle';
  static const routeMyTripDetailTitle = 'routeMyTripDetailTitle';
  static const routeCancelBookingTitle = 'routeCancelBookingTitle';
  static const routeLiveTrackingTitle = 'routeLiveTrackingTitle';
  static const routeWomenSafetyTitle = 'routeWomenSafetyTitle';
  static const routeSettingsTitle = 'routeSettingsTitle';
  static const routeAccountDeleteTitle = 'routeAccountDeleteTitle';

  static const Set<String> all = <String>{
    appName,
    navHome,
    navMyTrips,
    navSupport,
    navProfile,
    navMainLabel,
    startupCheckingSession,
    startupFailedTitle,
    startupFailedMessage,
    languageTitle,
    languageChangeAction,
    languageSelected,
    authLoginHeading,
    authLoginSubtitle,
    authPhoneLabel,
    authPhoneCountryCode,
    authSendCode,
    authSessionEndedNotice,
    authOtpHeading,
    authOtpSentWhatsApp,
    authOtpSentSms,
    authOtpSent,
    authOtpCodeLabel,
    authOtpVerify,
    authOtpResend,
    authOtpResendIn,
    authOtpResent,
    authOtpChangeNumber,
    authErrorCodeIncorrect,
    authErrorCodeExpired,
    authErrorTooManyAttempts,
    authErrorNotCustomerAccount,
    authErrorAccountDisabled,
    authErrorDeliveryFailed,
    authErrorTwoStepNotSupported,
    profileSignedInAs,
    profileSignOutConfirmTitle,
    profileSignOutConfirmMessage,
    unavailableLabel,
    unavailableMessage,
    routeOnboardingTitle,
    routeLoginTitle,
    routeOtpTitle,
    routeSearchTitle,
    routeSearchResultsTitle,
    routeBusTitle,
    routeTripTitle,
    routeSeatsTitle,
    routePassengerDetailsTitle,
    routeBookingReviewTitle,
    routePaymentTitle,
    routeBookingSuccessTitle,
    routeTicketTitle,
    routeMyTripDetailTitle,
    routeCancelBookingTitle,
    routeLiveTrackingTitle,
    routeWomenSafetyTitle,
    routeSettingsTitle,
    routeAccountDeleteTitle,
  };
}
