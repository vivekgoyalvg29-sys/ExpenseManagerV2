import 'package:flutter/material.dart';

import 'month_navigator_row.dart';
import 'section_tile.dart';

class MonthSummary extends StatelessWidget {
  final DateTime currentMonth;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final double budget;
  final double expense;
  final Widget? trailing;

  const MonthSummary({
    super.key,
    required this.currentMonth,
    required this.onPrev,
    required this.onNext,
    required this.budget,
    required this.expense,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final remaining = budget - expense;

    return SectionTile(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          children: [
            MonthNavigatorRow(
              currentMonth: currentMonth,
              onPrev: onPrev,
              onNext: onNext,
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                const Text('Budget', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                const Text('Expense', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Remaining', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    if (trailing != null) ...[
                      const SizedBox(width: 2),
                      trailing!,
                    ],
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Text(
                  '₹${budget.toStringAsFixed(0)}',
                  style: const TextStyle(
                    color: Colors.green,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '₹${expense.toStringAsFixed(0)}',
                  style: const TextStyle(
                    color: Colors.red,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '₹${remaining.toStringAsFixed(0)}',
                  style: TextStyle(
                    color: remaining >= 0 ? Colors.blue : Colors.red,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
