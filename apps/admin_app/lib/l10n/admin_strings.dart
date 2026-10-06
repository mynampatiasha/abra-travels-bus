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
  };
}
