import 'package:flutter/material.dart';

import '../utils/indian_number_formatter.dart';

class AggregationBarData {
  final String label;
  final double value;
  final int bucket;

  const AggregationBarData({
    required this.label,
    required this.value,
    required this.bucket,
  });
}

class AggregationBarChart extends StatelessWidget {
  final List<AggregationBarData> data;
  final String emptyMessage;
  final Widget Function(BuildContext context, AggregationBarData item)? labelBuilder;
  final double chartHeight;
  final ValueChanged<AggregationBarData>? onBarTap;
  final int? selectedBucket;
  final Widget? trailing;

  const AggregationBarChart({
    super.key,
    required this.data,
    required this.emptyMessage,
    this.labelBuilder,
    this.chartHeight = 210,
    this.onBarTap,
    this.selectedBucket,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (data.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 24),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: theme.dividerColor),
        ),
        child: Text(
          emptyMessage,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w500,
          ),
        ),
      );
    }

    final maxValue = data.fold<double>(0, (max, item) => item.value > max ? item.value : max);
    final normalizedMax = maxValue <= 0 ? 1.0 : maxValue;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.dividerColor),
      ),
      padding: const EdgeInsets.fromLTRB(10, 4, 10, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (trailing != null)
            Padding(
              padding: const EdgeInsets.only(top: 6, right: 2, bottom: 2),
              child: Align(
                alignment: Alignment.centerRight,
                child: trailing,
              ),
            ),
          SizedBox(
            height: chartHeight,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final item in data)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: _ChartBar(
                        value: item.value,
                        maxValue: normalizedMax,
                        label: item.label,
                        labelBuilder: labelBuilder,
                        item: item,
                        selected: selectedBucket != null && selectedBucket == item.bucket,
                        onTap: onBarTap == null ? null : () => onBarTap!(item),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChartBar extends StatelessWidget {
  final double value;
  final double maxValue;
  final String label;
  final Widget Function(BuildContext context, AggregationBarData item)? labelBuilder;
  final AggregationBarData item;
  final VoidCallback? onTap;
  final bool selected;

  const _ChartBar({
    required this.value,
    required this.maxValue,
    required this.label,
    required this.labelBuilder,
    required this.item,
    required this.onTap,
    required this.selected,
  });

  @override
  Widget build(BuildContext context) {
    final ratio = maxValue == 0 ? 0.0 : (value / maxValue).clamp(0.0, 1.0).toDouble();

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final availableHeight = constraints.maxHeight;
              final minBarHeight = availableHeight * 0.18;
              final maxBarHeight = availableHeight;
              final height = minBarHeight + ((maxBarHeight - minBarHeight) * ratio);

              return Align(
                alignment: Alignment.bottomCenter,
                child: InkWell(
                  borderRadius: BorderRadius.circular(999),
                  onTap: onTap,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 140),
                    height: height,
                    constraints: const BoxConstraints(minWidth: 18, maxWidth: 26),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      border: selected ? Border.all(color: const Color(0xFF312E81), width: 1.2) : null,
                      gradient: selected
                          ? const LinearGradient(
                              colors: [Color(0xFF312E81), Color(0xFF6D28D9)],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            )
                          : const LinearGradient(
                              colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                    ),
                    alignment: Alignment.center,
                    child: RotatedBox(
                      quarterTurns: 3,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Text(
                          formatIndianCurrency(value),
                          maxLines: 1,
                          overflow: TextOverflow.fade,
                          softWrap: false,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 6),
        if (labelBuilder != null)
          labelBuilder!(context, item)
        else
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
      ],
    );
  }
}
