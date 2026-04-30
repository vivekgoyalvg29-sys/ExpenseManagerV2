import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Some Android builds hit a Firebase Auth Pigeon bug: native auth succeeds but
/// Dart throws (e.g. List vs pigeonUserDetails). [currentUser] is often set anyway.
bool isAuthPlatformDeserializeBug(Object error) {
  final s = error.toString();
  if (s.contains('pigeonUserDetails') || s.contains('PigeonUserDetails')) {
    return true;
  }
  if (s.contains('is not a subtype') &&
      (s.contains('List') || s.contains('List<'))) {
    return true;
  }
  return false;
}

/// After a deserialize bug, the auth listener may set the user a frame later.
Future<bool> waitForAuthUserAfterPlatformBug({
  Duration timeout = const Duration(milliseconds: 3000),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    if (FirebaseAuth.instance.currentUser != null) {
      if (kDebugMode) {
        debugPrint(
          'firebase_auth_platform_recovery: currentUser appeared after platform bug',
        );
      }
      return true;
    }
    await Future<void>.delayed(const Duration(milliseconds: 120));
  }
  return FirebaseAuth.instance.currentUser != null;
}
