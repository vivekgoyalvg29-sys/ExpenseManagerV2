# Expense Manager

## Home screen widget support

This repository now includes widget data sync and platform templates for Android/iOS widgets.

### Widget content
The widget shows:
- Budget
- Expense
- Remaining
- Mode (`Selected month`, `Cumulative till selected month`, `Cumulative full year`)

### Widget mode source
The selected mode and month/year come from the Analysis screen selection.

### Android security config
Android manifest now disables cleartext traffic and points to a network security config.

### iOS notes
The project includes an app group entitlement (`group.com.example.expense_manager`) used for widget data sharing.

## Android release output (APK vs AAB)

If your build is producing an **AAB** (`.aab`) and you need an **APK** (`.apk`), use:

```bash
flutter build apk --release
```

Output file:

```text
build/app/outputs/flutter-apk/app-release.apk
```

Notes:
- `flutter build appbundle` creates an `.aab` file (for Play Store upload).
- `flutter build apk` creates an installable `.apk` file.
- ......

Documentation note: README received a minor one-line update.
