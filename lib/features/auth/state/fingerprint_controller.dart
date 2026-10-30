import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/auth_repository.dart';

class FingerprintState {
  const FingerprintState({this.loaded = false, this.available = false, this.enabledFor, this.offer = false});

  final bool loaded;

  /// The phone has a strong fingerprint sensor with a fingerprint set up.
  final bool available;

  /// The user fingerprint login is on for, on this phone.
  final String? enabledFor;

  /// Ask "Use fingerprint to log in next time?" (after a password login).
  final bool offer;

  bool get canLogIn => available && enabledFor != null;

  bool isOnFor(String username) => enabledFor?.toLowerCase() == username.toLowerCase();

  FingerprintState copyWith({bool? offer}) =>
      FingerprintState(loaded: loaded, available: available, enabledFor: enabledFor, offer: offer ?? this.offer);
}

/// Fingerprint login on this phone: whether it is on, and the one-time offer after a password login.
class FingerprintController extends Notifier<FingerprintState> {
  // The password typed at the login, in memory only, so accepting the offer needs no second typing
  String? _offerUsername;
  String? _offerPassword;

  AuthRepository get _repo => ref.read(authRepositoryProvider);

  @override
  FingerprintState build() {
    Future.microtask(refresh);
    return const FingerprintState();
  }

  Future<void> refresh() async {
    final available = await _repo.fingerprintAvailable();
    final login = await _repo.fingerprintLogin();
    state = FingerprintState(loaded: true, available: available, enabledFor: login?.username, offer: state.offer);
  }

  /// After an online password login.
  Future<void> offerAfterLogin(String username, String password) async {
    if (!await _repo.shouldOfferFingerprint(username)) return;
    _offerUsername = username;
    _offerPassword = password;
    state = state.copyWith(offer: true);
  }

  /// Throws [LoginException] or [FingerprintCanceled].
  Future<void> acceptOffer() async {
    final username = _offerUsername;
    final password = _offerPassword;
    clearOffer();
    if (username == null || password == null) return;
    await enable(username, password);
  }

  Future<void> declineOffer() async {
    final username = _offerUsername;
    clearOffer();
    if (username != null) await _repo.declineFingerprint(username);
  }

  void clearOffer() {
    _offerUsername = null;
    _offerPassword = null;
    if (state.offer) state = state.copyWith(offer: false);
  }

  /// Throws [LoginException] or [FingerprintCanceled].
  Future<void> enable(String username, String password) async {
    try {
      await _repo.enableFingerprint(username, password);
    } finally {
      await refresh();
    }
  }

  Future<void> disable() async {
    await _repo.disableFingerprint();
    await refresh();
  }
}

final fingerprintControllerProvider =
    NotifierProvider<FingerprintController, FingerprintState>(FingerprintController.new);
