import 'package:flutter/material.dart';

/// Optional month-bucket series (Jan–current or Jan–Dec) for till-month / yearly race.
class InsightsRaceMonthlyData {
  const InsightsRaceMonthlyData({
    required this.cumulativeExpense,
    required this.cumulativeBudget,
    required this.labels,
    required this.progressIndex,
  });

  final List<double> cumulativeExpense;
  final List<double> cumulativeBudget;
  final List<String> labels;
  /// Last index (inclusive) to draw the actual line; rest is future / flat.
  final int progressIndex;
}

/// Cumulative actual spend vs linear budget pace for the current month, or by month buckets.
class InsightsBudgetRaceChart extends StatelessWidget {
  const InsightsBudgetRaceChart({
    super.key,
    required this.daysInMonth,
    required this.todayDay,
    required this.dailyBudgetAllowance,
    required this.totalMonthBudget,
    required this.cumulativeExpenseByDay,
    required this.todayCumulativeLabel,
    required this.budgetEndLabel,
    required this.colorScheme,
    this.monthly,
  });

  final int daysInMonth;
  final int todayDay;
  final double dailyBudgetAllowance;
  final double totalMonthBudget;
  /// Length [daysInMonth]: cumulative expense through end of day (index 0 = day 1).
  final List<double> cumulativeExpenseByDay;
  final String todayCumulativeLabel;
  final String budgetEndLabel;
  final ColorScheme colorScheme;
  final InsightsRaceMonthlyData? monthly;

  static const double chartHeight = 120;

  @override
  Widget build(BuildContext context) {
    final m = monthly;
    if (m != null) {
      return SizedBox(
        height: chartHeight,
        width: double.infinity,
        child: LayoutBuilder(
          builder: (context, constraints) {
            return CustomPaint(
              size: Size(constraints.maxWidth, chartHeight),
              painter: _MonthRacePainter(
                width: constraints.maxWidth,
                height: chartHeight,
                data: m,
                colorScheme: colorScheme,
              ),
            );
          },
        ),
      );
    }
    return SizedBox(
      height: chartHeight,
      width: double.infinity,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return CustomPaint(
            size: Size(constraints.maxWidth, chartHeight),
            painter: _BudgetRacePainter(
              width: constraints.maxWidth,
              height: chartHeight,
              daysInMonth: daysInMonth,
              todayDay: todayDay,
              dailyBudgetAllowance: dailyBudgetAllowance,
              totalMonthBudget: totalMonthBudget,
              cumulativeExpenseByDay: cumulativeExpenseByDay,
              todayCumulativeLabel: todayCumulativeLabel,
              budgetEndLabel: budgetEndLabel,
              colorScheme: colorScheme,
            ),
          );
        },
      ),
    );
  }
}

class _MonthRacePainter extends CustomPainter {
  _MonthRacePainter({
    required this.width,
    required this.height,
    required this.data,
    required this.colorScheme,
  });

  final double width;
  final double height;
  final InsightsRaceMonthlyData data;
  final ColorScheme colorScheme;

  static const _padL = 8.0;
  static const _padR = 8.0;
  static const _padT = 8.0;
  static const _padB = 22.0;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.clipRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final n = data.cumulativeExpense.length;
    if (n < 1) return;
    final innerW = size.width - _padL - _padR;
    final innerH = size.height - _padT - _padB;
    if (innerW <= 0 || innerH <= 0) return;

    double maxY = 1.0;
    for (var i = 0; i < n; i++) {
      if (data.cumulativeBudget[i] > maxY) maxY = data.cumulativeBudget[i];
      if (data.cumulativeExpense[i] > maxY) maxY = data.cumulativeExpense[i];
    }
    maxY *= 1.08;
    if (maxY <= 0) maxY = 1.0;

    double xFor(int i) {
      if (n <= 1) return _padL + innerW / 2;
      return _padL + innerW * (i / (n - 1));
    }

    double yFor(double v) {
      final t = (v / maxY).clamp(0.0, 1.0);
      return _padT + innerH * (1.0 - t);
    }

    final budgetPts = <Offset>[
      for (var i = 0; i < n; i++) Offset(xFor(i), yFor(data.cumulativeBudget[i])),
    ];
    if (budgetPts.length >= 2) {
      final path = Path()..moveTo(budgetPts.first.dx, budgetPts.first.dy);
      for (var i = 1; i < budgetPts.length; i++) {
        path.lineTo(budgetPts[i].dx, budgetPts[i].dy);
      }
      _drawDashedPath(
        canvas,
        path,
        Paint()
          ..color = colorScheme.primary
          ..strokeWidth = 1.5
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round,
      );
    }

    final lastAct = data.progressIndex.clamp(0, n - 1);
    final actualPts = <Offset>[
      for (var i = 0; i <= lastAct; i++) Offset(xFor(i), yFor(data.cumulativeExpense[i])),
    ];
    if (actualPts.length >= 2) {
      final path = Path()..moveTo(actualPts.first.dx, actualPts.first.dy);
      for (var i = 1; i < actualPts.length; i++) {
        path.lineTo(actualPts[i].dx, actualPts[i].dy);
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = colorScheme.error
          ..strokeWidth = 2.5
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    } else if (actualPts.length == 1) {
      canvas.drawCircle(actualPts.first, 2, Paint()..color = colorScheme.error);
    }

    if (actualPts.isNotEmpty) {
      final p = actualPts.last;
      canvas.drawCircle(p, 4, Paint()..color = colorScheme.error);
    }

    final labelStyle = TextStyle(
      color: colorScheme.onSurfaceVariant,
      fontSize: 10,
    );
    void drawXAt(int i, String text) {
      if (i < 0 || i >= data.labels.length) return;
      final tp = TextPainter(
        text: TextSpan(text: text, style: labelStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      final cx = xFor(i) - tp.width / 2;
      tp.paint(canvas, Offset(cx.clamp(_padL, size.width - _padR - tp.width), _padT + innerH + 4));
    }

    drawXAt(0, data.labels[0]);
    if (n > 2) drawXAt(n ~/ 2, data.labels[n ~/ 2]);
    if (n > 1) drawXAt(n - 1, data.labels[n - 1]);
  }

  void _drawDashedPath(Canvas canvas, Path path, Paint paint) {
    for (final metric in path.computeMetrics()) {
      var d = 0.0;
      while (d < metric.length) {
        final e = (d + 5.0).clamp(0.0, metric.length);
        final extract = metric.extractPath(d, e);
        canvas.drawPath(extract, paint);
        d += 5.0 + 4.0;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _MonthRacePainter oldDelegate) {
    return oldDelegate.width != width ||
        oldDelegate.height != height ||
        oldDelegate.data != data ||
        oldDelegate.colorScheme != colorScheme;
  }
}

class _BudgetRacePainter extends CustomPainter {
  _BudgetRacePainter({
    required this.width,
    required this.height,
    required this.daysInMonth,
    required this.todayDay,
    required this.dailyBudgetAllowance,
    required this.totalMonthBudget,
    required this.cumulativeExpenseByDay,
    required this.todayCumulativeLabel,
    required this.budgetEndLabel,
    required this.colorScheme,
  });

  final double width;
  final double height;
  final int daysInMonth;
  final int todayDay;
  final double dailyBudgetAllowance;
  final double totalMonthBudget;
  final List<double> cumulativeExpenseByDay;
  final String todayCumulativeLabel;
  final String budgetEndLabel;
  final ColorScheme colorScheme;

  static const _padL = 8.0;
  static const _padR = 8.0;
  static const _padT = 8.0;
  static const _padB = 22.0;

  @override
  void paint(Canvas canvas, Size size) {
    final clipRect = Rect.fromLTWH(0, 0, size.width, size.height);
    canvas.clipRect(clipRect);

    final innerW = size.width - _padL - _padR;
    final innerH = size.height - _padT - _padB;
    if (innerW <= 0 || innerH <= 0 || daysInMonth < 1) return;

    double maxY = totalMonthBudget;
    for (var d = 0; d < cumulativeExpenseByDay.length && d < daysInMonth; d++) {
      final v = cumulativeExpenseByDay[d];
      if (v > maxY) maxY = v;
    }
    final budgetEnd = dailyBudgetAllowance * daysInMonth;
    if (budgetEnd > maxY) maxY = budgetEnd;
    if (maxY <= 0) maxY = 1.0;
    maxY *= 1.08;

    double xForDay(int day) {
      if (daysInMonth <= 1) return _padL + innerW / 2;
      return _padL + innerW * (day - 1) / (daysInMonth - 1);
    }

    double yForValue(double v) {
      final t = (v / maxY).clamp(0.0, 1.0);
      return _padT + innerH * (1.0 - t);
    }

    final budgetPts = <Offset>[
      for (var day = 1; day <= daysInMonth; day++)
        Offset(xForDay(day), yForValue(dailyBudgetAllowance * day)),
    ];
    if (budgetPts.length >= 2) {
      final path = Path()..moveTo(budgetPts.first.dx, budgetPts.first.dy);
      for (var i = 1; i < budgetPts.length; i++) {
        path.lineTo(budgetPts[i].dx, budgetPts[i].dy);
      }
      _drawDashedPath(
        canvas,
        path,
        Paint()
          ..color = colorScheme.primary
          ..strokeWidth = 1.5
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round,
      );
    }

    final lastDay = todayDay.clamp(1, daysInMonth);
    final actualPts = <Offset>[];
    for (var day = 1; day <= lastDay; day++) {
      final cum = day <= cumulativeExpenseByDay.length
          ? cumulativeExpenseByDay[day - 1]
          : 0.0;
      actualPts.add(Offset(xForDay(day), yForValue(cum)));
    }
    if (actualPts.length >= 2) {
      final path = Path()..moveTo(actualPts.first.dx, actualPts.first.dy);
      for (var i = 1; i < actualPts.length; i++) {
        path.lineTo(actualPts[i].dx, actualPts[i].dy);
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = colorScheme.error
          ..strokeWidth = 2.5
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    } else if (actualPts.length == 1) {
      canvas.drawCircle(actualPts.first, 2, Paint()..color = colorScheme.error);
    }

    if (lastDay >= 1 && actualPts.isNotEmpty) {
      final p = actualPts.last;
      canvas.drawCircle(p, 4, Paint()..color = colorScheme.error);
      final tp = TextPainter(
        text: TextSpan(
          text: todayCumulativeLabel,
          style: TextStyle(
            color: colorScheme.onSurface,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: innerW);
      var lx = p.dx - tp.width / 2;
      lx = lx.clamp(_padL, size.width - _padR - tp.width);
      final ly = (p.dy - tp.height - 6).clamp(_padT, size.height - _padB - tp.height);
      tp.paint(canvas, Offset(lx, ly));
    }

    if (budgetPts.isNotEmpty) {
      final end = budgetPts.last;
      final tp = TextPainter(
        text: TextSpan(
          text: budgetEndLabel,
          style: TextStyle(
            color: colorScheme.primary,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: innerW);
      var lx = end.dx - tp.width / 2;
      lx = lx.clamp(_padL, size.width - _padR - tp.width);
      final ly = (end.dy - tp.height - 4).clamp(_padT, size.height - _padB - tp.height);
      tp.paint(canvas, Offset(lx, ly));
    }

    final labelStyle = TextStyle(
      color: colorScheme.onSurfaceVariant,
      fontSize: 12,
    );
    void drawXLabel(String text, int day) {
      final tp = TextPainter(
        text: TextSpan(text: text, style: labelStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      final cx = xForDay(day) - tp.width / 2;
      tp.paint(canvas, Offset(cx.clamp(_padL, size.width - _padR - tp.width), _padT + innerH + 4));
    }

    drawXLabel('1', 1);
    if (daysInMonth > 2) {
      final mid = (1 + daysInMonth) ~/ 2;
      drawXLabel('$mid', mid);
    }
    drawXLabel('$daysInMonth', daysInMonth);
  }

  void _drawDashedPath(Canvas canvas, Path path, Paint paint) {
    for (final metric in path.computeMetrics()) {
      var d = 0.0;
      while (d < metric.length) {
        final e = (d + 5.0).clamp(0.0, metric.length);
        final extract = metric.extractPath(d, e);
        canvas.drawPath(extract, paint);
        d += 5.0 + 4.0;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _BudgetRacePainter oldDelegate) {
    return oldDelegate.width != width ||
        oldDelegate.height != height ||
        oldDelegate.daysInMonth != daysInMonth ||
        oldDelegate.todayDay != todayDay ||
        oldDelegate.totalMonthBudget != totalMonthBudget ||
        oldDelegate.dailyBudgetAllowance != dailyBudgetAllowance ||
        oldDelegate.cumulativeExpenseByDay != cumulativeExpenseByDay ||
        oldDelegate.todayCumulativeLabel != todayCumulativeLabel ||
        oldDelegate.budgetEndLabel != budgetEndLabel ||
        oldDelegate.colorScheme != colorScheme;
  }
}
