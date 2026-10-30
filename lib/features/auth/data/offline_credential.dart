import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// What the phone keeps to allow an offline login (LG-07, CL-04): a salted PBKDF2 hash of the
/// password, never the password itself, and when the user last logged in online.
class OfflineCredential {
  const OfflineCredential({
    required this.username,
    required this.salt,
    required this.iterations,
    required this.hash,
    required this.lastOnlineLoginAt,
  });

  final String username;
  final String salt;
  final int iterations;
  final String hash;
  final DateTime lastOnlineLoginAt;

  static const defaultIterations = 20000;

  static OfflineCredential create(String username, String password, DateTime now,
      {int iterations = defaultIterations}) {
    final random = Random.secure();
    final salt = base64Encode(List<int>.generate(16, (_) => random.nextInt(256)));
    return OfflineCredential(
      username: username,
      salt: salt,
      iterations: iterations,
      hash: _derive(password, salt, iterations),
      lastOnlineLoginAt: now.toUtc(),
    );
  }

  /// Usernames are not case-sensitive (FSD 2.1, Proposed).
  bool isFor(String otherUsername) => username.toLowerCase() == otherUsername.trim().toLowerCase();

  bool matches(String password) => _constantTimeEquals(_derive(password, salt, iterations), hash);

  bool isWithin(Duration period, DateTime now) {
    final age = now.toUtc().difference(lastOnlineLoginAt);
    return !age.isNegative && age < period;
  }

  /// The same password hash after another online login (a fingerprint login), which starts the
  /// offline login period again.
  OfflineCredential renewedAt(DateTime now) => OfflineCredential(
        username: username,
        salt: salt,
        iterations: iterations,
        hash: hash,
        lastOnlineLoginAt: now.toUtc(),
      );

  Map<String, dynamic> toJson() => {
        'username': username,
        'salt': salt,
        'iterations': iterations,
        'hash': hash,
        'lastOnlineLoginAt': lastOnlineLoginAt.toIso8601String(),
      };

  factory OfflineCredential.fromJson(Map<String, dynamic> json) => OfflineCredential(
        username: json['username'] as String,
        salt: json['salt'] as String,
        iterations: json['iterations'] as int,
        hash: json['hash'] as String,
        lastOnlineLoginAt: DateTime.parse(json['lastOnlineLoginAt'] as String),
      );

  /// PBKDF2-HMAC-SHA256, one 32-byte block.
  static String _derive(String password, String salt, int iterations) {
    final hmac = Hmac(sha256, utf8.encode(password));
    final block = Uint8List.fromList([...base64Decode(salt), 0, 0, 0, 1]);
    var u = hmac.convert(block).bytes;
    final result = Uint8List.fromList(u);
    for (var i = 1; i < iterations; i++) {
      u = hmac.convert(u).bytes;
      for (var j = 0; j < result.length; j++) {
        result[j] ^= u[j];
      }
    }
    return base64Encode(result);
  }

  static bool _constantTimeEquals(String a, String b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return diff == 0;
  }
}
