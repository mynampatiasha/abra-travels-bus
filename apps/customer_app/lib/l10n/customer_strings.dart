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
  static const homeHeading = 'homeHeading';
  static const searchFromLabel = 'searchFromLabel';
  static const searchToLabel = 'searchToLabel';
  static const searchFromHint = 'searchFromHint';
  static const searchToHint = 'searchToHint';
  static const searchSwap = 'searchSwap';
  static const searchDateLabel = 'searchDateLabel';
  static const searchToday = 'searchToday';
  static const searchTomorrow = 'searchTomorrow';
  static const searchButton = 'searchButton';
  static const searchRecentTitle = 'searchRecentTitle';
  static const searchRoute = 'searchRoute';
  static const searchErrorOriginRequired = 'searchErrorOriginRequired';
  static const searchErrorDestinationRequired =
      'searchErrorDestinationRequired';
  static const searchErrorSameCity = 'searchErrorSameCity';
  static const searchErrorDate = 'searchErrorDate';
  static const cityPickerFromTitle = 'cityPickerFromTitle';
  static const cityPickerToTitle = 'cityPickerToTitle';
  static const cityPickerSearchLabel = 'cityPickerSearchLabel';
  static const cityPickerPopular = 'cityPickerPopular';
  static const cityPickerTypeToSearch = 'cityPickerTypeToSearch';
  static const cityPickerEmptyTitle = 'cityPickerEmptyTitle';
  static const cityPickerEmptyMessage = 'cityPickerEmptyMessage';
  static const resultsCount = 'resultsCount';
  static const resultsEmptyTitle = 'resultsEmptyTitle';
  static const resultsEmptyMessage = 'resultsEmptyMessage';
  static const resultsEmptyFilteredMessage = 'resultsEmptyFilteredMessage';
  static const resultsClearFilters = 'resultsClearFilters';
  static const resultsPreviousDay = 'resultsPreviousDay';
  static const resultsNextDay = 'resultsNextDay';
  static const resultsFilter = 'resultsFilter';
  static const resultsFilterActive = 'resultsFilterActive';
  static const resultsSort = 'resultsSort';
  static const resultsLoadMore = 'resultsLoadMore';
  static const resultsLoadMoreFailed = 'resultsLoadMoreFailed';
  static const resultsInvalidTitle = 'resultsInvalidTitle';
  static const resultsInvalidMessage = 'resultsInvalidMessage';
  static const sortDepartureEarliest = 'sortDepartureEarliest';
  static const sortDepartureLatest = 'sortDepartureLatest';
  static const sortFareLowest = 'sortFareLowest';
  static const sortFareHighest = 'sortFareHighest';
  static const sortDurationShortest = 'sortDurationShortest';
  static const tripFareFrom = 'tripFareFrom';
  static const tripSeatsLeft = 'tripSeatsLeft';
  static const tripSoldOut = 'tripSoldOut';
  static const tripDuration = 'tripDuration';
  static const tripArrivesLater = 'tripArrivesLater';
  static const tripAc = 'tripAc';
  static const tripNonAc = 'tripNonAc';
  static const tripCardSemantics = 'tripCardSemantics';
  static const filterTitle = 'filterTitle';
  static const filterDeparture = 'filterDeparture';
  static const filterBusType = 'filterBusType';
  static const filterAirConditioning = 'filterAirConditioning';
  static const filterOperator = 'filterOperator';
  static const filterAmenities = 'filterAmenities';
  static const filterMaxFare = 'filterMaxFare';
  static const filterMaxFareValue = 'filterMaxFareValue';
  static const filterApply = 'filterApply';
  static const filterReset = 'filterReset';
  static const filterOption = 'filterOption';
  static const windowEarlyMorning = 'windowEarlyMorning';
  static const windowMorning = 'windowMorning';
  static const windowAfternoon = 'windowAfternoon';
  static const windowNight = 'windowNight';
  static const amenityWifi = 'amenityWifi';
  static const amenityChargingPoint = 'amenityChargingPoint';
  static const amenityBlanket = 'amenityBlanket';
  static const amenityPillow = 'amenityPillow';
  static const amenityWaterBottle = 'amenityWaterBottle';
  static const amenityReadingLight = 'amenityReadingLight';
  static const amenityCctv = 'amenityCctv';
  static const amenityGpsTracking = 'amenityGpsTracking';
  static const amenityToilet = 'amenityToilet';
  static const amenityEntertainment = 'amenityEntertainment';
  static const amenitySnacks = 'amenitySnacks';
  static const amenityEmergencyExit = 'amenityEmergencyExit';
  static const amenityFirstAid = 'amenityFirstAid';
  static const tripDetailsBoardingTitle = 'tripDetailsBoardingTitle';
  static const tripDetailsDroppingTitle = 'tripDetailsDroppingTitle';
  static const tripDetailsAmenitiesTitle = 'tripDetailsAmenitiesTitle';
  static const tripDetailsVia = 'tripDetailsVia';
  static const tripDetailsBusNumber = 'tripDetailsBusNumber';
  static const tripDetailsLandmark = 'tripDetailsLandmark';
  static const tripDetailsFareNote = 'tripDetailsFareNote';
  static const tripDetailsBookingUnavailable = 'tripDetailsBookingUnavailable';
  static const tripUnavailableTitle = 'tripUnavailableTitle';
  static const tripUnavailableMessage = 'tripUnavailableMessage';
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
    homeHeading,
    searchFromLabel,
    searchToLabel,
    searchFromHint,
    searchToHint,
    searchSwap,
    searchDateLabel,
    searchToday,
    searchTomorrow,
    searchButton,
    searchRecentTitle,
    searchRoute,
    searchErrorOriginRequired,
    searchErrorDestinationRequired,
    searchErrorSameCity,
    searchErrorDate,
    cityPickerFromTitle,
    cityPickerToTitle,
    cityPickerSearchLabel,
    cityPickerPopular,
    cityPickerTypeToSearch,
    cityPickerEmptyTitle,
    cityPickerEmptyMessage,
    resultsCount,
    resultsEmptyTitle,
    resultsEmptyMessage,
    resultsEmptyFilteredMessage,
    resultsClearFilters,
    resultsPreviousDay,
    resultsNextDay,
    resultsFilter,
    resultsFilterActive,
    resultsSort,
    resultsLoadMore,
    resultsLoadMoreFailed,
    resultsInvalidTitle,
    resultsInvalidMessage,
    sortDepartureEarliest,
    sortDepartureLatest,
    sortFareLowest,
    sortFareHighest,
    sortDurationShortest,
    tripFareFrom,
    tripSeatsLeft,
    tripSoldOut,
    tripDuration,
    tripArrivesLater,
    tripAc,
    tripNonAc,
    tripCardSemantics,
    filterTitle,
    filterDeparture,
    filterBusType,
    filterAirConditioning,
    filterOperator,
    filterAmenities,
    filterMaxFare,
    filterMaxFareValue,
    filterApply,
    filterReset,
    filterOption,
    windowEarlyMorning,
    windowMorning,
    windowAfternoon,
    windowNight,
    amenityWifi,
    amenityChargingPoint,
    amenityBlanket,
    amenityPillow,
    amenityWaterBottle,
    amenityReadingLight,
    amenityCctv,
    amenityGpsTracking,
    amenityToilet,
    amenityEntertainment,
    amenitySnacks,
    amenityEmergencyExit,
    amenityFirstAid,
    tripDetailsBoardingTitle,
    tripDetailsDroppingTitle,
    tripDetailsAmenitiesTitle,
    tripDetailsVia,
    tripDetailsBusNumber,
    tripDetailsLandmark,
    tripDetailsFareNote,
    tripDetailsBookingUnavailable,
    tripUnavailableTitle,
    tripUnavailableMessage,
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
