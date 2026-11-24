import '../../../core/i18n/app_strings.dart';

/// A record's Sync Status on the phone (FSD 10.5).
enum SyncStatus {
  waiting('WAITING'),
  sent('SENT'),
  rejected('REJECTED');

  const SyncStatus(this.code);

  /// Stored in the database and returned by the server's sync endpoints.
  final String code;

  String get label => switch (this) {
        waiting => tr.statusWaiting,
        sent => tr.statusSent,
        rejected => tr.statusRejected,
      };

  static SyncStatus fromCode(String code) => values.firstWhere((s) => s.code == code, orElse: () => waiting);
}
