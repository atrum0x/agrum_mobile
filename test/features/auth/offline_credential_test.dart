import 'package:agrum_mobile/features/auth/data/offline_credential.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.utc(2026, 10, 25, 8);

  OfflineCredential credential() => OfflineCredential.create('Sup01', 'secret', now, iterations: 50);

  test('matches only the password it was made from', () {
    final c = credential();
    expect(c.matches('secret'), isTrue);
    expect(c.matches('Secret'), isFalse);
    expect(c.matches(''), isFalse);
  });

  test('never keeps the password', () {
    final json = credential().toJson().toString();
    expect(json.contains('secret'), isFalse);
  });

  test('salts each credential differently', () {
    expect(credential().hash, isNot(credential().hash));
  });

  test('username is not case-sensitive', () {
    expect(credential().isFor(' sup01 '), isTrue);
    expect(credential().isFor('sup02'), isFalse);
  });

  test('is valid only inside the offline login period (CL-04)', () {
    final c = credential();
    const period = Duration(days: 3);
    expect(c.isWithin(period, now.add(const Duration(days: 2, hours: 23))), isTrue);
    expect(c.isWithin(period, now.add(period)), isFalse);
    // A phone clock set before the last online login is not trusted
    expect(c.isWithin(period, now.subtract(const Duration(minutes: 1))), isFalse);
  });

  test('survives a JSON round trip', () {
    final c = OfflineCredential.fromJson(credential().toJson());
    expect(c.matches('secret'), isTrue);
    expect(c.lastOnlineLoginAt, now);
  });
}
