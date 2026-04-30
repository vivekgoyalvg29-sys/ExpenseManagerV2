import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../widgets/login_or_create_panel.dart';

/// Opens login-or-create bottom sheet. Returns true if user signed in successfully.
Future<bool> ensureSignedInWithEmail(BuildContext context) async {
  if (FirebaseAuth.instance.currentUser != null) return true;
  final ok = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    useRootNavigator: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) => LoginOrCreatePanel(
      embedInSheet: true,
      onRequestClose: () => Navigator.pop(ctx, false),
      closeModalOnSuccess: true,
    ),
  );
  // Sheet result can be null if pop raced with an auth-driven rebuild; treat a
  // live session as success so Pro comparison / billing can proceed.
  if (FirebaseAuth.instance.currentUser != null) return true;
  return ok == true;
}
