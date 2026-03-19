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
    final labelStyle = Theme.of(context).textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w700,
          color: const Color(0xFF52606D),
        );
    final valueStyle = Theme.of(context).textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.bold,
          fontSize: 19,
        );

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
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _SummaryMetric(
                    label: 'Budget',
                    value: '₹${budget.toStringAsFixed(0)}',
                    labelStyle: labelStyle,
                    valueStyle: valueStyle?.copyWith(color: Colors.green[700]),
                  ),
                ),
                Expanded(
                  child: _SummaryMetric(
                    label: 'Expense',
                    value: '₹${expense.toStringAsFixed(0)}',
                    labelStyle: labelStyle,
                    valueStyle: valueStyle?.copyWith(color: Colors.red[700]),
                  ),
                ),
                Expanded(
                  child: _SummaryMetric(
                    label: 'Remaining',
                    value: '₹${remaining.toStringAsFixed(0)}',
                    labelStyle: labelStyle,
                    valueStyle: valueStyle?.copyWith(
                      color: remaining >= 0 ? Colors.blue[700] : Colors.red[700],
                    ),
                    trailing: trailing,
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

class _SummaryMetric extends StatelessWidget {
  final String label;
  final String value;
  final TextStyle? labelStyle;
  final TextStyle? valueStyle;
  final Widget? trailing;

  const _SummaryMetric({
    required this.label,
    required this.value,
    this.labelStyle,
    this.valueStyle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: labelStyle,
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 2),
              trailing!,
            ],
          ],
        ),
        const SizedBox(height: 8),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: valueStyle,
        ),
      ],
    );
  }
}
