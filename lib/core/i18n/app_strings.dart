import 'strings_en.dart';

/// Every text the app shows itself, in one language. English, Sinhala and Tamil each implement all
/// of it, so a text missing in one language is a compile error. Server messages (e.g. a Rejected
/// row's reason) and names typed by administrators are shown as they come.
abstract class AppStrings {
  const AppStrings();

  // Common
  String get cancel;
  String get back;
  String get save;
  String get done;
  String get remove;
  String get continueLabel;
  String get select;
  String get somethingWentWrong;
  String get language;
  String get searchEmpOrName;
  String get searchByEmpOrName;
  String xOfY(int x, int y);

  // Tabs and Mobile Home
  String get tabHome;
  String get tabAttendance;
  String get tabWeighing;
  String get tabMore;
  String hello(String name);
  String get attendanceHint;
  String get weighingHint;

  // Status line under the window title, and sending
  String offlineWaiting(int n);
  String get offlineSaved;
  String offlineSessionWaiting(int n);
  String waitingToSend(int n);
  String get siteDataNotDownloaded;
  String get allSent;
  String get online;
  String get sendNow;
  String sendNowWaiting(int n);
  String get sendNoConnection;
  String sendFailed(String reason);
  String get sendAllSent;
  String get sendOfflineSession;
  String get updatingSiteData;
  String sendingProgress(String what, int done, int total);
  String get whatAttendance;
  String get whatWeighings;
  String get whatFaces;
  String sentCount(int n);
  String rejectedCount(int n);
  String get setupOfflineSession;

  // Sync Status (10.5)
  String get statusWaiting;
  String get statusSent;
  String get statusRejected;

  // Login (2.1)
  String get fieldSupervisorLogin;
  String environmentBadge(String environment);
  String noConnectionLogin(int days);
  String get username;
  String get yourUsername;
  String get password;
  String get yourPassword;
  String get loggingIn;
  String get login;
  String get loginWithFingerprint;
  String get forgotChangePassword;
  String get enterUsername; // LG-01
  String get enterPassword; // LG-02
  String get loginIncorrect; // LG-03
  String get noAccess; // LG-05
  String get sessionExpired; // LG-06
  String get connectToLogIn; // LG-07
  String get contactAdminForPassword;
  String get fingerprintFailed;
  String get fingerprintChanged;
  String get fingerprintLockedOut;
  String get fingerprintUnavailable;
  String get fingerprintNeedsInternet;

  // Server errors the phone words itself
  String get cannotReachServer;
  String get noPermissionGeneric;
  String get tooManyRequests;

  // Fingerprint login
  String get fingerprintOfferTitle;
  String get fingerprintOfferBody;
  String get notNow;
  String get turnOn;
  String get fingerprintTurnedOff;
  String get turnOnFingerprintLogin;
  String get confirmWithPassword;
  String get fingerprintIsOn;
  String get fingerprintNextTime;
  String get fingerprintNotTurnedOn;
  String get loginToAgrum;
  String get usePassword;

  // More
  String get loggedInOfflineNotice;
  String get sending;
  String recordsWaiting(int n);
  String get nothingWaiting;
  String get siteData;
  String get updating;
  String downloadedAt(String dateTime);
  String get notDownloadedYet;
  String lastUpdateFailed(String error);
  String get faceRegistration;
  String get noFacesOnPhone;
  String facesOnPhone(int n);
  String get registerFace;
  String get loginSection;
  String get logout;
  String get logoutTitle;
  String get logoutBody;

  // Attendance (2.6)
  String todayDate(String date);
  String workersCount(int n);
  String get noAttendanceToday;
  String get earlierNotSent;
  String get addAttendance;
  String get workingSite;
  String get selectSite;
  String get workType;
  String get selectWorkType;
  String get division;
  String get field;
  String get workersPresent;
  String get tickWorkersPresent;
  String selectedCount(int n);
  String get noMoreWorkers;
  String noWorkersMatch(String search);
  String get submit;
  String submitCount(int n);
  String get submitAttendanceTitle;
  String defaultSite(String site);
  String get changeCategory;
  String get category;
  String get categoryRegular;
  String get categorySeasonal;
  String get categoryLent;
  String get categoryBorrowed;
  String get atNoWorkers; // AT-01
  String atAlreadyRecorded(String worker); // AT-02
  String get atSiteNotAllowed; // AT-05
  String atOtherSite(String worker); // AT-06
  String get atWorkType; // AT-07
  String get atCategory; // AT-08
  String get atField; // AT-09
  String get atSiteSetup; // AT-10
  String get atTodayOnly; // AT-11
  String get atDivision; // AT-19
  String get atNoPermission; // AT-13
  String get noSiteData;
  String attendanceConfirm(int n);
  String attendanceRecorded(int n);

  // Weighing (2.7)
  String get noFacesRegisteredHint;
  String get identifyByFace;
  String get captureWeight;
  String get manualEntry;
  String get scaleNotConnected;
  String get scaleNotAvailable;
  String get connectScale;
  String get worker;
  String get noWorkersToWeigh;
  String get entriesToday;
  String get changeWorker;
  String get weight;
  String get weightManual;
  String weighingsTodayCount(int n);
  String weighingsTodayDate(String date);
  String get noWeighingsToday;
  String weighingNumber(int sequence);
  String get entryAutomatic;
  String get entryManual;
  String get weSelectWorker; // WE-01
  String weLimitReached(int n); // WE-04
  String get weWeight; // WE-06
  String get weNoScaleReading; // WE-07
  String get weNoManual; // WE-08
  String get weNoPermission; // WE-11
  String get weTodayOnly;
  String get weEntryType;
  String weSaved(String employeeCode, int sequence, String kg);

  // Face registration and the face check at the scale
  String get removeFace;
  String removeFaceBody(String name);
  String faceRemoved(String name);
  String get removeNeedsConnection;
  String get faceRegistrationIntro;
  String noEmployeesMatch(String search);
  String get noEmployeesYet;
  String get cameraPermissionRegister;
  String get cameraPermissionIdentify;
  String cameraCouldNotStart(String detail);
  String get noFaceFound;
  String get holdStill;
  String capturing(String instruction);
  String faceAlreadyRegistered(String name);
  String faceNotSaved(String name);
  String get backToList;
  String faceRegistered(String name);
  String get registerAnother;
  String get putFaceInOval;
  String get poseFront;
  String get poseLeft;
  String get poseRight;
  String get poseRelaxed;
  String get poseAltLighting;
  String get noFramesMessage;
  String faceCheckFailed(String error);
  String faceTryAgain(String reason);
  String get startingCamera;
  String get pointCameraAtFace;
  String get identifying;
  String get faceNotRecognised;
  String get notSureWho;
  String get faceModelNotLoaded;
  String get switchCamera;
  String get noFaceInPhoto;
  String get couldNotReadPhoto;
  String get couldNotCropFace;
  String get noPermissionRemoveFaces;
  String get noPermissionRegisterFaces;

  // Face camera guidance (made in English in the background; translated when shown)
  String get guideOnePerson;
  String get guideMoveCloser;
  String get guideMoveBack;
  String get guideCenter;
  String get guideStraighten;
  String get guideAdjustAngle;
  String get guideGood;
  String get guideTooDark;
  String get guideTooBright;
  String get guideBlurred;

  /// The camera guidance in this language; [english] is the message the face check made.
  String faceGuidance(String english) => switch (english) {
        'Only one person at a time' => guideOnePerson,
        'Move closer' => guideMoveCloser,
        'Move back a little' => guideMoveBack,
        'Center your face in frame' => guideCenter,
        'Straighten your head' => guideStraighten,
        'Adjust head angle' => guideAdjustAngle,
        'Good' => guideGood,
        'Too dark. Move to better light' => guideTooDark,
        'Too bright. Move out of direct light' => guideTooBright,
        'Picture is blurred. Hold the camera steady' => guideBlurred,
        _ => english,
      };
}

AppStrings _current = const EnStrings();

/// The texts in the language chosen on this phone. Widgets rebuild on a change because the app
/// root rebuilds its subtree (see AgrumApp); code outside widgets reads it when it runs.
AppStrings get tr => _current;

/// Called by the language controller only.
void setCurrentStrings(AppStrings strings) => _current = strings;
