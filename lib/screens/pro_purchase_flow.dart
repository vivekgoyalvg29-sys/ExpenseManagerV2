import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/entitlement_service.dart';
import '../services/play_billing_service.dart';
import 'email_auth_sheet.dart';
import 'feature_comparison_sheet.dart';

/// When user may be logged out: **sign in/create first**, then comparison, then billing.
/// When already Pro, returns true without showing comparison.
Future<bool> ensureSignedInThenProComparisonAndPurchase(
  BuildContext context,
) async {
  if (FirebaseAuth.instance.currentUser == null) {
    final ok = await ensureSignedInWithEmail(context);
    if (!ok || !context.mounted) return false;
  }
  if (!context.mounted) return false;
  if (await EntitlementService.getCurrentTier() == UserTier.pro) {
    return true;
  }
  final r = await showFeatureComparisonForShareable(context);
  if (!context.mounted || r != ShareComparisonResult.proContinue) {
    return false;
  }
  return completeKharchaProPurchaseAfterComparison(context);
}

/// Google Play purchase only; caller must ensure user is signed in and comparison already shown if needed.
Future<bool> completeKharchaProPurchaseAfterComparison(
  BuildContext context,
) async {
  if (!Platform.isAndroid) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.showSnackBar(
      const SnackBar(
        content: Text(
          'Google Play subscriptions are only available on Android.',
        ),
      ),
    );
    return false;
  }
  try {
    final purchased =
        await PlayBillingService.instance.purchaseProSubscription();
    if (!context.mounted) return purchased;
    if (purchased) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Welcome to Pro!')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Payment completed but Pro did not activate. '
            'Please restart the app or try Restore Purchases.',
          ),
        ),
      );
    }
    return purchased;
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
    return false;
  }
}
