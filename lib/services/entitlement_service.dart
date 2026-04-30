import 'package:shared_preferences/shared_preferences.dart';

/// Subscription / tier for Free vs Pro (billing hooks come later).
enum UserTier { free, pro }

class EntitlementService {
  EntitlementService._();

  static const String _tierKey = 'user_tier';

  /// After a Pro user signs out, show sign-in on next cold start until they sign in again.
  static const String _proSignInRequiredKey = 'pro_sign_in_required';

  static Future<UserTier> getCurrentTier() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_tierKey);
    if (raw == 'pro') return UserTier.pro;
    return UserTier.free;
  }

  static Future<bool> get isPro async =>
      (await getCurrentTier()) == UserTier.pro;

  /// Dev / future billing: persist tier. Defaults to [UserTier.free].
  static Future<void> setTier(UserTier tier) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tierKey, tier == UserTier.pro ? 'pro' : 'free');
  }

  static Future<bool> getProSignInRequired() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_proSignInRequiredKey) ?? false;
  }

  static Future<void> setProSignInRequired(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_proSignInRequiredKey, value);
  }

  /// Continue without signing in: use the app as **Free** (local private books only).
  /// Clears the Pro re-auth gate. User can upgrade again later (e.g. another email).
  static Future<void> useAppWithoutProSignInForNow() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tierKey, 'free');
    await prefs.setBool(_proSignInRequiredKey, false);
  }
}
