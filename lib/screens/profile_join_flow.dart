import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../config/app_config.dart';
import '../models.dart';
import '../services/account_subscription_service.dart';
import '../services/data_store.dart';
import '../services/entitlement_service.dart';
import '../services/profile_service.dart';
import 'email_auth_sheet.dart';
import 'pro_purchase_flow.dart';

Future<void> _syncViewerReadOnlyFlags() async {
  final profileService = ProfileService();
  if (!AppConfig.firebaseCloudEnabled || !profileService.isSignedIn) {
    DataStore.clearViewerReadOnlyFlags();
    return;
  }
  final role = await profileService.getCurrentUserRole();
  final tier = await EntitlementService.getCurrentTier();
  DataStore.viewerReadOnly =
      role != null && role != 'owner' && tier == UserTier.free;
  DataStore.viewerReadOnlySilent = DataStore.viewerReadOnly;
}

Future<void> _showJoinedProfileReadOnlyDialog(
  BuildContext context,
  ProfileModel profile,
) async {
  if (!context.mounted) return;
  if (!AppConfig.firebaseCloudEnabled || !ProfileService().isSignedIn) {
    return;
  }
  final myKey = ProfileService().currentMemberKey;
  final role = profile.members[myKey] ?? '';
  if (role == 'owner') return;
  final tier = await EntitlementService.getCurrentTier();
  if (tier == UserTier.pro) return;
  if (!context.mounted) return;
  final action = await showDialog<String>(
    context: context,
    useRootNavigator: true,
    builder: (ctx) => AlertDialog(
      title: const Text('View-only access'),
      content: const Text(
        'You can only view this shared book. Become a Pro to add, edit, or delete entries.\n\n'
        'Making the book private or deleting it stays with the owner.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, 'ok'),
          child: const Text('OK'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, 'pro'),
          child: const Text('Become a Pro'),
        ),
      ],
    ),
  );
  if (!context.mounted) return;
  if (action == 'pro') {
    final ok = await ensureSignedInThenProComparisonAndPurchase(context);
    if (!context.mounted || !ok) return;
    if (AppConfig.firebaseCloudEnabled) {
      await AccountSubscriptionService.syncEntitlementFromFirestore();
    }
    await _syncViewerReadOnlyFlags();
  }
}

/// Waits until FirebaseAuth has a confirmed non-null current user,
/// or times out after [timeout]. Fixes the race condition where the
/// Firestore SDK fires a transaction before the auth token is fully
/// propagated after a fresh sign-in.
Future<void> _waitForAuthToken({
  Duration timeout = const Duration(seconds: 5),
}) async {
  if (FirebaseAuth.instance.currentUser != null) return;
  await FirebaseAuth.instance
      .authStateChanges()
      .firstWhere((user) => user != null)
      .timeout(timeout, onTimeout: () => null);
}

/// Invite-code join from **root** [BuildContext] (e.g. [HomeScreen]),
/// not from inside another dialog.
Future<void> runJoinProfileInviteCodeFlow(BuildContext context) async {
  final codeCtrl = TextEditingController();
  final code = await showDialog<String>(
    context: context,
    useRootNavigator: true,
    builder: (ctx) => AlertDialog(
      title: const Text('Join Profile'),
      content: TextField(
        controller: codeCtrl,
        autofocus: true,
        maxLength: 6,
        textCapitalization: TextCapitalization.characters,
        decoration: const InputDecoration(
          hintText: 'Enter 6-character code',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, codeCtrl.text.trim()),
          child: const Text('Join'),
        ),
      ],
    ),
  );
  codeCtrl.dispose();
  if (code == null || code.isEmpty || !context.mounted) return;

  final profileService = ProfileService();
  if (!profileService.isSignedIn) {
    final signedIn = await ensureSignedInWithEmail(context);
    if (!signedIn || !context.mounted) return;
    // Wait for the Firebase Auth token to fully propagate to the Firestore
    // SDK before firing the join transaction. Without this, the transaction
    // can execute while request.auth is still null in Firestore rules,
    // causing a spurious permission-denied error on fresh sign-ins.
    await _waitForAuthToken();
  }

  try {
    final profile = await profileService.joinProfileByCode(code);
    if (!context.mounted) return;
    final role = profile.members[profileService.currentMemberKey] ?? 'viewer';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Joined "${profile.name}" as ${role == 'owner' ? 'owner' : 'viewer'}.',
        ),
      ),
    );
    await _syncViewerReadOnlyFlags();
    if (!context.mounted) return;
    await Future<void>.delayed(const Duration(milliseconds: 350));
    if (!context.mounted) return;
    await _showJoinedProfileReadOnlyDialog(context, profile);
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }
}