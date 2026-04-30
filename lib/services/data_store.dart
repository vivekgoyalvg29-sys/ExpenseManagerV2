import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DataStore {
  static const String _smsTransactionsKey = 'sms_transactions';
  static const String _smsTabVisibleKey = 'sms_tab_visible';

  static List<Map<String, dynamic>> categories = [];
  static List<Map<String, dynamic>> accounts = [];
  static List<Map<String, dynamic>> transactions = [];
  static List<Map<String, dynamic>> budgets = [];
  static List<Map<String, dynamic>> smsTransactions = [];

  static int smsTransactionsVersion = 0;
  static bool isSmsTabVisible = false;

  /// Bumped after transactions or book metadata (accounts, categories, budgets) change so shell can remount data tabs.
  static final ValueNotifier<int> transactionMutationGeneration =
      ValueNotifier<int>(0);

  /// Bumped when the active profile / book identity changes (tabs should reload and reset month).
  static final ValueNotifier<int> profileSwitchGeneration = ValueNotifier<int>(0);

  static void bumpTransactionMutationGeneration() {
    transactionMutationGeneration.value++;
  }

  static void bumpProfileSwitchGeneration() {
    profileSwitchGeneration.value++;
  }

  /// Clears in-memory book lists after a profile switch so UI cannot flash wrong profile data.
  static void clearBookDataCache() {
    categories = [];
    accounts = [];
    transactions = [];
    budgets = [];
  }

  /// Normalizes [is_favorite] from SQLite (0/1) or Firestore into a strict [bool].
  ///
  /// Raw rows from [DataService] must not be assigned to [categories]/[accounts] without
  /// [replaceCategories]/[replaceAccounts]: in Dart, `1 == true` is false, so any UI that
  /// checks favorites with `== true` (categories/accounts pages) would show wrong stars.
  static bool coerceFavoriteFlag(dynamic v) {
    if (v is bool) return v;
    if (v == null) return false;
    if (v is num) return v != 0;
    final s = v.toString().trim().toLowerCase();
    return s == '1' || s == 'true' || s == 'yes';
  }

  static Map<String, dynamic> _normalizeCategoryRow(Map<String, dynamic> raw) {
    final m = Map<String, dynamic>.from(raw);
    m['is_favorite'] = coerceFavoriteFlag(m['is_favorite']);
    return m;
  }

  static Map<String, dynamic> _normalizeAccountRow(Map<String, dynamic> raw) {
    final m = Map<String, dynamic>.from(raw);
    m['is_favorite'] = coerceFavoriteFlag(m['is_favorite']);
    return m;
  }

  static void replaceCategories(List<Map<String, dynamic>> raw) {
    categories = raw.map(_normalizeCategoryRow).toList();
  }

  static void replaceAccounts(List<Map<String, dynamic>> raw) {
    accounts = raw.map(_normalizeAccountRow).toList();
  }

  /// When true, the active shared book is view-only (joined user on Free tier); hide mutating UI.
  /// Pro joiners are not view-only; Firestore rules still block non-owners from profile admin.
  static bool viewerReadOnly = false;

  /// When true with [viewerReadOnly], block edits **silently** (no snackbars).
  static bool viewerReadOnlySilent = false;

  static void showViewerReadOnlyNotice(BuildContext context) {
    if (viewerReadOnlySilent) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('You have view-only access to this shared book.'),
      ),
    );
  }

  static Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    isSmsTabVisible = prefs.getBool(_smsTabVisibleKey) ?? false;
    final stored = prefs.getString(_smsTransactionsKey);

    if (stored == null || stored.isEmpty) {
      smsTransactions = [];
      return;
    }

    try {
      final parsed = jsonDecode(stored);
      if (parsed is! List) {
        smsTransactions = [];
        return;
      }

      smsTransactions = parsed
          .whereType<Map>()
          .map((raw) {
            final map = Map<String, dynamic>.from(raw);
            final rawDate = map['date'];
            if (rawDate is String) {
              map['date'] = DateTime.tryParse(rawDate) ?? DateTime.now();
            }
            if (rawDate is int) {
              map['date'] = DateTime.fromMillisecondsSinceEpoch(rawDate);
            }
            map.putIfAbsent('icon', () => Icons.message);
            return map;
          })
          .toList();
      smsTransactionsVersion++;
    } catch (_) {
      smsTransactions = [];
    }
  }

  static void replaceSmsTransactions(List<Map<String, dynamic>> transactions) {
    smsTransactions = List<Map<String, dynamic>>.from(transactions);
    smsTransactionsVersion++;
    _persistSmsTransactions();
  }

  static Future<void> setSmsTabVisibility(bool isVisible) async {
    isSmsTabVisible = isVisible;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_smsTabVisibleKey, isVisible);
  }

  static void clearViewerReadOnlyFlags() {
    viewerReadOnly = false;
    viewerReadOnlySilent = false;
  }

  static Future<void> resetLocalState() async {
    categories = [];
    accounts = [];
    transactions = [];
    budgets = [];
    smsTransactions = [];
    smsTransactionsVersion++;
    await setSmsTabVisibility(false);
    await _persistSmsTransactions();
    bumpTransactionMutationGeneration();
  }

  static Future<void> _persistSmsTransactions() async {
    final prefs = await SharedPreferences.getInstance();

    final encodable = smsTransactions
        .map((tx) {
          final map = Map<String, dynamic>.from(tx);
          final date = map['date'];
          if (date is DateTime) {
            map['date'] = date.toIso8601String();
          }
          map.remove('icon');
          return map;
        })
        .toList();

    await prefs.setString(_smsTransactionsKey, jsonEncode(encodable));
  }
}
