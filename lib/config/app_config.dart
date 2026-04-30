/// Global feature flags.
class AppConfig {
  AppConfig._();

  /// When false: no Firestore/Auth cloud usage, SQLite + local profile list only.
  /// Remote Config / Firebase.initializeApp may still run for future use.
  static const bool firebaseCloudEnabled = true;

  /// Google Play subscription / in-app product id (must match Play Console).
  /// Create an auto-renewing subscription with this exact id in Play Console.
  static const String proSubscriptionProductId = 'kharcha_pro_yearly';

  /// Must match `applicationId` in android/app/build.gradle (Play Console package name).
  static const String androidPackageName = 'vivek.fintrack.app';
}
