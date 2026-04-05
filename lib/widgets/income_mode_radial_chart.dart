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
                  child: CustomPaint(
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
