import 'dart:io';
import 'package:home_widget/home_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'screens/add_transaction_page.dart';
import 'screens/home_screen.dart';
import 'services/data_store.dart';
import 'services/database_service.dart';
import 'services/visual_settings.dart';
import 'services/widget_sync_service.dart';

final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isIOS) {
    await HomeWidget.setAppGroupId('group.com.example.expense_manager');
  }

  await DataStore.initialize();
  await WidgetSyncService.syncFromStoredConfiguration();

  final visualSettings = await VisualSettings.load();
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
    _schedulePendingNavigationFlush();
  }

  Future<void> _handleWidgetNavigation(MethodCall call) async {
    if (call.method != 'navigateToRoute') {
      return;
    }

    final routeName = (call.arguments as String?) ?? '/';
    _pendingWidgetRoute = routeName;
    _schedulePendingNavigationFlush();
  }

  void _schedulePendingNavigationFlush() {
    if (_navigationFlushScheduled) {
      return;
    }

    _navigationFlushScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _navigationFlushScheduled = false;
      _flushPendingWidgetRoute();
    });
  }

  Future<void> _flushPendingWidgetRoute() async {
    final routeName = _pendingWidgetRoute;
    if (routeName == null) {
      return;
    }

    final navigator = appNavigatorKey.currentState;
    if (navigator == null) {
      _schedulePendingNavigationFlush();
      return;
    }

    _pendingWidgetRoute = null;
    await navigator.pushNamedAndRemoveUntil(routeName, (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: appNavigatorKey,
      title: 'FinTrack',
      theme: FinTrackTheme.build(widget.controller.value),
      builder: (context, child) {
        return ValueListenableBuilder<VisualSettings>(
          valueListenable: widget.controller,
          builder: (context, settings, _) {
            final mediaQuery = MediaQuery.of(context);
            return VisualSettingsScope(
              controller: widget.controller,
              child: Theme(
                data: FinTrackTheme.build(settings),
                child: MediaQuery(
                  data: mediaQuery.copyWith(textScaler: TextScaler.linear(settings.textScale)),
                  child: child ?? const SizedBox.shrink(),
                ),
              ),
            );
          },
        );
      },
      routes: {
        '/': (_) => const HomeScreen(),
        '/transactions': (_) => const HomeScreen(initialIndex: 0),
        '/add-transaction': (_) => const WidgetQuickAddTransactionPage(),
      },
      debugShowCheckedModeBanner: false,
    );
  }
}

class WidgetQuickAddTransactionPage extends StatelessWidget {
  const WidgetQuickAddTransactionPage({super.key});

  Future<void> _saveTransaction(Map<String, dynamic> result, BuildContext context) async {
    await DatabaseService.insertTransaction(
      result['title'],
      result['amount'],
      result['date'],
      result['type'],
      (result['account'] ?? '').toString(),
      (result['comment'] ?? '').toString(),
    );

    await WidgetSyncService.syncFromStoredConfiguration();

    if (!context.mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Transaction added.')),
    );
    appNavigatorKey.currentState?.pushNamedAndRemoveUntil('/transactions', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    return AddTransactionPage(
      onSaveResult: (result) => _saveTransaction(result, context),
    );
  }
}
