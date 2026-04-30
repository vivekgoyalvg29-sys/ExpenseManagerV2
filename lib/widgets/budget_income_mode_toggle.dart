import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../services/visual_settings.dart';

/// Compact pill switch for [ComparisonMode]: Budget (thumb left) vs Income (thumb right).
/// The active label sits directly beside the thumb (no dead space in the track).
class BudgetIncomeModeToggle extends StatelessWidget {
  final ComparisonMode mode;
  final ValueChanged<ComparisonMode> onChanged;

  /// When set, search + toggle can share one width; must be ≥ [measureTrackWidth].
  final double? trackWidth;

  /// When true, track/labels match a light app bar on scaffold background (not on primary).
  final bool lightAppBarChrome;

  const BudgetIncomeModeToggle({
    super.key,
    required this.mode,
    required this.onChanged,
    this.trackWidth,
    this.lightAppBarChrome = false,
  });

  static const double _thumb = 22;
  static const double _hPad = 3;
  static const double _vPad = 2;
  static const double _labelGap = 2;

  static double _measureLabel(
    TextStyle? style,
    String s, {
    TextScaler textScaler = TextScaler.noScaling,
  }) {
    final tp = TextPainter(
      text: TextSpan(text: s, style: style),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      textScaler: textScaler,
    )..layout();
    return tp.width;
  }

  /// Minimum track width for the current labels (single line, no wrap).
  static double measureTrackWidth(
    TextStyle? labelStyle, {
    TextScaler textScaler = TextScaler.noScaling,
  }) {
    final lw = math.max(
      _measureLabel(labelStyle, 'Budget', textScaler: textScaler),
      _measureLabel(labelStyle, 'Income', textScaler: textScaler),
    );
    return 2 * _hPad + _thumb + _labelGap + lw;
  }

  bool get _isBudget => mode == ComparisonMode.budgetVsExpense;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    const trackHeight = _thumb + _vPad * 2;
    final textStyle = Theme.of(context).textTheme.labelLarge?.copyWith(
          color: lightAppBarChrome
              ? cs.onSurface.withValues(alpha: 0.92)
              : Colors.white.withValues(alpha: 0.92),
          fontWeight: FontWeight.w600,
          fontSize: 12,
        );
    final scaler = MediaQuery.textScalerOf(context);
    final w = math.max(
      trackWidth ?? measureTrackWidth(textStyle, textScaler: scaler),
      measureTrackWidth(textStyle, textScaler: scaler),
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onChanged(
          _isBudget ? ComparisonMode.incomeVsExpense : ComparisonMode.budgetVsExpense,
        ),
        borderRadius: BorderRadius.circular(trackHeight / 2),
        child: Semantics(
          toggled: !_isBudget,
          label: _isBudget ? 'Budget mode' : 'Income mode',
          child: Tooltip(
            message: _isBudget ? 'Budget mode' : 'Income mode',
            child: _BudgetIncomeTogglePainted(
              trackWidth: w,
              thumbDiameter: _thumb,
              horizontalPadding: _hPad,
              verticalPadding: _vPad,
              labelGap: _labelGap,
              isBudget: _isBudget,
              trackHeight: trackHeight,
              textStyle: textStyle,
              lightAppBarChrome: lightAppBarChrome,
            ),
          ),
        ),
      ),
    );
  }
}

class _BudgetIncomeTogglePainted extends StatelessWidget {
  final double trackWidth;
  final double thumbDiameter;
  final double horizontalPadding;
  final double verticalPadding;
  final double labelGap;
  final bool isBudget;
  final double trackHeight;
  final TextStyle? textStyle;
  final bool lightAppBarChrome;

  const _BudgetIncomeTogglePainted({
    required this.trackWidth,
    required this.thumbDiameter,
    required this.horizontalPadding,
    required this.verticalPadding,
    required this.labelGap,
    required this.isBudget,
    required this.trackHeight,
    required this.textStyle,
    required this.lightAppBarChrome,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final trackColor = lightAppBarChrome
        ? cs.surfaceContainerHighest.withValues(alpha: 0.95)
        : Colors.white.withValues(alpha: 0.14);
    final borderColor = lightAppBarChrome
        ? cs.outline.withValues(alpha: 0.35)
        : Colors.white.withValues(alpha: 0.24);
    final thumbColor = lightAppBarChrome ? cs.surface : const Color(0xFFFFF6F2);

    return SizedBox(
      width: trackWidth,
      height: trackHeight,
      child: Stack(
        clipBehavior: Clip.hardEdge,
        alignment: Alignment.center,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: trackColor,
              borderRadius: BorderRadius.circular(trackHeight / 2),
              border: Border.all(color: borderColor, width: 1),
            ),
            child: const SizedBox.expand(),
          ),
          if (isBudget)
            Positioned(
              left: horizontalPadding + thumbDiameter + labelGap,
              right: horizontalPadding,
              top: 0,
              bottom: 0,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Budget',
                  style: textStyle,
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.clip,
                ),
              ),
            )
          else
            Positioned(
              left: horizontalPadding,
              right: horizontalPadding + thumbDiameter + labelGap,
              top: 0,
              bottom: 0,
              child: Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'Income',
                  style: textStyle,
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.clip,
                ),
              ),
            ),
          AnimatedAlign(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeInOutCubic,
            alignment: isBudget ? Alignment.centerLeft : Alignment.centerRight,
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: horizontalPadding,
                vertical: verticalPadding,
              ),
              child: Container(
                width: thumbDiameter,
                height: thumbDiameter,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: thumbColor,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
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
