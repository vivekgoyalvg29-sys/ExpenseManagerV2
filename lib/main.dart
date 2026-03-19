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
    i
