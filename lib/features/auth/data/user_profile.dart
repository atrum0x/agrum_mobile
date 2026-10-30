/// The logged-in user and their grants, from GET /api/auth/me/mobile. Cached on the phone so
/// an offline login shows the same Mobile Home.
class UserProfile {
  const UserProfile({
    required this.username,
    required this.employeeName,
    required this.superuser,
    required this.permissions,
  });

  final String username;
  final String? employeeName;
  final bool superuser;

  /// Projection ids such as "POST:/api/attendance/sync".
  final Set<String> permissions;

  /// Same rule as the server: the superuser is granted everything.
  bool can(String method, String path) => superuser || permissions.contains('$method:$path');

  bool get canRecordAttendance => can('POST', '/api/attendance/sync');
  bool get canRecordWeights => can('POST', '/api/weights/sync');

  /// CL-03: these grants are the rights themselves.
  bool get canRecordOtherSite => can('POST', '/api/attendance/other-site');
  bool get canEnterWeightManually => can('POST', '/api/weights/manual');

  /// Face Registration on the More tab, and downloading registered faces for the weighing screen.
  bool get canRegisterFaces => can('POST', '/api/face-templates/sync');
  bool get canDownloadFaces => can('GET', '/api/face-templates');

  /// LG-05 for the phone: at least one of its windows.
  bool get hasMobileAccess => canRecordAttendance || canRecordWeights;

  String get displayName => (employeeName == null || employeeName!.isEmpty) ? username : employeeName!;

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
        username: json['username'] as String,
        employeeName: json['employeeName'] as String?,
        superuser: json['superuser'] as bool? ?? false,
        permissions: {...((json['permissions'] as List?) ?? const []).cast<String>()},
      );

  Map<String, dynamic> toJson() => {
        'username': username,
        'employeeName': employeeName,
        'superuser': superuser,
        'permissions': permissions.toList(),
      };
}
