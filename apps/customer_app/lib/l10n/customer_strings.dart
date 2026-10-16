/// Keys of the customer app's own messages (`l10n/customer_<locale>.arb`).
///
/// Messages shared by every app are in `AbraStrings` (shared_localization).
/// A test keeps this list identical to `customer_en.arb`.
abstract final class CustomerStrings {
  static const authWelcomeTitle = 'authWelcomeTitle';
  static const authWelcomeMessage = 'authWelcomeMessage';
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

  static const homeSubtitle = 'homeSubtitle';
  static const homeTrustTitle = 'homeTrustTitle';
  static const homeTrustOperators = 'homeTrustOperators';
  static const homeTrustFares = 'homeTrustFares';
  static const homeTrustPoints = 'homeTrustPoints';
  static const homeOffersTitle = 'homeOffersTitle';
  static const homeOffersViewAll = 'homeOffersViewAll';
  static const homePopularRoutesTitle = 'homePopularRoutesTitle';
  static const splashTagline = 'splashTagline';
  static const loginBrandTagline = 'loginBrandTagline';

  static const welcomeGetStarted = 'welcomeGetStarted';
  static const welcomeSkip = 'welcomeSkip';
  static const welcomeHeading = 'welcomeHeading';
  static const welcomeTagline = 'welcomeTagline';
  static const welcomeImageLabel = 'welcomeImageLabel';
  static const onboardingNext = 'onboardingNext';
  static const onboardingBack = 'onboardingBack';
  static const onboardingDone = 'onboardingDone';
  static const onboardingComingSoon = 'onboardingComingSoon';
  static const onboardingStep = 'onboardingStep';
  static const onboardingDiscoverTitle = 'onboardingDiscoverTitle';
  static const onboardingDiscoverBody = 'onboardingDiscoverBody';
  static const onboardingSearchTitle = 'onboardingSearchTitle';
  static const onboardingSearchBody = 'onboardingSearchBody';
  static const onboardingBookTitle = 'onboardingBookTitle';
  static const onboardingBookBody = 'onboardingBookBody';
  static const onboardingTrackTitle = 'onboardingTrackTitle';
  static const onboardingTrackBody = 'onboardingTrackBody';
  static const onboardingSafetyTitle = 'onboardingSafetyTitle';
  static const onboardingSafetyBody = 'onboardingSafetyBody';
  static const authTermsNote = 'authTermsNote';

  static const homeBannerPosition = 'homeBannerPosition';
  static const homeBannerOfferTitle = 'homeBannerOfferTitle';
  static const homeBannerLinkTitle = 'homeBannerLinkTitle';
  static const gateTitle = 'gateTitle';
  static const gateMessage = 'gateMessage';
  static const gateAction = 'gateAction';
  static const gateActionShort = 'gateActionShort';
  static const gateRequiredTitle = 'gateRequiredTitle';
  static const gateRequiredMessage = 'gateRequiredMessage';
  static const sessionEndedTitle = 'sessionEndedTitle';
  static const sessionEndedMessage = 'sessionEndedMessage';
  static const sessionEndedLater = 'sessionEndedLater';
  static const myTripsGuestTitle = 'myTripsGuestTitle';
  static const myTripsGuestMessage = 'myTripsGuestMessage';
  static const contentComingSoon = 'contentComingSoon';
  static const supportHelpTitle = 'supportHelpTitle';
  static const supportHelpMessage = 'supportHelpMessage';
  static const supportContactAction = 'supportContactAction';
  static const infoTermsTitle = 'infoTermsTitle';
  static const infoPrivacyTitle = 'infoPrivacyTitle';
  static const infoAboutTitle = 'infoAboutTitle';
  static const infoContentComingSoon = 'infoContentComingSoon';
  static const infoAboutBody = 'infoAboutBody';
  static const infoAboutVersion = 'infoAboutVersion';
  static const seatsComingSoonTitle = 'seatsComingSoonTitle';
  static const seatsComingSoonMessage = 'seatsComingSoonMessage';
  static const seatsPassengersLabel = 'seatsPassengersLabel';
  static const passengerCount = 'passengerCount';
  static const profileGuestTitle = 'profileGuestTitle';
  static const profileGuestMessage = 'profileGuestMessage';
  static const profileAccount = 'profileAccount';
  static const profilePreferences = 'profilePreferences';
  static const profileAboutSection = 'profileAboutSection';
  static const routeSupportContactTitle = 'routeSupportContactTitle';
  static const routeProfileEditTitle = 'routeProfileEditTitle';
  static const routeNotificationSettingsTitle =
      'routeNotificationSettingsTitle';
  static const routeNotificationsTitle = 'routeNotificationsTitle';
  static const tripSelectSeats = 'tripSelectSeats';
  static const tripPointSelected = 'tripPointSelected';

  static const seatSelectTitle = 'seatSelectTitle';
  static const seatLegendAvailable = 'seatLegendAvailable';
  static const seatLegendSelected = 'seatLegendSelected';
  static const seatLegendBooked = 'seatLegendBooked';
  static const seatLegendLadies = 'seatLegendLadies';
  static const seatLegendBlocked = 'seatLegendBlocked';
  static const seatChosenCount = 'seatChosenCount';
  static const seatDeckLower = 'seatDeckLower';
  static const seatDeckUpper = 'seatDeckUpper';
  static const seatFront = 'seatFront';
  static const seatNoneSelected = 'seatNoneSelected';
  static const seatSelectedSummary = 'seatSelectedSummary';
  static const seatLimitReached = 'seatLimitReached';
  static const seatBookedTip = 'seatBookedTip';
  static const seatSemantics = 'seatSemantics';
  static const seatSemanticsNoPrice = 'seatSemanticsNoPrice';
  static const seatContinue = 'seatContinue';
  static const seatLoggedInKept = 'seatLoggedInKept';
  static const seatSummaryTitle = 'seatSummaryTitle';
  static const seatTotal = 'seatTotal';
  static const seatClose = 'seatClose';
  static const seatMapLabel = 'seatMapLabel';
  static const seatSoldOutTitle = 'seatSoldOutTitle';
  static const seatSoldOutMessage = 'seatSoldOutMessage';
  static const pointsTitle = 'pointsTitle';
  static const pointsSubtitle = 'pointsSubtitle';
  static const pointsBoardingTab = 'pointsBoardingTab';
  static const pointsDroppingTab = 'pointsDroppingTab';
  static const pointsBoardingHeading = 'pointsBoardingHeading';
  static const pointsDroppingHeading = 'pointsDroppingHeading';
  static const pointsLandmark = 'pointsLandmark';
  static const pointsMap = 'pointsMap';
  static const pointsMapSemantics = 'pointsMapSemantics';
  static const pointsMapFailed = 'pointsMapFailed';
  static const pointsSummaryBoarding = 'pointsSummaryBoarding';
  static const pointsSummaryDropping = 'pointsSummaryDropping';
  static const pointsContinue = 'pointsContinue';
  static const pointsTabs = 'pointsTabs';

  static const holdChipSemantics = 'holdChipSemantics';
  static const holdBanner = 'holdBanner';
  static const holdExpiredBarTitle = 'holdExpiredBarTitle';
  static const holdExpiredTitle = 'holdExpiredTitle';
  static const holdExpiredMessage = 'holdExpiredMessage';
  static const holdExpiredMessageGeneric = 'holdExpiredMessageGeneric';
  static const holdExpiredAgain = 'holdExpiredAgain';
  static const holdExpiredBack = 'holdExpiredBack';
  static const seatsTakenMessage = 'seatsTakenMessage';
  static const passengerTitle = 'passengerTitle';
  static const passengerUseProfile = 'passengerUseProfile';
  static const passengerUseProfileHint = 'passengerUseProfileHint';
  static const passengerCardTitle = 'passengerCardTitle';
  static const passengerSeatChip = 'passengerSeatChip';
  static const passengerSeatChipLadies = 'passengerSeatChipLadies';
  static const passengerName = 'passengerName';
  static const passengerAge = 'passengerAge';
  static const passengerGenderMale = 'passengerGenderMale';
  static const passengerGenderFemale = 'passengerGenderFemale';
  static const passengerGenderOther = 'passengerGenderOther';
  static const passengerGenderLabel = 'passengerGenderLabel';
  static const passengerNameError = 'passengerNameError';
  static const passengerAgeError = 'passengerAgeError';
  static const passengerGenderError = 'passengerGenderError';
  static const passengerLadiesError = 'passengerLadiesError';
  static const contactTitle = 'contactTitle';
  static const contactHint = 'contactHint';
  static const contactCountryCode = 'contactCountryCode';
  static const contactMobile = 'contactMobile';
  static const contactEmail = 'contactEmail';
  static const contactMobileError = 'contactMobileError';
  static const contactEmailError = 'contactEmailError';
  static const gstTitle = 'gstTitle';
  static const gstHint = 'gstHint';
  static const gstGstin = 'gstGstin';
  static const gstCompany = 'gstCompany';
  static const gstGstinError = 'gstGstinError';
  static const gstCompanyError = 'gstCompanyError';
  static const passengerFixFields = 'passengerFixFields';
  static const passengerContinue = 'passengerContinue';
  static const reviewTitle = 'reviewTitle';
  static const reviewSubtitle = 'reviewSubtitle';
  static const reviewRouteLine = 'reviewRouteLine';
  static const reviewPassengers = 'reviewPassengers';
  static const reviewBoarding = 'reviewBoarding';
  static const reviewDropping = 'reviewDropping';
  static const reviewProceed = 'reviewProceed';
  static const couponTitle = 'couponTitle';
  static const couponCodeLabel = 'couponCodeLabel';
  static const couponApply = 'couponApply';
  static const couponApplied = 'couponApplied';
  static const couponRemove = 'couponRemove';
  static const couponInvalid = 'couponInvalid';
  static const fareTitle = 'fareTitle';
  static const fareSummaryTitle = 'fareSummaryTitle';
  static const fareBase = 'fareBase';
  static const fareGst = 'fareGst';
  static const fareConvenienceFee = 'fareConvenienceFee';
  static const fareDiscount = 'fareDiscount';
  static const cancelPolicyTitle = 'cancelPolicyTitle';
  static const cancelPolicyBefore = 'cancelPolicyBefore';
  static const cancelPolicyBetween = 'cancelPolicyBetween';
  static const cancelPolicyUnder = 'cancelPolicyUnder';
  static const cancelPolicyRefund = 'cancelPolicyRefund';
  static const cancelPolicyNoRefund = 'cancelPolicyNoRefund';
  static const termsAgree = 'termsAgree';

  static const payTitle = 'payTitle';
  static const paySubtitle = 'paySubtitle';
  static const payMethodUpi = 'payMethodUpi';
  static const payMethodUpiHint = 'payMethodUpiHint';
  static const payMethodCard = 'payMethodCard';
  static const payMethodCardHint = 'payMethodCardHint';
  static const payMethodNetBanking = 'payMethodNetBanking';
  static const payMethodNetBankingHint = 'payMethodNetBankingHint';
  static const payMethodWallet = 'payMethodWallet';
  static const payMethodWalletHint = 'payMethodWalletHint';
  static const payUpiGpay = 'payUpiGpay';
  static const payUpiPhonepe = 'payUpiPhonepe';
  static const payUpiPaytm = 'payUpiPaytm';
  static const payUpiBhim = 'payUpiBhim';
  static const payUpiId = 'payUpiId';
  static const payUpiIdHint = 'payUpiIdHint';
  static const payUpiIdError = 'payUpiIdError';
  static const payUpiVerify = 'payUpiVerify';
  static const payUpiVerified = 'payUpiVerified';
  static const payCardNumber = 'payCardNumber';
  static const payCardNumberError = 'payCardNumberError';
  static const payCardExpiry = 'payCardExpiry';
  static const payCardExpiryError = 'payCardExpiryError';
  static const payCardCvv = 'payCardCvv';
  static const payCardCvvError = 'payCardCvvError';
  static const payCardName = 'payCardName';
  static const payCardNameError = 'payCardNameError';
  static const payBankSbi = 'payBankSbi';
  static const payBankHdfc = 'payBankHdfc';
  static const payBankIcici = 'payBankIcici';
  static const payBankAxis = 'payBankAxis';
  static const payBankKotak = 'payBankKotak';
  static const payWalletPaytm = 'payWalletPaytm';
  static const payWalletPhonepe = 'payWalletPhonepe';
  static const payWalletAmazon = 'payWalletAmazon';
  static const payEncrypted = 'payEncrypted';
  static const payHoldCaption = 'payHoldCaption';
  static const payAction = 'payAction';
  static const payProcessingBarTitle = 'payProcessingBarTitle';
  static const payProcessingBarSubtitle = 'payProcessingBarSubtitle';
  static const payProcessingTitle = 'payProcessingTitle';
  static const payProcessingMessage = 'payProcessingMessage';
  static const payFailedBarTitle = 'payFailedBarTitle';
  static const payFailedBarSubtitle = 'payFailedBarSubtitle';
  static const payFailedTitle = 'payFailedTitle';
  static const payFailedMessage = 'payFailedMessage';
  static const payFailedNetwork = 'payFailedNetwork';
  static const payFailedRefundNote = 'payFailedRefundNote';
  static const payFailedRefundNoteShort = 'payFailedRefundNoteShort';
  static const payRetry = 'payRetry';
  static const payChangeMethod = 'payChangeMethod';
  static const payBackToReview = 'payBackToReview';

  static const holdBannerShort = 'holdBannerShort';

  static const ticketConfirmedTitle = 'ticketConfirmedTitle';
  static const ticketSentTo = 'ticketSentTo';
  static const ticketReady = 'ticketReady';
  static const ticketPnrChip = 'ticketPnrChip';
  static const ticketPnrCopyHint = 'ticketPnrCopyHint';
  static const ticketPnrCopied = 'ticketPnrCopied';
  static const ticketPaid = 'ticketPaid';
  static const ticketSummaryLine = 'ticketSummaryLine';
  static const ticketSummarySeats = 'ticketSummarySeats';
  static const ticketViewTicket = 'ticketViewTicket';
  static const ticketShare = 'ticketShare';
  static const ticketAddToCalendar = 'ticketAddToCalendar';
  static const ticketCalendarFailed = 'ticketCalendarFailed';
  static const ticketCalendarTitle = 'ticketCalendarTitle';
  static const ticketBarTitle = 'ticketBarTitle';
  static const ticketBarSubtitle = 'ticketBarSubtitle';
  static const ticketQrLabel = 'ticketQrLabel';
  static const ticketQrHint = 'ticketQrHint';
  static const ticketPassengersTitle = 'ticketPassengersTitle';
  static const ticketSeat = 'ticketSeat';
  static const ticketBoardingPoint = 'ticketBoardingPoint';
  static const ticketReportEarly = 'ticketReportEarly';
  static const ticketOperatorContact = 'ticketOperatorContact';
  static const ticketCallOperator = 'ticketCallOperator';
  static const ticketDownloadPdf = 'ticketDownloadPdf';
  static const ticketPdfFailed = 'ticketPdfFailed';
  static const ticketShareText = 'ticketShareText';

  static const tripsTabUpcoming = 'tripsTabUpcoming';
  static const tripsTabCompleted = 'tripsTabCompleted';
  static const tripsTabCancelled = 'tripsTabCancelled';
  static const tripsTabsLabel = 'tripsTabsLabel';
  static const tripsToday = 'tripsToday';
  static const statusConfirmed = 'statusConfirmed';
  static const statusCompleted = 'statusCompleted';
  static const statusCancelled = 'statusCancelled';
  static const statusRefundProcessing = 'statusRefundProcessing';
  static const statusRefunded = 'statusRefunded';
  static const tripsCardSeats = 'tripsCardSeats';
  static const tripsCardTimes = 'tripsCardTimes';
  static const tripsEmptyUpcomingTitle = 'tripsEmptyUpcomingTitle';
  static const tripsEmptyUpcomingMessage = 'tripsEmptyUpcomingMessage';
  static const tripsEmptyCompletedTitle = 'tripsEmptyCompletedTitle';
  static const tripsEmptyCompletedMessage = 'tripsEmptyCompletedMessage';
  static const tripsEmptyCancelledTitle = 'tripsEmptyCancelledTitle';
  static const tripsEmptyCancelledMessage = 'tripsEmptyCancelledMessage';
  static const tripsViewUpcoming = 'tripsViewUpcoming';
  static const tripsSearchBuses = 'tripsSearchBuses';
  static const tripDetailsTitle = 'tripDetailsTitle';
  static const tdTimeline = 'tdTimeline';
  static const tdBooked = 'tdBooked';
  static const tdBookedLine = 'tdBookedLine';
  static const tdTicketIssued = 'tdTicketIssued';
  static const tdTicketIssuedLine = 'tdTicketIssuedLine';
  static const tdBoarding = 'tdBoarding';
  static const tdBoardingLine = 'tdBoardingLine';
  static const tdArrival = 'tdArrival';
  static const tdArrivalLine = 'tdArrivalLine';
  static const tdEticket = 'tdEticket';
  static const tdEticketLine = 'tdEticketLine';
  static const tdCancelSeats = 'tdCancelSeats';
  static const tdGetHelp = 'tdGetHelp';
  static const tdTrackBus = 'tdTrackBus';
  static const tdTrackLater = 'tdTrackLater';
  static const tdRefundLink = 'tdRefundLink';
  static const cancelTitle = 'cancelTitle';
  static const cancelSelectSeats = 'cancelSelectSeats';
  static const cancelEstimate = 'cancelEstimate';
  static const cancelTierBefore = 'cancelTierBefore';
  static const cancelTierBetween = 'cancelTierBetween';
  static const cancelTierUnder = 'cancelTierUnder';
  static const cancelFarePaid = 'cancelFarePaid';
  static const cancelCharge = 'cancelCharge';
  static const cancelRefundAmount = 'cancelRefundAmount';
  static const cancelRefundNote = 'cancelRefundNote';
  static const cancelPickSeat = 'cancelPickSeat';
  static const cancelReasonTitle = 'cancelReasonTitle';
  static const cancelReasonPlans = 'cancelReasonPlans';
  static const cancelReasonMistake = 'cancelReasonMistake';
  static const cancelReasonBetter = 'cancelReasonBetter';
  static const cancelReasonMedical = 'cancelReasonMedical';
  static const cancelReasonOther = 'cancelReasonOther';
  static const cancelBarRefund = 'cancelBarRefund';
  static const cancelAction = 'cancelAction';
  static const cancelSheetTitle = 'cancelSheetTitle';
  static const cancelSheetBody = 'cancelSheetBody';
  static const cancelSheetRefund = 'cancelSheetRefund';
  static const cancelSheetNoRefund = 'cancelSheetNoRefund';
  static const cancelKeep = 'cancelKeep';
  static const cancelConfirm = 'cancelConfirm';
  static const cancelFailed = 'cancelFailed';
  static const refundTitle = 'refundTitle';
  static const refundAmountLabel = 'refundAmountLabel';
  static const refundDoneLabel = 'refundDoneLabel';
  static const refundTo = 'refundTo';
  static const refundRequested = 'refundRequested';
  static const refundRequestedLine = 'refundRequestedLine';
  static const refundProcessing = 'refundProcessing';
  static const refundProcessingLine = 'refundProcessingLine';
  static const refundProcessingDone = 'refundProcessingDone';
  static const refundRefunded = 'refundRefunded';
  static const refundRefundedExpected = 'refundRefundedExpected';
  static const refundRefundedLine = 'refundRefundedLine';
  static const refundUtr = 'refundUtr';
  static const refundUtrPending = 'refundUtrPending';
  static const refundUtrCopy = 'refundUtrCopy';
  static const refundUtrCopied = 'refundUtrCopied';
  static const refundHelp = 'refundHelp';
  static const refundBack = 'refundBack';

  static const timelineDone = 'timelineDone';
  static const timelineNow = 'timelineNow';
  static const timelineNext = 'timelineNext';

  static const trackTitle = 'trackTitle';
  static const trackSubtitle = 'trackSubtitle';
  static const trackArriving = 'trackArriving';
  static const trackEtaMinutes = 'trackEtaMinutes';
  static const trackEtaApprox = 'trackEtaApprox';
  static const trackStaleEta = 'trackStaleEta';
  static const trackOnTime = 'trackOnTime';
  static const trackDelayed = 'trackDelayed';
  static const trackSignalLost = 'trackSignalLost';
  static const trackLastUpdated = 'trackLastUpdated';
  static const trackLastUpdatedShort = 'trackLastUpdatedShort';
  static const trackLastSeen = 'trackLastSeen';
  static const trackStaleBanner = 'trackStaleBanner';
  static const trackStaleBannerNoPlace = 'trackStaleBannerNoPlace';
  static const trackCallOperator = 'trackCallOperator';
  static const trackRetry = 'trackRetry';
  static const trackDriver = 'trackDriver';
  static const trackDriverLine = 'trackDriverLine';
  static const trackCallDriver = 'trackCallDriver';
  static const trackShareTrip = 'trackShareTrip';
  static const trackSos = 'trackSos';
  static const trackMapLive = 'trackMapLive';
  static const trackMapStale = 'trackMapStale';
  static const sosTitle = 'sosTitle';
  static const sosSubtitle = 'sosSubtitle';
  static const sosIntro = 'sosIntro';
  static const sosButton = 'sosButton';
  static const sosButtonSemantics = 'sosButtonSemantics';
  static const sosSeconds = 'sosSeconds';
  static const sosReleasedEarly = 'sosReleasedEarly';
  static const sosNote = 'sosNote';
  static const sosContacts = 'sosContacts';
  static const sosContactsEmpty = 'sosContactsEmpty';
  static const sosCall = 'sosCall';
  static const sosAddContact = 'sosAddContact';
  static const sosShareLocation = 'sosShareLocation';
  static const sosHelplines = 'sosHelplines';
  static const helplineWomen = 'helplineWomen';
  static const helplinePolice = 'helplinePolice';
  static const helplineAmbulance = 'helplineAmbulance';
  static const helplineAbra = 'helplineAbra';
  static const contactAddTitle = 'contactAddTitle';
  static const contactNameLabel = 'contactNameLabel';
  static const contactPhoneLabel = 'contactPhoneLabel';
  static const contactRelationLabel = 'contactRelationLabel';
  static const contactSave = 'contactSave';
  static const contactNameRequired = 'contactNameRequired';
  static const contactPhoneRequired = 'contactPhoneRequired';
  static const sosAlertTitle = 'sosAlertTitle';
  static const sosAlertSubtitle = 'sosAlertSubtitle';
  static const sosAlertMessage = 'sosAlertMessage';
  static const sosAlertContacts = 'sosAlertContacts';
  static const sosAlertLocation = 'sosAlertLocation';
  static const sosAlertPolice = 'sosAlertPolice';
  static const sosAlertTeam = 'sosAlertTeam';
  static const sosCall112 = 'sosCall112';
  static const sosImSafe = 'sosImSafe';
  static const sosSafeConfirmTitle = 'sosSafeConfirmTitle';
  static const sosSafeConfirmBody = 'sosSafeConfirmBody';
  static const sosSafeConfirmYes = 'sosSafeConfirmYes';
  static const sosSafeConfirmNo = 'sosSafeConfirmNo';
  static const sosFailed = 'sosFailed';
  static const shareTitle = 'shareTitle';
  static const shareSubtitle = 'shareSubtitle';
  static const shareOnBanner = 'shareOnBanner';
  static const shareOnBannerNobody = 'shareOnBannerNobody';
  static const shareOffBanner = 'shareOffBanner';
  static const shareLinkTitle = 'shareLinkTitle';
  static const shareWhatsapp = 'shareWhatsapp';
  static const shareSms = 'shareSms';
  static const shareCopyLink = 'shareCopyLink';
  static const shareLinkCopied = 'shareLinkCopied';
  static const shareMessage = 'shareMessage';
  static const sharePeople = 'sharePeople';
  static const sharePersonViewed = 'sharePersonViewed';
  static const sharePersonNotOpened = 'sharePersonNotOpened';
  static const sharePeopleNone = 'sharePeopleNone';
  static const shareStop = 'shareStop';
  static const shareStart = 'shareStart';
  static const shareStopped = 'shareStopped';
  static const shareStarted = 'shareStarted';
  static const shareOpenFailed = 'shareOpenFailed';

  static const notifTitle = 'notifTitle';
  static const notifUnread = 'notifUnread';
  static const notifFilterAll = 'notifFilterAll';
  static const notifFilterBooking = 'notifFilterBooking';
  static const notifFilterOffers = 'notifFilterOffers';
  static const notifFilterSafety = 'notifFilterSafety';
  static const notifFilters = 'notifFilters';
  static const notifMarkAllRead = 'notifMarkAllRead';
  static const notifToday = 'notifToday';
  static const notifEarlier = 'notifEarlier';
  static const notifUnreadDot = 'notifUnreadDot';
  static const notifEmptyTitle = 'notifEmptyTitle';
  static const notifEmptyMessage = 'notifEmptyMessage';
  static const notifShowAll = 'notifShowAll';
  static const notifOffersAction = 'notifOffersAction';
  static const notifJustNow = 'notifJustNow';
  static const notifMinutesAgo = 'notifMinutesAgo';
  static const notifHoursAgo = 'notifHoursAgo';
  static const notifDaysAgo = 'notifDaysAgo';
  static const offersTitle = 'offersTitle';
  static const offersSubtitle = 'offersSubtitle';
  static const offersViewOffer = 'offersViewOffer';
  static const offersCopy = 'offersCopy';
  static const offersCopied = 'offersCopied';
  static const offersCodeCopied = 'offersCodeCopied';
  static const offersValidTill = 'offersValidTill';
  static const offersTermsApply = 'offersTermsApply';
  static const offersTermsTitle = 'offersTermsTitle';
  static const offersGotIt = 'offersGotIt';
  static const offersEmptyTitle = 'offersEmptyTitle';
  static const offersEmptyMessage = 'offersEmptyMessage';
  static const offersCarousel = 'offersCarousel';
  static const offersCarouselPage = 'offersCarouselPage';
  static const offersCopyCodeSemantics = 'offersCopyCodeSemantics';

  static const Set<String> all = <String>{
    authWelcomeTitle,
    authWelcomeMessage,
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
    homeSubtitle,
    homeTrustTitle,
    homeTrustOperators,
    homeTrustFares,
    homeTrustPoints,
    splashTagline,
    loginBrandTagline,
    welcomeGetStarted,
    welcomeSkip,
    welcomeHeading,
    welcomeTagline,
    welcomeImageLabel,
    onboardingNext,
    onboardingBack,
    onboardingDone,
    onboardingComingSoon,
    onboardingStep,
    onboardingDiscoverTitle,
    onboardingDiscoverBody,
    onboardingSearchTitle,
    onboardingSearchBody,
    onboardingBookTitle,
    onboardingBookBody,
    onboardingTrackTitle,
    onboardingTrackBody,
    onboardingSafetyTitle,
    onboardingSafetyBody,
    authTermsNote,
    homeBannerPosition,
    homeBannerOfferTitle,
    homeBannerLinkTitle,
    gateTitle,
    gateMessage,
    gateAction,
    gateActionShort,
    gateRequiredTitle,
    gateRequiredMessage,
    sessionEndedTitle,
    sessionEndedMessage,
    sessionEndedLater,
    myTripsGuestTitle,
    myTripsGuestMessage,
    contentComingSoon,
    supportHelpTitle,
    supportHelpMessage,
    supportContactAction,
    infoTermsTitle,
    infoPrivacyTitle,
    infoAboutTitle,
    infoContentComingSoon,
    infoAboutBody,
    infoAboutVersion,
    seatsComingSoonTitle,
    seatsComingSoonMessage,
    seatsPassengersLabel,
    passengerCount,
    profileGuestTitle,
    profileGuestMessage,
    profileAccount,
    profilePreferences,
    profileAboutSection,
    routeSupportContactTitle,
    routeProfileEditTitle,
    routeNotificationSettingsTitle,
    routeNotificationsTitle,
    tripSelectSeats,
    tripPointSelected,
    seatSelectTitle,
    seatLegendAvailable,
    seatLegendSelected,
    seatLegendBooked,
    seatLegendLadies,
    seatLegendBlocked,
    seatChosenCount,
    seatDeckLower,
    seatDeckUpper,
    seatFront,
    seatNoneSelected,
    seatSelectedSummary,
    seatLimitReached,
    seatBookedTip,
    seatSemantics,
    seatSemanticsNoPrice,
    seatContinue,
    seatLoggedInKept,
    seatSummaryTitle,
    seatTotal,
    seatClose,
    seatMapLabel,
    seatSoldOutTitle,
    seatSoldOutMessage,
    pointsTitle,
    pointsSubtitle,
    pointsBoardingTab,
    pointsDroppingTab,
    pointsBoardingHeading,
    pointsDroppingHeading,
    pointsLandmark,
    pointsMap,
    pointsMapSemantics,
    pointsMapFailed,
    pointsSummaryBoarding,
    pointsSummaryDropping,
    pointsContinue,
    pointsTabs,
    holdChipSemantics,
    holdBanner,
    holdExpiredBarTitle,
    holdExpiredTitle,
    holdExpiredMessage,
    holdExpiredMessageGeneric,
    holdExpiredAgain,
    holdExpiredBack,
    seatsTakenMessage,
    passengerTitle,
    passengerUseProfile,
    passengerUseProfileHint,
    passengerCardTitle,
    passengerSeatChip,
    passengerSeatChipLadies,
    passengerName,
    passengerAge,
    passengerGenderMale,
    passengerGenderFemale,
    passengerGenderOther,
    passengerGenderLabel,
    passengerNameError,
    passengerAgeError,
    passengerGenderError,
    passengerLadiesError,
    contactTitle,
    contactHint,
    contactCountryCode,
    contactMobile,
    contactEmail,
    contactMobileError,
    contactEmailError,
    gstTitle,
    gstHint,
    gstGstin,
    gstCompany,
    gstGstinError,
    gstCompanyError,
    passengerFixFields,
    passengerContinue,
    reviewTitle,
    reviewSubtitle,
    reviewRouteLine,
    reviewPassengers,
    reviewBoarding,
    reviewDropping,
    reviewProceed,
    couponTitle,
    couponCodeLabel,
    couponApply,
    couponApplied,
    couponRemove,
    couponInvalid,
    fareTitle,
    fareSummaryTitle,
    fareBase,
    fareGst,
    fareConvenienceFee,
    fareDiscount,
    cancelPolicyTitle,
    cancelPolicyBefore,
    cancelPolicyBetween,
    cancelPolicyUnder,
    cancelPolicyRefund,
    cancelPolicyNoRefund,
    termsAgree,
    payTitle,
    paySubtitle,
    payMethodUpi,
    payMethodUpiHint,
    payMethodCard,
    payMethodCardHint,
    payMethodNetBanking,
    payMethodNetBankingHint,
    payMethodWallet,
    payMethodWalletHint,
    payUpiGpay,
    payUpiPhonepe,
    payUpiPaytm,
    payUpiBhim,
    payUpiId,
    payUpiIdHint,
    payUpiIdError,
    payUpiVerify,
    payUpiVerified,
    payCardNumber,
    payCardNumberError,
    payCardExpiry,
    payCardExpiryError,
    payCardCvv,
    payCardCvvError,
    payCardName,
    payCardNameError,
    payBankSbi,
    payBankHdfc,
    payBankIcici,
    payBankAxis,
    payBankKotak,
    payWalletPaytm,
    payWalletPhonepe,
    payWalletAmazon,
    payEncrypted,
    payHoldCaption,
    payAction,
    payProcessingBarTitle,
    payProcessingBarSubtitle,
    payProcessingTitle,
    payProcessingMessage,
    payFailedBarTitle,
    payFailedBarSubtitle,
    payFailedTitle,
    payFailedMessage,
    payFailedNetwork,
    payFailedRefundNote,
    payFailedRefundNoteShort,
    payRetry,
    payChangeMethod,
    payBackToReview,
    holdBannerShort,
    ticketConfirmedTitle,
    ticketSentTo,
    ticketReady,
    ticketPnrChip,
    ticketPnrCopyHint,
    ticketPnrCopied,
    ticketPaid,
    ticketSummaryLine,
    ticketSummarySeats,
    ticketViewTicket,
    ticketShare,
    ticketAddToCalendar,
    ticketCalendarFailed,
    ticketCalendarTitle,
    ticketBarTitle,
    ticketBarSubtitle,
    ticketQrLabel,
    ticketQrHint,
    ticketPassengersTitle,
    ticketSeat,
    ticketBoardingPoint,
    ticketReportEarly,
    ticketOperatorContact,
    ticketCallOperator,
    ticketDownloadPdf,
    ticketPdfFailed,
    ticketShareText,
    tripsTabUpcoming,
    tripsTabCompleted,
    tripsTabCancelled,
    tripsTabsLabel,
    tripsToday,
    statusConfirmed,
    statusCompleted,
    statusCancelled,
    statusRefundProcessing,
    statusRefunded,
    tripsCardSeats,
    tripsCardTimes,
    tripsEmptyUpcomingTitle,
    tripsEmptyUpcomingMessage,
    tripsEmptyCompletedTitle,
    tripsEmptyCompletedMessage,
    tripsEmptyCancelledTitle,
    tripsEmptyCancelledMessage,
    tripsViewUpcoming,
    tripsSearchBuses,
    tripDetailsTitle,
    tdTimeline,
    tdBooked,
    tdBookedLine,
    tdTicketIssued,
    tdTicketIssuedLine,
    tdBoarding,
    tdBoardingLine,
    tdArrival,
    tdArrivalLine,
    tdEticket,
    tdEticketLine,
    tdCancelSeats,
    tdGetHelp,
    tdTrackBus,
    tdTrackLater,
    tdRefundLink,
    cancelTitle,
    cancelSelectSeats,
    cancelEstimate,
    cancelTierBefore,
    cancelTierBetween,
    cancelTierUnder,
    cancelFarePaid,
    cancelCharge,
    cancelRefundAmount,
    cancelRefundNote,
    cancelPickSeat,
    cancelReasonTitle,
    cancelReasonPlans,
    cancelReasonMistake,
    cancelReasonBetter,
    cancelReasonMedical,
    cancelReasonOther,
    cancelBarRefund,
    cancelAction,
    cancelSheetTitle,
    cancelSheetBody,
    cancelSheetRefund,
    cancelSheetNoRefund,
    cancelKeep,
    cancelConfirm,
    cancelFailed,
    refundTitle,
    refundAmountLabel,
    refundDoneLabel,
    refundTo,
    refundRequested,
    refundRequestedLine,
    refundProcessing,
    refundProcessingLine,
    refundProcessingDone,
    refundRefunded,
    refundRefundedExpected,
    refundRefundedLine,
    refundUtr,
    refundUtrPending,
    refundUtrCopy,
    refundUtrCopied,
    refundHelp,
    refundBack,
    timelineDone,
    timelineNow,
    timelineNext,
    trackTitle,
    trackSubtitle,
    trackArriving,
    trackEtaMinutes,
    trackEtaApprox,
    trackStaleEta,
    trackOnTime,
    trackDelayed,
    trackSignalLost,
    trackLastUpdated,
    trackLastUpdatedShort,
    trackLastSeen,
    trackStaleBanner,
    trackStaleBannerNoPlace,
    trackCallOperator,
    trackRetry,
    trackDriver,
    trackDriverLine,
    trackCallDriver,
    trackShareTrip,
    trackSos,
    trackMapLive,
    trackMapStale,
    sosTitle,
    sosSubtitle,
    sosIntro,
    sosButton,
    sosButtonSemantics,
    sosSeconds,
    sosReleasedEarly,
    sosNote,
    sosContacts,
    sosContactsEmpty,
    sosCall,
    sosAddContact,
    sosShareLocation,
    sosHelplines,
    helplineWomen,
    helplinePolice,
    helplineAmbulance,
    helplineAbra,
    contactAddTitle,
    contactNameLabel,
    contactPhoneLabel,
    contactRelationLabel,
    contactSave,
    contactNameRequired,
    contactPhoneRequired,
    sosAlertTitle,
    sosAlertSubtitle,
    sosAlertMessage,
    sosAlertContacts,
    sosAlertLocation,
    sosAlertPolice,
    sosAlertTeam,
    sosCall112,
    sosImSafe,
    sosSafeConfirmTitle,
    sosSafeConfirmBody,
    sosSafeConfirmYes,
    sosSafeConfirmNo,
    sosFailed,
    shareTitle,
    shareSubtitle,
    shareOnBanner,
    shareOnBannerNobody,
    shareOffBanner,
    shareLinkTitle,
    shareWhatsapp,
    shareSms,
    shareCopyLink,
    shareLinkCopied,
    shareMessage,
    sharePeople,
    sharePersonViewed,
    sharePersonNotOpened,
    sharePeopleNone,
    shareStop,
    shareStart,
    shareStopped,
    shareStarted,
    shareOpenFailed,
    notifTitle,
    notifUnread,
    notifFilterAll,
    notifFilterBooking,
    notifFilterOffers,
    notifFilterSafety,
    notifFilters,
    notifMarkAllRead,
    notifToday,
    notifEarlier,
    notifUnreadDot,
    notifEmptyTitle,
    notifEmptyMessage,
    notifShowAll,
    notifOffersAction,
    notifJustNow,
    notifMinutesAgo,
    notifHoursAgo,
    notifDaysAgo,
    offersTitle,
    offersSubtitle,
    offersViewOffer,
    offersCopy,
    offersCopied,
    offersCodeCopied,
    offersValidTill,
    offersTermsApply,
    offersTermsTitle,
    offersGotIt,
    offersEmptyTitle,
    offersEmptyMessage,
    offersCarousel,
    offersCarouselPage,
    offersCopyCodeSemantics,
  };
}
