import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Local notifications: ~7 days before Pro expiry and on expiry day (Android).
class SubscriptionReminderService {
  SubscriptionReminderService._();

  static const _channelId = 'subscription_reminders';
  static const _idWeekBefore = 91001;
  static const _idExpiryDay = 91002;

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static bool _tzReady = false;

  static Future<void> initialize() async {
    if (!Platform.isAndroid) return;

    tzdata.initializeTimeZones();
    try {
      final name = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(name));
      _tzReady = true;
    } catch (e, st) {
      debugPrint('SubscriptionReminderService: timezone init failed: $e\n$st');
    }

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _plugin.initialize(
      const InitializationSettings(android: androidInit),
    );

    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        _channelId,
        'Subscription',
        description: 'Pro renewal and expiry reminders',
        importance: Importance.defaultImportance,
      ),
    );
    await androidPlugin?.requestNotificationsPermission();
  }

  /// Clears prior schedules, then schedules reminders when [isPro] and [proExpiresAt] are set.
  static Future<void> applyEntitlementSnapshot({
    required bool isPro,
    DateTime? proExpiresAt,
  }) async {
    if (!Platform.isAndroid) return;

    await _plugin.cancel(_idWeekBefore);
    await _plugin.cancel(_idExpiryDay);

    if (!isPro || proExpiresAt == null) return;
    if (!_tzReady) {
      try {
        final name = await FlutterTimezone.getLocalTimezone();
        tz.setLocalLocation(tz.getLocation(name));
        _tzReady = true;
      } catch (_) {
        return;
      }
    }

    final now = DateTime.now();
    final weekBefore = proExpiresAt.subtract(const Duration(days: 7));
    if (weekBefore.isAfter(now)) {
      await _schedule(
        _idWeekBefore,
        weekBefore,
        'Pro renews soon',
        'Your Pro period ends in one week. Open the app to manage or renew.',
      );
    }

    final expiryDayMorning = DateTime(
      proExpiresAt.year,
      proExpiresAt.month,
      proExpiresAt.day,
      9,
    );
    if (expiryDayMorning.isAfter(now)) {
      await _schedule(
        _idExpiryDay,
        expiryDayMorning,
        'Pro subscription',
        'Your Pro period ends today. Renew to keep Pro features.',
      );
    }
  }

  static Future<void> _schedule(
    int id,
    DateTime localWallClock,
    String title,
    String body,
  ) async {
    final tzDate = tz.TZDateTime.from(localWallClock, tz.local);
    try {
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        tzDate,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            'Subscription',
            channelDescription: 'Pro renewal and expiry reminders',
            importance: Importance.defaultImportance,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (e, st) {
      debugPrint('SubscriptionReminderService schedule: $e\n$st');
    }
  }
}
