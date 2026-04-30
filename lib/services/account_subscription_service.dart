import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';

import '../config/app_config.dart';
import 'entitlement_service.dart';
import 'play_billing_service.dart';
import 'subscription_reminder_service.dart';

/// Firestore user fields for Pro: `accountStatus` (`free` | `pro`),
/// `proExpiresAt`, `playSubscriptionState`, `entitlementUpdatedAt`, `lastPurchaseProductId`.
class AccountSubscriptionService {
  AccountSubscriptionService._();

  static FirebaseFirestore get _firestore => FirebaseFirestore.instanceFor(
        app: Firebase.app(),
        databaseId: 'krchabookdb',
      );

  static const String _statusFree = 'free';
  static const String _statusPro = 'pro';

  /// Merge Free defaults into `users/{uid}` (e.g. right after registration).
  static Future<void> ensureFreeAccountFieldsInFirestore() async {
    if (!AppConfig.firebaseCloudEnabled) return;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await _firestore.collection('users').doc(uid).set(
      {
        'accountStatus': _statusFree,
        'proExpiresAt': null,
      },
      SetOptions(merge: true),
    );
    await EntitlementService.setTier(UserTier.free);
  }

  /// Writes Pro entitlement from an active Play purchase to Firestore and local prefs.
  /// Returns true if Firestore was updated and local state reflects Pro.
  static Future<bool> applyVerifiedAndroidPurchase(
    PurchaseDetails details,
  ) async {
    if (!AppConfig.firebaseCloudEnabled) return false;
    if (!Platform.isAndroid) return false;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return false;
    if (details.productID != AppConfig.proSubscriptionProductId) return false;

    try {
      // Derive expiry from purchase time if available, otherwise fall back to
      // now + 365 days. The safe cast handles cases where the PurchaseDetails
      // object is not a GooglePlayPurchaseDetails (e.g. during restore flows).
      DateTime expiry;
      if (details is GooglePlayPurchaseDetails) {
        final purchaseTimeMs = details.billingClientPurchase.purchaseTime;
        final purchaseDate =
            DateTime.fromMillisecondsSinceEpoch(purchaseTimeMs);
        expiry = purchaseDate.add(const Duration(days: 365));
      } else {
        debugPrint(
          'AccountSubscriptionService: PurchaseDetails is not '
          'GooglePlayPurchaseDetails (${details.runtimeType}), '
          'using fallback expiry.',
        );
        expiry = DateTime.now().add(const Duration(days: 365));
      }

      await _firestore.collection('users').doc(uid).set(
        {
          'accountStatus': _statusPro,
          'proExpiresAt': Timestamp.fromDate(expiry),
          'lastPurchaseProductId': details.productID,
          'entitlementUpdatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
      await EntitlementService.setTier(UserTier.pro);
      await EntitlementService.setProSignInRequired(false);
      await SubscriptionReminderService.applyEntitlementSnapshot(
        isPro: true,
        proExpiresAt: expiry,
      );
      return true;
    } catch (e, st) {
      debugPrint(
          'AccountSubscriptionService applyVerifiedAndroidPurchase: $e\n$st');
      await syncEntitlementFromFirestore();
      return false;
    }
  }

  /// Read cloud tier into local prefs. Expired Pro is downgraded in Firestore (client).
  static Future<void> syncEntitlementFromFirestore() async {
    if (!AppConfig.firebaseCloudEnabled) return;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    bool remindersPro = false;
    DateTime? remindersExpiry;

    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      final data = doc.data();
      final status = (data?['accountStatus'] as String?)?.toLowerCase().trim();
      final ts = data?['proExpiresAt'] as Timestamp?;

      if (status == _statusPro) {
        if (ts != null && ts.toDate().isBefore(DateTime.now())) {
          await _firestore.collection('users').doc(uid).set(
            {
              'accountStatus': _statusFree,
              'proExpiresAt': FieldValue.delete(),
            },
            SetOptions(merge: true),
          );
          await EntitlementService.setTier(UserTier.free);
          remindersPro = false;
          remindersExpiry = null;
        } else {
          await EntitlementService.setTier(UserTier.pro);
          await EntitlementService.setProSignInRequired(false);
          remindersPro = true;
          remindersExpiry = ts?.toDate();
        }
      } else {
        await EntitlementService.setTier(UserTier.free);
        remindersPro = false;
        remindersExpiry = null;
      }
    } catch (e, st) {
      debugPrint('AccountSubscriptionService sync: $e\n$st');
      await EntitlementService.setTier(UserTier.free);
      remindersPro = false;
      remindersExpiry = null;
    }

    await SubscriptionReminderService.applyEntitlementSnapshot(
      isPro: remindersPro,
      proExpiresAt: remindersExpiry,
    );
  }

  /// If Firestore-backed tier is still Free, restore from Play so an active
  /// subscription can stamp Pro for this account (e.g. after sign-in).
  static Future<void> syncEntitlementFromPlayIfFree() async {
    if (!Platform.isAndroid) return;
    if (!AppConfig.firebaseCloudEnabled) return;
    if (FirebaseAuth.instance.currentUser?.uid == null) return;
    final tier = await EntitlementService.getCurrentTier();
    if (tier == UserTier.pro) return;
    try {
      await PlayBillingService.instance.restorePurchasesForSync();
    } catch (e, st) {
      debugPrint('syncEntitlementFromPlayIfFree: $e\n$st');
    }
  }
}