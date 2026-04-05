import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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

/// Theme-aware accent for a bar (stable per label + bucket).
Color aggregationBarAccentColor(BuildContext context, AggregationBarData item) {
  final cs = Theme.of(context).colorScheme;
  final colors = <Color>[
    cs.primary,
    cs.tertiary,
    cs.secondary,
    Color.lerp(cs.primary, cs.tertiary, 0.45) ?? cs.primary,
    Color.lerp(cs.secondary, cs.primary, 0.4) ?? cs.secondary,
    Color.lerp(cs.tertiary, cs.secondary, 0.35) ?? cs.tertiary,
  ];
  final k = (item.label.hashCode ^ (item.bucket * 997)).abs() % colors.length;
  return colors[k];
}

class _HorizontalGridPainter extends CustomPainter {
  _HorizontalGridPainter({required this.color, this.segments = 4});

  final Color color;
  /// Draws horizontal rules at 1/segments, 2/segments, … (not at 0 or full height).
  final int segments;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1
      ..isAntiAlias = true;
    for (var i = 1; i < segments; i++) {
      final y = size.height * i / segments;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _HorizontalGridPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.segments != segments;
  }
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

  static BoxDecoration _shellDecoration(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return BoxDecoration(
      color: cs.surface.withValues(
        alpha: theme.brightness == Brightness.dark ? 0.92 : 0.98,
      ),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
        color: cs.outline.withValues(
          alpha: theme.brightness == Brightness.dark ? 0.28 : 0.22,
        ),
        width: 0.8,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(
            alpha: theme.brightness == Brightness.dark ? 0.18 : 0.04,
          ),
          blurRadius: 12,
          spreadRadius: -3,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    if (data.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
        decoration: _shellDecoration(context),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.bar_chart_rounded,
              size: 36,
              color: cs.onSurfaceVariant.withValues(alpha: 0.45),
            ),
            const SizedBox(height: 12),
            Text(
              emptyMessage,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.w500,
                height: 1.35,
              ),
            ),
          ],
        ),
      );
    }

    final maxValue = data.fold<double>(0, (max, item) => item.value > max ? item.value : max);
    final normalizedMax = maxValue <= 0 ? 1.0 : maxValue;

    final gridColor = cs.outlineVariant.withValues(
      alpha: theme.brightness == Brightness.dark ? 0.38 : 0.32,
    );

    return Container(
      decoration: _shellDecoration(context),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (trailing != null)
            Padding(
              padding: const EdgeInsets.only(right: 2, bottom: 8),
              child: Align(
                alignment: Alignment.centerRight,
                child: trailing,
              ),
            ),
          DecoratedBox(
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest.withValues(
                alpha: theme.brightness == Brightness.dark ? 0.35 : 0.5,
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: cs.outline.withValues(alpha: 0.12),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 12, 8, 10),
              child: SizedBox(
                height: chartHeight,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _HorizontalGridPainter(
                          color: gridColor,
                          segments: 5,
                        ),
                      ),
                    ),
                    Row(
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
                                accent: aggregationBarAccentColor(context, item),
                                selected: selectedBucket != null && selectedBucket == item.bucket,
                                onTap: onBarTap == null
                                    ? null
                                    : () {
                                        HapticFeedback.selectionClick();
                                        onBarTap!(item);
                                      },
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
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
  final Color accent;
  final VoidCallback? onTap;
  final bool selected;

  const _ChartBar({
    required this.value,
    required this.maxValue,
    required this.label,
    required this.labelBuilder,
    required this.item,
    required this.accent,
    required this.onTap,
    required this.selected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final ratio = maxValue == 0 ? 0.0 : (value / maxValue).clamp(0.0, 1.0).toDouble();
    final selectedBorder = Color.lerp(accent, Colors.black, 0.22) ?? accent;
    final selectedEnd = Color.lerp(accent, Colors.black, 0.32) ?? accent;
    final defaultStart = Color.lerp(accent, Colors.white, 0.14) ?? accent;
    final defaultEnd = Color.lerp(accent, Colors.black, 0.18) ?? accent;
    final trackColor = cs.outlineVariant.withValues(
      alpha: theme.brightness == Brightness.dark ? 0.42 : 0.38,
    );

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

              return Stack(
                alignment: Alignment.bottomCenter,
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    left: 2,
                    right: 2,
                    bottom: 0,
                    top: 0,
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: Container(
                        width: 22,
                        constraints: const BoxConstraints(maxWidth: 26),
                        height: availableHeight,
                        decoration: BoxDecoration(
                          color: trackColor,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(999),
                      onTap: onTap,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        curve: Curves.easeOutCubic,
                        height: height,
                        constraints: const BoxConstraints(minWidth: 18, maxWidth: 26),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(999),
                          border: selected ? Border.all(color: selectedBorder, width: 1.4) : null,
                          boxShadow: [
                            BoxShadow(
                              color: (selected ? selectedEnd : defaultEnd).withValues(alpha: 0.38),
                              blurRadius: selected ? 10 : 6,
                              spreadRadius: -1,
                              offset: const Offset(0, 4),
                            ),
                          ],
                          gradient: selected
                              ? LinearGradient(
                                  colors: [selectedBorder, selectedEnd],
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                )
                              : LinearGradient(
                                  colors: [defaultStart, defaultEnd],
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
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                shadows: [
                                  Shadow(
                                    color: Colors.black.withValues(alpha: 0.35),
                                    blurRadius: 2,
                                    offset: const Offset(0, 0.5),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        if (labelBuilder != null)
          labelBuilder!(context, item)
        else
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: theme.textTheme.labelMedium?.copyWith(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: cs.onSurfaceVariant.withValues(alpha: 0.92),
            ),
          ),
      ],
    );
  }
}
