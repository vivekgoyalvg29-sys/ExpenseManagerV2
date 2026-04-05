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
  final String leftLabel;
  final String middleLabel;
  final String rightLabel;
  final String? aggregationSubtitle;

  const MonthSummary({
    super.key,
    required this.currentMonth,
    required this.onPrev,
    required this.onNext,
    required this.budget,
    required this.expense,
    this.trailing,
    this.monthTrailing,
    this.leftLabel = 'Budget',
    this.middleLabel = 'Expense',
    this.rightLabel = 'Remaining',
    this.aggregationSubtitle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final remaining = budget - expense;

    final heroLabelStyle = theme.textTheme.labelMedium?.copyWith(
      fontWeight: FontWeight.w500,
      color: cs.onSurfaceVariant.withValues(alpha: 0.9),
      letterSpacing: 0.2,
    );

    final heroValueColor =
        remaining >= 0 ? cs.primary : cs.error;

    final heroValueStyle = theme.textTheme.headlineSmall?.copyWith(
          fontWeight: FontWeight.w600,
          letterSpacing: -0.6,
          color: heroValueColor,
          height: 1.05,
        ) ??
        TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.6,
          color: heroValueColor,
          height: 1.05,
        );

    final secondaryStyle = theme.textTheme.bodySmall?.copyWith(
      fontWeight: FontWeight.w500,
      color: cs.onSurfaceVariant.withValues(alpha: 0.85),
      height: 1.25,
    );

    final secondaryValueStyle = secondaryStyle?.copyWith(
      fontWeight: FontWeight.w600,
      color: cs.onSurface.withValues(alpha: 0.92),
    );

    return MonthSectionCard(
      currentMonth: currentMonth,
      onPrev: onPrev,
      onNext: onNext,
      monthTrailing: monthTrailing,
      aggregationSubtitle: aggregationSubtitle,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 0, 4, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        rightLabel,
                        style: heroLabelStyle,
                      ),
                      const SizedBox(height: 2),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          formatIndianCurrency(remaining),
                          style: heroValueStyle,
                        ),
                      ),
                    ],
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _SecondaryPair(
                    label: leftLabel,
                    value: formatIndianCurrency(budget),
                    labelStyle: secondaryStyle,
                    valueStyle: secondaryValueStyle,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _SecondaryPair(
                    label: middleLabel,
                    value: formatIndianCurrency(expense),
                    labelStyle: secondaryStyle,
                    valueStyle: secondaryValueStyle,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _EmbeddedMonthProgress(
              expense: expense,
              reference: budget,
            ),
          ],
        ),
      ),
    );
  }
}

class _SecondaryPair extends StatelessWidget {
  final String label;
  final String value;
  final TextStyle? labelStyle;
  final TextStyle? valueStyle;

  const _SecondaryPair({
    required this.label,
    required this.value,
    this.labelStyle,
    this.valueStyle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: labelStyle,
        ),
        const SizedBox(height: 2),
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

class _EmbeddedMonthProgress extends StatefulWidget {
  final double expense;
  final double reference;

  const _EmbeddedMonthProgress({
    required this.expense,
    required this.reference,
  });

  @override
  State<_EmbeddedMonthProgress> createState() => _EmbeddedMonthProgressState();
}

class _EmbeddedMonthProgressState extends State<_EmbeddedMonthProgress>
    with SingleTickerProviderStateMixin {
  static const Duration _edgePulseDuration = Duration(milliseconds: 2400);

  late final AnimationController _edgeController;

  @override
  void initState() {
    super.initState();
    _edgeController = AnimationController(vsync: this, duration: _edgePulseDuration);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncEdgeAnimation();
  }

  @override
  void didUpdateWidget(covariant _EmbeddedMonthProgress oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncEdgeAnimation();
  }

  void _syncEdgeAnimation() {
    if (!mounted) return;
    final hasFill = widget.reference > 0 && widget.expense > 0;
    if (MediaQuery.of(context).disableAnimations || !hasFill) {
      _edgeController.stop();
    } else if (!_edgeController.isAnimating) {
      _edgeController.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _edgeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final hasReference = widget.reference > 0;
    final ratio = hasReference && widget.expense > 0 ? (widget.expense / widget.reference) : 0.0;
    final clamped = ratio.clamp(0.0, 2.0).toDouble();

    Color fillColor(double r) {
      if (!hasReference) return cs.outline.withValues(alpha: 0.35);
      if (r <= 0.5) return cs.primary;
      if (r <= 1.0) return cs.tertiary;
      return cs.error;
    }

    final percentage =
        hasReference && widget.expense > 0 ? (ratio * 100).clamp(0, 999).round() : 0;

    final trackColor = cs.outlineVariant.withValues(
      alpha: theme.brightness == Brightness.dark ? 0.45 : 0.55,
    );
    final disableMotion = MediaQuery.of(context).disableAnimations;

    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final maxW = constraints.maxWidth;
                var fillW = maxW * clamped.clamp(0.0, 1.0);
                if (fillW > 0 && fillW < 1.0) {
                  fillW = 1.0;
                }
                final showFill = hasReference && widget.expense > 0 && fillW > 0;

                return SizedBox(
                  height: 6,
                  width: maxW,
                  child: Stack(
                    clipBehavior: Clip.hardEdge,
                    children: [
                      Positioned.fill(
                        child: ColoredBox(color: trackColor),
                      ),
                      if (showFill)
                        Positioned(
                          left: 0,
                          top: 0,
                          bottom: 0,
                          width: fillW,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              ColoredBox(color: fillColor(clamped)),
                              Positioned(
                                right: 0,
                                top: 0,
                                bottom: 0,
                                width: 3,
                                child: AnimatedBuilder(
                                  animation: _edgeController,
                                  builder: (context, _) {
                                    final t = Curves.easeInOut.transform(_edgeController.value);
                                    final highlight = disableMotion ? 0.22 : (0.12 + 0.26 * t);
                                    return DecoratedBox(
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.centerLeft,
                                          end: Alignment.centerRight,
                                          colors: [
                                            Colors.white.withValues(alpha: 0),
                                            Colors.white.withValues(alpha: highlight),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
        const SizedBox(width: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: cs.outline.withValues(alpha: 0.22),
            ),
          ),
          child: Text(
            '$percentage%',
            style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: cs.onSurfaceVariant,
                  letterSpacing: 0.2,
                ) ??
                TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurfaceVariant,
                ),
          ),
        ),
      ],
    );
  }
}
