import 'dart:io';

import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';

import 'screens/home_screen.dart';
import 'services/widget_sync_service.dart';
import 'services/data_store.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isIOS) {
    await HomeWidget.setAppGroupId('group.com.example.expense_manager');
  }
  await WidgetSyncService.syncFromStoredConfiguration();
  await DataStore.initialize();

  runApp(const FinTrackApp());
}

class FinTrackApp extends StatelessWidget {
  const FinTrackApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "FinTrack",
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
      },
      debugShowCheckedModeBanner: false,
    );
  }
}
