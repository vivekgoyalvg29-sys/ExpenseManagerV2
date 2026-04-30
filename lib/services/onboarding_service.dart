import 'package:shared_preferences/shared_preferences.dart';

/// First-launch intro slides; cleared on reinstall / app data clear.
class OnboardingService {
  OnboardingService._();

  static const String _key = 'onboarding_completed';

  static Future<bool> isComplete() async {
    final p = await SharedPreferences.getInstance();
    return p.getBool(_key) ?? false;
  }

  static Future<void> markComplete() async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_key, true);
  }
}
