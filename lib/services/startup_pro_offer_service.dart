import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists which app version last saw the startup Free-vs-Pro comparison so we
/// show it at most once per install/version bump (separate from feature gates).
class StartupProOfferService {
  StartupProOfferService._();

  static const String _prefsKey = 'startup_pro_offer_consumed_version';

  static Future<String> currentVersionKey() async {
    final p = await PackageInfo.fromPlatform();
    return '${p.version}+${p.buildNumber}';
  }

  static Future<bool> isVersionConsumed(String versionKey) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_prefsKey) == versionKey;
  }

  static Future<void> markVersionConsumed(String versionKey) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, versionKey);
  }
}
