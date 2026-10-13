/// Keys of the management app's own messages (`l10n/admin_<locale>.arb`).
///
/// Messages shared by every app are in `AbraStrings` (shared_localization).
/// A test keeps this list identical to `admin_en.arb`.
abstract final class AdminStrings {
  static const appName = 'appName';
  static const signInTitle = 'signInTitle';
  static const signInSubtitle = 'signInSubtitle';
  static const signInEmail = 'signInEmail';
  static const signInPassword = 'signInPassword';
  static const signInButton = 'signInButton';
  static const signInEmailInvalid = 'signInEmailInvalid';
  static const signInPasswordRequired = 'signInPasswordRequired';
  static const signInErrorCredentials = 'signInErrorCredentials';
  static const signInErrorLocked = 'signInErrorLocked';
  static const signInErrorDisabled = 'signInErrorDisabled';
  static const sessionEndedNotice = 'sessionEndedNotice';
  static const mfaTitle = 'mfaTitle';
  static const mfaSubtitle = 'mfaSubtitle';
  static const mfaRecoverySubtitle = 'mfaRecoverySubtitle';
  static const mfaCode = 'mfaCode';
  static const mfaRecoveryCode = 'mfaRecoveryCode';
  static const mfaUseRecovery = 'mfaUseRecovery';
  static const mfaUseApp = 'mfaUseApp';
  static const mfaVerify = 'mfaVerify';
  static const mfaErrorInvalid = 'mfaErrorInvalid';
  static const mfaBack = 'mfaBack';
  static const accessNotStaffTitle = 'accessNotStaffTitle';
  static const accessNotStaffMessage = 'accessNotStaffMessage';
  static const accessMfaSetupTitle = 'accessMfaSetupTitle';
  static const accessMfaSetupMessage = 'accessMfaSetupMessage';
  static const accessNoSectionsTitle = 'accessNoSectionsTitle';
  static const accessNoSectionsMessage = 'accessNoSectionsMessage';
  static const accessPermissionsFailedTitle = 'accessPermissionsFailedTitle';
  static const navCatalogue = 'navCatalogue';
  static const navCities = 'navCities';
  static const navBusTypes = 'navBusTypes';
  static const navOperators = 'navOperators';
  static const navLocations = 'navLocations';
  static const navBuses = 'navBuses';
  static const navRoutes = 'navRoutes';
  static const navTrips = 'navTrips';
  static const navMenu = 'navMenu';
  static const navScopePlatform = 'navScopePlatform';
  static const navScopeOperator = 'navScopeOperator';
  static const listCreate = 'listCreate';
  static const listSearch = 'listSearch';
  static const listRefresh = 'listRefresh';
  static const listAll = 'listAll';
  static const listRange = 'listRange';
  static const listPrevious = 'listPrevious';
  static const listNext = 'listNext';
  static const listEmptyTitle = 'listEmptyTitle';
  static const listEmptyFiltered = 'listEmptyFiltered';
  static const listActions = 'listActions';
  static const actionEdit = 'actionEdit';
  static const actionView = 'actionView';
  static const actionEnable = 'actionEnable';
  static const actionDisable = 'actionDisable';
  static const actionChangeStatus = 'actionChangeStatus';
  static const statusActive = 'statusActive';
  static const statusInactive = 'statusInactive';
  static const formSave = 'formSave';
  static const formRequired = 'formRequired';
  static const formWholeNumber = 'formWholeNumber';
  static const formNumber = 'formNumber';
  static const formSaved = 'formSaved';
  static const formReason = 'formReason';
  static const formReasonHelp = 'formReasonHelp';
  static const formAddRow = 'formAddRow';
  static const formRemoveRow = 'formRemoveRow';
  static const formChoose = 'formChoose';
  static const formYes = 'formYes';
  static const formNo = 'formNo';
  static const confirmEnableTitle = 'confirmEnableTitle';
  static const confirmDisableTitle = 'confirmDisableTitle';
  static const confirmStatusMessage = 'confirmStatusMessage';
  static const fieldName = 'fieldName';
  static const fieldState = 'fieldState';
  static const fieldCountryCode = 'fieldCountryCode';
  static const fieldSlug = 'fieldSlug';
  static const fieldPopular = 'fieldPopular';
  static const fieldSortOrder = 'fieldSortOrder';
  static const fieldLatitude = 'fieldLatitude';
  static const fieldLongitude = 'fieldLongitude';
  static const fieldStatus = 'fieldStatus';
  static const fieldKey = 'fieldKey';
  static const fieldAc = 'fieldAc';
  static const fieldBerthType = 'fieldBerthType';
  static const fieldCompanyName = 'fieldCompanyName';
  static const fieldDisplayName = 'fieldDisplayName';
  static const fieldCity = 'fieldCity';
  static const fieldOperator = 'fieldOperator';
  static const fieldAddress = 'fieldAddress';
  static const fieldLandmark = 'fieldLandmark';
  static const fieldInstructions = 'fieldInstructions';
  static const fieldContactPhone = 'fieldContactPhone';
  static const fieldOwner = 'fieldOwner';
  static const ownerShared = 'ownerShared';
  static const ownerOperator = 'ownerOperator';
  static const fieldRegistration = 'fieldRegistration';
  static const fieldBusType = 'fieldBusType';
  static const fieldAmenities = 'fieldAmenities';
  static const fieldSeatCapacity = 'fieldSeatCapacity';
  static const fieldOrigin = 'fieldOrigin';
  static const fieldDestination = 'fieldDestination';
  static const fieldDistanceKm = 'fieldDistanceKm';
  static const fieldDuration = 'fieldDuration';
  static const fieldStops = 'fieldStops';
  static const fieldOffsetMinutes = 'fieldOffsetMinutes';
  static const fieldBus = 'fieldBus';
  static const fieldRoute = 'fieldRoute';
  static const fieldTravelDate = 'fieldTravelDate';
  static const fieldDepartureTime = 'fieldDepartureTime';
  static const fieldFare = 'fieldFare';
  static const fieldBoardingPoints = 'fieldBoardingPoints';
  static const fieldDroppingPoints = 'fieldDroppingPoints';
  static const fieldLocation = 'fieldLocation';
  static const fieldDeparture = 'fieldDeparture';
  static const fieldArrival = 'fieldArrival';
  static const fieldSeats = 'fieldSeats';
  static const fieldDate = 'fieldDate';
  static const cityCreateTitle = 'cityCreateTitle';
  static const cityEditTitle = 'cityEditTitle';
  static const busTypeCreateTitle = 'busTypeCreateTitle';
  static const busTypeEditTitle = 'busTypeEditTitle';
  static const operatorCreateTitle = 'operatorCreateTitle';
  static const operatorEditTitle = 'operatorEditTitle';
  static const operatorStatusTitle = 'operatorStatusTitle';
  static const locationCreateTitle = 'locationCreateTitle';
  static const locationEditTitle = 'locationEditTitle';
  static const busCreateTitle = 'busCreateTitle';
  static const busEditTitle = 'busEditTitle';
  static const busStatusTitle = 'busStatusTitle';
  static const routeCreateTitle = 'routeCreateTitle';
  static const routeEditTitle = 'routeEditTitle';
  static const tripCreateTitle = 'tripCreateTitle';
  static const tripEditTitle = 'tripEditTitle';
  static const tripDetailTitle = 'tripDetailTitle';
  static const berthSeater = 'berthSeater';
  static const berthSleeper = 'berthSleeper';
  static const berthSemiSleeper = 'berthSemiSleeper';
  static const berthMixed = 'berthMixed';
  static const operatorPending = 'operatorPending';
  static const operatorActive = 'operatorActive';
  static const operatorRejected = 'operatorRejected';
  static const operatorSuspended = 'operatorSuspended';
  static const busActive = 'busActive';
  static const busMaintenance = 'busMaintenance';
  static const busRetired = 'busRetired';
  static const tripDraft = 'tripDraft';
  static const tripScheduled = 'tripScheduled';
  static const tripBoarding = 'tripBoarding';
  static const tripDeparted = 'tripDeparted';
  static const tripInTransit = 'tripInTransit';
  static const tripArrived = 'tripArrived';
  static const tripDelayed = 'tripDelayed';
  static const tripCancelled = 'tripCancelled';
  static const tripPublish = 'tripPublish';
  static const tripCancel = 'tripCancel';
  static const tripPublishConfirmTitle = 'tripPublishConfirmTitle';
  static const tripPublishConfirmMessage = 'tripPublishConfirmMessage';
  static const tripCancelTitle = 'tripCancelTitle';
  static const tripCancelMessage = 'tripCancelMessage';
  static const tripPublishedNotice = 'tripPublishedNotice';
  static const tripCancelledNotice = 'tripCancelledNotice';
  static const tripPublishRejectedTitle = 'tripPublishRejectedTitle';
  static const tripChecklistTitle = 'tripChecklistTitle';
  static const tripChecklistNote = 'tripChecklistNote';
  static const checkOperator = 'checkOperator';
  static const checkBus = 'checkBus';
  static const checkSeatCapacity = 'checkSeatCapacity';
  static const checkRoute = 'checkRoute';
  static const checkBoarding = 'checkBoarding';
  static const checkDropping = 'checkDropping';
  static const checkDeparture = 'checkDeparture';
  static const checkBusType = 'checkBusType';
  static const checkCities = 'checkCities';
  static const checkBusFree = 'checkBusFree';
  static const checkMet = 'checkMet';
  static const checkNotMet = 'checkNotMet';
  static const checkByServer = 'checkByServer';
  static const tripSeatsValue = 'tripSeatsValue';
  static const tripFareValue = 'tripFareValue';

  static const brandName = 'brandName';
  static const brandCaption = 'brandCaption';
  static const signInBrandHeadline = 'signInBrandHeadline';
  static const signInBrandBody = 'signInBrandBody';
  static const signInBrandPointCatalogue = 'signInBrandPointCatalogue';
  static const signInBrandPointAccess = 'signInBrandPointAccess';
  static const signInBrandPointAudit = 'signInBrandPointAudit';
  static const signInShowPassword = 'signInShowPassword';
  static const signInHidePassword = 'signInHidePassword';
  static const hintTrips = 'hintTrips';
  static const hintBuses = 'hintBuses';
  static const hintRoutes = 'hintRoutes';
  static const hintLocations = 'hintLocations';
  static const hintOperators = 'hintOperators';
  static const hintCities = 'hintCities';
  static const hintBusTypes = 'hintBusTypes';
  static const navDocumentTypes = 'navDocumentTypes';
  static const hintDocumentTypes = 'hintDocumentTypes';
  static const documentTypeCreateTitle = 'documentTypeCreateTitle';
  static const documentTypeEditTitle = 'documentTypeEditTitle';
  static const fieldAppliesTo = 'fieldAppliesTo';
  static const fieldRequired = 'fieldRequired';
  static const fieldRequiresExpiry = 'fieldRequiresExpiry';
  static const fieldFileTypes = 'fieldFileTypes';
  static const fieldMaxFileSize = 'fieldMaxFileSize';
  static const fieldMaxFiles = 'fieldMaxFiles';
  static const subjectOperator = 'subjectOperator';
  static const subjectBus = 'subjectBus';
  static const navSettings = 'navSettings';
  static const hintSettings = 'hintSettings';
  static const settingsTabWhatsApp = 'settingsTabWhatsApp';
  static const settingsTabEmail = 'settingsTabEmail';
  static const settingsStatusReady = 'settingsStatusReady';
  static const settingsStatusDisabled = 'settingsStatusDisabled';
  static const settingsStatusIncomplete = 'settingsStatusIncomplete';
  static const settingsStillMissing = 'settingsStillMissing';
  static const settingsReadOnly = 'settingsReadOnly';
  static const settingsHelpWhatsApp = 'settingsHelpWhatsApp';
  static const settingsHelpEmail = 'settingsHelpEmail';
  static const fieldEnabled = 'fieldEnabled';
  static const fieldBusinessAccountId = 'fieldBusinessAccountId';
  static const navKycConfiguration = 'navKycConfiguration';
  static const navCustomers = 'navCustomers';
  static const hintCustomers = 'hintCustomers';
  static const hintKycConfiguration = 'hintKycConfiguration';
  static const fieldPhoneDisplay = 'fieldPhoneDisplay';
  static const fieldWebhookVerifyToken = 'fieldWebhookVerifyToken';
  static const settingsWhatsAppConnection = 'settingsWhatsAppConnection';
  static const settingsWhatsAppOtp = 'settingsWhatsAppOtp';
  static const settingsWhatsAppNotifications = 'settingsWhatsAppNotifications';
  static const settingsPhoneDisplayHelp = 'settingsPhoneDisplayHelp';
  static const settingsWebhookHelp = 'settingsWebhookHelp';
  static const settingsOtpHelp = 'settingsOtpHelp';
  static const fieldPhoneNumberId = 'fieldPhoneNumberId';
  static const fieldAccessToken = 'fieldAccessToken';
  static const fieldOtpTemplateName = 'fieldOtpTemplateName';
  static const fieldOtpTemplateLanguage = 'fieldOtpTemplateLanguage';
  static const fieldOtpFallbackSms = 'fieldOtpFallbackSms';
  static const fieldHost = 'fieldHost';
  static const fieldPort = 'fieldPort';
  static const fieldSecurity = 'fieldSecurity';
  static const fieldUsername = 'fieldUsername';
  static const fieldPassword = 'fieldPassword';
  static const fieldFromName = 'fieldFromName';
  static const fieldFromAddress = 'fieldFromAddress';
  static const fieldReplyTo = 'fieldReplyTo';
  static const fieldReason = 'fieldReason';
  static const securitySsl = 'securitySsl';
  static const securityStarttls = 'securityStarttls';
  static const securityNone = 'securityNone';
  static const secretNotSet = 'secretNotSet';
  static const secretSaved = 'secretSaved';
  static const secretSavedEnding = 'secretSavedEnding';
  static const secretFromServer = 'secretFromServer';
  static const settingsTestConnection = 'settingsTestConnection';
  static const settingsSendTestEmail = 'settingsSendTestEmail';
  static const settingsTestEmailTo = 'settingsTestEmailTo';
  static const settingsTestRunning = 'settingsTestRunning';
  static const settingsSaveFirst = 'settingsSaveFirst';
  static const settingsDefaultReason = 'settingsDefaultReason';
  static const revDocMissing = 'revDocMissing';
  static const revFiles = 'revFiles';
  static const revNoFiles = 'revNoFiles';
  static const revSubmittedOn = 'revSubmittedOn';
  static const revNotSentYet = 'revNotSentYet';
  static const revDecided = 'revDecided';
  static const listDateFrom = 'listDateFrom';
  static const listDateTo = 'listDateTo';
  static const listExport = 'listExport';
  static const listImport = 'listImport';
  static const listExporting = 'listExporting';
  static const listExportEmpty = 'listExportEmpty';
  static const listExportDone = 'listExportDone';
  static const importTitle = 'importTitle';
  static const importIntro = 'importIntro';
  static const importSample = 'importSample';
  static const importChoose = 'importChoose';
  static const importRun = 'importRun';
  static const importDone = 'importDone';
  static const importRow = 'importRow';
  static const importReason = 'importReason';
  static const importNoFile = 'importNoFile';
  static const importEmptyFile = 'importEmptyFile';
  static const importMissingColumns = 'importMissingColumns';
  static const importClose = 'importClose';
  static const navInvitations = 'navInvitations';
  static const hintInvitations = 'hintInvitations';
  static const navReviews = 'navReviews';
  static const hintReviews = 'hintReviews';
  static const invCreateTitle = 'invCreateTitle';
  static const invCompany = 'invCompany';
  static const invDisplayName = 'invDisplayName';
  static const invOwner = 'invOwner';
  static const invEmail = 'invEmail';
  static const invPhone = 'invPhone';
  static const invSent = 'invSent';
  static const invNotSent = 'invNotSent';
  static const invLink = 'invLink';
  static const invColCompany = 'invColCompany';
  static const invColOwner = 'invColOwner';
  static const invColEmail = 'invColEmail';
  static const invColStatus = 'invColStatus';
  static const invColMail = 'invColMail';
  static const invColExpires = 'invColExpires';
  static const invColCreated = 'invColCreated';
  static const invStatusPending = 'invStatusPending';
  static const invStatusAccepted = 'invStatusAccepted';
  static const invStatusRevoked = 'invStatusRevoked';
  static const invStatusExpired = 'invStatusExpired';
  static const invMailSent = 'invMailSent';
  static const invMailFailed = 'invMailFailed';
  static const invMailNotSent = 'invMailNotSent';
  static const invActionResend = 'invActionResend';
  static const invActionRevoke = 'invActionRevoke';
  static const invResent = 'invResent';
  static const invRevoked = 'invRevoked';
  static const invRevokeTitle = 'invRevokeTitle';
  static const invRevokeMessage = 'invRevokeMessage';
  static const invRevokeConfirm = 'invRevokeConfirm';
  static const revColSubject = 'revColSubject';
  static const revColCompany = 'revColCompany';
  static const revColBus = 'revColBus';
  static const revColStatus = 'revColStatus';
  static const revColSent = 'revColSent';
  static const revColTimes = 'revColTimes';
  static const revSubjectCompany = 'revSubjectCompany';
  static const revSubjectBus = 'revSubjectBus';
  static const revStatusDraft = 'revStatusDraft';
  static const revStatusPending = 'revStatusPending';
  static const revStatusApproved = 'revStatusApproved';
  static const revStatusRejected = 'revStatusRejected';
  static const revActionOpen = 'revActionOpen';
  static const revBack = 'revBack';
  static const revDocuments = 'revDocuments';
  static const revNoDocuments = 'revNoDocuments';
  static const revDocApproved = 'revDocApproved';
  static const revDocRejected = 'revDocRejected';
  static const revDocPending = 'revDocPending';
  static const revAccept = 'revAccept';
  static const revReject = 'revReject';
  static const revReasonLabel = 'revReasonLabel';
  static const revApprove = 'revApprove';
  static const revSendBack = 'revSendBack';
  static const revApproveTitle = 'revApproveTitle';
  static const revApproveMessage = 'revApproveMessage';
  static const revSendBackTitle = 'revSendBackTitle';
  static const revNoteLabel = 'revNoteLabel';
  static const revProblems = 'revProblems';
  static const revHistory = 'revHistory';
  static const revOpenFile = 'revOpenFile';
  static const revExpires = 'revExpires';
  static const revDecisionNote = 'revDecisionNote';
  static const revOpenFailed = 'revOpenFailed';
  static const revApprovedDone = 'revApprovedDone';
  static const revSentBackDone = 'revSentBackDone';
  static const revHistCreated = 'revHistCreated';
  static const revHistSubmitted = 'revHistSubmitted';
  static const revHistResubmitted = 'revHistResubmitted';
  static const revHistDocumentApproved = 'revHistDocumentApproved';
  static const revHistDocumentRejected = 'revHistDocumentRejected';
  static const revHistApproved = 'revHistApproved';
  static const revHistRejected = 'revHistRejected';
  static const settingsSearch = 'settingsSearch';
  static const settingsSectionWhatsApp = 'settingsSectionWhatsApp';
  static const settingsSectionWhatsAppHint = 'settingsSectionWhatsAppHint';
  static const settingsSectionEmail = 'settingsSectionEmail';
  static const settingsSectionEmailHint = 'settingsSectionEmailHint';
  static const settingsClose = 'settingsClose';
  static const settingsNoMatch = 'settingsNoMatch';
  static const fieldNotificationTemplate = 'fieldNotificationTemplate';
  static const fieldNotificationLanguage = 'fieldNotificationLanguage';
  static const settingsNotificationHelp = 'settingsNotificationHelp';
  static const listEmptyMessage = 'listEmptyMessage';
  static const listEmptyAction = 'listEmptyAction';
  static const listClearFilters = 'listClearFilters';
  static const listUpdating = 'listUpdating';
  static const tripSeatsNotOnSale = 'tripSeatsNotOnSale';
  static const tripSeatsClosed = 'tripSeatsClosed';
  static const userMenuSignedInAs = 'userMenuSignedInAs';
  static const navContent = 'navContent';
  static const navBanners = 'navBanners';
  static const hintBanners = 'hintBanners';
  static const bannerCreateTitle = 'bannerCreateTitle';
  static const bannerEditTitle = 'bannerEditTitle';
  static const bannerSearch = 'bannerSearch';
  static const bannerStatusLive = 'bannerStatusLive';
  static const bannerStatusScheduled = 'bannerStatusScheduled';
  static const bannerStatusExpired = 'bannerStatusExpired';
  static const fieldTitle = 'fieldTitle';
  static const fieldSubtitle = 'fieldSubtitle';
  static const fieldButtonText = 'fieldButtonText';
  static const fieldLinkType = 'fieldLinkType';
  static const fieldLinkValue = 'fieldLinkValue';
  static const fieldPlacement = 'fieldPlacement';
  static const fieldLanguage = 'fieldLanguage';
  static const fieldStartDate = 'fieldStartDate';
  static const fieldEndDate = 'fieldEndDate';
  static const fieldSchedule = 'fieldSchedule';
  static const fieldImage = 'fieldImage';
  static const fieldImageUrl = 'fieldImageUrl';
  static const fieldCreated = 'fieldCreated';
  static const fieldActive = 'fieldActive';
  static const linkNone = 'linkNone';
  static const linkOffer = 'linkOffer';
  static const linkRouteSearch = 'linkRouteSearch';
  static const linkScreen = 'linkScreen';
  static const linkUrl = 'linkUrl';
  static const linkHintNone = 'linkHintNone';
  static const linkHintOffer = 'linkHintOffer';
  static const linkHintRouteSearch = 'linkHintRouteSearch';
  static const linkHintScreen = 'linkHintScreen';
  static const linkHintUrl = 'linkHintUrl';
  static const placementHomeTop = 'placementHomeTop';
  static const placementOffers = 'placementOffers';
  static const languageAll = 'languageAll';
  static const languageEn = 'languageEn';
  static const languageHi = 'languageHi';
  static const languageTe = 'languageTe';
  static const languageKn = 'languageKn';
  static const languageTa = 'languageTa';
  static const languageMl = 'languageMl';
  static const languageMr = 'languageMr';
  static const languageBn = 'languageBn';
  static const bannerScheduleAlways = 'bannerScheduleAlways';
  static const bannerScheduleFrom = 'bannerScheduleFrom';
  static const bannerScheduleUntil = 'bannerScheduleUntil';
  static const bannerMonths = 'bannerMonths';
  static const actionDelete = 'actionDelete';
  static const actionUploadImage = 'actionUploadImage';
  static const actionPreview = 'actionPreview';
  static const bannerDeleteTitle = 'bannerDeleteTitle';
  static const bannerDeleteMessage = 'bannerDeleteMessage';
  static const bannerDeleted = 'bannerDeleted';
  static const bannerUploadTitle = 'bannerUploadTitle';
  static const bannerUploadIntro = 'bannerUploadIntro';
  static const bannerUploadChoose = 'bannerUploadChoose';
  static const bannerUploadWrongType = 'bannerUploadWrongType';
  static const bannerUploadTooLarge = 'bannerUploadTooLarge';
  static const bannerPreviewTitle = 'bannerPreviewTitle';
  static const bannerPreviewCaption = 'bannerPreviewCaption';
  static const bannerNoImage = 'bannerNoImage';
  static const formClearDate = 'formClearDate';
  static const bannerImagesTitle = 'bannerImagesTitle';
  static const bannerImageMobile = 'bannerImageMobile';
  static const bannerImageMobileHint = 'bannerImageMobileHint';
  static const bannerImageDesktop = 'bannerImageDesktop';
  static const bannerImageDesktopHint = 'bannerImageDesktopHint';
  static const bannerImageSafeArea = 'bannerImageSafeArea';
  static const bannerImageReplace = 'bannerImageReplace';
  static const bannerImageRemove = 'bannerImageRemove';
  static const bannerImageWillRemove = 'bannerImageWillRemove';
  static const bannerImagePending = 'bannerImagePending';
  static const bannerImageRatioWarning = 'bannerImageRatioWarning';
  static const bannerImageUploadFailed = 'bannerImageUploadFailed';
  static const bannerImagesPartlySaved = 'bannerImagesPartlySaved';
  static const bannerPreviewPhone = 'bannerPreviewPhone';
  static const bannerPreviewTablet = 'bannerPreviewTablet';
  static const bannerPreviewDesktop = 'bannerPreviewDesktop';
  static const bannerDesktopChip = 'bannerDesktopChip';
  static const bannerButtonHelp = 'bannerButtonHelp';
  static const fieldDesktopImageUrl = 'fieldDesktopImageUrl';
  static const exportImageUrl = 'exportImageUrl';
  static const exportDesktopImageUrl = 'exportDesktopImageUrl';
  static const linkOfferSoon = 'linkOfferSoon';
  static const linkScreenSoon = 'linkScreenSoon';

  static const listEmptyFilteredTitle = 'listEmptyFilteredTitle';

  static const deleteTitle = 'deleteTitle';
  static const deleteMessage = 'deleteMessage';
  static const deleteDone = 'deleteDone';
  static const deleteUndo = 'deleteUndo';
  static const deleteRestored = 'deleteRestored';
  static const bnSubtitle = 'bnSubtitle';
  static const bnTabAll = 'bnTabAll';
  static const bnNew = 'bnNew';
  static const bnNewTitle = 'bnNewTitle';
  static const bnEditTitle = 'bnEditTitle';
  static const bnColBanner = 'bnColBanner';
  static const bnColStatus = 'bnColStatus';
  static const bnColRuns = 'bnColRuns';
  static const bnColShownTo = 'bnColShownTo';
  static const bnColOpens = 'bnColOpens';
  static const bnColOrder = 'bnColOrder';
  static const bnRunsAlways = 'bnRunsAlways';
  static const bnRunsFrom = 'bnRunsFrom';
  static const bnRunsUntil = 'bnRunsUntil';
  static const bnRunsRange = 'bnRunsRange';
  static const bnStatusDraft = 'bnStatusDraft';
  static const bnStatusScheduled = 'bnStatusScheduled';
  static const bnStatusPublished = 'bnStatusPublished';
  static const bnStatusExpired = 'bnStatusExpired';
  static const bnStatusArchived = 'bnStatusArchived';
  static const bnAudAll = 'bnAudAll';
  static const bnAudNew = 'bnAudNew';
  static const bnAudSigned = 'bnAudSigned';
  static const bnOpenOffer = 'bnOpenOffer';
  static const bnOpenOfferNone = 'bnOpenOfferNone';
  static const bnOpenRoute = 'bnOpenRoute';
  static const bnOpenOperator = 'bnOpenOperator';
  static const bnOpenUrl = 'bnOpenUrl';
  static const bnOpenNone = 'bnOpenNone';
  static const bnOpenScreen = 'bnOpenScreen';
  static const bnFieldColour = 'bnFieldColour';
  static const bnColourNavyBlue = 'bnColourNavyBlue';
  static const bnColourBlueSky = 'bnColourBlueSky';
  static const bnColourGreenNavy = 'bnColourGreenNavy';
  static const bnFieldOpens = 'bnFieldOpens';
  static const bnOptOffer = 'bnOptOffer';
  static const bnOptRoute = 'bnOptRoute';
  static const bnOptOperator = 'bnOptOperator';
  static const bnOptLink = 'bnOptLink';
  static const bnFieldOfferCode = 'bnFieldOfferCode';
  static const bnFieldRouteFrom = 'bnFieldRouteFrom';
  static const bnFieldRouteTo = 'bnFieldRouteTo';
  static const bnFieldOperator = 'bnFieldOperator';
  static const bnFieldLink = 'bnFieldLink';
  static const bnFieldShownTo = 'bnFieldShownTo';
  static const bnFieldStarts = 'bnFieldStarts';
  static const bnFieldEnds = 'bnFieldEnds';
  static const bnFieldOrder = 'bnFieldOrder';
  static const bnSaveDraft = 'bnSaveDraft';
  static const bnPublish = 'bnPublish';
  static const bnUnpublish = 'bnUnpublish';
  static const bnDuplicate = 'bnDuplicate';
  static const bnArchive = 'bnArchive';
  static const bnUnarchive = 'bnUnarchive';
  static const bnMoveUp = 'bnMoveUp';
  static const bnMoveDown = 'bnMoveDown';
  static const bnEndBeforeStart = 'bnEndBeforeStart';
  static const bnToastPublished = 'bnToastPublished';
  static const bnToastScheduled = 'bnToastScheduled';
  static const bnToastDraft = 'bnToastDraft';
  static const bnToastUnpublished = 'bnToastUnpublished';
  static const bnToastArchived = 'bnToastArchived';
  static const bnToastUnarchived = 'bnToastUnarchived';
  static const bnToastDuplicated = 'bnToastDuplicated';
  static const bnPictures = 'bnPictures';
  static const bnPictureDesktop = 'bnPictureDesktop';
  static const bnPicturePhone = 'bnPicturePhone';
  static const bnPictureHint = 'bnPictureHint';
  static const bnPreviewHome = 'bnPreviewHome';
  static const bnPreviewCaption = 'bnPreviewCaption';
  static const bnPreviewOfferButton = 'bnPreviewOfferButton';
  static const invEditTitle = 'invEditTitle';
  static const invEditHint = 'invEditHint';
  static const invFieldExpires = 'invFieldExpires';
  static const invSearch = 'invSearch';
  static const invSaved = 'invSaved';
  static const listExportCsv = 'listExportCsv';
  static const listExportExcel = 'listExportExcel';
  static const impsWhatCities = 'impsWhatCities';
  static const impsWhatPlaces = 'impsWhatPlaces';
  static const impsTitle = 'impsTitle';
  static const impsIntro = 'impsIntro';
  static const impsTemplateCsv = 'impsTemplateCsv';
  static const impsTemplateExcel = 'impsTemplateExcel';
  static const impsChoose = 'impsChoose';
  static const impsChecking = 'impsChecking';
  static const impsReady = 'impsReady';
  static const impsProblems = 'impsProblems';
  static const impsRowLine = 'impsRowLine';
  static const impsIgnored = 'impsIgnored';
  static const impsImport = 'impsImport';
  static const impsSaving = 'impsSaving';
  static const impsDone = 'impsDone';
  static const impsNothingReady = 'impsNothingReady';
  static const impsClose = 'impsClose';
  static const listExportReady = 'listExportReady';
  static const amenitiesTitle = 'amenitiesTitle';
  static const amenityAdd = 'amenityAdd';
  static const amenityAddTitle = 'amenityAddTitle';
  static const amenityName = 'amenityName';
  static const amenityAddConfirm = 'amenityAddConfirm';
  static const amenityToggle = 'amenityToggle';
  static const amenityOn = 'amenityOn';
  static const amenityOff = 'amenityOff';
  static const amenitiesEmpty = 'amenitiesEmpty';
  static const amenitiesHint = 'amenitiesHint';
  static const navPlaces = 'navPlaces';
  static const hintPlaces = 'hintPlaces';
  static const placesTabPlaces = 'placesTabPlaces';
  static const placesTabCities = 'placesTabCities';
  static const placesTabRequests = 'placesTabRequests';
  static const placesAdd = 'placesAdd';
  static const placesEdit = 'placesEdit';
  static const placesFieldName = 'placesFieldName';
  static const placesFieldInstructions = 'placesFieldInstructions';
  static const placesColPlace = 'placesColPlace';
  static const placesColUsedFor = 'placesColUsedFor';
  static const placesColAddedBy = 'placesColAddedBy';
  static const placesColTrips = 'placesColTrips';
  static const placesUsedBoarding = 'placesUsedBoarding';
  static const placesUsedDropping = 'placesUsedDropping';
  static const placesUsedBoth = 'placesUsedBoth';
  static const placesBadgeBoarding = 'placesBadgeBoarding';
  static const placesBadgeDropping = 'placesBadgeDropping';
  static const placesBadgeBoth = 'placesBadgeBoth';
  static const placesSourceAdmin = 'placesSourceAdmin';
  static const placesSourceImport = 'placesSourceImport';
  static const placesSourceRequest = 'placesSourceRequest';
  static const placesSourceOperator = 'placesSourceOperator';
  static const preqColPlace = 'preqColPlace';
  static const preqColRequested = 'preqColRequested';
  static const preqPending = 'preqPending';
  static const preqApproved = 'preqApproved';
  static const preqRejected = 'preqRejected';
  static const preqApprove = 'preqApprove';
  static const preqApprovedDone = 'preqApprovedDone';
  static const preqReject = 'preqReject';
  static const preqRejectTitle = 'preqRejectTitle';
  static const preqReason = 'preqReason';
  static const agoNow = 'agoNow';
  static const agoMinutes = 'agoMinutes';
  static const agoHours = 'agoHours';
  static const agoDays = 'agoDays';
  static const opdBack = 'opdBack';
  static const opdTabOverview = 'opdTabOverview';
  static const opdTabBuses = 'opdTabBuses';
  static const opdTabPayout = 'opdTabPayout';
  static const opdTabBookings = 'opdTabBookings';
  static const opdTabActivity = 'opdTabActivity';
  static const opdSuspend = 'opdSuspend';
  static const opdReactivate = 'opdReactivate';
  static const opdMessage = 'opdMessage';
  static const opdCompany = 'opdCompany';
  static const opdNumbers = 'opdNumbers';
  static const opdOwner = 'opdOwner';
  static const opdEmail = 'opdEmail';
  static const opdPhone = 'opdPhone';
  static const opdJoined = 'opdJoined';
  static const opdCompanyName = 'opdCompanyName';
  static const opdBuses = 'opdBuses';
  static const opdTrips = 'opdTrips';
  static const opdBookings = 'opdBookings';
  static const opdSales = 'opdSales';
  static const opdKycNone = 'opdKycNone';
  static const opdKyc = 'opdKyc';
  static const opdSuspendTitle = 'opdSuspendTitle';
  static const opdSuspendBody = 'opdSuspendBody';
  static const opdSuspendReason = 'opdSuspendReason';
  static const opdSuspendProof = 'opdSuspendProof';
  static const opdSuspended = 'opdSuspended';
  static const opdReactivated = 'opdReactivated';
  static const opdReactivateTitle = 'opdReactivateTitle';
  static const opdReactivateBody = 'opdReactivateBody';
  static const opdMessageTitle = 'opdMessageTitle';
  static const opdMessageField = 'opdMessageField';
  static const opdMessageSend = 'opdMessageSend';
  static const opdMessageSent = 'opdMessageSent';
  static const opdSuspensionTitle = 'opdSuspensionTitle';
  static const opdSuspensionReason = 'opdSuspensionReason';
  static const opdSuspensionProof = 'opdSuspensionProof';
  static const opdSuspensionSince = 'opdSuspensionSince';
  static const opdSuspensionEnded = 'opdSuspensionEnded';
  static const opdBusesEmpty = 'opdBusesEmpty';
  static const opdBusReg = 'opdBusReg';
  static const opdBusName = 'opdBusName';
  static const opdBusSeats = 'opdBusSeats';
  static const opdBusStatus = 'opdBusStatus';
  static const opdCommissionTitle = 'opdCommissionTitle';
  static const opdCommissionEmpty = 'opdCommissionEmpty';
  static const opdPayoutTitle = 'opdPayoutTitle';
  static const opdPayoutEmpty = 'opdPayoutEmpty';
  static const opdBookingsEmpty = 'opdBookingsEmpty';
  static const opdActivityEmpty = 'opdActivityEmpty';
  static const opdActivityBy = 'opdActivityBy';
  static const opdLoadFailed = 'opdLoadFailed';
  static const opNameColumn = 'opNameColumn';
  static const opKycColumn = 'opKycColumn';
  static const opJoinedColumn = 'opJoinedColumn';
  static const opSearch = 'opSearch';
  static const opInvite = 'opInvite';
  static const opdPayoutMode = 'opdPayoutMode';
  static const opdPayoutAuto = 'opdPayoutAuto';
  static const opdPayoutManual = 'opdPayoutManual';
  static const opdBankHolder = 'opdBankHolder';
  static const opdBankAccount = 'opdBankAccount';
  static const opdBankIfsc = 'opdBankIfsc';
  static const opdBankStatus = 'opdBankStatus';
  static const opdBankCheck = 'opdBankCheck';
  static const opdBankNone = 'opdBankNone';
  static const opdBankPending = 'opdBankPending';
  static const opdBankVerifiedLabel = 'opdBankVerifiedLabel';
  static const opdBankFailedLabel = 'opdBankFailedLabel';
  static const opdChangeMode = 'opdChangeMode';
  static const opdModeTitle = 'opdModeTitle';
  static const opdModeField = 'opdModeField';
  static const opdModeAutoOption = 'opdModeAutoOption';
  static const opdModeManualOption = 'opdModeManualOption';
  static const opdModeHint = 'opdModeHint';
  static const opdModeSaved = 'opdModeSaved';
  static const opdModeSave = 'opdModeSave';
  static const opdVerifyBank = 'opdVerifyBank';
  static const opdVerifyTitle = 'opdVerifyTitle';
  static const opdVerifyOutcome = 'opdVerifyOutcome';
  static const opdVerifyPassed = 'opdVerifyPassed';
  static const opdVerifyFailedOption = 'opdVerifyFailedOption';
  static const opdVerifyNote = 'opdVerifyNote';
  static const opdVerifyHint = 'opdVerifyHint';
  static const opdVerifySave = 'opdVerifySave';
  static const opdBankMarkedVerified = 'opdBankMarkedVerified';
  static const opdBankMarkedFailed = 'opdBankMarkedFailed';
  static const Set<String> all = <String>{
    appName,
    signInTitle,
    signInSubtitle,
    signInEmail,
    signInPassword,
    signInButton,
    signInEmailInvalid,
    signInPasswordRequired,
    signInErrorCredentials,
    signInErrorLocked,
    signInErrorDisabled,
    sessionEndedNotice,
    mfaTitle,
    mfaSubtitle,
    mfaRecoverySubtitle,
    mfaCode,
    mfaRecoveryCode,
    mfaUseRecovery,
    mfaUseApp,
    mfaVerify,
    mfaErrorInvalid,
    mfaBack,
    accessNotStaffTitle,
    accessNotStaffMessage,
    accessMfaSetupTitle,
    accessMfaSetupMessage,
    accessNoSectionsTitle,
    accessNoSectionsMessage,
    accessPermissionsFailedTitle,
    navCatalogue,
    navCities,
    navBusTypes,
    navOperators,
    navLocations,
    navBuses,
    navRoutes,
    navTrips,
    navMenu,
    navScopePlatform,
    navScopeOperator,
    listCreate,
    listSearch,
    listRefresh,
    listAll,
    listRange,
    listPrevious,
    listNext,
    listEmptyTitle,
    listEmptyFiltered,
    listActions,
    actionEdit,
    actionView,
    actionEnable,
    actionDisable,
    actionChangeStatus,
    statusActive,
    statusInactive,
    formSave,
    formRequired,
    formWholeNumber,
    formNumber,
    formSaved,
    formReason,
    formReasonHelp,
    formAddRow,
    formRemoveRow,
    formChoose,
    formYes,
    formNo,
    confirmEnableTitle,
    confirmDisableTitle,
    confirmStatusMessage,
    fieldName,
    fieldState,
    fieldCountryCode,
    fieldSlug,
    fieldPopular,
    fieldSortOrder,
    fieldLatitude,
    fieldLongitude,
    fieldStatus,
    fieldKey,
    fieldAc,
    fieldBerthType,
    fieldCompanyName,
    fieldDisplayName,
    fieldCity,
    fieldOperator,
    fieldAddress,
    fieldLandmark,
    fieldInstructions,
    fieldContactPhone,
    fieldOwner,
    ownerShared,
    ownerOperator,
    fieldRegistration,
    fieldBusType,
    fieldAmenities,
    fieldSeatCapacity,
    fieldOrigin,
    fieldDestination,
    fieldDistanceKm,
    fieldDuration,
    fieldStops,
    fieldOffsetMinutes,
    fieldBus,
    fieldRoute,
    fieldTravelDate,
    fieldDepartureTime,
    fieldFare,
    fieldBoardingPoints,
    fieldDroppingPoints,
    fieldLocation,
    fieldDeparture,
    fieldArrival,
    fieldSeats,
    fieldDate,
    cityCreateTitle,
    cityEditTitle,
    busTypeCreateTitle,
    busTypeEditTitle,
    operatorCreateTitle,
    operatorEditTitle,
    operatorStatusTitle,
    locationCreateTitle,
    locationEditTitle,
    busCreateTitle,
    busEditTitle,
    busStatusTitle,
    routeCreateTitle,
    routeEditTitle,
    tripCreateTitle,
    tripEditTitle,
    tripDetailTitle,
    berthSeater,
    berthSleeper,
    berthSemiSleeper,
    berthMixed,
    operatorPending,
    operatorActive,
    operatorRejected,
    operatorSuspended,
    busActive,
    busMaintenance,
    busRetired,
    tripDraft,
    tripScheduled,
    tripBoarding,
    tripDeparted,
    tripInTransit,
    tripArrived,
    tripDelayed,
    tripCancelled,
    tripPublish,
    tripCancel,
    tripPublishConfirmTitle,
    tripPublishConfirmMessage,
    tripCancelTitle,
    tripCancelMessage,
    tripPublishedNotice,
    tripCancelledNotice,
    tripPublishRejectedTitle,
    tripChecklistTitle,
    tripChecklistNote,
    checkOperator,
    checkBus,
    checkSeatCapacity,
    checkRoute,
    checkBoarding,
    checkDropping,
    checkDeparture,
    checkBusType,
    checkCities,
    checkBusFree,
    checkMet,
    checkNotMet,
    checkByServer,
    tripSeatsValue,
    tripFareValue,
    brandName,
    brandCaption,
    signInBrandHeadline,
    signInBrandBody,
    signInBrandPointCatalogue,
    signInBrandPointAccess,
    signInBrandPointAudit,
    signInShowPassword,
    signInHidePassword,
    hintTrips,
    hintBuses,
    hintRoutes,
    hintLocations,
    hintOperators,
    hintCities,
    hintBusTypes,
    navDocumentTypes,
    hintDocumentTypes,
    documentTypeCreateTitle,
    documentTypeEditTitle,
    fieldAppliesTo,
    fieldRequired,
    fieldRequiresExpiry,
    fieldFileTypes,
    fieldMaxFileSize,
    fieldMaxFiles,
    subjectOperator,
    subjectBus,
    navSettings,
    hintSettings,
    settingsTabWhatsApp,
    settingsTabEmail,
    settingsStatusReady,
    settingsStatusDisabled,
    settingsStatusIncomplete,
    settingsStillMissing,
    settingsReadOnly,
    settingsHelpWhatsApp,
    settingsHelpEmail,
    fieldEnabled,
    fieldBusinessAccountId,
    navKycConfiguration,
    navCustomers,
    hintCustomers,
    hintKycConfiguration,
    fieldPhoneDisplay,
    fieldWebhookVerifyToken,
    settingsWhatsAppConnection,
    settingsWhatsAppOtp,
    settingsWhatsAppNotifications,
    settingsPhoneDisplayHelp,
    settingsWebhookHelp,
    settingsOtpHelp,
    fieldPhoneNumberId,
    fieldAccessToken,
    fieldOtpTemplateName,
    fieldOtpTemplateLanguage,
    fieldOtpFallbackSms,
    fieldHost,
    fieldPort,
    fieldSecurity,
    fieldUsername,
    fieldPassword,
    fieldFromName,
    fieldFromAddress,
    fieldReplyTo,
    fieldReason,
    securitySsl,
    securityStarttls,
    securityNone,
    secretNotSet,
    secretSaved,
    secretSavedEnding,
    secretFromServer,
    settingsTestConnection,
    settingsSendTestEmail,
    settingsTestEmailTo,
    settingsTestRunning,
    settingsSaveFirst,
    settingsDefaultReason,
    revDocMissing,
    revFiles,
    revNoFiles,
    revSubmittedOn,
    revNotSentYet,
    revDecided,
    listDateFrom,
    listDateTo,
    listExport,
    listImport,
    listExporting,
    listExportEmpty,
    listExportDone,
    importTitle,
    importIntro,
    importSample,
    importChoose,
    importRun,
    importDone,
    importRow,
    importReason,
    importNoFile,
    importEmptyFile,
    importMissingColumns,
    importClose,
    navInvitations,
    hintInvitations,
    navReviews,
    hintReviews,
    invCreateTitle,
    invCompany,
    invDisplayName,
    invOwner,
    invEmail,
    invPhone,
    invSent,
    invNotSent,
    invLink,
    invColCompany,
    invColOwner,
    invColEmail,
    invColStatus,
    invColMail,
    invColExpires,
    invColCreated,
    invStatusPending,
    invStatusAccepted,
    invStatusRevoked,
    invStatusExpired,
    invMailSent,
    invMailFailed,
    invMailNotSent,
    invActionResend,
    invActionRevoke,
    invResent,
    invRevoked,
    invRevokeTitle,
    invRevokeMessage,
    invRevokeConfirm,
    revColSubject,
    revColCompany,
    revColBus,
    revColStatus,
    revColSent,
    revColTimes,
    revSubjectCompany,
    revSubjectBus,
    revStatusDraft,
    revStatusPending,
    revStatusApproved,
    revStatusRejected,
    revActionOpen,
    revBack,
    revDocuments,
    revNoDocuments,
    revDocApproved,
    revDocRejected,
    revDocPending,
    revAccept,
    revReject,
    revReasonLabel,
    revApprove,
    revSendBack,
    revApproveTitle,
    revApproveMessage,
    revSendBackTitle,
    revNoteLabel,
    revProblems,
    revHistory,
    revOpenFile,
    revExpires,
    revDecisionNote,
    revOpenFailed,
    revApprovedDone,
    revSentBackDone,
    revHistCreated,
    revHistSubmitted,
    revHistResubmitted,
    revHistDocumentApproved,
    revHistDocumentRejected,
    revHistApproved,
    revHistRejected,
    settingsSearch,
    settingsSectionWhatsApp,
    settingsSectionWhatsAppHint,
    settingsSectionEmail,
    settingsSectionEmailHint,
    settingsClose,
    settingsNoMatch,
    fieldNotificationTemplate,
    fieldNotificationLanguage,
    settingsNotificationHelp,
    listEmptyMessage,
    listEmptyAction,
    listClearFilters,
    listUpdating,
    tripSeatsNotOnSale,
    tripSeatsClosed,
    userMenuSignedInAs,
    listEmptyFilteredTitle,
    navContent,
    navBanners,
    hintBanners,
    bannerCreateTitle,
    bannerEditTitle,
    bannerSearch,
    bannerStatusLive,
    bannerStatusScheduled,
    bannerStatusExpired,
    fieldTitle,
    fieldSubtitle,
    fieldButtonText,
    fieldLinkType,
    fieldLinkValue,
    fieldPlacement,
    fieldLanguage,
    fieldStartDate,
    fieldEndDate,
    fieldSchedule,
    fieldImage,
    fieldImageUrl,
    fieldCreated,
    fieldActive,
    linkNone,
    linkOffer,
    linkRouteSearch,
    linkScreen,
    linkUrl,
    linkHintNone,
    linkHintOffer,
    linkHintRouteSearch,
    linkHintScreen,
    linkHintUrl,
    placementHomeTop,
    placementOffers,
    languageAll,
    languageEn,
    languageHi,
    languageTe,
    languageKn,
    languageTa,
    languageMl,
    languageMr,
    languageBn,
    bannerScheduleAlways,
    bannerScheduleFrom,
    bannerScheduleUntil,
    bannerMonths,
    actionDelete,
    actionUploadImage,
    actionPreview,
    bannerDeleteTitle,
    bannerDeleteMessage,
    bannerDeleted,
    bannerUploadTitle,
    bannerUploadIntro,
    bannerUploadChoose,
    bannerUploadWrongType,
    bannerUploadTooLarge,
    bannerPreviewTitle,
    bannerPreviewCaption,
    bannerNoImage,
    formClearDate,
    'kycQuestions',
    'kycRules',
    'kycActiveRules',
    'kycCompany',
    'kycBus',
    'kycIntro',
    'kycAddQuestion',
    'kycAddRule',
    'kycEditQuestion',
    'kycEditRule',
    'kycPreview',
    'kycExport',
    'kycImport',
    'kycRefresh',
    'kycReadOnly',
    'kycDocumentHelp',
    'kycManageDocuments',
    'kycSearch',
    'kycSubject',
    'kycAllSubjects',
    'kycStatus',
    'kycAllStatuses',
    'kycActive',
    'kycInactive',
    'kycRequirement',
    'kycAllRequirements',
    'kycRequired',
    'kycOptional',
    'kycDocument',
    'kycAllDocuments',
    'kycClearFilters',
    'kycResults',
    'kycEmpty',
    'kycNoMatches',
    'kycPrevious',
    'kycNext',
    'kycEdit',
    'kycDelete',
    'kycDeleteTitle',
    'kycDeleteHelp',
    'kycAlways',
    'kycOr',
    'kycAnd',
    'kycDocumentInactive',
    'kycKey',
    'kycKeyHelp',
    'kycKeyInvalid',
    'kycQuestionText',
    'kycFieldRequired',
    'kycHelpText',
    'kycAnswerType',
    'kycSingleChoice',
    'kycMultiChoice',
    'kycYesNo',
    'kycAnswerOptions',
    'kycOptionsHelp',
    'kycOptionsInvalid',
    'kycSortOrder',
    'kycOrderInvalid',
    'kycAnswerRequired',
    'kycCancel',
    'kycSave',
    'kycRuleName',
    'kycRuleInvalid',
    'kycNoDocuments',
    'kycDocumentRequired',
    'kycRequiredWins',
    'kycConditionsHelp',
    'kycMatch',
    'kycMatchAll',
    'kycMatchAny',
    'kycAddCondition',
    'kycRemoveCondition',
    'kycQuestion',
    'kycImportHelp',
    'kycChooseFile',
    'kycSample',
    'kycJson',
    'kycFileInvalid',
    'kycValidImport',
    'kycReplaceConfirm',
    'kycValidate',
    'kycNoQuestions',
    'kycApplicableDocuments',
    'kycMissingAnswers',
    'kycNoApplicableDocuments',
    'kycClose',
    'kycShowChecklist',
    bannerImagesTitle,
    bannerImageMobile,
    bannerImageMobileHint,
    bannerImageDesktop,
    bannerImageDesktopHint,
    bannerImageSafeArea,
    bannerImageReplace,
    bannerImageRemove,
    bannerImageWillRemove,
    bannerImagePending,
    bannerImageRatioWarning,
    bannerImageUploadFailed,
    bannerImagesPartlySaved,
    bannerPreviewPhone,
    bannerPreviewTablet,
    bannerPreviewDesktop,
    bannerDesktopChip,
    bannerButtonHelp,
    fieldDesktopImageUrl,
    exportImageUrl,
    exportDesktopImageUrl,
    linkOfferSoon,
    linkScreenSoon,
    deleteTitle,
    deleteMessage,
    deleteDone,
    deleteUndo,
    deleteRestored,
    bnSubtitle,
    bnTabAll,
    bnNew,
    bnNewTitle,
    bnEditTitle,
    bnColBanner,
    bnColStatus,
    bnColRuns,
    bnColShownTo,
    bnColOpens,
    bnColOrder,
    bnRunsAlways,
    bnRunsFrom,
    bnRunsUntil,
    bnRunsRange,
    bnStatusDraft,
    bnStatusScheduled,
    bnStatusPublished,
    bnStatusExpired,
    bnStatusArchived,
    bnAudAll,
    bnAudNew,
    bnAudSigned,
    bnOpenOffer,
    bnOpenOfferNone,
    bnOpenRoute,
    bnOpenOperator,
    bnOpenUrl,
    bnOpenNone,
    bnOpenScreen,
    bnFieldColour,
    bnColourNavyBlue,
    bnColourBlueSky,
    bnColourGreenNavy,
    bnFieldOpens,
    bnOptOffer,
    bnOptRoute,
    bnOptOperator,
    bnOptLink,
    bnFieldOfferCode,
    bnFieldRouteFrom,
    bnFieldRouteTo,
    bnFieldOperator,
    bnFieldLink,
    bnFieldShownTo,
    bnFieldStarts,
    bnFieldEnds,
    bnFieldOrder,
    bnSaveDraft,
    bnPublish,
    bnUnpublish,
    bnDuplicate,
    bnArchive,
    bnUnarchive,
    bnMoveUp,
    bnMoveDown,
    bnEndBeforeStart,
    bnToastPublished,
    bnToastScheduled,
    bnToastDraft,
    bnToastUnpublished,
    bnToastArchived,
    bnToastUnarchived,
    bnToastDuplicated,
    bnPictures,
    bnPictureDesktop,
    bnPicturePhone,
    bnPictureHint,
    bnPreviewHome,
    bnPreviewCaption,
    bnPreviewOfferButton,
    invEditTitle,
    invEditHint,
    invFieldExpires,
    invSearch,
    invSaved,
    listExportCsv,
    listExportExcel,
    impsWhatCities,
    impsWhatPlaces,
    impsTitle,
    impsIntro,
    impsTemplateCsv,
    impsTemplateExcel,
    impsChoose,
    impsChecking,
    impsReady,
    impsProblems,
    impsRowLine,
    impsIgnored,
    impsImport,
    impsSaving,
    impsDone,
    impsNothingReady,
    impsClose,
    listExportReady,
    amenitiesTitle,
    amenityAdd,
    amenityAddTitle,
    amenityName,
    amenityAddConfirm,
    amenityToggle,
    amenityOn,
    amenityOff,
    amenitiesEmpty,
    amenitiesHint,
    navPlaces,
    hintPlaces,
    placesTabPlaces,
    placesTabCities,
    placesTabRequests,
    placesAdd,
    placesEdit,
    placesFieldName,
    placesFieldInstructions,
    placesColPlace,
    placesColUsedFor,
    placesColAddedBy,
    placesColTrips,
    placesUsedBoarding,
    placesUsedDropping,
    placesUsedBoth,
    placesBadgeBoarding,
    placesBadgeDropping,
    placesBadgeBoth,
    placesSourceAdmin,
    placesSourceImport,
    placesSourceRequest,
    placesSourceOperator,
    preqColPlace,
    preqColRequested,
    preqPending,
    preqApproved,
    preqRejected,
    preqApprove,
    preqApprovedDone,
    preqReject,
    preqRejectTitle,
    preqReason,
    agoNow,
    agoMinutes,
    agoHours,
    agoDays,
    opdBack,
    opdTabOverview,
    opdTabBuses,
    opdTabPayout,
    opdTabBookings,
    opdTabActivity,
    opdSuspend,
    opdReactivate,
    opdMessage,
    opdCompany,
    opdNumbers,
    opdOwner,
    opdEmail,
    opdPhone,
    opdJoined,
    opdCompanyName,
    opdBuses,
    opdTrips,
    opdBookings,
    opdSales,
    opdKycNone,
    opdKyc,
    opdSuspendTitle,
    opdSuspendBody,
    opdSuspendReason,
    opdSuspendProof,
    opdSuspended,
    opdReactivated,
    opdReactivateTitle,
    opdReactivateBody,
    opdMessageTitle,
    opdMessageField,
    opdMessageSend,
    opdMessageSent,
    opdSuspensionTitle,
    opdSuspensionReason,
    opdSuspensionProof,
    opdSuspensionSince,
    opdSuspensionEnded,
    opdBusesEmpty,
    opdBusReg,
    opdBusName,
    opdBusSeats,
    opdBusStatus,
    opdCommissionTitle,
    opdCommissionEmpty,
    opdPayoutTitle,
    opdPayoutEmpty,
    opdBookingsEmpty,
    opdActivityEmpty,
    opdActivityBy,
    opdLoadFailed,
    opNameColumn,
    opKycColumn,
    opJoinedColumn,
    opSearch,
    opInvite,
    opdPayoutMode,
    opdPayoutAuto,
    opdPayoutManual,
    opdBankHolder,
    opdBankAccount,
    opdBankIfsc,
    opdBankStatus,
    opdBankCheck,
    opdBankNone,
    opdBankPending,
    opdBankVerifiedLabel,
    opdBankFailedLabel,
    opdChangeMode,
    opdModeTitle,
    opdModeField,
    opdModeAutoOption,
    opdModeManualOption,
    opdModeHint,
    opdModeSaved,
    opdModeSave,
    opdVerifyBank,
    opdVerifyTitle,
    opdVerifyOutcome,
    opdVerifyPassed,
    opdVerifyFailedOption,
    opdVerifyNote,
    opdVerifyHint,
    opdVerifySave,
    opdBankMarkedVerified,
    opdBankMarkedFailed,
  };
}
