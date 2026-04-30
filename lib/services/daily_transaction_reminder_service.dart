import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Daily local notification nudging the user to log transactions (Android).
class DailyTransactionReminderService {
  DailyTransactionReminderService._();

  static const _channelId = 'daily_transaction_reminder';
  static const _notificationId = 92001;
  static const _prefsEnabled = 'daily_tx_reminder_enabled_v1';
  static const _prefsHour = 'daily_tx_reminder_hour_v1';
  static const _prefsMinute = 'daily_tx_reminder_minute_v1';
  static const _prefsPromptedExactAlarms = 'daily_tx_reminder_prompted_exact_alarms_v1';

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static bool _tzReady = false;

  static AndroidFlutterLocalNotificationsPlugin? get _android =>
      _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

  static Future<void> initialize() async {
    if (!Platform.isAndroid) return;

    tzdata.initializeTimeZones();
    try {
      final name = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(name));
      _tzReady = true;
    } catch (e, st) {
      debugPrint('DailyTransactionReminderService: timezone init failed: $e\n$st');
    }

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _plugin.initialize(
      const InitializationSettings(android: androidInit),
    );

    await _android?.createNotificationChannel(
      const AndroidNotificationChannel(
        _channelId,
        'Daily reminders',
        description: 'Reminder to add transactions',
        importance: Importance.defaultImportance,
      ),
    );
    await _android?.requestNotificationsPermission();

    await applyFromPrefs();
  }

  static Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    if (!prefs.containsKey(_prefsEnabled)) return true;
    return prefs.getBool(_prefsEnabled) ?? true;
  }

  static Future<void> setEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsEnabled, enabled);
    if (enabled) {
      await _maybePromptExactAlarmsForPreciseTiming();
    }
    await applyFromPrefs();
  }

  static Future<(int hour, int minute)> getTime() async {
    final prefs = await SharedPreferences.getInstance();
    final h = prefs.getInt(_prefsHour);
    final m = prefs.getInt(_prefsMinute);
    if (h == null || m == null) return (19, 0);
    return (h.clamp(0, 23), m.clamp(0, 59));
  }

  static Future<void> setTime(int hour, int minute) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_prefsHour, hour.clamp(0, 23));
    await prefs.setInt(_prefsMinute, minute.clamp(0, 59));
    await _maybePromptExactAlarmsForPreciseTiming();
    await applyFromPrefs();
  }

  /// One-time system prompt so the daily fire can use [AndroidScheduleMode.exactAllowWhileIdle]
  /// when the OS requires it (e.g. Android 14+).
  static Future<void> _maybePromptExactAlarmsForPreciseTiming() async {
    final android = _android;
    if (android == null) return;
    try {
      if (await android.canScheduleExactNotifications() == true) return;
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_prefsPromptedExactAlarms) ?? false) return;
      await prefs.setBool(_prefsPromptedExactAlarms, true);
      await android.requestExactAlarmsPermission();
    } catch (e, st) {
      debugPrint('DailyTransactionReminderService exact-alarms prompt: $e\n$st');
    }
  }

  static Future<AndroidScheduleMode> _androidScheduleMode() async {
    final can = await _android?.canScheduleExactNotifications();
    if (can == true) {
      return AndroidScheduleMode.exactAllowWhileIdle;
    }
    return AndroidScheduleMode.inexactAllowWhileIdle;
  }

  static Future<void> applyFromPrefs() async {
    if (!Platform.isAndroid) return;

    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool(_prefsEnabled) ?? true;
    if (!enabled) {
      await _plugin.cancel(_notificationId);
      return;
    }

    if (!_tzReady) {
      try {
        final name = await FlutterTimezone.getLocalTimezone();
        tz.setLocalLocation(tz.getLocation(name));
        _tzReady = true;
      } catch (e, st) {
        debugPrint('DailyTransactionReminderService: timezone retry failed: $e\n$st');
        // Do not cancel: keep any previously scheduled notification.
        return;
      }
    }

    final hour = prefs.getInt(_prefsHour) ?? 19;
    final minute = prefs.getInt(_prefsMinute) ?? 0;
    final next = _nextInstanceOfTime(hour, minute);
    final mode = await _androidScheduleMode();

    try {
      await _plugin.cancel(_notificationId);
      await _plugin.zonedSchedule(
        _notificationId,
        'Kharcha Manager',
        "Add today's income and expenses.",
        next,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            'Daily reminders',
            channelDescription: 'Reminder to add transactions',
            importance: Importance.defaultImportance,
          ),
        ),
        androidScheduleMode: mode,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    } catch (e, st) {
      debugPrint('DailyTransactionReminderService schedule: $e\n$st');
    }
  }

  static tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    if (!scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }
}
