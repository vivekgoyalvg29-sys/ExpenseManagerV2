import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_sms_inbox/flutter_sms_inbox.dart';
import 'package:permission_handler/permission_handler.dart';

class MessageExpenseService {
  static final RegExp _amountRegex = RegExp(
    r'(?:INR|Rs\.?|₹)\s*([0-9,]+(?:\.[0-9]{1,2})?)',
    caseSensitive: false,
  );
  static final RegExp _fallbackAmountRegex = RegExp(r'([0-9,]+(?:\.[0-9]{1,2})?)');
  static final RegExp _merchantRegex = RegExp(
    r'at\s+([A-Za-z0-9\- _&.]+?)(?:\s+on|\.|$)',
    caseSensitive: false,
  );

  static Future<List<Map<String, dynamic>>> fetchExpensesFromMessages({
    required DateTime start,
    required DateTime end,
  }) async {
    if (!Platform.isAndroid) {
      throw const MessageExpenseException(
        'Reading SMS is only supported on Android devices.',
      );
    }

    final permission = await Permission.sms.request();
    if (!permission.isGranted) {
      throw const MessageExpenseException(
        'SMS permission was denied. Please allow SMS access to load expenses.',
      );
    }

    final query = SmsQuery();
    final messages = await query.querySms(
      kinds: <SmsQueryKind>[SmsQueryKind.inbox],
    );

    final expenses = <Map<String, dynamic>>[];
    for (final message in messages) {
      final body = message.body;
      final rawDate = message.date;

      if (body == null || rawDate == null) {
        continue;
      }

      if (!body.toLowerCase().contains('debited')) {
        continue;
      }

      final date = _normalizeMessageDate(rawDate);
      if (date == null) {
        continue;
      }
      if (date.isBefore(start) || date.isAfter(end)) {
        continue;
      }

      final amount = _extractAmount(body);
      if (amount <= 0) {
        continue;
      }

      expenses.add({
        'title': _extractMerchant(body),
        'amount': amount,
        'date': date,
        'type': 'expense',
        'icon': Icons.message,
      });
    }

    expenses.sort((a, b) => (b['date'] as DateTime).compareTo(a['date'] as DateTime));

    return expenses;
  }

  static double _extractAmount(String message) {
    final amountMatch = _amountRegex.firstMatch(message);
    if (amountMatch != null) {
      return double.tryParse(amountMatch.group(1)!.replaceAll(',', '')) ?? 0;
    }

    final debitedIndex = message.toLowerCase().indexOf('debited');
    if (debitedIndex < 0) return 0;

    final leadingText = message.substring(0, debitedIndex);
    final fallbackMatches = _fallbackAmountRegex.allMatches(leadingText);
    if (fallbackMatches.isEmpty) return 0;

    final lastMatch = fallbackMatches.last;
    return double.tryParse(lastMatch.group(1)!.replaceAll(',', '')) ?? 0;
  }

  static String _extractMerchant(String message) {
    final match = _merchantRegex.firstMatch(message);
    if (match == null) return 'Bank Message Expense';

    return match.group(1)!.trim();
  }

  static DateTime? _normalizeMessageDate(Object rawDate) {
    if (rawDate is DateTime) return rawDate;
    if (rawDate is int) {
      return DateTime.fromMillisecondsSinceEpoch(rawDate);
    }

    return null;
  }
}

class MessageExpenseException implements Exception {
  final String message;

  const MessageExpenseException(this.message);

  @override
  String toString() => message;
}
