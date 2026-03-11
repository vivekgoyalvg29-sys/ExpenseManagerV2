import 'package:flutter/material.dart';

class MessageExpenseService {
  static final RegExp _amountRegex = RegExp(r'(?:INR|Rs\.?|₹)\s*([0-9,]+(?:\.[0-9]{1,2})?)');
  static final RegExp _merchantRegex = RegExp(r'at\s+([A-Za-z0-9\- _&.]+?)(?:\s+on|\.|$)');

  static Future<List<Map<String, dynamic>>> fetchExpensesFromMessages({
    required DateTime start,
    required DateTime end,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 600));

    final sampleMessages = <Map<String, dynamic>>[
      {
        'date': DateTime(2026, 1, 4),
        'text': 'INR 245.00 spent on your HDFC card at Zomato on 04-Jan-26.',
      },
      {
        'date': DateTime(2026, 1, 7),
        'text': 'Rs.1,299 debited via UPI at Amazon on 07-Jan-26.',
      },
      {
        'date': DateTime(2026, 2, 3),
        'text': '₹499 spent from A/C XXXX2189 at Swiggy on 03-Feb-26.',
      },
      {
        'date': DateTime(2026, 2, 18),
        'text': 'INR 80.50 spent on your SBI card at Metro on 18-Feb-26.',
      },
      {
        'date': DateTime(2026, 3, 9),
        'text': 'Rs 2,050 debited from account via IMPS at Blinkit on 09-Mar-26.',
      },
    ];

    final transactionsInRange = sampleMessages.where((message) {
      final date = message['date'] as DateTime;
      return !date.isBefore(start) && !date.isAfter(end);
    });

    return transactionsInRange.map((message) {
      final sms = message['text'] as String;
      final amount = _extractAmount(sms);
      final merchant = _extractMerchant(sms);

      return {
        'title': merchant,
        'amount': amount,
        'date': message['date'],
        'type': 'expense',
        'icon': Icons.message,
      };
    }).toList();
  }

  static double _extractAmount(String message) {
    final match = _amountRegex.firstMatch(message);
    if (match == null) return 0;

    return double.tryParse(match.group(1)!.replaceAll(',', '')) ?? 0;
  }

  static String _extractMerchant(String message) {
    final match = _merchantRegex.firstMatch(message);
    if (match == null) return 'Bank Message Expense';

    return match.group(1)!.trim();
  }
}
