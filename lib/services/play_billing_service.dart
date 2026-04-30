import 'dart:async';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';

import '../config/app_config.dart';
import 'account_subscription_service.dart';

/// Google Play Billing (subscriptions). Listen to [purchaseStream] is started in [initialize].
class PlayBillingService {
  PlayBillingService._();

  static final PlayBillingService instance = PlayBillingService._();

  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _subscription;
  Completer<PurchaseDetails?>? _purchaseCompleter;

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    if (!Platform.isAndroid) return;

    final available = await _iap.isAvailable();
    if (!available) {
      debugPrint('PlayBillingService: billing not available on device');
    }

    await _subscription?.cancel();
    _subscription = _iap.purchaseStream.listen(
      _onPurchaseUpdated,
      onError: (Object e, StackTrace st) {
        debugPrint('PlayBillingService purchaseStream error: $e\n$st');
        if (_purchaseCompleter != null && !_purchaseCompleter!.isCompleted) {
          _purchaseCompleter!.completeError(e);
        }
      },
    );
  }

  void _onPurchaseUpdated(List<PurchaseDetails> purchases) {
    unawaited(_handlePurchases(purchases));
  }

  Future<void> _handlePurchases(List<PurchaseDetails> purchases) async {
    for (final p in purchases) {
      if (p.productID != AppConfig.proSubscriptionProductId) {
        if (p.pendingCompletePurchase) {
          await _iap.completePurchase(p);
        }
        continue;
      }

      if (p.status == PurchaseStatus.pending) {
        continue;
      }

      if (p.status == PurchaseStatus.error) {
        final err = p.error?.message ?? 'Purchase error';
        if (_purchaseCompleter != null && !_purchaseCompleter!.isCompleted) {
          _purchaseCompleter!.completeError(err);
        }
        continue;
      }

      if (p.status == PurchaseStatus.canceled) {
        if (_purchaseCompleter != null && !_purchaseCompleter!.isCompleted) {
          _purchaseCompleter!.complete(null);
        }
        continue;
      }

      if (p.status == PurchaseStatus.purchased ||
          p.status == PurchaseStatus.restored) {
        if (FirebaseAuth.instance.currentUser == null) {
          debugPrint(
            'PlayBillingService: purchase ready but user not signed in yet',
          );
          continue;
        }
        try {
          final verified =
              await AccountSubscriptionService.applyVerifiedAndroidPurchase(p);
          if (_purchaseCompleter != null && !_purchaseCompleter!.isCompleted) {
            _purchaseCompleter!.complete(verified ? p : null);
          }
        } catch (e, st) {
          debugPrint('PlayBillingService apply purchase failed: $e\n$st');
          if (_purchaseCompleter != null && !_purchaseCompleter!.isCompleted) {
            _purchaseCompleter!.completeError(e);
          }
          if (p.pendingCompletePurchase) {
            await _iap.completePurchase(p);
          }
          continue;
        }
        if (p.pendingCompletePurchase) {
          await _iap.completePurchase(p);
        }
      }
    }
  }

  /// Ask Play to emit past purchases (e.g. after login). Updates go through [purchaseStream].
  Future<void> restorePurchasesForSync() async {
    if (!Platform.isAndroid) return;
    await _iap.restorePurchases();
  }

  /// Launches the Google Play purchase sheet for [AppConfig.proSubscriptionProductId].
  /// Returns true if a purchase or restore completed successfully for our product.
  Future<bool> purchaseProSubscription() async {
    if (!Platform.isAndroid) return false;
    if (FirebaseAuth.instance.currentUser == null) {
      throw StateError('Sign in before subscribing.');
    }

    final available = await _iap.isAvailable();
    if (!available) {
      throw StateError('Google Play Billing is not available on this device.');
    }

    final response = await _iap.queryProductDetails(
      {AppConfig.proSubscriptionProductId},
    );

    if (response.error != null) {
      throw StateError(response.error!.message);
    }
    if (response.productDetails.isEmpty) {
      throw StateError(
        'Subscription product "${AppConfig.proSubscriptionProductId}" was not found. '
        'Create it in Play Console and use a signed / internal testing build.',
      );
    }

    GooglePlayProductDetails? androidDetails;
    for (final pd in response.productDetails) {
      if (pd is GooglePlayProductDetails) {
        androidDetails = pd;
        break;
      }
    }
    if (androidDetails == null) {
      throw StateError('Expected Google Play product details.');
    }

    _purchaseCompleter = Completer<PurchaseDetails?>();
    final purchaseParam = GooglePlayPurchaseParam(
      productDetails: androidDetails,
      offerToken: androidDetails.offerToken,
    );

    await _iap.buyNonConsumable(purchaseParam: purchaseParam);

    final result = await _purchaseCompleter!.future.timeout(
      const Duration(minutes: 5),
      onTimeout: () => null,
    );
    return result != null;
  }

  void dispose() {
    _subscription?.cancel();
    _subscription = null;
    _initialized = false;
  }
}
