import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';

import '../config/app_config.dart';
import 'data_service.dart';
import 'data_store.dart';
import 'entitlement_service.dart';
import 'profile_service.dart';
import 'recurring_schedule.dart';
import 'widget_sync_service.dart';

/// One proposed posting from a recurring master (preview before insert).
class PendingRecurringOccurrence {
  PendingRecurringOccurrence({
    required this.masterId,
    required this.scheduledDate,
    required this.title,
    required this.amount,
    required this.type,
    required this.account,
    required this.comment,
    required this.scheduleSummary,
  });

  final int masterId;
  final DateTime scheduledDate;
  final String title;
  final double amount;
  final String type;
  final String account;
  final String comment;
  final String scheduleSummary;

  String get scheduledDateKey =>
      '${scheduledDate.year.toString().padLeft(4, '0')}-'
      '${scheduledDate.month.toString().padLeft(2, '0')}-'
      '${scheduledDate.day.toString().padLeft(2, '0')}';
}

/// `Schedule / Category / amount / From-account / Comment- text`
String formatRuleSummaryLine(PendingRecurringOccurrence o) =>
    formatRuleSummaryParts(
      scheduleSummary: o.scheduleSummary,
      category: o.title,
      amount: o.amount,
      account: o.account,
      comment: o.comment,
    );

String formatRuleSummaryParts({
  required String scheduleSummary,
  required String category,
  required double amount,
  required String account,
  required String comment,
}) {
  final c = comment.trim().isEmpty ? '—' : comment.trim();
  return '$scheduleSummary / $category / ${amount.toStringAsFixed(2)} / From-$account / Comment- $c';
}

String formatRuleSummaryFromMasterRow(Map<String, dynamic> row) {
  final kind = (row['schedule_kind'] ?? '').toString();
  final sched = parseScheduleJson((row['schedule_json'] ?? '{}').toString());
  final sch = describeSchedule(kind, sched);
  final amt = (row['amount'] as num?)?.toDouble() ?? 0;
  return formatRuleSummaryParts(
    scheduleSummary: sch,
    category: (row['title'] ?? '').toString(),
    amount: amt,
    account: (row['account'] ?? '').toString(),
    comment: (row['comment'] ?? '').toString(),
  );
}

Map<String, dynamic> parseScheduleJson(String raw) {
  if (raw.trim().isEmpty) return {};
  try {
    final d = jsonDecode(raw);
    if (d is Map<String, dynamic>) return d;
    if (d is Map) return Map<String, dynamic>.from(d);
  } catch (_) {}
  return {};
}

String scheduleDateKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

/// Free joiners are view-only. Shared book: owner always; non-owners only if Pro
/// (matches Firestore write rules for financial data).
Future<bool> canUserRunRecurringEngine() async {
  if (DataStore.viewerReadOnly) return false;
  if (!AppConfig.firebaseCloudEnabled) return true;
  final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
  if (uid.isEmpty) return true;
  final profileId = await ProfileService().getActiveProfileId();
  if (profileId == null) return false;
  if (ProfileService.isLocalProfileId(profileId)) return true;
  final role = await ProfileService().getRoleInProfile(profileId);
  if (role == 'owner') return true;
  return await EntitlementService.isPro;
}

/// Returns due occurrences through today that still need user action.
Future<List<PendingRecurringOccurrence>> computePendingOccurrences() async {
  final masters = await DataService.getRecurringMasters();
  final resolved = await DataService.getRecurringResolvedMap();
  final today = recurringDateOnly(DateTime.now());
  final todayKey = scheduleDateKey(today);
  final out = <PendingRecurringOccurrence>[];

  for (final m in masters) {
    final id = (m['id'] as num?)?.toInt();
    if (id == null) continue;
    final kind = (m['schedule_kind'] ?? '').toString();
    final rawJson = (m['schedule_json'] ?? '{}').toString();
    final sched = parseScheduleJson(rawJson);
    final createdMs = (m['created_at_ms'] as num?)?.toInt() ?? 0;
    final createdAt = DateTime.fromMillisecondsSinceEpoch(
      createdMs > 0 ? createdMs : DateTime.now().millisecondsSinceEpoch,
    );

    for (final d in occurrencesForMaster(
      kind: kind,
      scheduleJson: sched,
      createdAt: createdAt,
      until: today,
    )) {
      final key = '$id|${scheduleDateKey(d)}';
      final row = resolved[key];
      if (row == null) {
        out.add(_pendingFromMaster(m, id, d, kind, sched));
        continue;
      }
      if (row.status == 'posted' || row.status == 'skipped') continue;
      if (row.status == 'deferred') {
        final du = row.deferUntilIso;
        if (du != null && du.isNotEmpty && todayKey.compareTo(du) < 0) {
          continue;
        }
        out.add(_pendingFromMaster(m, id, d, kind, sched));
      }
    }
  }

  out.sort((a, b) {
    final c = a.scheduledDate.compareTo(b.scheduledDate);
    if (c != 0) return c;
    return a.masterId.compareTo(b.masterId);
  });
  return out;
}

PendingRecurringOccurrence _pendingFromMaster(
  Map<String, dynamic> m,
  int id,
  DateTime d,
  String kind,
  Map<String, dynamic> sched,
) =>
    PendingRecurringOccurrence(
      masterId: id,
      scheduledDate: d,
      title: (m['title'] ?? '').toString(),
      amount: (m['amount'] as num?)?.toDouble() ?? 0,
      type: (m['type'] ?? 'expense').toString(),
      account: (m['account'] ?? '').toString(),
      comment: (m['comment'] ?? '').toString(),
      scheduleSummary: describeSchedule(kind, sched),
    );

Future<void> runRecurringOccurrence(PendingRecurringOccurrence o) async {
  await DataService.insertTransaction(
    o.title,
    o.amount,
    o.scheduledDate,
    o.type,
    o.account,
    o.comment,
  );
  await DataService.putRecurringResolved(
    masterId: o.masterId,
    scheduledDateIso: o.scheduledDateKey,
    status: 'posted',
    deferUntilIso: null,
  );
  try {
    await WidgetSyncService.syncFromStoredConfiguration();
  } catch (_) {}
}

Future<void> skipRecurringOccurrence(PendingRecurringOccurrence o) async {
  await DataService.putRecurringResolved(
    masterId: o.masterId,
    scheduledDateIso: o.scheduledDateKey,
    status: 'skipped',
    deferUntilIso: null,
  );
  try {
    await WidgetSyncService.syncFromStoredConfiguration();
  } catch (_) {}
}

Future<void> deferRecurringOccurrence(PendingRecurringOccurrence o) async {
  final tomorrow = recurringDateOnly(DateTime.now()).add(const Duration(days: 1));
  await DataService.putRecurringResolved(
    masterId: o.masterId,
    scheduledDateIso: o.scheduledDateKey,
    status: 'deferred',
    deferUntilIso: scheduleDateKey(tomorrow),
  );
  try {
    await WidgetSyncService.syncFromStoredConfiguration();
  } catch (_) {}
}

Future<void> skipAllRecurringOccurrences(List<PendingRecurringOccurrence> items) async {
  for (final o in items) {
    await skipRecurringOccurrence(o);
  }
}
