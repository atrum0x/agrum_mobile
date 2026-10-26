/// A record's Sync Status on the phone (FSD 10.5).
enum SyncStatus {
  waiting('WAITING', 'Waiting to send'),
  sent('SENT', 'Sent'),
  rejected('REJECTED', 'Rejected');

  const SyncStatus(this.code, this.label);

  /// Stored in the database and returned by the server's sync endpoints.
  final String code;
  final String label;

  static SyncStatus fromCode(String code) => values.firstWhere((s) => s.code == code, orElse: () => waiting);
}
