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

  const IncomeExpensePieChart({
    super.key,
    required this.incomeTotal,
    required this.expenseTotal,
    required this.selectedSlice,
    required this.onSliceTap,
    required this.incomeColor,
    required this.expenseColor,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = math.min(constraints.maxWidth, constraints.maxHeight);
        final diameter = size.isFinite ? size : 220.0;

        return Stack(
          clipBehavior: Clip.none,
          children: [
            Center(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (details) {
                  final box = context.findRenderObject() as RenderBox?;
                  if (box == null) return;

                  final local = box.globalToLocal(details.globalPosition);
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
        ..strokeWidth = 10
        ..color = Colors.grey.shade300;
      canvas.drawCircle(center, radius * 0.82, paint);
      return;
    }

    const startAngle = -math.pi / 2;
    final incomeSweep = (incomeTotal / total) * math.pi * 2;
    final expenseSweep = (expenseTotal / total) * math.pi * 2;

    final bgPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 26
      ..strokeCap = StrokeCap.butt
      ..color = Colors.black.withOpacity(0.05);
    canvas.drawCircle(center, radius * 0.86, bgPaint);

    final incomePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 26
      ..strokeCap = StrokeCap.butt;

    final expensePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 26
      ..strokeCap = StrokeCap.butt;

    final incomeSelected = selectedSlice == IncomeExpensePieSlice.income;
    final expenseSelected = selectedSlice == IncomeExpensePieSlice.expense;

    incomePaint.color = incomeSelected ? incomeColor : incomeColor.withOpacity(selectedSlice == null ? 1.0 : 0.35);
    expensePaint.color = expenseSelected ? expenseColor : expenseColor.withOpacity(selectedSlice == null ? 1.0 : 0.35);

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius * 0.86),
      startAngle,
      incomeSweep,
      false,
      incomePaint,
    );
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius * 0.86),
      startAngle + incomeSweep,
      expenseSweep,
      false,
      expensePaint,
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

