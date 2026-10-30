import 'package:biometric_signature/biometric_signature.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum FingerprintFailure {
  /// The user closed the prompt or chose "Use password".
  canceled,

  /// The phone's fingerprints changed (or the key is gone): Android destroyed the key.
  invalidated,

  /// Too many wrong fingerprints; Android blocks the sensor for a while.
  lockedOut,

  /// No fingerprint set up on the phone, or no sensor.
  unavailable,
  failed,
}

class FingerprintException implements Exception {
  const FingerprintException(this.failure, [this.detail]);

  final FingerprintFailure failure;
  final String? detail;

  @override
  String toString() => 'FingerprintException($failure${detail == null ? '' : ': $detail'})';
}

/// The fingerprint login key: an EC P-256 key in the Android Keystore that signs only right after a
/// fingerprint check, and that Android destroys when the phone's fingerprints change. The private key
/// never leaves the phone; the server keeps the public key.
abstract class FingerprintKeys {
  /// A strong (Class 3) fingerprint sensor with at least one fingerprint set up.
  Future<bool> available();

  /// Makes a new key, replacing any old one, after a fingerprint check. Returns the public key
  /// (X.509, base64). Throws [FingerprintException].
  Future<String> createKey();

  /// Signs [text] after a fingerprint check. Returns the signature (DER, base64). Throws
  /// [FingerprintException].
  Future<String> sign(String text);

  Future<void> deleteKey();
}

class KeystoreFingerprintKeys implements FingerprintKeys {
  KeystoreFingerprintKeys([BiometricSignature? plugin]) : _plugin = plugin ?? BiometricSignature();

  final BiometricSignature _plugin;

  static const _alias = 'agrum_login';

  @override
  Future<bool> available() async {
    try {
      final result = await _plugin.biometricAuthAvailable();
      return result.canAuthenticate == true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<String> createKey() async {
    final result = await _plugin.createKeys(
      keyAlias: _alias,
      keyFormat: KeyFormat.base64,
      promptMessage: 'Turn on fingerprint login',
      config: CreateKeysConfig(
        signatureType: SignatureType.ecdsa,
        enforceBiometric: true,
        requireAuthentication: true,
        setInvalidatedByBiometricEnrollment: true,
        // Fingerprint only: the phone's PIN must not be enough to log in
        useDeviceCredentials: false,
        enableDecryption: false,
        promptSubtitle: 'Agrum',
        cancelButtonText: 'Cancel',
      ),
    );
    final publicKey = result.publicKey;
    if (result.code != BiometricError.success || publicKey == null) throw _failure(result.code, result.error);
    return publicKey;
  }

  @override
  Future<String> sign(String text) async {
    final result = await _plugin.createSignature(
      payload: text,
      keyAlias: _alias,
      signatureFormat: SignatureFormat.base64,
      promptMessage: 'Log in to Agrum',
      config: CreateSignatureConfig(allowDeviceCredentials: false, cancelButtonText: 'Use password'),
    );
    final signature = result.signature;
    if (result.code != BiometricError.success || signature == null) throw _failure(result.code, result.error);
    return signature;
  }

  @override
  Future<void> deleteKey() async {
    try {
      await _plugin.deleteKeys(keyAlias: _alias);
    } catch (_) {
      // Nothing to remove, or the Keystore already dropped it
    }
  }

  static FingerprintException _failure(BiometricError? code, String? detail) => FingerprintException(
        switch (code) {
          BiometricError.userCanceled || BiometricError.systemCanceled => FingerprintFailure.canceled,
          BiometricError.keyInvalidated || BiometricError.keyNotFound => FingerprintFailure.invalidated,
          BiometricError.lockedOut || BiometricError.lockedOutPermanent => FingerprintFailure.lockedOut,
          BiometricError.notAvailable ||
          BiometricError.notEnrolled ||
          BiometricError.passcodeNotSet ||
          BiometricError.notSupported =>
            FingerprintFailure.unavailable,
          _ => FingerprintFailure.failed,
        },
        detail,
      );
}

final fingerprintKeysProvider = Provider<FingerprintKeys>((ref) => KeystoreFingerprintKeys());
