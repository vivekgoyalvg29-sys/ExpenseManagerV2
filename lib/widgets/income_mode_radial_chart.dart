import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'income_expense_pie_chart.dart';

/// Three concentric rings vs income: outer = income (full), middle = budget share,
/// inner = expense share. Tap rings to change selection.
class IncomeModeRadialChart extends StatelessWidget {
  final double incomeTotal;
  final double budgetTotal;
  final double expenseTotal;
  final IncomeExpensePieSlice? selectedSlice;
  final ValueChanged<IncomeExpensePieSlice> onSliceTap;
  final VoidCallback? onClear;
  final double chartHeight;

  const IncomeModeRadialChart({
    super.key,
    required this.incomeTotal,
    required this.budgetTotal,
    required this.expenseTotal,
    required this.selectedSlice,
    required this.onSliceTap,
    this.onClear,
    this.chartHeight = 220,
  });

  static const Color _softGreen = Color(0xDD4ADE80);

  static const Color _softRed = Color(0xDDF87171);

  static Color _softBudget(Color primary) =>
      Color.lerp(primary, Colors.white, 0.42) ?? primary.withValues(alpha: 0.75);

  @override
  Widget build(BuildContext context) {
    final budgetColor = _softBudget(Theme.of(context).colorScheme.primary);
    const incomeColor = _softGreen;
    const expenseColor = _softRed;

    return LayoutBuilder(
      builder: (context, constraints) {
        final available = math.min(constraints.maxWidth, chartHeight);
        final side = available.isFinite ? available : chartHeight;

        final R = side / 2;
        const kOuterR = _RadialChartPainter._kOuterR;
        const kMidR = _RadialChartPainter._kMidR;
        const kInnerR = _RadialChartPainter._kInnerR;
        const wOuter = _RadialChartPainter._wOuter;
        const wMid = _RadialChartPainter._wMid;
        const wInner = _RadialChartPainter._wInner;
        // Slightly inset from stroke midline so glyphs stay inside the colored ring.
        final rIncomeLab = R * kOuterR - wOuter / 2 - 2.5;
        final rBudgetLab = R * kMidR - wMid / 2 - 1.5;
        final rExpenseLab = R * kInnerR - wInner / 2 - 1.0;

        final labelColor =
            Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.88);
        final baseSize = math.min(12.0, side * 0.042);
        final labelStyle = Theme.of(context).textTheme.labelSmall?.copyWith(
              fontSize: baseSize,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.3,
              height: 1.0,
              color: labelColor,
              shadows: [
                Shadow(
                  color: Colors.white.withValues(alpha: 0.92),
                  blurRadius: 3,
                ),
                Shadow(
                  color: Colors.black.withValues(alpha: 0.38),
                  blurRadius: 2,
                  offset: const Offset(0, 0.5),
                ),
              ],
            ) ??
            TextStyle(
              fontSize: baseSize,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.3,
              height: 1.0,
              color: labelColor,
              shadows: [
                Shadow(
                  color: Colors.white.withValues(alpha: 0.92),
                  blurRadius: 3,
                ),
                Shadow(
                  color: Colors.black.withValues(alpha: 0.38),
                  blurRadius: 2,
                  offset: const Offset(0, 0.5),
                ),
              ],
            );

        return Stack(
          clipBehavior: Clip.none,
          children: [
            Center(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (details) {
                  final slice = _RadialChartPainter.ringHitTest(
                    details.localPosition,
                    Size(side, side),
                  );
                  if (slice != null) onSliceTap(slice);
                },
                child: SizedBox(
                  width: side,
                  height: side,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      CustomPaint(
                        size: Size(side, side),
                        painter: _RadialChartPainter(
                          incomeTotal: incomeTotal,
                          budgetTotal: budgetTotal,
                          expenseTotal: expenseTotal,
                          selectedSlice: selectedSlice,
                          incomeColor: incomeColor,
                          budgetColor: budgetColor,
                          expenseColor: expenseColor,
                        ),
                      ),
                      if (incomeTotal > 0)
                        IgnorePointer(
                          child: CustomPaint(
                            size: Size(side, side),
                            painter: _CurvedRingLabelsPainter(
                              rIncome: rIncomeLab,
                              rBudget: rBudgetLab,
                              rExpense: rExpenseLab,
                              textStyle: labelStyle,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            if (onClear != null)
              Positioned(
                right: 2,
                top: 2,
                child: IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  icon: const Icon(Icons.close_rounded, size: 16),
                  tooltip: 'Clear filter',
                  onPressed: onClear,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _RadialChartPainter extends CustomPainter {
  _RadialChartPainter({
    required this.incomeTotal,
    required this.budgetTotal,
    required this.expenseTotal,
    required this.selectedSlice,
    required this.incomeColor,
    required this.budgetColor,
    required this.expenseColor,
  });

  final double incomeTotal;
  final double budgetTotal;
  final double expenseTotal;
  final IncomeExpensePieSlice? selectedSlice;
  final Color incomeColor;
  final Color budgetColor;
  final Color expenseColor;

  static const double _kOuterR = 0.76;
  static const double _kMidR = 0.54;
  static const double _kInnerR = 0.34;
  static const double _wOuter = 13;
  static const double _wMid = 11;
  static const double _wInner = 9;

  static IncomeExpensePieSlice? ringHitTest(Offset local, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final R = math.min(size.width, size.height) / 2;
    final d = (local - c).distance;
    if (d > R * 0.96 || d < R * 0.1) return null;

    final rOuter = R * _kOuterR;
    final rMid = R * _kMidR;
    final rInner = R * _kInnerR;
    final innerOuterBound = (rInner + rMid) / 2;
    final midOuterBound = (rMid + rOuter) / 2;

    if (d <= innerOuterBound) return IncomeExpensePieSlice.expense;
    if (d <= midOuterBound) return IncomeExpensePieSlice.budget;
    return IncomeExpensePieSlice.income;
  }

  Color _layerColor(IncomeExpensePieSlice layer, Color full) {
    final dim = selectedSlice != null && selectedSlice != layer;
    return dim ? full.withValues(alpha: 0.32) : full;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final R = math.min(size.width, size.height) / 2;
    const start = -math.pi / 2;

    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final rOuter = R * _kOuterR;
    final rMid = R * _kMidR;
    final rInner = R * _kInnerR;

    // Outer: income — full ring (reference)
    track
      ..strokeWidth = _wOuter
      ..color = Colors.black.withValues(alpha: 0.06);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: rOuter),
      start,
      math.pi * 2,
      false,
      track,
    );
    track
      ..color = _layerColor(IncomeExpensePieSlice.income, incomeColor)
      ..strokeWidth = _wOuter;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: rOuter),
      start,
      math.pi * 2,
      false,
      track,
    );

    final inc = incomeTotal > 0 ? incomeTotal : 0.0;
    final budgetFrac = inc > 0 ? (budgetTotal / inc).clamp(0.0, 1.0) : 0.0;
    final expenseFrac = inc > 0 ? (expenseTotal / inc).clamp(0.0, 1.0) : 0.0;

    // Middle: budget vs income
    track
      ..strokeWidth = _wMid
      ..color = Colors.black.withValues(alpha: 0.05);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: rMid),
      start,
      math.pi * 2,
      false,
      track,
    );
    if (budgetFrac > 0.001) {
      track
        ..color = _layerColor(IncomeExpensePieSlice.budget, budgetColor)
        ..strokeWidth = _wMid;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: rMid),
        start,
        budgetFrac * math.pi * 2,
        false,
        track,
      );
    }

    // Inner: expense vs income
    track
      ..strokeWidth = _wInner
      ..color = Colors.black.withValues(alpha: 0.05);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: rInner),
      start,
      math.pi * 2,
      false,
      track,
    );
    if (expenseFrac > 0.001) {
      track
        ..color = _layerColor(IncomeExpensePieSlice.expense, expenseColor)
        ..strokeWidth = _wInner;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: rInner),
        start,
        expenseFrac * math.pi * 2,
        false,
        track,
      );
    }

    if (inc <= 0) {
      final tp = TextPainter(
        text: TextSpan(
          text: 'No income\nin range',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade600,
            height: 1.2,
          ),
        ),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: R * 1.4);
      tp.paint(
        canvas,
        Offset(center.dx - tp.width / 2, center.dy - tp.height / 2),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RadialChartPainter oldDelegate) {
    return incomeTotal != oldDelegate.incomeTotal ||
        budgetTotal != oldDelegate.budgetTotal ||
        expenseTotal != oldDelegate.expenseTotal ||
        selectedSlice != oldDelegate.selectedSlice ||
        incomeColor != oldDelegate.incomeColor ||
        budgetColor != oldDelegate.budgetColor ||
        expenseColor != oldDelegate.expenseColor;
  }
}

/// Curved labels along each ring; [centerAngle]s are 120° apart so labels do not crowd.
class _CurvedRingLabelsPainter extends CustomPainter {
  _CurvedRingLabelsPainter({
    required this.rIncome,
    required this.rBudget,
    required this.rExpense,
    required this.textStyle,
  });

  final double rIncome;
  final double rBudget;
  final double rExpense;
  final TextStyle textStyle;

  /// Outer ring — top.
  static const double _centerIncome = -math.pi / 2;

  /// Middle ring — ~4 o'clock (separated from top & bottom-left).
  static const double _centerBudget = -math.pi / 2 + 2 * math.pi / 3;

  /// Inner ring — ~8 o'clock.
  static const double _centerExpense = -math.pi / 2 + 4 * math.pi / 3;

  void _paintStringOnArc(
    Canvas canvas,
    Offset center,
    String text,
    double radius,
    double centerAngle,
  ) {
    if (radius <= 1 || text.isEmpty) return;

    var totalWidth = 0.0;
    final painters = <TextPainter>[];
    for (var i = 0; i < text.length; i++) {
      final tp = TextPainter(
        text: TextSpan(text: text[i], style: textStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      painters.add(tp);
      totalWidth += tp.width;
    }

    final angularSpan = (totalWidth / radius).clamp(0.35, 2.15);
    var edgeAngle = centerAngle - angularSpan / 2;

    for (final tp in painters) {
      final w = tp.width;
      final h = tp.height;
      final charAngle = edgeAngle + (w / 2) / radius;
      edgeAngle += w / radius;

      final x = center.dx + radius * math.cos(charAngle);
      final y = center.dy + radius * math.sin(charAngle);

      canvas.save();
      canvas.translate(x, y);
      // Tangent to circle (CCW), text reads along the arc.
      canvas.rotate(charAngle + math.pi / 2);
      tp.paint(canvas, Offset(-w / 2, -h / 2));
      canvas.restore();
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    _paintStringOnArc(canvas, center, 'Income', rIncome, _centerIncome);
    _paintStringOnArc(canvas, center, 'Budget', rBudget, _centerBudget);
    _paintStringOnArc(canvas, center, 'Expense', rExpense, _centerExpense);
  }

  @override
  bool shouldRepaint(covariant _CurvedRingLabelsPainter oldDelegate) {
    return rIncome != oldDelegate.rIncome ||
        rBudget != oldDelegate.rBudget ||
        rExpense != oldDelegate.rExpense ||
        textStyle != oldDelegate.textStyle;
  }
}
