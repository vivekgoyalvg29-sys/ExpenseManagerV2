import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:home_widget/home_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'screens/add_transaction_page.dart';
import 'screens/auth/phone_auth_screen.dart';
import 'screens/home_screen.dart';
import 'services/data_store.dart';
import 'services/app_localizations.dart';
import 'services/database_service.dart';
import 'services/visual_settings.dart';
import 'services/widget_sync_service.dart';

final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp();

  try {
    if (Platform.isIOS) {
      await HomeWidget.setAppGroupId('group.com.example.expense_manager');
    }
    await DataStore.initialize();
  } catch (_) {}

  try {
    await WidgetSyncService.syncFromStoredConfiguration();
  } catch (_) {}

  VisualSettings visualSettings;
  try {
    visualSettings = await VisualSettings.load();
  } catch (_) {
    visualSettings = VisualSettings.defaults;
  }

  runApp(FinTrackApp(controller: VisualSettingsController(visualSettings)));
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
  }

  Future<void> _handleWidgetNavigation(MethodCall call) async {
    if (call.method != 'navigateToRoute') return;
    final routeName = (call.arguments as String?) ?? '/';
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
      await navigator.pushNamedAndRemoveUntil('/', (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<VisualSettings>(
      valueListenable: widget.controller,
      builder: (context, settings, _) => MaterialApp(
        navigatorKey: appNavigatorKey,
        title: 'WhereIsMyMoney',
        theme: FinTrackTheme.build(settings, brightness: Brightness.light),
        darkTheme: FinTrackTheme.build(settings, brightness: Brightness.dark),
        themeMode: settings.themeMode,
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
            return const Scaffold(
              backgroundColor: Colors.black,
              body: Center(
                child: CircularProgressIndicator(color: const Color(0xFF4F46E5)),
              ),
            );
          }
          if (snapshot.hasData) {
            return const HomeScreen();
          }
          return const PhoneAuthScreen();
        },
      ),
      routes: {
        '/': (_) => const HomeScreen(),
        '/transactions': (_) => const HomeScreen(initialIndex: 0),
        '/add-transaction': (_) => const WidgetQuickAddTransactionPage(),
      },
      debugShowCheckedModeBanner: false,
      ),
    );
  }
}

class WidgetQuickAddTransactionPage extends StatelessWidget {
  const WidgetQuickAddTransactionPage({super.key});

  Future<void> _saveTransaction(
      Map<String, dynamic> result, BuildContext context) async {
    await DatabaseService.insertTransaction(
      result['title'],
      result['amount'],
      result['date'],
      result['type'],
      (result['account'] ?? '').toString(),
      (result['comment'] ?? '').toString(),
    );

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
