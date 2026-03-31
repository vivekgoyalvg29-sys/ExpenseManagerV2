import 'dart:math' as math;

import 'package:flutter/material.dart';

enum IncomeExpensePieSlice {
  income,
  expense,
}

class IncomeExpensePieChart extends StatelessWidget {
  final double incomeTotal;
  final double expenseTotal;
  final IncomeExpensePieSlice? selectedSlice;
  final ValueChanged<IncomeExpensePieSlice> onSliceTap;
  final VoidCallback? onClear;
  final Color incomeColor;
  final Color expenseColor;
  final double chartHeight;

  const IncomeExpensePieChart({
    super.key,
    required this.incomeTotal,
    required this.expenseTotal,
    required this.selectedSlice,
    required this.onSliceTap,
    required this.incomeColor,
    required this.expenseColor,
    this.chartHeight = 210,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final available = math.min(constraints.maxWidth, chartHeight);
        final diameter = available.isFinite ? available : 210.0;

        return Stack(
          clipBehavior: Clip.none,
          children: [
            Center(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (details) {
                  final local = details.localPosition;
                  final center = Offset(diameter / 2, diameter / 2);
                  final dx = local.dx - center.dx;
                  final dy = local.dy - center.dy;
                  final distance = math.sqrt(dx * dx + dy * dy);

                  // Radius includes a little padding so taps near edge still work.
                  final radius = diameter / 2;
                  if (distance > radius) return;

                  final total = incomeTotal + expenseTotal;
                  if (total <= 0) return;

                  final incomeSweep = (incomeTotal / total) * math.pi * 2;
                  const startAngle = -math.pi / 2;

                  // Normalize tap angle into [0, 2pi) relative to startAngle
                  var tapAngle = math.atan2(dy, dx); // [-pi, pi]
                  var rel = tapAngle - startAngle;
                  rel = (rel % (math.pi * 2) + (math.pi * 2)) % (math.pi * 2);

                  if (rel <= incomeSweep) {
                    onSliceTap(IncomeExpensePieSlice.income);
                  } else {
                    onSliceTap(IncomeExpensePieSlice.expense);
                  }
                },
                child: SizedBox(
                  width: diameter,
                  height: diameter,
                  child: CustomPaint(
                    painter: _PiePainter(
                      incomeTotal: incomeTotal,
                      expenseTotal: expenseTotal,
                      selectedSlice: selectedSlice,
                      incomeColor: incomeColor,
                      expenseColor: expenseColor,
                    ),
                  ),
                ),
              ),
            ),
            if (onClear != null)
              Positioned(
                right: 6,
                top: 6,
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

class _PiePainter extends CustomPainter {
  final double incomeTotal;
  final double expenseTotal;
  final IncomeExpensePieSlice? selectedSlice;
  final Color incomeColor;
  final Color expenseColor;

  _PiePainter({
    required this.incomeTotal,
    required this.expenseTotal,
    required this.selectedSlice,
    required this.incomeColor,
    required this.expenseColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final total = incomeTotal + expenseTotal;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2;

    if (total <= 0) {
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 24
        ..color = Colors.grey.shade300;
      canvas.drawCircle(center, radius * 0.86, paint);
      return;
    }

    const startAngle = -math.pi / 2;
    final incomeSweep = (incomeTotal / total) * math.pi * 2;
    final expenseSweep = (expenseTotal / total) * math.pi * 2;

    const strokeWidth = 24.0;
    final ringRadius = radius * 0.86;

    final bgPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt
      ..color = Colors.black.withOpacity(0.05);
    canvas.drawCircle(center, ringRadius, bgPaint);

    final incomePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;

    final expensePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;

    final incomeSelected = selectedSlice == IncomeExpensePieSlice.income;
    final expenseSelected = selectedSlice == IncomeExpensePieSlice.expense;

    incomePaint.color = incomeSelected ? incomeColor : incomeColor.withOpacity(selectedSlice == null ? 1.0 : 0.35);
    expensePaint.color = expenseSelected ? expenseColor : expenseColor.withOpacity(selectedSlice == null ? 1.0 : 0.35);

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: ringRadius),
      startAngle,
      incomeSweep,
      false,
      incomePaint,
    );
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: ringRadius),
      startAngle + incomeSweep,
      expenseSweep,
      false,
      expensePaint,
    );

    final incomeMidAngle = startAngle + (incomeSweep / 2);
    final expenseMidAngle = startAngle + incomeSweep + (expenseSweep / 2);
    final labelRadius = ringRadius;

    _drawArcAmount(
      canvas: canvas,
      center: center,
      angle: incomeMidAngle,
      radius: labelRadius,
      text: _compactAmount(incomeTotal),
      color: Colors.white,
    );
    _drawArcAmount(
      canvas: canvas,
      center: center,
      angle: expenseMidAngle,
      radius: labelRadius,
      text: _compactAmount(expenseTotal),
      color: Colors.white,
    );
  }

  static String _compactAmount(double value) {
    if (value >= 10000000) return '${(value / 10000000).toStringAsFixed(1)}Cr';
    if (value >= 100000) return '${(value / 100000).toStringAsFixed(1)}L';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}K';
    return value.toStringAsFixed(value == value.roundToDouble() ? 0 : 1);
  }

  void _drawArcAmount({
    required Canvas canvas,
    required Offset center,
    required double angle,
    required double radius,
    required String text,
    required Color color,
  }) {
    final offset = Offset(
      center.dx + math.cos(angle) * radius,
      center.dy + math.sin(angle) * radius,
    );
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          shadows: const [
            Shadow(color: Colors.black38, blurRadius: 2),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout(maxWidth: 52);

    painter.paint(
      canvas,
      Offset(
        offset.dx - (painter.width / 2),
        offset.dy - (painter.height / 2),
      ),
    );
  }

  @override
  bool shouldRepaint(covariant _PiePainter oldDelegate) {
    return incomeTotal != oldDelegate.incomeTotal ||
        expenseTotal != oldDelegate.expenseTotal ||
        selectedSlice != oldDelegate.selectedSlice ||
        incomeColor != oldDelegate.incomeColor ||
        expenseColor != oldDelegate.expenseColor;
  }
}

