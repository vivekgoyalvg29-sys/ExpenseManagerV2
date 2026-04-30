import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:home_widget/home_widget.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'config/app_config.dart';
import 'app_navigator.dart';
import 'screens/add_transaction_page.dart';
import 'screens/auth_landing_screen.dart';
import 'screens/home_screen.dart';
import 'screens/onboarding_screen.dart';
import 'services/auth_gate_service.dart';
import 'services/onboarding_service.dart';
import 'services/account_subscription_service.dart';
import 'services/data_service.dart';
import 'services/data_store.dart';
import 'services/app_localizations.dart';
import 'services/database_service.dart';
import 'services/profile_service.dart';
import 'services/visual_settings.dart';
import 'services/widget_sync_service.dart';
import 'services/app_update_service.dart';
import 'services/play_billing_service.dart';
import 'services/subscription_reminder_service.dart';
import 'services/daily_transaction_reminder_service.dart';

String _fullFlutterErrorText(FlutterErrorDetails details) {
  final b = StringBuffer(details.exceptionAsString());
  final st = details.stack?.toString();
  if (st != null && st.isNotEmpty) {
    b
      ..writeln()
      ..writeln(st);
  }
  final ctx = details.context?.toDescription();
  if (ctx != null && ctx.isNotEmpty) {
    b
      ..writeln()
      ..writeln('Widget location: $ctx');
  }
  return b.toString();
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (kDebugMode) {
    ErrorWidget.builder = (FlutterErrorDetails details) {
      return Material(
        color: Colors.red.shade900,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Debug: framework error',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: SingleChildScrollView(
                    child: Text(
                      _fullFlutterErrorText(details),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        height: 1.35,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.tonal(
                  onPressed: () {
                    Clipboard.setData(
                      ClipboardData(text: _fullFlutterErrorText(details)),
                    );
                  },
                  child: const Text('Copy full error + stack'),
                ),
                const SizedBox(height: 10),
                FilledButton(
                  onPressed: () => SystemNavigator.pop(),
                  child: const Text('Exit app (relaunch from IDE)'),
                ),
              ],
            ),
          ),
        ),
      );
    };
  }

  await Firebase.initializeApp();

  await PlayBillingService.instance.initialize();
  await SubscriptionReminderService.initialize();
  await DailyTransactionReminderService.initialize();

  if (AppConfig.firebaseCloudEnabled) {
    // Enable Firestore offline persistence when cloud mode is on.
    FirebaseFirestore.instanceFor(
      app: Firebase.app(),
      databaseId: 'krchabookdb',
    ).settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );
  }

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
        title: 'Kharcha Manager',
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
            value: settings,
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
        home: const _AuthWrapper(),
        routes: {
          '/transactions': (_) => const HomeScreen(initialIndex: 0),
          '/add-transaction': (_) => const WidgetQuickAddTransactionPage(),
        },
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}

/// Cold start: show [AuthLandingScreen] until signed in or guest session; then load profile state.
class _AuthWrapper extends StatefulWidget {
  const _AuthWrapper();

  @override
  State<_AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<_AuthWrapper> {
  StreamSubscription<User?>? _authSub;
  User? _user;
  bool? _onboardingComplete;

  @override
  void initState() {
    super.initState();
    _user = FirebaseAuth.instance.currentUser;
    _authSub = FirebaseAuth.instance.authStateChanges().listen((u) {
      if (mounted) setState(() => _user = u);
    });
    AuthGateService.guestSession.addListener(_onGuestChanged);
    unawaited(_loadOnboardingFlag());
  }

  Future<void> _loadOnboardingFlag() async {
    final done = await OnboardingService.isComplete();
    if (!mounted) return;
    setState(() => _onboardingComplete = done);
  }

  Future<void> _completeOnboarding() async {
    await OnboardingService.markComplete();
    if (!mounted) return;
    setState(() => _onboardingComplete = true);
  }

  void _onGuestChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _authSub?.cancel();
    AuthGateService.guestSession.removeListener(_onGuestChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_onboardingComplete == null) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: Center(
          child: CircularProgressIndicator(
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      );
    }
    if (!_onboardingComplete!) {
      return OnboardingScreen(onFinished: _completeOnboarding);
    }
    if (!AppConfig.firebaseCloudEnabled) {
      return const _HomeWithInitBanner();
    }
    final guest = AuthGateService.guestSession.value;
    final showApp = _user != null || guest;
    if (!showApp) {
      return const AuthLandingScreen();
    }
    return _HomeBootstrapShell(
      key: ValueKey<Object>(_user?.uid ?? 'guest'),
    );
  }
}

class _HomeBootstrapShell extends StatefulWidget {
  const _HomeBootstrapShell({super.key});

  @override
  State<_HomeBootstrapShell> createState() => _HomeBootstrapShellState();
}

class _HomeBootstrapShellState extends State<_HomeBootstrapShell> {
  late Future<void> _ready;

  @override
  void initState() {
    super.initState();
    _ready = _bootstrap();
  }

  Future<void> _bootstrap() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await ProfileService().syncActiveProfileForCurrentUser();
        unawaited(
          ProfileService().ensureActiveProfileMembership().catchError((_) {}),
        );
        // Await so HomeScreen never reads a stale `user_tier` left from a prior
        // signed-in account before Firestore sync finishes (unawaited caused
        // Free-vs-Pro menu mismatch after switch + cold start).
        await AccountSubscriptionService.syncEntitlementFromFirestore();
      } else {
        await ProfileService().ensureLocalPrivateProfileActive();
      }
      await ProfileService().refreshCachedActiveProfileId();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _ready,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return Scaffold(
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            body: Center(
              child: CircularProgressIndicator(
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          );
        }
        return const _HomeWithInitBanner();
      },
    );
  }
}

/// Home shell with optional non-blocking banner while signed-in Firestore init runs.
class _HomeWithInitBanner extends StatefulWidget {
  const _HomeWithInitBanner();

  @override
  State<_HomeWithInitBanner> createState() => _HomeWithInitBannerState();
}

class _HomeWithInitBannerState extends State<_HomeWithInitBanner> {
  bool _initializing = true;

  @override
  void initState() {
    super.initState();
    _finishBanner();
  }

  Future<void> _finishBanner() async {
    if (!AppConfig.firebaseCloudEnabled) {
      if (mounted) setState(() => _initializing = false);
      return;
    }
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) setState(() => _initializing = false);
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 400));
    if (mounted) setState(() => _initializing = false);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const HomeScreen(),
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
