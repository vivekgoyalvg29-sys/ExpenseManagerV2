import 'package:flutter/material.dart';

import '../utils/indian_number_formatter.dart';
import 'month_section_card.dart';

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
          fontSize: 12,
        );
    final valueStyle = Theme.of(context).textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.bold,
          fontSize: 18,
        );

    return MonthSectionCard(
      currentMonth: currentMonth,
      onPrev: onPrev,
      onNext: onNext,
      child: Row(
        children: [
          Expanded(
            child: _SummaryMetric(
              label: 'Budget',
              value: formatIndianCurrency(budget),
              labelStyle: labelStyle,
              valueStyle: valueStyle?.copyWith(color: Colors.green[700]),
            ),
          ),
          Expanded(
            child: _SummaryMetric(
              label: 'Expense',
              value: formatIndianCurrency(expense),
              labelStyle: labelStyle,
              valueStyle: valueStyle?.copyWith(color: Colors.red[700]),
            ),
          ),
          Expanded(
            child: _SummaryMetric(
              label: 'Remaining',
              value: formatIndianCurrency(remaining),
              labelStyle: labelStyle,
              valueStyle: valueStyle?.copyWith(
                color: remaining >= 0 ? Colors.blue[700] : Colors.red[700],
              ),
              trailing: trailing,
            ),
          ),
        ],
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
    final effectiveValueStyle = valueStyle?.copyWith(fontSize: 16.5);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
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
        const SizedBox(height: 6),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: effectiveValueStyle,
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}
