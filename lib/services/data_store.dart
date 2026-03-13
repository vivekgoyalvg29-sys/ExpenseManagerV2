import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DataStore {
  static const String _smsTransactionsKey = 'sms_transactions';

  static List<Map<String, dynamic>> categories = [];

  static List<Map<String, dynamic>> accounts = [];

  static List<Map<String, dynamic>> transactions = [];

  static List<Map<String, dynamic>> budgets = [];

  static List<Map<String, dynamic>> smsTransactions = [];

  static int smsTransactionsVersion = 0;

  static Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
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
    } catch (_) {
      smsTransactions = [];
    }
  }

  static void replaceSmsTransactions(List<Map<String, dynamic>> transactions) {
    smsTransactions = List<Map<String, dynamic>>.from(transactions);
    smsTransactionsVersion++;
    _persistSmsTransactions();
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
