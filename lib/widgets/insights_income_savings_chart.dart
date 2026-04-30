import 'package:flutter/material.dart';

class InsightsIncomeSavingsMonthDatum {
  const InsightsIncomeSavingsMonthDatum({
    required this.monthIndex,
    required this.label,
    required this.income,
    required this.expense,
    required this.savings,
  });

  /// 1–12
  final int monthIndex;
  final String label;
  final double income;
  final double expense;
  final double savings;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InsightsIncomeSavingsMonthDatum &&
          monthIndex == other.monthIndex &&
          label == other.label &&
          income == other.income &&
          expense == other.expense &&
          savings == other.savings;

  @override
  int get hashCode => Object.hash(monthIndex, label, income, expense, savings);
}

/// Multi-series line chart: income (purple), expense (red), savings (green).
class InsightsIncomeSavingsChart extends StatelessWidget {
  const InsightsIncomeSavingsChart({
    super.key,
    required this.data,
  });

  final List<InsightsIncomeSavingsMonthDatum> data;

  static const double chartHeight = 140;

  static const Color incomeLineColor = Color(0xFF7C3AED);
  static const Color expenseLineColor = Color(0xFFDC2626);
  static const Color savingsLineColor = Color(0xFF16A34A);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: chartHeight,
      width: double.infinity,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return CustomPaint(
            size: Size(constraints.maxWidth, chartHeight),
            painter: _MultiLinePainter(
              width: constraints.maxWidth,
              height: chartHeight,
              data: data,
            ),
          );
        },
      ),
    );
  }
}

class _MultiLinePainter extends CustomPainter {
  _MultiLinePainter({
    required this.width,
    required this.height,
    required this.data,
  });

  final double width;
  final double height;
  final List<InsightsIncomeSavingsMonthDatum> data;

  static const _padL = 8.0;
  static const _padR = 8.0;
  static const _padT = 10.0;
  static const _padB = 20.0;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.clipRect(Rect.fromLTWH(0, 0, size.width, size.height));
    if (data.isEmpty) return;

    final n = data.length;
    final innerW = size.width - _padL - _padR;
    final innerH = size.height - _padT - _padB;
    if (innerW <= 0 || innerH <= 0) return;

    double maxAbs = 1.0;
    for (final d in data) {
      for (final v in [d.income, d.expense, d.savings]) {
        final av = v.abs();
        if (av > maxAbs) maxAbs = av;
      }
    }
    maxAbs *= 1.08;
    if (maxAbs <= 0) maxAbs = 1.0;

    double xFor(int i) {
      if (n <= 1) return _padL + innerW / 2;
      return _padL + innerW * (i / (n - 1));
    }

    double yFor(double v) {
      final t = ((v + maxAbs) / (2 * maxAbs)).clamp(0.0, 1.0);
      return _padT + innerH * (1.0 - t);
    }

    // Zero line
    final y0 = yFor(0);
    canvas.drawLine(
      Offset(_padL, y0),
      Offset(size.width - _padR, y0),
      Paint()
        ..color = Colors.grey.withValues(alpha: 0.35)
        ..strokeWidth = 1,
    );

    Path pathFor(List<double> ys) {
      final path = Path();
      path.moveTo(xFor(0), yFor(ys[0]));
      for (var i = 1; i < ys.length; i++) {
        path.lineTo(xFor(i), yFor(ys[i]));
      }
      return path;
    }

    final inc = data.map((e) => e.income).toList();
    final exp = data.map((e) => e.expense).toList();
    final sav = data.map((e) => e.savings).toList();

    void stroke(Path path, Color color) {
      canvas.drawPath(
        path,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.4
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }

    stroke(pathFor(exp), InsightsIncomeSavingsChart.expenseLineColor);
    stroke(pathFor(inc), InsightsIncomeSavingsChart.incomeLineColor);
    stroke(pathFor(sav), InsightsIncomeSavingsChart.savingsLineColor);

    for (var i = 0; i < n; i++) {
      final cx = xFor(i);
      for (final entry in [
        (inc[i], InsightsIncomeSavingsChart.incomeLineColor),
        (exp[i], InsightsIncomeSavingsChart.expenseLineColor),
        (sav[i], InsightsIncomeSavingsChart.savingsLineColor),
      ]) {
        canvas.drawCircle(
          Offset(cx, yFor(entry.$1)),
          3.2,
          Paint()..color = entry.$2,
        );
      }
    }

    final labelStyle = TextStyle(
      color: Colors.grey.shade700,
      fontSize: 10,
    );
    void labelAt(int i) {
      if (i < 0 || i >= data.length) return;
      final tp = TextPainter(
        text: TextSpan(text: data[i].label, style: labelStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      final cx = xFor(i) - tp.width / 2;
      tp.paint(canvas, Offset(cx.clamp(_padL, size.width - _padR - tp.width), _padT + innerH + 4));
    }

    labelAt(0);
    if (n > 2) labelAt(n ~/ 2);
    if (n > 1) labelAt(n - 1);
  }

  @override
  bool shouldRepaint(covariant _MultiLinePainter oldDelegate) {
    return oldDelegate.width != width ||
        oldDelegate.height != height ||
        oldDelegate.data != data;
  }
}
