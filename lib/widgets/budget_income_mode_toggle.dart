import 'package:flutter/material.dart';

import '../services/visual_settings.dart';

/// Compact pill switch for [ComparisonMode]: Budget (thumb left) vs Income (thumb right).
/// Label is shown only in the half not covered by the thumb, centered in that segment.
class BudgetIncomeModeToggle extends StatelessWidget {
  final ComparisonMode mode;
  final ValueChanged<ComparisonMode> onChanged;

  const BudgetIncomeModeToggle({
    super.key,
    required this.mode,
    required this.onChanged,
  });

  bool get _isBudget => mode == ComparisonMode.budgetVsExpense;

  @override
  Widget build(BuildContext context) {
    const thumb = 22.0;
    const vPad = 2.0;
    const hPad = 3.0;
    const trackHeight = thumb + vPad * 2;

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
              thumbDiameter: thumb,
              horizontalPadding: hPad,
              verticalPadding: vPad,
              isBudget: _isBudget,
              trackHeight: trackHeight,
              textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: Colors.white.withValues(alpha: 0.92),
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BudgetIncomeTogglePainted extends StatelessWidget {
  final double thumbDiameter;
  final double horizontalPadding;
  final double verticalPadding;
  final bool isBudget;
  final double trackHeight;
  final TextStyle? textStyle;

  const _BudgetIncomeTogglePainted({
    required this.thumbDiameter,
    required this.horizontalPadding,
    required this.verticalPadding,
    required this.isBudget,
    required this.trackHeight,
    required this.textStyle,
  });

  static double _labelSlotWidth(TextStyle? style) {
    double w(String s) {
      final tp = TextPainter(
        text: TextSpan(text: s, style: style),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout();
      return tp.width;
    }

    return (w('Budget') > w('Income') ? w('Budget') : w('Income')) + 8;
  }

  @override
  Widget build(BuildContext context) {
    final labelSlot = _labelSlotWidth(textStyle);
    // Labels live in a 50/50 [Row]; each half must fit the longer word and the
    // thumb + padding when the thumb sits in that half.
    final halfMin = labelSlot > thumbDiameter + 2 * horizontalPadding
        ? labelSlot
        : thumbDiameter + 2 * horizontalPadding;
    final trackWidth = 2 * halfMin;

    final trackColor = Colors.white.withValues(alpha: 0.26);
    final borderColor = Colors.white.withValues(alpha: 0.38);
    const thumbColor = Color(0xFFFFF6F2);

    return SizedBox(
      width: trackWidth,
      height: trackHeight,
      child: Stack(
        clipBehavior: Clip.none,
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
          Positioned.fill(
            child: Row(
              children: [
                Expanded(
                  child: Center(
                    child: isBudget
                        ? const SizedBox.shrink()
                        : Text(
                            'Income',
                            style: textStyle,
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            softWrap: false,
                          ),
                  ),
                ),
                Expanded(
                  child: Center(
                    child: isBudget
                        ? Text(
                            'Budget',
                            style: textStyle,
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            softWrap: false,
                          )
                        : const SizedBox.shrink(),
                  ),
                ),
              ],
            ),
          ),
          AnimatedAlign(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeInOutCubic,
            alignment: isBudget ? Alignment.centerLeft : Alignment.centerRight,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: verticalPadding),
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
