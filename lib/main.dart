import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:home_widget/home_widget.dart';

import 'screens/add_transaction_page.dart';
import 'screens/home_screen.dart';
import 'services/data_store.dart';
import 'services/database_service.dart';
import 'services/widget_sync_service.dart';

final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isIOS) {
    await HomeWidget.setAppGroupId('group.com.example.expense_manager');
  }
  await WidgetSyncService.syncFromStoredConfiguration();
  await DataStore.initialize();

  runApp(const FinTrackApp());
}

class FinTrackApp extends StatefulWidget {
  const FinTrackApp({super.key});

  @override
  State<FinTrackApp> createState() => _FinTrackAppState();
}

class _FinTrackAppState extends State<FinTrackApp> {
  static const MethodChannel _widgetNavigationChannel = MethodChannel(
    'fintrack/widget_navigation',
  );

  @override
  void initState() {
    super.initState();
    _widgetNavigationChannel.setMethodCallHandler(_handleWidgetNavigation);
  }

  Future<void> _handleWidgetNavigation(MethodCall call) async {
    if (call.method != 'navigateToRoute') {
      return;
    }

    final routeName = (call.arguments as String?) ?? '/';
    final navigator = appNavigatorKey.currentState;
    if (navigator == null) {
      return;
    }

    await navigator.pushNamedAndRemoveUntil(routeName, (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: appNavigatorKey,
      title: 'FinTrack',
      theme: ThemeData(
        primarySwatch: Colors.green,
        textTheme: const TextTheme(
          bodyMedium: TextStyle(fontSize: 14),
          titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
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
