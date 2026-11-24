import 'app_strings.dart';

/// Tamil. A draft for client review; the terms match the web app (src/i18n/ta.json).
class TaStrings extends AppStrings {
  const TaStrings();

  // Common
  @override
  String get cancel => 'ரத்து செய்';
  @override
  String get back => 'பின்செல்';
  @override
  String get save => 'சேமி';
  @override
  String get done => 'முடிந்தது';
  @override
  String get remove => 'அகற்று';
  @override
  String get continueLabel => 'தொடர்';
  @override
  String get select => 'தேர்ந்தெடு';
  @override
  String get somethingWentWrong => 'ஏதோ தவறு ஏற்பட்டது. மீண்டும் முயற்சிக்கவும்.';
  @override
  String get language => 'மொழி';
  @override
  String get searchEmpOrName => 'தொழிலாளர் எண் அல்லது பெயர் தேடு';
  @override
  String get searchByEmpOrName => 'தொழிலாளர் எண் அல்லது பெயரால் தேடு';
  @override
  String xOfY(int x, int y) => '$x / $y';

  // Tabs and Mobile Home
  @override
  String get tabHome => 'முகப்பு';
  @override
  String get tabAttendance => 'வருகை';
  @override
  String get tabWeighing => 'எடையிடல்';
  @override
  String get tabMore => 'மேலும்';
  @override
  String hello(String name) => 'வணக்கம், $name';
  @override
  String get attendanceHint => 'இன்று வந்த தொழிலாளர்களைக் குறிக்கவும்';
  @override
  String get weighingHint => 'கொழுந்து பறிப்பவர்களின் தேயிலையை எடையிடவும்';

  // Status line and sending
  @override
  String offlineWaiting(int n) => 'இணைப்பில்லை · அனுப்ப $n உள்ளன';
  @override
  String get offlineSaved => 'இணைப்பில்லை · பதிவுகள் இந்தத் தொலைபேசியில் சேமிக்கப்படும்';
  @override
  String offlineSessionWaiting(int n) => 'இணைப்பின்றி உள்நுழைவு · $n உள்ளன';
  @override
  String waitingToSend(int n) => 'அனுப்ப $n உள்ளன';
  @override
  String get siteDataNotDownloaded => 'தோட்டத் தரவு இன்னும் பதிவிறக்கப்படவில்லை';
  @override
  String get allSent => 'அனைத்தும் அனுப்பப்பட்டன';
  @override
  String get online => 'இணைப்பில்';
  @override
  String get sendNow => 'இப்போது அனுப்பு';
  @override
  String sendNowWaiting(int n) => 'இப்போது அனுப்பு · அனுப்ப $n உள்ளன';
  @override
  String get sendNoConnection => 'அனுப்புதல் தோல்வி · இணைப்பு இல்லை';
  @override
  String sendFailed(String reason) => 'அனுப்புதல் தோல்வி · $reason';
  @override
  String get sendAllSent => 'அனைத்தும் அனுப்பப்பட்டன · தோட்டத் தரவு புதுப்பிக்கப்பட்டது';
  @override
  String get sendOfflineSession => 'இணைப்பின்றி உள்நுழைவு · அனுப்ப இணைப்புடன் உள்நுழையவும்';
  @override
  String get updatingSiteData => 'தோட்டத் தரவு புதுப்பிக்கப்படுகிறது…';
  @override
  String sendingProgress(String what, int done, int total) => '$what அனுப்பப்படுகிறது $done / $total…';
  @override
  String get whatAttendance => 'வருகை';
  @override
  String get whatWeighings => 'எடையிடல்கள்';
  @override
  String get whatFaces => 'முகங்கள்';
  @override
  String sentCount(int n) => '$n அனுப்பப்பட்டன';
  @override
  String rejectedCount(int n) => '$n நிராகரிக்கப்பட்டன';
  @override
  String get setupOfflineSession =>
      'நீங்கள் இணையம் இல்லாமல் உள்நுழைந்தீர்கள். அனுப்ப வெளியேறி மீண்டும் இணைப்புடன் உள்நுழையவும்.';

  // Sync Status
  @override
  String get statusWaiting => 'அனுப்பக் காத்திருக்கிறது';
  @override
  String get statusSent => 'அனுப்பப்பட்டது';
  @override
  String get statusRejected => 'நிராகரிக்கப்பட்டது';

  // Login
  @override
  String get fieldSupervisorLogin => 'கள மேற்பார்வையாளர் உள்நுழைவு';
  @override
  String environmentBadge(String environment) => '$environment – சோதனை அமைப்பு';
  @override
  String noConnectionLogin(int days) =>
      'இணைப்பு இல்லை. கடந்த $days நாட்களில் இந்தத் தொலைபேசியில் உள்நுழைந்திருந்தால் இப்போதும் உள்நுழையலாம்.';
  @override
  String get username => 'பயனர்பெயர்';
  @override
  String get yourUsername => 'உங்கள் பயனர்பெயர்';
  @override
  String get password => 'கடவுச்சொல்';
  @override
  String get yourPassword => 'உங்கள் கடவுச்சொல்';
  @override
  String get loggingIn => 'உள்நுழைகிறது…';
  @override
  String get login => 'உள்நுழை';
  @override
  String get loginWithFingerprint => 'கைரேகையால் உள்நுழை';
  @override
  String get forgotChangePassword => 'கடவுச்சொல் மறந்ததா / மாற்று';
  @override
  String get enterUsername => 'உங்கள் பயனர்பெயரை உள்ளிடவும்.';
  @override
  String get enterPassword => 'உங்கள் கடவுச்சொல்லை உள்ளிடவும்.';
  @override
  String get loginIncorrect => 'பயனர்பெயர் அல்லது கடவுச்சொல் தவறானது.';
  @override
  String get noAccess => 'இந்தப் பயன்பாட்டை அணுக உங்களுக்கு அனுமதி இல்லை. நிர்வாகியைத் தொடர்பு கொள்ளவும்.';
  @override
  String get sessionExpired => 'உங்கள் அமர்வு முடிந்துவிட்டது. மீண்டும் உள்நுழையவும்.';
  @override
  String get connectToLogIn => 'உள்நுழைய இணையத்துடன் இணைக்கவும்.';
  @override
  String get contactAdminForPassword => 'கடவுச்சொல்லை மாற்ற நிர்வாகியைத் தொடர்பு கொள்ளவும்.';
  @override
  String get fingerprintFailed => 'கைரேகை உள்நுழைவு தோல்வியடைந்தது. கடவுச்சொல்லால் உள்நுழையவும்.';
  @override
  String get fingerprintChanged =>
      'இந்தத் தொலைபேசியின் கைரேகைகள் மாறியுள்ளன. கடவுச்சொல்லால் உள்நுழைந்து, கைரேகை உள்நுழைவை மீண்டும் இயக்கவும்.';
  @override
  String get fingerprintLockedOut => 'கைரேகை முயற்சிகள் அதிகம். கடவுச்சொல்லால் உள்நுழையவும்.';
  @override
  String get fingerprintUnavailable => 'முதலில் தொலைபேசி அமைப்புகளில் கைரேகையை அமைக்கவும்.';
  @override
  String get fingerprintNeedsInternet => 'கைரேகை உள்நுழைவை இயக்க இணையத்துடன் இணைக்கவும்.';

  // Server errors
  @override
  String get cannotReachServer => 'சேவையகத்தை அடைய முடியவில்லை.';
  @override
  String get noPermissionGeneric => 'இதைச் செய்ய உங்களுக்கு அனுமதி இல்லை.';
  @override
  String get tooManyRequests => 'கோரிக்கைகள் அதிகம். சிறிது நேரம் கழித்து மீண்டும் முயற்சிக்கவும்.';

  // Fingerprint login
  @override
  String get fingerprintOfferTitle => 'கைரேகையால் உள்நுழையவா?';
  @override
  String get fingerprintOfferBody =>
      'அடுத்த முறை கடவுச்சொல்லைத் தட்டச்சு செய்வதற்குப் பதிலாக கைரேகையால் உள்நுழையலாம். இதை "மேலும்" பகுதியில் நிறுத்தலாம்.';
  @override
  String get notNow => 'இப்போது வேண்டாம்';
  @override
  String get turnOn => 'இயக்கு';
  @override
  String get fingerprintTurnedOff => 'கைரேகை உள்நுழைவு நிறுத்தப்பட்டது';
  @override
  String get turnOnFingerprintLogin => 'கைரேகை உள்நுழைவை இயக்கு';
  @override
  String get confirmWithPassword => 'இது நீங்கள்தான் என உறுதிப்படுத்த கடவுச்சொல்லை உள்ளிடவும்.';
  @override
  String get fingerprintIsOn => 'கைரேகை உள்நுழைவு இயக்கத்தில் உள்ளது';
  @override
  String get fingerprintNextTime => 'அடுத்த முறை கைரேகையால் உள்நுழையவும்.';
  @override
  String get fingerprintNotTurnedOn => 'கைரேகை உள்நுழைவு இயக்கப்படவில்லை';
  @override
  String get loginToAgrum => 'Agrum இல் உள்நுழை';
  @override
  String get usePassword => 'கடவுச்சொல்லைப் பயன்படுத்து';

  // More
  @override
  String get loggedInOfflineNotice =>
      'இணையம் இல்லாமல் உள்நுழைந்துள்ளீர்கள். பதிவுகளை அனுப்ப வெளியேறி மீண்டும் இணைப்புடன் உள்நுழையவும்.';
  @override
  String get sending => 'அனுப்புதல்';
  @override
  String recordsWaiting(int n) => 'அனுப்ப $n பதிவுகள் உள்ளன';
  @override
  String get nothingWaiting => 'அனுப்ப எதுவும் இல்லை';
  @override
  String get siteData => 'தோட்டத் தரவு';
  @override
  String get updating => 'புதுப்பிக்கப்படுகிறது…';
  @override
  String downloadedAt(String dateTime) => 'பதிவிறக்கியது $dateTime';
  @override
  String get notDownloadedYet => 'இன்னும் பதிவிறக்கப்படவில்லை. இணையத்துடன் இணைத்து "இப்போது அனுப்பு" அழுத்தவும்.';
  @override
  String lastUpdateFailed(String error) => 'கடைசிப் புதுப்பிப்பு தோல்வி: $error';
  @override
  String get faceRegistration => 'முகப் பதிவு';
  @override
  String get noFacesOnPhone => 'இந்தத் தொலைபேசியில் முகங்கள் பதிவு செய்யப்படவில்லை';
  @override
  String facesOnPhone(int n) => 'இந்தத் தொலைபேசியில் $n முகங்கள் பதிவு செய்யப்பட்டுள்ளன';
  @override
  String get registerFace => 'முகத்தைப் பதிவு செய்';
  @override
  String get loginSection => 'உள்நுழைவு';
  @override
  String get logout => 'வெளியேறு';
  @override
  String get logoutTitle => 'வெளியேறவா?';
  @override
  String get logoutBody => 'இந்தத் தொலைபேசியில் சேமித்த பதிவுகள் வைக்கப்பட்டு, மீண்டும் உள்நுழைந்த பின் அனுப்பப்படும்.';

  // Attendance
  @override
  String todayDate(String date) => 'இன்று, $date';
  @override
  String workersCount(int n) => '$n தொழிலாளர்கள்';
  @override
  String get noAttendanceToday => 'இன்று இந்தத் தொலைபேசியில் வருகை பதிவு செய்யப்படவில்லை.';
  @override
  String get earlierNotSent => 'முந்தைய நாட்கள், அனுப்பப்படாதவை';
  @override
  String get addAttendance => 'வருகையைச் சேர்';
  @override
  String get workingSite => 'வேலை செய்யும் தோட்டம்';
  @override
  String get selectSite => 'தோட்டத்தைத் தேர்க';
  @override
  String get workType => 'வேலை வகை';
  @override
  String get selectWorkType => 'வேலை வகையைத் தேர்க';
  @override
  String get division => 'பிரிவு';
  @override
  String get field => 'களம்';
  @override
  String get workersPresent => 'வந்த தொழிலாளர்கள்';
  @override
  String get tickWorkersPresent => 'வந்த தொழிலாளர்களைக் குறிக்கவும்';
  @override
  String selectedCount(int n) => '$n தேர்ந்தெடுக்கப்பட்டனர்';
  @override
  String get noMoreWorkers => 'இன்று குறிக்க வேறு தொழிலாளர்கள் இல்லை.';
  @override
  String noWorkersMatch(String search) => '"$search" உடன் பொருந்தும் தொழிலாளர்கள் இல்லை.';
  @override
  String get submit => 'சமர்ப்பி';
  @override
  String submitCount(int n) => 'சமர்ப்பி ($n)';
  @override
  String get submitAttendanceTitle => 'வருகையைச் சமர்ப்பி';
  @override
  String defaultSite(String site) => 'இயல்புத் தோட்டம் $site';
  @override
  String get changeCategory => 'வகையை மாற்று';
  @override
  String get category => 'வகை';
  @override
  String get categoryRegular => 'வழக்கமான';
  @override
  String get categorySeasonal => 'பருவகால';
  @override
  String get categoryLent => 'இரவல் கொடுத்த';
  @override
  String get categoryBorrowed => 'இரவல் பெற்ற';
  @override
  String get atNoWorkers => 'குறைந்தது ஒரு தொழிலாளரைத் தேர்ந்தெடுக்கவும்.';
  @override
  String atAlreadyRecorded(String worker) => '$worker க்கு இன்றைய வருகை ஏற்கனவே பதிவு செய்யப்பட்டுள்ளது.';
  @override
  String get atSiteNotAllowed => 'செயலற்ற அல்லது ஒதுக்கப்படாத தோட்டத்துக்கு வருகையைப் பதிவு செய்ய முடியாது.';
  @override
  String atOtherSite(String worker) => '$worker ஐ வேறு தோட்டத்தில் பதிவு செய்ய உங்களுக்கு அனுமதி இல்லை.';
  @override
  String get atWorkType => 'வேலை வகையைத் தேர்ந்தெடுக்கவும்.';
  @override
  String get atCategory => 'வருகை வகையைத் தேர்ந்தெடுக்கவும்.';
  @override
  String get atField => 'களத்தைத் தேர்ந்தெடுக்கவும்.';
  @override
  String get atSiteSetup => 'தோட்ட அமைப்பு முழுமையாக இல்லை. நிர்வாகியைத் தொடர்பு கொள்ளவும்.';
  @override
  String get atTodayOnly => 'இன்றைக்கு மட்டுமே வருகையைப் பதிவு செய்ய முடியும். தொலைபேசியின் தேதியைச் சரிபார்க்கவும்.';
  @override
  String get atDivision => 'பிரிவைத் தேர்ந்தெடுக்கவும்.';
  @override
  String get atNoPermission => 'வருகையைப் பதிவு செய்ய உங்களுக்கு அனுமதி இல்லை.';
  @override
  String get noSiteData =>
      'தோட்டத் தரவு இன்னும் இந்தத் தொலைபேசியில் இல்லை. இணையத்துடன் இணைத்து "இப்போது அனுப்பு" அழுத்தவும்.';
  @override
  String attendanceConfirm(int n) =>
      'சமர்ப்பித்த பின் வருகையை மாற்ற முடியாது. $n தொழிலாளர்களின் வருகையைச் சமர்ப்பிக்கவா?';
  @override
  String attendanceRecorded(int n) => '$n தொழிலாளர்களின் வருகை பதிவு செய்யப்பட்டது.';

  // Weighing
  @override
  String get noFacesRegisteredHint =>
      'இந்தத் தொலைபேசியில் முகங்கள் பதிவு செய்யப்படவில்லை. "மேலும்" → "முகப் பதிவு" இல் பதிவு செய்யவும்.';
  @override
  String get identifyByFace => 'முகத்தால் அடையாளம் காண்';
  @override
  String get captureWeight => 'எடையைப் பெறு';
  @override
  String get manualEntry => 'கைமுறை உள்ளீடு';
  @override
  String get scaleNotConnected => 'தராசு இணைக்கப்படவில்லை';
  @override
  String get scaleNotAvailable => 'தராசு இணைப்பு இன்னும் கிடைக்கவில்லை.';
  @override
  String get connectScale => 'தராசை இணை';
  @override
  String get worker => 'தொழிலாளர்';
  @override
  String get noWorkersToWeigh =>
      'இன்று எடையிட தொழிலாளர்கள் இல்லை. முதலில் எடையிடும் வேலை வகையுடன் வருகையைப் பதிவு செய்யவும்.';
  @override
  String get entriesToday => 'இன்றைய பதிவுகள்';
  @override
  String get changeWorker => 'தொழிலாளரை மாற்று';
  @override
  String get weight => 'எடை';
  @override
  String get weightManual => 'எடை · கைமுறை';
  @override
  String weighingsTodayCount(int n) => 'இன்று $n எடையிடல்கள்';
  @override
  String weighingsTodayDate(String date) => 'இன்றைய எடையிடல்கள், $date';
  @override
  String get noWeighingsToday => 'இன்று இந்தத் தொலைபேசியில் எடையிடல்கள் பதிவு செய்யப்படவில்லை.';
  @override
  String weighingNumber(int sequence) => 'எடையிடல் $sequence';
  @override
  String get entryAutomatic => 'தானியங்கி';
  @override
  String get entryManual => 'கைமுறை';
  @override
  String get weSelectWorker => 'தொழிலாளரைத் தேர்ந்தெடுக்கவும்.';
  @override
  String weLimitReached(int n) => 'இந்தத் தொழிலாளருக்கு ஒரு நாளுக்கான அதிகபட்ச $n எடையிடல்கள் ஏற்கனவே பதிவாகியுள்ளன.';
  @override
  String get weWeight => '0 ஐ விட அதிகமான எடையை உள்ளிடவும்.';
  @override
  String get weNoScaleReading => 'தராசிலிருந்து சரியான அளவீடு இல்லை. தராசு இணைப்பைச் சரிபார்க்கவும்.';
  @override
  String get weNoManual => 'எடையைக் கைமுறையாக உள்ளிட உங்களுக்கு அனுமதி இல்லை.';
  @override
  String get weNoPermission => 'எடையைப் பதிவு செய்ய உங்களுக்கு அனுமதி இல்லை.';
  @override
  String get weTodayOnly => 'இன்றைக்கு மட்டுமே எடையைப் பதிவு செய்ய முடியும். தொலைபேசியின் தேதியைச் சரிபார்க்கவும்.';
  @override
  String get weEntryType => 'தராசிலிருந்து எடையைப் பெறவும் அல்லது கைமுறையாக உள்ளிடவும்.';
  @override
  String weSaved(String employeeCode, int sequence, String kg) =>
      'சேமிக்கப்பட்டது – $employeeCode, எடையிடல் $sequence, $kg kg';

  // Faces
  @override
  String get removeFace => 'முகத்தை அகற்று';
  @override
  String removeFaceBody(String name) =>
      '$name இன் பதிவு செய்த முகத்தை அகற்றவா? முகம் மீண்டும் பதிவு செய்யப்படும் வரை தராசில் அவர் தேடல் மூலம் தேர்ந்தெடுக்கப்படுவார்.';
  @override
  String faceRemoved(String name) => '$name இன் முகம் அகற்றப்பட்டது.';
  @override
  String get removeNeedsConnection => 'முகத்தை அகற்ற இணைப்பு தேவை. இணைப்பில் இருக்கும்போது மீண்டும் முயற்சிக்கவும்.';
  @override
  String get faceRegistrationIntro =>
      'தொழிலாளரைத் தேர்ந்தெடுத்து, அவரது முகத்தை நீள்வட்டத்துக்குள் வைத்து படிகளைப் பின்பற்றவும். '
      'மீண்டும் பதிவு செய்தால் பழைய முகம் மாற்றப்படும். முகங்கள் மற்ற பதிவுகளைப் போல சேவையகத்துக்கு அனுப்பப்படும்.';
  @override
  String noEmployeesMatch(String search) => '"$search" உடன் பொருந்தும் தொழிலாளர்கள் இல்லை.';
  @override
  String get noEmployeesYet => 'தோட்டத் தரவில் இன்னும் தொழிலாளர்கள் இல்லை.';
  @override
  String get cameraPermissionRegister =>
      'முகங்களைப் பதிவு செய்ய கேமரா அனுமதி தேவை. தொலைபேசி அமைப்புகளில் அனுமதிக்கவும்.';
  @override
  String get cameraPermissionIdentify =>
      'தொழிலாளர்களை அடையாளம் காண கேமரா அனுமதி தேவை. தொலைபேசி அமைப்புகளில் அனுமதிக்கவும்.';
  @override
  String cameraCouldNotStart(String detail) => 'கேமராவைத் தொடங்க முடியவில்லை: $detail';
  @override
  String get noFaceFound => 'முகம் கண்டறியப்படவில்லை';
  @override
  String get holdStill => 'அசையாமல் இருங்கள்...';
  @override
  String capturing(String instruction) => '"$instruction" பெறப்படுகிறது...';
  @override
  String faceAlreadyRegistered(String name) =>
      'இந்த முகம் ஏற்கனவே $name க்குப் பதிவு செய்யப்பட்டுள்ளது. ஒரு முகம் ஒரு தொழிலாளருக்கு மட்டுமே உரியது. '
      'அந்தப் பதிவு தவறு என்றால், முதலில் அதை அகற்றவும்.';
  @override
  String faceNotSaved(String name) => '$name இன் முகம் சேமிக்கப்படவில்லை.';
  @override
  String get backToList => 'பட்டியலுக்குத் திரும்பு';
  @override
  String faceRegistered(String name) => '$name இன் முகம் பதிவு செய்யப்பட்டது.';
  @override
  String get registerAnother => 'இன்னொன்றைப் பதிவு செய்';
  @override
  String get putFaceInOval => 'முகத்தை நீள்வட்டத்துக்குள் வைக்கவும்';
  @override
  String get poseFront => 'நேராகப் பாருங்கள்';
  @override
  String get poseLeft => 'சற்று இடப்புறம் திரும்புங்கள்';
  @override
  String get poseRight => 'சற்று வலப்புறம் திரும்புங்கள்';
  @override
  String get poseRelaxed => 'நேராகப் பாருங்கள், முகத்தைத் தளர்வாக வையுங்கள்';
  @override
  String get poseAltLighting => 'மீண்டும் நேராகப் பாருங்கள் (முடிந்தால் வேறு வெளிச்சத்தில்)';
  @override
  String get noFramesMessage => 'கேமரா முகச் சோதனைக்குப் படங்களை அனுப்பவில்லை. இந்தத் திரையை மூடி மீண்டும் திறக்கவும்.';
  @override
  String faceCheckFailed(String error) => 'முகச் சோதனை தோல்வி: $error';
  @override
  String faceTryAgain(String reason) => '$reason. மீண்டும் முயற்சிக்கவும், அல்லது தொழிலாளர் எண்ணால் தேடவும்.';
  @override
  String get startingCamera => 'கேமரா தொடங்குகிறது…';
  @override
  String get pointCameraAtFace => 'கேமராவைத் தொழிலாளரின் முகத்தை நோக்கி வைக்கவும்';
  @override
  String get identifying => 'அடையாளம் காணப்படுகிறது…';
  @override
  String get faceNotRecognised => 'முகம் அடையாளம் காணப்படவில்லை';
  @override
  String get notSureWho => 'இது யார் என்று உறுதியாகத் தெரியவில்லை';
  @override
  String get faceModelNotLoaded => 'முக மாதிரி ஏற்றப்படவில்லை';
  @override
  String get switchCamera => 'கேமராவை மாற்று';
  @override
  String get noFaceInPhoto => 'புகைப்படத்தில் முகம் கண்டறியப்படவில்லை. மீண்டும் முயற்சிக்கவும்.';
  @override
  String get couldNotReadPhoto => 'புகைப்படத்தைப் படிக்க முடியவில்லை. மீண்டும் முயற்சிக்கவும்.';
  @override
  String get couldNotCropFace => 'முகத்தை வெட்டி எடுக்க முடியவில்லை. மீண்டும் முயற்சிக்கவும்.';
  @override
  String get noPermissionRemoveFaces => 'முகங்களை அகற்ற உங்களுக்கு அனுமதி இல்லை.';
  @override
  String get noPermissionRegisterFaces => 'முகங்களைப் பதிவு செய்ய உங்களுக்கு அனுமதி இல்லை.';

  // Face camera guidance
  @override
  String get guideOnePerson => 'ஒரு நேரத்தில் ஒருவர் மட்டும்';
  @override
  String get guideMoveCloser => 'அருகில் வாருங்கள்';
  @override
  String get guideMoveBack => 'சற்றுப் பின்னால் செல்லுங்கள்';
  @override
  String get guideCenter => 'முகத்தைச் சட்டகத்தின் நடுவில் வையுங்கள்';
  @override
  String get guideStraighten => 'தலையை நேராக வையுங்கள்';
  @override
  String get guideAdjustAngle => 'தலையின் கோணத்தைச் சரிசெய்யுங்கள்';
  @override
  String get guideGood => 'சரி';
  @override
  String get guideTooDark => 'மிகவும் இருட்டு. நல்ல வெளிச்சத்துக்குச் செல்லுங்கள்';
  @override
  String get guideTooBright => 'மிகவும் பிரகாசம். நேரடி வெளிச்சத்திலிருந்து விலகுங்கள்';
  @override
  String get guideBlurred => 'படம் மங்கலாக உள்ளது. கேமராவை அசையாமல் பிடியுங்கள்';
}
