import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:home_widget/home_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'app_navigator.dart';
import 'screens/add_transaction_page.dart';
import 'screens/auth/phone_auth_screen.dart';
import 'screens/home_screen.dart';
import 'services/data_service.dart';
import 'services/data_store.dart';
import 'services/app_localizations.dart';
import 'services/database_service.dart';
import 'services/migration_service.dart';
import 'services/profile_service.dart';
import 'services/visual_settings.dart';
import 'services/widget_sync_service.dart';
import 'services/app_update_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp();

  // Enable Firestore offline persistence for reliable sync and notifications.
  // Must target the named database ('krchabookdb') — not the default instance.
  FirebaseFirestore.instanceFor(
    app: Firebase.app(),
    databaseId: 'krchabookdb',
  ).settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );

  try {
    if (Platform.isIOS) {
      await HomeWidget.setAppGroupId('group.com.example.expense_manager');
    }
    await DataStore.initialize();
  } catch (_) {}

  VisualSettings visualSettings;
  try {
    visualSettings = await VisualSettings.load();
  } catch (_) {
    visualSettings = VisualSettings.defaults;
  }

  runApp(FinTrackApp(controller: VisualSettingsController(visualSettings)));

  // Avoid blocking first frame on a full transaction read + widget I/O.
  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(
      WidgetSyncService.syncFromStoredConfiguration().catchError((_, __) {}),
    );
  });
}

class FinTrackApp extends StatefulWidget {
  final VisualSettingsController controller;

  const FinTrackApp({super.key, required this.controller});

  @override
  State<FinTrackApp> createState() => _FinTrackAppState();
}

class _FinTrackAppState extends State<FinTrackApp> {
  static const MethodChannel _widgetNavigationChannel = MethodChannel(
    'fintrack/widget_navigation',
  );

  String? _pendingWidgetRoute;
  bool _navigationFlushScheduled = false;

  @override
  void initState() {
    super.initState();
    _widgetNavigationChannel.setMethodCallHandler(_handleWidgetNavigation);
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) _schedulePendingNavigationFlush();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(AppUpdateService.checkAfterFirstFrameIfAndroid());
    });
  }

  Future<void> _handleWidgetNavigation(MethodCall call) async {
    if (call.method != 'navigateToRoute') return;
    final routeName = (call.arguments as String?) ?? '/transactions';
    _pendingWidgetRoute = routeName;
    _schedulePendingNavigationFlush();
  }

  void _schedulePendingNavigationFlush() {
    if (_navigationFlushScheduled) return;
    _navigationFlushScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _navigationFlushScheduled = false;
      _flushPendingWidgetRoute();
    });
  }

  Future<void> _flushPendingWidgetRoute() async {
    final routeName = _pendingWidgetRoute;
    if (routeName == null) return;

    final navigator = appNavigatorKey.currentState;
    if (navigator == null) {
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) _schedulePendingNavigationFlush();
      });
      return;
    }

    _pendingWidgetRoute = null;
    try {
      await navigator.pushNamedAndRemoveUntil(routeName, (route) => false);
    } catch (_) {
      await navigator.pushNamedAndRemoveUntil('/transactions', (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<VisualSettings>(
      valueListenable: widget.controller,
      builder: (context, settings, _) => MaterialApp(
        navigatorKey: appNavigatorKey,
        title: 'Kharcha Book',
        theme: FinTrackTheme.build(settings, brightness: Brightness.light),
        darkTheme: FinTrackTheme.build(settings, brightness: Brightness.dark),
        themeMode: settings.themeMode == ThemeMode.system ? ThemeMode.light : settings.themeMode,
        locale: Locale(settings.localeCode),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        localeResolutionCallback: (locale, supportedLocales) {
          if (locale == null) return const Locale('en');
          final match = supportedLocales.where((supported) => supported.languageCode == locale.languageCode);
          return match.isNotEmpty ? match.first : const Locale('en');
        },
        builder: (context, child) {
          final mediaQuery = MediaQuery.of(context);
          return VisualSettingsScope(
            controller: widget.controller,
            child: AppLocalizationsScope(
              localizations: AppLocalizations(settings.localeCode),
              child: MediaQuery(
                data: mediaQuery.copyWith(
                    textScaler: TextScaler.linear(settings.textScale)),
                child: child ?? const SizedBox.shrink(),
              ),
            ),
          );
        },
        home: StreamBuilder<User?>(
          stream: FirebaseAuth.instance.authStateChanges(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Scaffold(
                backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                body: Center(
                  child: CircularProgressIndicator(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              );
            }
            if (snapshot.hasData) {
              return const _PostLoginInitScreen();
            }
            return const PhoneAuthScreen();
          },
        ),
        routes: {
          '/transactions': (_) => const HomeScreen(initialIndex: 0),
          '/add-transaction': (_) => const WidgetQuickAddTransactionPage(),
        },
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}

/// Shows HomeScreen immediately after login and performs profile/migration
/// initialization in the background.  A thin progress banner is shown at the
/// top of the screen while the background task runs, then disappears.
class _PostLoginInitScreen extends StatefulWidget {
  const _PostLoginInitScreen();

  @override
  State<_PostLoginInitScreen> createState() => _PostLoginInitScreenState();
}

class _PostLoginInitScreenState extends State<_PostLoginInitScreen> {
  // Show the home screen straight away — no blocking spinner.
  bool _initializing = true;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final phone = FirebaseAuth.instance.currentUser?.phoneNumber ?? '';

      // Step 1 — Ensure active_profile_id matches this Firebase user. SharedPreferences
      // are global: logging in with another number used to leave the previous
      // user's profile id in place, so Firestore looked empty for the new account.
      if (phone.isNotEmpty) {
        await ProfileService().syncActiveProfileForCurrentUser();
      }

      // Step 2 — One-time SQLite wipe on the first run after Firebase
      // integration, so old local-only data never contaminates Firestore profiles.
      final migrationService = MigrationService();
      if (!await migrationService.hasMigrated()) {
        try {
          await DatabaseService.deleteAllData();
        } catch (_) {}
        await migrationService.markDone();
      }

      // Step 3 — Background: ensure the default profile document exists in
      // Firestore. With offline persistence this hits the local cache
      // immediately, so the profile appears in the real-time stream at once.
      if (phone.isNotEmpty) {
        ProfileService()
            .ensureDefaultProfileExists()
            .then((_) => ProfileService().ensureActiveProfileMembership())
            .catchError((_) {});
      }
    } catch (_) {}

    if (mounted) setState(() => _initializing = false);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const HomeScreen(),
        // Non-blocking banner shown while background init runs.
        if (_initializing)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: LinearProgressIndicator(
              color: Theme.of(context).colorScheme.primary,
              backgroundColor: Colors.transparent,
            ),
          ),
      ],
    );
  }
}

class WidgetQuickAddTransactionPage extends StatelessWidget {
  const WidgetQuickAddTransactionPage({super.key});

  Future<void> _saveTransaction(
      Map<String, dynamic> result, BuildContext context) async {
    try {
      await DataService.insertTransaction(
        result['title'],
        result['amount'],
        result['date'],
        result['type'],
        (result['account'] ?? '').toString(),
        (result['comment'] ?? '').toString(),
      );
    } catch (_) {
      // Fallback to SQLite if Firestore fails
      await DatabaseService.insertTransaction(
        result['title'],
        result['amount'],
        result['date'],
        result['type'],
        (result['account'] ?? '').toString(),
        (result['comment'] ?? '').toString(),
      );
    }

    try {
      await WidgetSyncService.syncFromStoredConfiguration();
    } catch (_) {}

    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Transaction added.')),
    );
    appNavigatorKey.currentState
        ?.pushNamedAndRemoveUntil('/transactions', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    return AddTransactionPage(
      modalStyle: false,
      onSaveResult: (result) => _saveTransaction(result, context),
    );
  }
}
