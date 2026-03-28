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
  final Widget? monthTrailing;

  const MonthSummary({
    super.key,
    required this.currentMonth,
    required this.onPrev,
    required this.onNext,
    required this.budget,
    required this.expense,
    this.trailing,
    this.monthTrailing,
  });

  @override
  Widget build(BuildContext context) {
    final remaining = budget - expense;

    final labelStyle = Theme.of(context).textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w700,
          color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.75),
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
      monthTrailing: monthTrailing,
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
          Container(width: 1, height: 36, color: Theme.of(context).dividerColor),
          Expanded(
            child: _SummaryMetric(
              label: 'Expense',
              value: formatIndianCurrency(expense),
              labelStyle: labelStyle,
              valueStyle: valueStyle?.copyWith(color: Colors.red[700]),
            ),
          ),
          Container(width: 1, height: 36, color: Theme.of(context).dividerColor),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Label row
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
                textAlign: TextAlign.center,
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 2),
              trailing!,
            ],
          ],
        ),
        const SizedBox(height: 4),
        // Value — same row level as all others
        LayoutBuilder(
          builder: (context, constraints) {
            return SizedBox(
              width: constraints.maxWidth,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.center,
                child: Text(
                  value,
                  maxLines: 1,
                  style: valueStyle?.copyWith(fontSize: 16.5),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
