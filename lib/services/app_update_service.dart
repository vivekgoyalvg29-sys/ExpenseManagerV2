import 'dart:async';
import 'dart:io';

import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Google Play in-app updates with optional “mandatory” behavior via Remote Config.
///
/// Firebase Remote Config keys (set in Firebase Console → Remote Config):
/// - [kMinSupportedBuild]: int. If the installed `versionCode` (build number) is
///   **strictly less** than this value, a **blocking** update is attempted
///   ([performImmediateUpdate]) when Play allows it; otherwise flexible update.
///   Default in code: `0` (no mandatory threshold).
///
/// After publishing a critical fix, raise `min_supported_build` to the first
/// “good” build number so older builds are pushed to update.
class AppUpdateService {
  AppUpdateService._();

  static const String kMinSupportedBuild = 'min_supported_build';

  static bool _sessionCheckDone = false;
  static StreamSubscription<InstallStatus>? _installSubscription;

  /// Call once per app launch after the first frame (MaterialApp is mounted).
  static Future<void> checkAfterFirstFrameIfAndroid() async {
    if (!Platform.isAndroid || kDebugMode) return;
    if (_sessionCheckDone) return;
    _sessionCheckDone = true;

    try {
      final remote = FirebaseRemoteConfig.instance;
      await remote.setConfigSettings(
        RemoteConfigSettings(
          fetchTimeout: const Duration(seconds: 12),
          minimumFetchInterval: const Duration(hours: 1),
        ),
      );
      await remote.setDefaults(const <String, dynamic>{
        kMinSupportedBuild: 0,
      });
      try {
        await remote.fetchAndActivate();
      } catch (_) {
        // Offline or fetch failure — use defaults / cache.
      }

      final minSupportedBuild = remote.getInt(kMinSupportedBuild);
      final packageInfo = await PackageInfo.fromPlatform();
      final currentBuild = int.tryParse(packageInfo.buildNumber) ?? 0;
      final mandatory = minSupportedBuild > 0 && currentBuild < minSupportedBuild;

      final info = await InAppUpdate.checkForUpdate();

      if (info.updateAvailability ==
          UpdateAvailability.developerTriggeredUpdateInProgress) {
        if (info.installStatus == InstallStatus.downloaded) {
          try {
            await InAppUpdate.completeFlexibleUpdate();
          } catch (_) {}
          return;
        }
        _attachFlexibleInstallListener();
        return;
      }

      if (info.updateAvailability != UpdateAvailability.updateAvailable) {
        return;
      }

      if (mandatory) {
        if (info.immediateUpdateAllowed) {
          await InAppUpdate.performImmediateUpdate();
        } else if (info.flexibleUpdateAllowed) {
          await _startFlexibleDownload();
        }
        return;
      }

      if (info.flexibleUpdateAllowed) {
        await _startFlexibleDownload();
      }
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('AppUpdateService: $e\n$st');
      }
    }
  }

  static Future<void> _startFlexibleDownload() async {
    _attachFlexibleInstallListener();
    final result = await InAppUpdate.startFlexibleUpdate();
    if (result != AppUpdateResult.success) {
      await _installSubscription?.cancel();
      _installSubscription = null;
    }
  }

  static void _attachFlexibleInstallListener() {
    _installSubscription?.cancel();
    _installSubscription = InAppUpdate.installUpdateListener.listen(
      (status) async {
        if (status == InstallStatus.downloaded) {
          try {
            await InAppUpdate.completeFlexibleUpdate();
          } finally {
            await _installSubscription?.cancel();
            _installSubscription = null;
          }
        }
      },
    );
  }
}
