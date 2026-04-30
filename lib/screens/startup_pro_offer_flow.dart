import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../app_navigator.dart';
import '../config/app_config.dart';
import '../services/account_subscription_service.dart';
import '../services/entitlement_service.dart';
import '../services/startup_pro_offer_service.dart';
import 'email_auth_sheet.dart';
import 'feature_comparison_sheet.dart';
import 'pro_purchase_flow.dart';

BuildContext? _navigatorContext(BuildContext? trigger) {
  if (trigger != null && trigger.mounted) return trigger;
  return appNavigatorKey.currentContext;
}

void _showSnack(BuildContext ctx, String message) {
  if (!ctx.mounted) return;
  ScaffoldMessenger.maybeOf(ctx)?.showSnackBar(
    SnackBar(content: Text(message)),
  );
}

/// Once per app version, after first-run defaults: Free users see comparison;
/// Pro users never see it. Does not run when [AppConfig.firebaseCloudEnabled]
/// is false. Independent of other in-app Pro gates.
Future<void> runStartupProOfferFlowIfEligible(BuildContext triggerContext) async {
  if (!AppConfig.firebaseCloudEnabled) return;

  if (await EntitlementService.getCurrentTier() == UserTier.pro) return;

  final versionKey = await StartupProOfferService.currentVersionKey();
  if (await StartupProOfferService.isVersionConsumed(versionKey)) return;

  var ctx = _navigatorContext(triggerContext);
  if (ctx == null) return;

  final result = await showFeatureComparisonForShareable(ctx);

  await StartupProOfferService.markVersionConsumed(versionKey);

  ctx = _navigatorContext(triggerContext);
  if (ctx == null) return;

  if (result != ShareComparisonResult.proContinue) return;

  if (await EntitlementService.getCurrentTier() == UserTier.pro) {
    _showSnack(
      ctx,
      "You're already on Pro. All Pro features are enabled.",
    );
    return;
  }

  if (FirebaseAuth.instance.currentUser != null) {
    if (!Platform.isAndroid) {
      _showSnack(
        ctx,
        'Google Play subscriptions are only available on Android.',
      );
      return;
    }
    await completeKharchaProPurchaseAfterComparison(ctx);
    return;
  }

  final signedIn = await ensureSignedInWithEmail(ctx);
  ctx = _navigatorContext(triggerContext);
  if (ctx == null || !signedIn) return;

  await AccountSubscriptionService.syncEntitlementFromFirestore();
  await AccountSubscriptionService.syncEntitlementFromPlayIfFree();

  ctx = _navigatorContext(triggerContext);
  if (ctx == null) return;

  if (await EntitlementService.getCurrentTier() == UserTier.pro) {
    _showSnack(
      ctx,
      "You're already on Pro. All Pro features are enabled.",
    );
    return;
  }

  if (!Platform.isAndroid) {
    _showSnack(
      ctx,
      'Google Play subscriptions are only available on Android.',
    );
    return;
  }

  await completeKharchaProPurchaseAfterComparison(ctx);
}
