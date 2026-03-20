import 'package:flutter/material.dart';

import '../utils/indian_number_formatter.dart';
import 'month_section_card.dart';

class MonthSummary extends StatelessWidget {
  final DateTime currentMonth;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final double budget;
  final double expense;
  final Widget? action;

  const MonthSummary({
    super.key,
    required this.currentMonth,
    required this.onPrev,
    required this.onNext,
    required this.budget,
    required this.expense,
    this.action,
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

    return MonthSectionCard(
      currentMonth: currentMonth,
      onPrev: onPrev,
      onNext: onNext,
      action: action,
      child: Row(
        children: [
          Expanded(
            child: SummaryMetric(
              label: 'Budget',
              value: formatIndianCurrency(budget),
              labelStyle: labelStyle,
              valueStyle: valueStyle?.copyWith(color: Colors.green[700]),
            ),
          ),
          Expanded(
            child: SummaryMetric(
              label: 'Expense',
              value: formatIndianCurrency(expense),
              labelStyle: labelStyle,
              valueStyle: valueStyle?.copyWith(color: Colors.red[700]),
            ),
          ),
          Expanded(
            child: SummaryMetric(
              label: 'Remaining',
              value: formatIndianCurrency(remaining),
              labelStyle: labelStyle,
              valueStyle: valueStyle?.copyWith(
                color: remaining >= 0 ? Colors.blue[700] : Colors.red[700],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class SummaryMetric extends StatelessWidget {
  final String label;
  final String value;
  final TextStyle? labelStyle;
  final TextStyle? valueStyle;
  final CrossAxisAlignment crossAxisAlignment;
  final TextAlign textAlign;

  const SummaryMetric({
    super.key,
    required this.label,
    required this.value,
    this.labelStyle,
    this.valueStyle,
    this.crossAxisAlignment = CrossAxisAlignment.center,
    this.textAlign = TextAlign.center,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveValueStyle = valueStyle?.copyWith(fontSize: 17);

    return Column(
      crossAxisAlignment: crossAxisAlignment,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: labelStyle,
          textAlign: textAlign,
        ),
        const SizedBox(height: 8),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: effectiveValueStyle,
          textAlign: textAlign,
        ),
      ],
    );
  }
}
