import 'app_strings.dart';

/// Sinhala. A draft for client review; the terms match the web app (src/i18n/si.json).
class SiStrings extends AppStrings {
  const SiStrings();

  // Common
  @override
  String get cancel => 'අවලංගු කරන්න';
  @override
  String get back => 'ආපසු';
  @override
  String get save => 'සුරකින්න';
  @override
  String get done => 'අවසන්';
  @override
  String get remove => 'ඉවත් කරන්න';
  @override
  String get continueLabel => 'ඉදිරියට';
  @override
  String get select => 'තෝරන්න';
  @override
  String get somethingWentWrong => 'යම් දෝෂයක් සිදු විය. කරුණාකර නැවත උත්සාහ කරන්න.';
  @override
  String get language => 'භාෂාව';
  @override
  String get searchEmpOrName => 'සේවක අංකය හෝ නම සොයන්න';
  @override
  String get searchByEmpOrName => 'සේවක අංකය හෝ නමෙන් සොයන්න';
  @override
  String xOfY(int x, int y) => '$x / $y';

  // Tabs and Mobile Home
  @override
  String get tabHome => 'මුල් පිටුව';
  @override
  String get tabAttendance => 'පැමිණීම';
  @override
  String get tabWeighing => 'බර කිරීම';
  @override
  String get tabMore => 'තවත්';
  @override
  String hello(String name) => 'ආයුබෝවන්, $name';
  @override
  String get attendanceHint => 'අද පැමිණි සේවකයින් සලකුණු කරන්න';
  @override
  String get weighingHint => 'දළු නෙළන්නන්ගේ තේ කිරන්න';

  // Status line and sending
  @override
  String offlineWaiting(int n) => 'නොබැඳි · යැවීමට $n ක් ඇත';
  @override
  String get offlineSaved => 'නොබැඳි · වාර්තා මෙම දුරකථනයේ සුරැකේ';
  @override
  String offlineSessionWaiting(int n) => 'නොබැඳිව පිවිසුණි · $n ක් ඇත';
  @override
  String waitingToSend(int n) => 'යැවීමට $n ක් ඇත';
  @override
  String get siteDataNotDownloaded => 'වතු දත්ත තවම බාගත කර නැත';
  @override
  String get allSent => 'සියල්ල යවා ඇත';
  @override
  String get online => 'සබැඳි';
  @override
  String get sendNow => 'දැන් යවන්න';
  @override
  String sendNowWaiting(int n) => 'දැන් යවන්න · යැවීමට $n ක් ඇත';
  @override
  String get sendNoConnection => 'යැවීම අසාර්ථකයි · සම්බන්ධතාවයක් නැත';
  @override
  String sendFailed(String reason) => 'යැවීම අසාර්ථකයි · $reason';
  @override
  String get sendAllSent => 'සියල්ල යවා ඇත · වතු දත්ත යාවත්කාලීනයි';
  @override
  String get sendOfflineSession => 'නොබැඳිව පිවිසුණි · යැවීමට සබැඳිව පිවිසෙන්න';
  @override
  String get updatingSiteData => 'වතු දත්ත යාවත්කාලීන වෙමින්…';
  @override
  String sendingProgress(String what, int done, int total) => '$what යවමින් $done / $total…';
  @override
  String get whatAttendance => 'පැමිණීම්';
  @override
  String get whatWeighings => 'බර කිරීම්';
  @override
  String get whatFaces => 'මුහුණු';
  @override
  String sentCount(int n) => '$n ක් යැවිණි';
  @override
  String rejectedCount(int n) => '$n ක් ප්‍රතික්ෂේපිතයි';
  @override
  String get setupOfflineSession =>
      'ඔබ අන්තර්ජාලය නොමැතිව පිවිසුණා. යැවීමට ඉවත් වී නැවත සබැඳිව පිවිසෙන්න.';

  // Sync Status
  @override
  String get statusWaiting => 'යැවීමට ඇත';
  @override
  String get statusSent => 'යැවිණි';
  @override
  String get statusRejected => 'ප්‍රතික්ෂේපිතයි';

  // Login
  @override
  String get fieldSupervisorLogin => 'ක්ෂේත්‍ර අධීක්ෂක පිවිසුම';
  @override
  String environmentBadge(String environment) => '$environment – පරීක්ෂණ පද්ධතිය';
  @override
  String noConnectionLogin(int days) =>
      'සම්බන්ධතාවයක් නැත. පසුගිය දින $days තුළ මෙම දුරකථනයෙන් පිවිසුණේ නම් ඔබට තවමත් පිවිසිය හැක.';
  @override
  String get username => 'පරිශීලක නාමය';
  @override
  String get yourUsername => 'ඔබේ පරිශීලක නාමය';
  @override
  String get password => 'මුරපදය';
  @override
  String get yourPassword => 'ඔබේ මුරපදය';
  @override
  String get loggingIn => 'පිවිසෙමින්…';
  @override
  String get login => 'පිවිසෙන්න';
  @override
  String get loginWithFingerprint => 'ඇඟිලි සලකුණෙන් පිවිසෙන්න';
  @override
  String get forgotChangePassword => 'මුරපදය අමතකද / වෙනස් කරන්න';
  @override
  String get enterUsername => 'කරුණාකර ඔබේ පරිශීලක නාමය ඇතුළත් කරන්න.';
  @override
  String get enterPassword => 'කරුණාකර ඔබේ මුරපදය ඇතුළත් කරන්න.';
  @override
  String get loginIncorrect => 'පරිශීලක නාමය හෝ මුරපදය වැරදියි.';
  @override
  String get noAccess => 'මෙම යෙදුමට ඔබට ප්‍රවේශය නැත. කරුණාකර පරිපාලක අමතන්න.';
  @override
  String get sessionExpired => 'ඔබේ සැසිය අවසන් වී ඇත. කරුණාකර නැවත පිවිසෙන්න.';
  @override
  String get connectToLogIn => 'පිවිසීමට කරුණාකර අන්තර්ජාලයට සම්බන්ධ වන්න.';
  @override
  String get contactAdminForPassword => 'මුරපදය වෙනස් කිරීමට පරිපාලක අමතන්න.';
  @override
  String get fingerprintFailed => 'ඇඟිලි සලකුණෙන් පිවිසීම අසාර්ථකයි. කරුණාකර මුරපදයෙන් පිවිසෙන්න.';
  @override
  String get fingerprintChanged =>
      'මෙම දුරකථනයේ ඇඟිලි සලකුණු වෙනස් වී ඇත. මුරපදයෙන් පිවිස, ඇඟිලි සලකුණු පිවිසුම නැවත සක්‍රිය කරන්න.';
  @override
  String get fingerprintLockedOut => 'ඇඟිලි සලකුණු උත්සාහයන් වැඩියි. කරුණාකර මුරපදයෙන් පිවිසෙන්න.';
  @override
  String get fingerprintUnavailable => 'පළමුව දුරකථන සැකසුම්වල ඇඟිලි සලකුණක් සකසන්න.';
  @override
  String get fingerprintNeedsInternet =>
      'ඇඟිලි සලකුණු පිවිසුම සක්‍රිය කිරීමට කරුණාකර අන්තර්ජාලයට සම්බන්ධ වන්න.';

  // Server errors
  @override
  String get cannotReachServer => 'සේවාදායකයට සම්බන්ධ විය නොහැක.';
  @override
  String get noPermissionGeneric => 'මෙය කිරීමට ඔබට අවසර නැත.';
  @override
  String get tooManyRequests => 'ඉල්ලීම් වැඩියි. මොහොතක් රැඳී නැවත උත්සාහ කරන්න.';

  // Fingerprint login
  @override
  String get fingerprintOfferTitle => 'ඇඟිලි සලකුණෙන් පිවිසෙනවාද?';
  @override
  String get fingerprintOfferBody =>
      'ඊළඟ වතාවේ මුරපදය ටයිප් කරනවා වෙනුවට ඇඟිලි සලකුණෙන් පිවිසෙන්න. මෙය "තවත්" තුළින් අක්‍රිය කළ හැක.';
  @override
  String get notNow => 'දැන් නොවේ';
  @override
  String get turnOn => 'සක්‍රිය කරන්න';
  @override
  String get fingerprintTurnedOff => 'ඇඟිලි සලකුණු පිවිසුම අක්‍රිය කළා';
  @override
  String get turnOnFingerprintLogin => 'ඇඟිලි සලකුණු පිවිසුම සක්‍රිය කරන්න';
  @override
  String get confirmWithPassword => 'මෙය ඔබ බව තහවුරු කිරීමට මුරපදය ඇතුළත් කරන්න.';
  @override
  String get fingerprintIsOn => 'ඇඟිලි සලකුණු පිවිසුම සක්‍රියයි';
  @override
  String get fingerprintNextTime => 'ඊළඟ වතාවේ ඇඟිලි සලකුණෙන් පිවිසෙන්න.';
  @override
  String get fingerprintNotTurnedOn => 'ඇඟිලි සලකුණු පිවිසුම සක්‍රිය නොවීය';
  @override
  String get loginToAgrum => 'Agrum වෙත පිවිසෙන්න';
  @override
  String get usePassword => 'මුරපදය භාවිත කරන්න';

  // More
  @override
  String get loggedInOfflineNotice =>
      'අන්තර්ජාලය නොමැතිව පිවිසුණි. වාර්තා යැවීමට ඉවත් වී නැවත සබැඳිව පිවිසෙන්න.';
  @override
  String get sending => 'යැවීම';
  @override
  String recordsWaiting(int n) => 'යැවීමට වාර්තා $n ක් ඇත';
  @override
  String get nothingWaiting => 'යැවීමට කිසිවක් නැත';
  @override
  String get siteData => 'වතු දත්ත';
  @override
  String get updating => 'යාවත්කාලීන වෙමින්…';
  @override
  String downloadedAt(String dateTime) => 'බාගත කළේ $dateTime';
  @override
  String get notDownloadedYet => 'තවම බාගත කර නැත. අන්තර්ජාලයට සම්බන්ධ වී "දැන් යවන්න" ඔබන්න.';
  @override
  String lastUpdateFailed(String error) => 'අවසන් යාවත්කාලීනය අසාර්ථකයි: $error';
  @override
  String get faceRegistration => 'මුහුණ ලියාපදිංචිය';
  @override
  String get noFacesOnPhone => 'මෙම දුරකථනයේ මුහුණු ලියාපදිංචි කර නැත';
  @override
  String facesOnPhone(int n) => 'මෙම දුරකථනයේ මුහුණු $n ක් ලියාපදිංචියි';
  @override
  String get registerFace => 'මුහුණ ලියාපදිංචි කරන්න';
  @override
  String get loginSection => 'පිවිසුම';
  @override
  String get logout => 'ඉවත් වන්න';
  @override
  String get logoutTitle => 'ඉවත් වෙනවාද?';
  @override
  String get logoutBody => 'මෙම දුරකථනයේ සුරැකි වාර්තා තබා ගෙන, ඔබ නැවත පිවිසුණු පසු යවනු ලැබේ.';

  // Attendance
  @override
  String todayDate(String date) => 'අද, $date';
  @override
  String workersCount(int n) => 'සේවකයින් $n';
  @override
  String get noAttendanceToday => 'අද මෙම දුරකථනයෙන් පැමිණීම් වාර්තා කර නැත.';
  @override
  String get earlierNotSent => 'පෙර දින, නොයැවූ';
  @override
  String get addAttendance => 'පැමිණීම එක් කරන්න';
  @override
  String get workingSite => 'වැඩ කරන වත්ත';
  @override
  String get selectSite => 'වත්තක් තෝරන්න';
  @override
  String get workType => 'වැඩ වර්ගය';
  @override
  String get selectWorkType => 'වැඩ වර්ගයක් තෝරන්න';
  @override
  String get division => 'කොට්ඨාසය';
  @override
  String get field => 'ක්ෂේත්‍රය';
  @override
  String get workersPresent => 'පැමිණි සේවකයින්';
  @override
  String get tickWorkersPresent => 'පැමිණි සේවකයින් සලකුණු කරන්න';
  @override
  String selectedCount(int n) => '$n ක් තෝරා ඇත';
  @override
  String get noMoreWorkers => 'අද සලකුණු කිරීමට තවත් සේවකයින් නැත.';
  @override
  String noWorkersMatch(String search) => '"$search" ට ගැළපෙන සේවකයින් නැත.';
  @override
  String get submit => 'ඉදිරිපත් කරන්න';
  @override
  String submitCount(int n) => 'ඉදිරිපත් කරන්න ($n)';
  @override
  String get submitAttendanceTitle => 'පැමිණීම ඉදිරිපත් කරන්න';
  @override
  String defaultSite(String site) => 'පෙරනිමි වත්ත $site';
  @override
  String get changeCategory => 'කාණ්ඩය වෙනස් කරන්න';
  @override
  String get category => 'කාණ්ඩය';
  @override
  String get categoryRegular => 'නිත්‍ය';
  @override
  String get categorySeasonal => 'සෘතුමය';
  @override
  String get categoryLent => 'ණයට දුන්';
  @override
  String get categoryBorrowed => 'ණයට ගත්';
  @override
  String get atNoWorkers => 'කරුණාකර අවම වශයෙන් එක් සේවකයෙකු තෝරන්න.';
  @override
  String atAlreadyRecorded(String worker) => '$worker සඳහා අද පැමිණීම දැනටමත් වාර්තා කර ඇත.';
  @override
  String get atSiteNotAllowed => 'අක්‍රිය හෝ පවරා නොමැති වත්තක් සඳහා පැමිණීම වාර්තා කළ නොහැක.';
  @override
  String atOtherSite(String worker) => '$worker වෙනත් වත්තක වාර්තා කිරීමට ඔබට අවසර නැත.';
  @override
  String get atWorkType => 'කරුණාකර වැඩ වර්ගයක් තෝරන්න.';
  @override
  String get atCategory => 'කරුණාකර පැමිණීමේ කාණ්ඩය තෝරන්න.';
  @override
  String get atField => 'කරුණාකර ක්ෂේත්‍රය තෝරන්න.';
  @override
  String get atSiteSetup => 'වත්තේ සැකසුම් අසම්පූර්ණයි. කරුණාකර පරිපාලක අමතන්න.';
  @override
  String get atTodayOnly => 'පැමිණීම වාර්තා කළ හැක්කේ අදට පමණි. කරුණාකර දුරකථනයේ දිනය පරීක්ෂා කරන්න.';
  @override
  String get atDivision => 'කරුණාකර කොට්ඨාසය තෝරන්න.';
  @override
  String get atNoPermission => 'පැමිණීම වාර්තා කිරීමට ඔබට අවසර නැත.';
  @override
  String get noSiteData => 'වතු දත්ත තවම මෙම දුරකථනයේ නැත. අන්තර්ජාලයට සම්බන්ධ වී "දැන් යවන්න" ඔබන්න.';
  @override
  String attendanceConfirm(int n) =>
      'ඉදිරිපත් කළ පසු පැමිණීම වෙනස් කළ නොහැක. සේවකයින් $n දෙනෙකුගේ පැමිණීම ඉදිරිපත් කරනවාද?';
  @override
  String attendanceRecorded(int n) => 'සේවකයින් $n දෙනෙකුගේ පැමිණීම වාර්තා කළා.';

  // Weighing
  @override
  String get noFacesRegisteredHint =>
      'මෙම දුරකථනයේ මුහුණු ලියාපදිංචි කර නැත. "තවත්" → "මුහුණ ලියාපදිංචිය" තුළ ලියාපදිංචි කරන්න.';
  @override
  String get identifyByFace => 'මුහුණෙන් හඳුනාගන්න';
  @override
  String get captureWeight => 'බර ලබාගන්න';
  @override
  String get manualEntry => 'අතින් ඇතුළත් කිරීම';
  @override
  String get scaleNotConnected => 'තරාදිය සම්බන්ධ කර නැත';
  @override
  String get scaleNotAvailable => 'තරාදි සම්බන්ධතාවය තවම ලබා ගත නොහැක.';
  @override
  String get connectScale => 'තරාදිය සම්බන්ධ කරන්න';
  @override
  String get worker => 'සේවකයා';
  @override
  String get noWorkersToWeigh =>
      'අද බර කිරීමට සේවකයින් නැත. පළමුව බර කිරීමේ වැඩ වර්ගයක් සමඟ පැමිණීම වාර්තා කරන්න.';
  @override
  String get entriesToday => 'අද ඇතුළත් කිරීම්';
  @override
  String get changeWorker => 'සේවකයා වෙනස් කරන්න';
  @override
  String get weight => 'බර';
  @override
  String get weightManual => 'බර · අතින්';
  @override
  String weighingsTodayCount(int n) => 'අද බර කිරීම් $n';
  @override
  String weighingsTodayDate(String date) => 'අද බර කිරීම්, $date';
  @override
  String get noWeighingsToday => 'අද මෙම දුරකථනයෙන් බර කිරීම් වාර්තා කර නැත.';
  @override
  String weighingNumber(int sequence) => 'බර කිරීම $sequence';
  @override
  String get entryAutomatic => 'ස්වයංක්‍රීය';
  @override
  String get entryManual => 'අතින්';
  @override
  String get weSelectWorker => 'කරුණාකර සේවකයෙකු තෝරන්න.';
  @override
  String weLimitReached(int n) => 'මෙම සේවකයා සඳහා දිනකට උපරිම බර කිරීම් $n දැනටමත් වාර්තා කර ඇත.';
  @override
  String get weWeight => 'කරුණාකර 0 ට වැඩි බරක් ඇතුළත් කරන්න.';
  @override
  String get weNoScaleReading => 'තරාදියෙන් වලංගු කියවීමක් නැත. කරුණාකර තරාදි සම්බන්ධතාවය පරීක්ෂා කරන්න.';
  @override
  String get weNoManual => 'බර අතින් ඇතුළත් කිරීමට ඔබට අවසර නැත.';
  @override
  String get weNoPermission => 'බර වාර්තා කිරීමට ඔබට අවසර නැත.';
  @override
  String get weTodayOnly => 'බර වාර්තා කළ හැක්කේ අදට පමණි. කරුණාකර දුරකථනයේ දිනය පරීක්ෂා කරන්න.';
  @override
  String get weEntryType => 'කරුණාකර තරාදියෙන් බර ලබාගන්න හෝ අතින් ඇතුළත් කරන්න.';
  @override
  String weSaved(String employeeCode, int sequence, String kg) =>
      'සුරැකිණි – $employeeCode, බර කිරීම $sequence, $kg kg';

  // Faces
  @override
  String get removeFace => 'මුහුණ ඉවත් කරන්න';
  @override
  String removeFaceBody(String name) =>
      '$name ගේ ලියාපදිංචි මුහුණ ඉවත් කරනවාද? මුහුණ නැවත ලියාපදිංචි කරන තුරු තරාදිය අසළ ඔවුන් සෙවීමෙන් තෝරනු ලැබේ.';
  @override
  String faceRemoved(String name) => '$name ගේ මුහුණ ඉවත් කළා.';
  @override
  String get removeNeedsConnection => 'මුහුණක් ඉවත් කිරීමට සම්බන්ධතාවයක් අවශ්‍යයි. සබැඳි වූ විට නැවත උත්සාහ කරන්න.';
  @override
  String get faceRegistrationIntro =>
      'සේවකයා තෝරා, ඔවුන්ගේ මුහුණ ඕවලය තුළ තබා පියවර අනුගමනය කරන්න. '
      'නැවත ලියාපදිංචි කිරීමෙන් පැරණි මුහුණ ප්‍රතිස්ථාපනය වේ. මුහුණු අනෙකුත් වාර්තා මෙන් සේවාදායකයට යවනු ලැබේ.';
  @override
  String noEmployeesMatch(String search) => '"$search" ට ගැළපෙන සේවකයින් නැත.';
  @override
  String get noEmployeesYet => 'වතු දත්තවල තවම සේවකයින් නැත.';
  @override
  String get cameraPermissionRegister =>
      'මුහුණු ලියාපදිංචි කිරීමට කැමරා අවසරය අවශ්‍යයි. දුරකථන සැකසුම්වල එයට ඉඩ දෙන්න.';
  @override
  String get cameraPermissionIdentify =>
      'සේවකයින් හඳුනාගැනීමට කැමරා අවසරය අවශ්‍යයි. දුරකථන සැකසුම්වල එයට ඉඩ දෙන්න.';
  @override
  String cameraCouldNotStart(String detail) => 'කැමරාව ආරම්භ කළ නොහැකි විය: $detail';
  @override
  String get noFaceFound => 'මුහුණක් හමු නොවීය';
  @override
  String get holdStill => 'නොසෙල්වී සිටින්න...';
  @override
  String capturing(String instruction) => '"$instruction" ලබාගනිමින්...';
  @override
  String faceAlreadyRegistered(String name) =>
      'මෙම මුහුණ දැනටමත් $name ට ලියාපදිංචියි. මුහුණක් එක් සේවකයෙකුට පමණක් අයත් විය හැක. '
      'එම ලියාපදිංචිය වැරදි නම්, පළමුව එය ඉවත් කරන්න.';
  @override
  String faceNotSaved(String name) => '$name ගේ මුහුණ සුරැකුණේ නැත.';
  @override
  String get backToList => 'ලැයිස්තුවට ආපසු';
  @override
  String faceRegistered(String name) => '$name ගේ මුහුණ ලියාපදිංචි කළා.';
  @override
  String get registerAnother => 'තවත් එකක් ලියාපදිංචි කරන්න';
  @override
  String get putFaceInOval => 'මුහුණ ඕවලය තුළ තබන්න';
  @override
  String get poseFront => 'කෙළින්ම ඉදිරිය බලන්න';
  @override
  String get poseLeft => 'මඳක් වමට හැරෙන්න';
  @override
  String get poseRight => 'මඳක් දකුණට හැරෙන්න';
  @override
  String get poseRelaxed => 'කෙළින්ම ඉදිරිය බලන්න, මුහුණ ලිහිල් කරන්න';
  @override
  String get poseAltLighting => 'නැවත කෙළින්ම ඉදිරිය බලන්න (හැකි නම් වෙනත් ආලෝකයක)';
  @override
  String get noFramesMessage => 'කැමරාව මුහුණු පරීක්ෂාවට රූප යවන්නේ නැත. මෙම තිරය වසා නැවත විවෘත කරන්න.';
  @override
  String faceCheckFailed(String error) => 'මුහුණු පරීක්ෂාව අසාර්ථකයි: $error';
  @override
  String faceTryAgain(String reason) => '$reason. නැවත උත්සාහ කරන්න, නැතහොත් සේවක අංකයෙන් සොයන්න.';
  @override
  String get startingCamera => 'කැමරාව ආරම්භ වෙමින්…';
  @override
  String get pointCameraAtFace => 'කැමරාව සේවකයාගේ මුහුණට යොමු කරන්න';
  @override
  String get identifying => 'හඳුනාගනිමින්…';
  @override
  String get faceNotRecognised => 'මුහුණ හඳුනාගත නොහැකි විය';
  @override
  String get notSureWho => 'මෙය කවුදැයි විශ්වාස නැත';
  @override
  String get faceModelNotLoaded => 'මුහුණු ආකෘතිය පූරණය වී නැත';
  @override
  String get switchCamera => 'කැමරාව මාරු කරන්න';
  @override
  String get noFaceInPhoto => 'ඡායාරූපයේ මුහුණක් හමු නොවීය. නැවත උත්සාහ කරන්න.';
  @override
  String get couldNotReadPhoto => 'ඡායාරූපය කියවිය නොහැකි විය. නැවත උත්සාහ කරන්න.';
  @override
  String get couldNotCropFace => 'මුහුණ කපා ගත නොහැකි විය. නැවත උත්සාහ කරන්න.';
  @override
  String get noPermissionRemoveFaces => 'මුහුණු ඉවත් කිරීමට ඔබට අවසර නැත.';
  @override
  String get noPermissionRegisterFaces => 'මුහුණු ලියාපදිංචි කිරීමට ඔබට අවසර නැත.';

  // Face camera guidance
  @override
  String get guideOnePerson => 'වරකට එක් අයෙකු පමණි';
  @override
  String get guideMoveCloser => 'තව ළං වන්න';
  @override
  String get guideMoveBack => 'මඳක් පසුපසට යන්න';
  @override
  String get guideCenter => 'මුහුණ රාමුවේ මැදට ගන්න';
  @override
  String get guideStraighten => 'හිස කෙළින් තබා ගන්න';
  @override
  String get guideAdjustAngle => 'හිසේ කෝණය සකසන්න';
  @override
  String get guideGood => 'හොඳයි';
  @override
  String get guideTooDark => 'ඉතා අඳුරුයි. වඩා හොඳ ආලෝකයකට යන්න';
  @override
  String get guideTooBright => 'ඉතා දීප්තියි. සෘජු ආලෝකයෙන් ඉවත් වන්න';
  @override
  String get guideBlurred => 'රූපය බොඳයි. කැමරාව නොසෙල්වී අල්ලා ගන්න';
}
