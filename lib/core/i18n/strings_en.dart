import 'app_strings.dart';

/// English: the FSD's own texts.
class EnStrings extends AppStrings {
  const EnStrings();

  // Common
  @override
  String get cancel => 'Cancel';
  @override
  String get back => 'Back';
  @override
  String get save => 'Save';
  @override
  String get done => 'Done';
  @override
  String get remove => 'Remove';
  @override
  String get continueLabel => 'Continue';
  @override
  String get select => 'Select';
  @override
  String get somethingWentWrong => 'Something went wrong. Please try again.';
  @override
  String get language => 'Language';
  @override
  String get searchEmpOrName => 'Search EMP No or name';
  @override
  String get searchByEmpOrName => 'Search by EMP No or name';
  @override
  String xOfY(int x, int y) => '$x of $y';

  // Tabs and Mobile Home
  @override
  String get tabHome => 'Home';
  @override
  String get tabAttendance => 'Attendance';
  @override
  String get tabWeighing => 'Weighing';
  @override
  String get tabMore => 'More';
  @override
  String hello(String name) => 'Hello, $name';
  @override
  String get attendanceHint => "Mark today's workers present";
  @override
  String get weighingHint => "Weigh pluckers' tea";

  // Status line and sending
  @override
  String offlineWaiting(int n) => 'Offline · $n waiting to send';
  @override
  String get offlineSaved => 'Offline · records are saved on this phone';
  @override
  String offlineSessionWaiting(int n) => 'Logged in offline · $n waiting';
  @override
  String waitingToSend(int n) => '$n waiting to send';
  @override
  String get siteDataNotDownloaded => 'Site data not downloaded yet';
  @override
  String get allSent => 'All sent';
  @override
  String get online => 'Online';
  @override
  String get sendNow => 'Send Now';
  @override
  String sendNowWaiting(int n) => 'Send Now · $n waiting to send';
  @override
  String get sendNoConnection => 'Sending failed · no connection';
  @override
  String sendFailed(String reason) => 'Sending failed · $reason';
  @override
  String get sendAllSent => 'All sent · site data updated';
  @override
  String get sendOfflineSession => 'Logged in offline · log in online to send';
  @override
  String get updatingSiteData => 'Updating site data…';
  @override
  String sendingProgress(String what, int done, int total) => 'Sending $what $done of $total…';
  @override
  String get whatAttendance => 'attendance';
  @override
  String get whatWeighings => 'weighings';
  @override
  String get whatFaces => 'faces';
  @override
  String sentCount(int n) => '$n sent';
  @override
  String rejectedCount(int n) => '$n rejected';
  @override
  String get setupOfflineSession => 'You logged in without internet. Log out and log in again online to send.';

  // Sync Status
  @override
  String get statusWaiting => 'Waiting to send';
  @override
  String get statusSent => 'Sent';
  @override
  String get statusRejected => 'Rejected';

  // Login
  @override
  String get fieldSupervisorLogin => 'Field supervisor login';
  @override
  String environmentBadge(String environment) => '$environment – test system';
  @override
  String noConnectionLogin(int days) =>
      'No connection. You can still log in if you logged in on this phone in the last $days days.';
  @override
  String get username => 'Username';
  @override
  String get yourUsername => 'Your username';
  @override
  String get password => 'Password';
  @override
  String get yourPassword => 'Your password';
  @override
  String get loggingIn => 'Logging in…';
  @override
  String get login => 'Login';
  @override
  String get loginWithFingerprint => 'Log in with fingerprint';
  @override
  String get forgotChangePassword => 'Forgot / Change Password';
  @override
  String get enterUsername => 'Please enter your username.';
  @override
  String get enterPassword => 'Please enter your password.';
  @override
  String get loginIncorrect => 'Username or password is incorrect.';
  @override
  String get noAccess => 'You do not have access to this application. Please contact the administrator.';
  @override
  String get sessionExpired => 'Your session has expired. Please log in again.';
  @override
  String get connectToLogIn => 'Please connect to the internet to log in.';
  @override
  String get contactAdminForPassword => 'Contact administrator to change password.';
  @override
  String get fingerprintFailed => 'Fingerprint login failed. Please log in with your password.';
  @override
  String get fingerprintChanged =>
      'The fingerprints on this phone have changed. Log in with your password, then turn fingerprint login on again.';
  @override
  String get fingerprintLockedOut => 'Too many fingerprint attempts. Please log in with your password.';
  @override
  String get fingerprintUnavailable => 'Set up a fingerprint in the phone settings first.';
  @override
  String get fingerprintNeedsInternet => 'Please connect to the internet to turn on fingerprint login.';

  // Server errors
  @override
  String get cannotReachServer => 'Cannot reach the server.';
  @override
  String get noPermissionGeneric => 'You do not have permission to do this.';
  @override
  String get tooManyRequests => 'Too many requests. Please wait a moment and try again.';

  // Fingerprint login
  @override
  String get fingerprintOfferTitle => 'Log in with your fingerprint?';
  @override
  String get fingerprintOfferBody =>
      'Next time, log in with your fingerprint instead of typing your password. You can turn this off in More.';
  @override
  String get notNow => 'Not now';
  @override
  String get turnOn => 'Turn on';
  @override
  String get fingerprintTurnedOff => 'Fingerprint login turned off';
  @override
  String get turnOnFingerprintLogin => 'Turn on fingerprint login';
  @override
  String get confirmWithPassword => 'Enter your password to confirm it is you.';
  @override
  String get fingerprintIsOn => 'Fingerprint login is on';
  @override
  String get fingerprintNextTime => 'Next time, log in with your fingerprint.';
  @override
  String get fingerprintNotTurnedOn => 'Fingerprint login not turned on';
  @override
  String get loginToAgrum => 'Log in to Agrum';
  @override
  String get usePassword => 'Use password';

  // More
  @override
  String get loggedInOfflineNotice => 'Logged in without internet. Log out and log in again online to send records.';
  @override
  String get sending => 'Sending';
  @override
  String recordsWaiting(int n) => '$n records waiting to send';
  @override
  String get nothingWaiting => 'Nothing waiting to send';
  @override
  String get siteData => 'Site data';
  @override
  String get updating => 'Updating…';
  @override
  String downloadedAt(String dateTime) => 'Downloaded $dateTime';
  @override
  String get notDownloadedYet => 'Not downloaded yet. Connect to the internet and tap Send Now.';
  @override
  String lastUpdateFailed(String error) => 'Last update failed: $error';
  @override
  String get faceRegistration => 'Face Registration';
  @override
  String get noFacesOnPhone => 'No faces registered on this phone';
  @override
  String facesOnPhone(int n) => '$n ${n == 1 ? 'face' : 'faces'} registered on this phone';
  @override
  String get registerFace => 'Register Face';
  @override
  String get loginSection => 'Login';
  @override
  String get logout => 'Logout';
  @override
  String get logoutTitle => 'Log out?';
  @override
  String get logoutBody => 'Records saved on this phone are kept and sent after you log in again.';

  // Attendance
  @override
  String todayDate(String date) => 'Today, $date';
  @override
  String workersCount(int n) => '$n workers';
  @override
  String get noAttendanceToday => 'No attendance recorded today on this phone.';
  @override
  String get earlierNotSent => 'Earlier days, not sent';
  @override
  String get addAttendance => 'Add Attendance';
  @override
  String get workingSite => 'Working Site';
  @override
  String get selectSite => 'Select a site';
  @override
  String get workType => 'Work Type';
  @override
  String get selectWorkType => 'Select a work type';
  @override
  String get division => 'Division';
  @override
  String get field => 'Field';
  @override
  String get workersPresent => 'Workers present';
  @override
  String get tickWorkersPresent => 'Tick the workers present';
  @override
  String selectedCount(int n) => '$n selected';
  @override
  String get noMoreWorkers => 'No more workers to mark today.';
  @override
  String noWorkersMatch(String search) => 'No workers match "$search".';
  @override
  String get submit => 'Submit';
  @override
  String submitCount(int n) => 'Submit ($n)';
  @override
  String get submitAttendanceTitle => 'Submit attendance';
  @override
  String defaultSite(String site) => 'Default site $site';
  @override
  String get changeCategory => 'Change category';
  @override
  String get category => 'Category';
  @override
  String get categoryRegular => 'Regular';
  @override
  String get categorySeasonal => 'Seasonal';
  @override
  String get categoryLent => 'Lent';
  @override
  String get categoryBorrowed => 'Borrowed';
  @override
  String get atNoWorkers => 'Please select at least one worker.';
  @override
  String atAlreadyRecorded(String worker) => 'Attendance has already been recorded today for $worker.';
  @override
  String get atSiteNotAllowed => 'Attendance cannot be recorded for an inactive or unassigned site.';
  @override
  String atOtherSite(String worker) => 'You are not permitted to record $worker at a different site.';
  @override
  String get atWorkType => 'Please select a Work Type.';
  @override
  String get atCategory => 'Please select the Attendance Category.';
  @override
  String get atField => 'Please select the Field.';
  @override
  String get atSiteSetup => 'Site setup is incomplete. Please contact the administrator.';
  @override
  String get atTodayOnly => 'Attendance can only be recorded for today. Please check the phone date.';
  @override
  String get atDivision => 'Please select the Division.';
  @override
  String get atNoPermission => 'You do not have permission to record attendance.';
  @override
  String get noSiteData => 'Site data is not on this phone yet. Connect to the internet and tap Send Now.';
  @override
  String attendanceConfirm(int n) =>
      'Attendance cannot be changed after submission. Submit attendance for $n workers?';
  @override
  String attendanceRecorded(int n) => 'Attendance recorded for $n workers.';

  // Weighing
  @override
  String get noFacesRegisteredHint =>
      'No faces registered on this phone. Register them in More → Face Registration.';
  @override
  String get identifyByFace => 'Identify by face';
  @override
  String get captureWeight => 'Capture Weight';
  @override
  String get manualEntry => 'Manual Entry';
  @override
  String get scaleNotConnected => 'Scale not connected';
  @override
  String get scaleNotAvailable => 'Scale connection is not available yet.';
  @override
  String get connectScale => 'Connect Scale';
  @override
  String get worker => 'Worker';
  @override
  String get noWorkersToWeigh =>
      'No workers to weigh today. Record attendance with a weighing work type first.';
  @override
  String get entriesToday => 'Entries Today';
  @override
  String get changeWorker => 'Change worker';
  @override
  String get weight => 'Weight';
  @override
  String get weightManual => 'Weight · Manual';
  @override
  String weighingsTodayCount(int n) => '$n weighings today';
  @override
  String weighingsTodayDate(String date) => 'Weighings today, $date';
  @override
  String get noWeighingsToday => 'No weighings recorded today on this phone.';
  @override
  String weighingNumber(int sequence) => 'Weighing $sequence';
  @override
  String get entryAutomatic => 'Automatic';
  @override
  String get entryManual => 'Manual';
  @override
  String get weSelectWorker => 'Please select a worker.';
  @override
  String weLimitReached(int n) => 'Maximum of $n weighings per day already recorded for this worker.';
  @override
  String get weWeight => 'Please enter a weight greater than 0.';
  @override
  String get weNoScaleReading => 'No valid reading from the scale. Please check the scale connection.';
  @override
  String get weNoManual => 'You are not permitted to enter weight manually.';
  @override
  String get weNoPermission => 'You do not have permission to record weights.';
  @override
  String get weTodayOnly => 'Weights can only be recorded for today. Please check the phone date.';
  @override
  String get weEntryType => 'Please capture the weight from the scale or enter it manually.';
  @override
  String weSaved(String employeeCode, int sequence, String kg) => 'Saved – $employeeCode, weighing $sequence, $kg kg';

  // Faces
  @override
  String get removeFace => 'Remove face';
  @override
  String removeFaceBody(String name) =>
      'Remove the registered face of $name? At the scale they are picked by search until their face is registered again.';
  @override
  String faceRemoved(String name) => 'Face removed for $name.';
  @override
  String get removeNeedsConnection => 'Removing a face needs a connection. Try again when online.';
  @override
  String get faceRegistrationIntro =>
      'Pick the employee, then follow the steps with their face in the oval. '
      'Registering again replaces their face. Faces are sent to the server like other records.';
  @override
  String noEmployeesMatch(String search) => 'No employees match "$search".';
  @override
  String get noEmployeesYet => 'No employees in the site data yet.';
  @override
  String get cameraPermissionRegister =>
      'Camera permission is needed to register faces. Allow it in the phone settings.';
  @override
  String get cameraPermissionIdentify =>
      'Camera permission is needed to identify workers. Allow it in the phone settings.';
  @override
  String cameraCouldNotStart(String detail) => 'Camera could not start: $detail';
  @override
  String get noFaceFound => 'No face found';
  @override
  String get holdStill => 'Hold still...';
  @override
  String capturing(String instruction) => 'Capturing "$instruction"...';
  @override
  String faceAlreadyRegistered(String name) =>
      'This face is already registered to $name. A face can belong to only one employee. '
      'If that registration is wrong, remove it first.';
  @override
  String faceNotSaved(String name) => 'Face not saved for $name.';
  @override
  String get backToList => 'Back to the list';
  @override
  String faceRegistered(String name) => 'Face registered for $name.';
  @override
  String get registerAnother => 'Register another';
  @override
  String get putFaceInOval => 'Put the face in the oval';
  @override
  String get poseFront => 'Look straight ahead';
  @override
  String get poseLeft => 'Turn slightly left';
  @override
  String get poseRight => 'Turn slightly right';
  @override
  String get poseRelaxed => 'Look straight ahead, relax your expression';
  @override
  String get poseAltLighting => 'Look straight ahead again (try different lighting if possible)';
  @override
  String get noFramesMessage =>
      'The camera is not sending pictures to the face check. Close this screen and open it again.';
  @override
  String faceCheckFailed(String error) => 'Face check failed: $error';
  @override
  String faceTryAgain(String reason) => '$reason. Try again, or search by EMP No.';
  @override
  String get startingCamera => 'Starting camera…';
  @override
  String get pointCameraAtFace => "Point the camera at the worker's face";
  @override
  String get identifying => 'Identifying…';
  @override
  String get faceNotRecognised => 'Face not recognised';
  @override
  String get notSureWho => 'Not sure who this is';
  @override
  String get faceModelNotLoaded => 'Face model not loaded';
  @override
  String get switchCamera => 'Switch camera';
  @override
  String get noFaceInPhoto => 'No face found in the photo. Try again.';
  @override
  String get couldNotReadPhoto => 'Could not read the photo. Try again.';
  @override
  String get couldNotCropFace => 'Could not crop the face. Try again.';
  @override
  String get noPermissionRemoveFaces => 'You do not have permission to remove faces.';
  @override
  String get noPermissionRegisterFaces => 'You do not have permission to register faces.';

  // Face camera guidance
  @override
  String get guideOnePerson => 'Only one person at a time';
  @override
  String get guideMoveCloser => 'Move closer';
  @override
  String get guideMoveBack => 'Move back a little';
  @override
  String get guideCenter => 'Center your face in frame';
  @override
  String get guideStraighten => 'Straighten your head';
  @override
  String get guideAdjustAngle => 'Adjust head angle';
  @override
  String get guideGood => 'Good';
  @override
  String get guideTooDark => 'Too dark. Move to better light';
  @override
  String get guideTooBright => 'Too bright. Move out of direct light';
  @override
  String get guideBlurred => 'Picture is blurred. Hold the camera steady';
}
