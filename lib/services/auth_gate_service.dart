import 'package:flutter/foundation.dart';

/// In-memory only: user chose "Continue without signing in" for this process.
/// Cleared on logout and never persisted (cold start always shows auth until login or guest again).
class AuthGateService {
  AuthGateService._();

  static final ValueNotifier<bool> guestSession = ValueNotifier<bool>(false);

  static void enterGuestSession() {
    guestSession.value = true;
  }

  /// Call on sign-out so the auth screen is shown immediately.
  static void clearGuestSession() {
    guestSession.value = false;
  }
}
