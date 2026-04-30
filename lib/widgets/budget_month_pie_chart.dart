import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'aggregation_bar_chart.dart';

/// Top contributors shown as their own slices; the rest merge into [othersLabel].
const int _kMaxPieSlices = 10;

/// Inner hole radius as fraction of min(width, height). Smaller = less empty centre.
const double _kInnerRatio = 0.13;

/// Outer ring radius as fraction of min(width, height).
const double _kOuterRatio = 0.29;

/// 3-D extrusion depth as fraction of outerR.
const double _kDepthRatio = 0.06;

/// Fraction of total width reserved for labels on each side.
const double _kLabelZone = 0.30;

// ─────────────────────────────────────────────────────────────────────────────
// Data models
// ─────────────────────────────────────────────────────────────────────────────

class _BudgetPieBuild {
  _BudgetPieBuild({
    required this.segments,
    required this.grandTotal,
    this.othersMembers,
    this.monthGrandTotal,
  });
  final List<_PieSegment> segments;
  final double grandTotal;
  final List<AggregationBarData>? othersMembers;
  final double? monthGrandTotal;
}

class _PieSegment {
  _PieSegment({
    required this.label,
    required this.value,
    required this.startAngle,
    required this.sweepAngle,
    required this.rank,
    required this.color,
    required this.pctOfTotal,
    this.isOthersBucket = false,
  });
  final String label;
  final double value;
  final double startAngle;
  final double sweepAngle;
  final int rank;
  final Color color;
  final double pctOfTotal;
  final bool isOthersBucket;
}

// ─────────────────────────────────────────────────────────────────────────────
// Widget
// ─────────────────────────────────────────────────────────────────────────────

class BudgetMonthPieChart extends StatefulWidget {
  const BudgetMonthPieChart({
    super.key,
    required this.data,
    this.headerHint,
    this.othersLabel = 'Others',
  });

  final List<AggregationBarData> data;
  final String? headerHint;
  final String othersLabel;

  static BoxDecoration shellDecoration(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final fill = cs.surfaceContainerHighest.withValues(
      alpha: theme.brightness == Brightness.dark ? 0.55 : 0.92,
    );
    return BoxDecoration(
      color: fill,
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
  State<BudgetMonthPieChart> createState() => _BudgetMonthPieChartState();
}

class _BudgetMonthPieChartState extends State<BudgetMonthPieChart> {
  _BudgetPieBuild? _cached;
  List<AggregationBarData>? _cachedDataRef;

  @override
  void didUpdateWidget(covariant BudgetMonthPieChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.data != widget.data) {
      _cached = null;
      _cachedDataRef = null;
    }
  }

  _BudgetPieBuild _buildForFrame(BuildContext context) {
    if (_cached != null && identical(_cachedDataRef, widget.data)) return _cached!;
    _cachedDataRef = widget.data;
    _cached = _buildBudgetPie(context, widget.data, widget.othersLabel);
    return _cached!;
  }

  void _showOthersDialog(
    BuildContext context,
    ThemeData theme,
    List<AggregationBarData> members,
    double monthGrandTotal,
  ) {
    final inner = _buildOthersDrillPie(context, members, monthGrandTotal);
    if (inner == null || inner.segments.isEmpty) return;

    showDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black54,
      builder: (ctx) {
        final cs = theme.colorScheme;
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 16, 12, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.othersLabel,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '% of total monthly budget',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: math.min(360.0, MediaQuery.sizeOf(ctx).width - 64),
                  height: (math.min(360.0, MediaQuery.sizeOf(ctx).width - 64) * 0.72).clamp(240.0, 320.0),
                  child: CustomPaint(
                    painter: _BudgetMonthPiePainter(
                      segments: inner.segments,
                      grandTotal: inner.grandTotal,
                      labelStyle: _labelStyle(theme),
                      pctStyle: _pctStyle(theme),
                      theme: theme,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final built = _buildForFrame(context);

    if (built.segments.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
        decoration: BudgetMonthPieChart.shellDecoration(context),
        child: Text(
          'No budget',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: cs.onSurfaceVariant,
            fontWeight: FontWeight.w500,
          ),
        ),
      );
    }

    return Container(
      width: double.infinity,
      decoration: BudgetMonthPieChart.shellDecoration(context),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.headerHint != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                widget.headerHint!,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: cs.onSurfaceVariant,
                  height: 1.25,
                ),
              ),
            ),
          LayoutBuilder(
            builder: (context, constraints) {
              final w = constraints.maxWidth;
              // Canvas height: enough for ~5 labels each side at ~14 px each.
              // The pie itself is ~60% of w in diameter so h = w * 0.7 works well.
              final h = (w * 0.72).clamp(260.0, 340.0);
              return SizedBox(
                height: h,
                width: w,
                child: Builder(
                  builder: (tapCtx) => GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapUp: (details) {
                      final box = tapCtx.findRenderObject() as RenderBox?;
                      if (box == null) return;
                      final local = box.globalToLocal(details.globalPosition);
                      final idx = _hitTestSegment(local, Size(w, h), built.segments);
                      if (idx == null) return;
                      final seg = built.segments[idx];
                      if (seg.isOthersBucket &&
                          built.othersMembers != null &&
                          built.othersMembers!.isNotEmpty) {
                        _showOthersDialog(
                          context,
                          theme,
                          built.othersMembers!,
                          built.monthGrandTotal ?? built.grandTotal,
                        );
                      }
                    },
                    child: CustomPaint(
                      painter: _BudgetMonthPiePainter(
                        segments: built.segments,
                        grandTotal: built.grandTotal,
                        labelStyle: _labelStyle(theme),
                        pctStyle: _pctStyle(theme),
                        theme: theme,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

TextStyle _labelStyle(ThemeData theme) =>
    theme.textTheme.labelSmall?.copyWith(
      fontWeight: FontWeight.w600,
      fontSize: 10.0,
      height: 1.1,
      color: theme.colorScheme.onSurface,
    ) ??
    TextStyle(fontWeight: FontWeight.w600, fontSize: 10.0, color: theme.colorScheme.onSurface);

TextStyle _pctStyle(ThemeData theme) =>
    theme.textTheme.labelSmall?.copyWith(
      fontWeight: FontWeight.w800,
      fontSize: 9.5,
      height: 1.0,
      color: Colors.white,
      shadows: const [
        Shadow(offset: Offset(0.5, 0.5), blurRadius: 2, color: Color(0x99000000)),
      ],
    ) ??
    const TextStyle(fontWeight: FontWeight.w800, fontSize: 9.5, color: Colors.white);

// ─────────────────────────────────────────────────────────────────────────────
// Build helpers
// ─────────────────────────────────────────────────────────────────────────────

_BudgetPieBuild _buildBudgetPie(
  BuildContext context,
  List<AggregationBarData> raw,
  String othersLabel,
) {
  final positive = raw.where((e) => e.value > 0).toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  if (positive.isEmpty) return _BudgetPieBuild(segments: [], grandTotal: 0);

  final grandTotal = positive.fold<double>(0, (s, e) => s + e.value);
  if (grandTotal <= 0) return _BudgetPieBuild(segments: [], grandTotal: 0);

  List<AggregationBarData>? tail;
  final rows = List<AggregationBarData>.from(
    positive.length <= _kMaxPieSlices ? positive : positive.sublist(0, _kMaxPieSlices),
  );

  if (positive.length > _kMaxPieSlices) {
    tail = positive.sublist(_kMaxPieSlices);
    final othersSum = tail.fold<double>(0, (s, e) => s + e.value);
    rows.add(AggregationBarData(label: othersLabel, value: othersSum, bucket: -1));
  }

  final n = rows.length;
  var start = -math.pi / 2;
  final out = <_PieSegment>[];
  for (var i = 0; i < n; i++) {
    final r = rows[i];
    final sweep = 2 * math.pi * (r.value / grandTotal);
    final pct = r.value / grandTotal * 100.0;
    final isOthers = tail != null && i == n - 1;
    out.add(_PieSegment(
      label: r.label,
      value: r.value,
      startAngle: start,
      sweepAngle: sweep,
      rank: i,
      color: _budgetMonthSliceColor(context, i, n),
      pctOfTotal: pct,
      isOthersBucket: isOthers,
    ));
    start += sweep;
  }
  return _BudgetPieBuild(
    segments: out,
    grandTotal: grandTotal,
    othersMembers: tail,
    monthGrandTotal: grandTotal,
  );
}

/// Drill-down: arc proportional within Others group; % label = share of full month.
_BudgetPieBuild? _buildOthersDrillPie(
  BuildContext context,
  List<AggregationBarData> members,
  double monthGrandTotal,
) {
  if (members.isEmpty || monthGrandTotal <= 0) return null;
  final groupTotal = members.fold<double>(0, (s, e) => s + e.value);
  if (groupTotal <= 0) return null;

  final n = members.length;
  var start = -math.pi / 2;
  final out = <_PieSegment>[];
  for (var i = 0; i < n; i++) {
    final r = members[i];
    final sweep = 2 * math.pi * (r.value / groupTotal);
    final pct = r.value / monthGrandTotal * 100.0; // % of full month total
    out.add(_PieSegment(
      label: r.label,
      value: r.value,
      startAngle: start,
      sweepAngle: sweep,
      rank: i,
      color: _budgetMonthSliceColor(context, i, n),
      pctOfTotal: pct,
      isOthersBucket: false,
    ));
    start += sweep;
  }
  return _BudgetPieBuild(segments: out, grandTotal: monthGrandTotal);
}

Color _budgetMonthSliceColor(BuildContext context, int index, int total) {
  final theme = Theme.of(context);
  final cs = theme.colorScheme;
  final dark = theme.brightness == Brightness.dark;
  final anchors = <Color>[
    cs.primary,
    Color.lerp(cs.primary, const Color(0xFFE07A5F), dark ? 0.42 : 0.32)!,
    Color.lerp(cs.primary, cs.tertiary, 0.45)!,
    Color.lerp(cs.tertiary, const Color(0xFFD4847A), dark ? 0.38 : 0.3)!,
    cs.tertiary,
    Color.lerp(cs.secondary, const Color(0xFFD4A574), dark ? 0.45 : 0.35)!,
    Color.lerp(cs.secondary, cs.primary, 0.42)!,
    Color.lerp(cs.primary, const Color(0xFFB85C38), dark ? 0.35 : 0.28)!,
    Color.lerp(cs.primary, const Color(0xFF9A4E3A), dark ? 0.4 : 0.22)!,
    Color.lerp(cs.tertiary, const Color(0xFFE8A598), dark ? 0.35 : 0.38)!,
    Color.lerp(const Color(0xFFE07A5F), const Color(0xFFD4A574), 0.5)!,
  ];
  if (total <= 1) return anchors[0];
  final u = index / (total - 1);
  final f = u * (anchors.length - 1);
  final i0 = f.floor().clamp(0, anchors.length - 2);
  return Color.lerp(anchors[i0], anchors[i0 + 1], f - i0)!;
}

// ─────────────────────────────────────────────────────────────────────────────
// Hit test
// ─────────────────────────────────────────────────────────────────────────────

int? _hitTestSegment(Offset local, Size size, List<_PieSegment> segments) {
  if (segments.isEmpty) return null;
  final center = _pieCenter(size);
  final minDim = math.min(size.width, size.height);
  final innerR = minDim * _kInnerRatio;
  final outerR = minDim * _kOuterRatio;

  final dx = local.dx - center.dx;
  final dy = local.dy - center.dy;
  final dist = math.sqrt(dx * dx + dy * dy);
  if (dist < innerR * 0.95 || dist > outerR * 1.08) return null;

  var angle = math.atan2(dy, dx);
  var rel = angle - (-math.pi / 2);
  while (rel < 0) rel += 2 * math.pi;
  while (rel >= 2 * math.pi) rel -= 2 * math.pi;

  var acc = 0.0;
  for (var i = 0; i < segments.length; i++) {
    acc += segments[i].sweepAngle;
    if (rel < acc - 1e-10) return i;
  }
  return segments.length - 1;
}

Offset _pieCenter(Size size) => Offset(size.width / 2, size.height * 0.47);

// ─────────────────────────────────────────────────────────────────────────────
// Painter
// ─────────────────────────────────────────────────────────────────────────────

class _BudgetMonthPiePainter extends CustomPainter {
  _BudgetMonthPiePainter({
    required this.segments,
    required this.grandTotal,
    required this.labelStyle,
    required this.pctStyle,
    required this.theme,
  });

  final List<_PieSegment> segments;
  final double grandTotal;
  final TextStyle labelStyle;
  final TextStyle pctStyle;
  final ThemeData theme;

  bool get _dark => theme.brightness == Brightness.dark;

  @override
  void paint(Canvas canvas, Size size) {
    if (segments.isEmpty) return;

    final center = _pieCenter(size);
    final minDim = math.min(size.width, size.height);
    final innerR = minDim * _kInnerRatio;
    final outerR = minDim * _kOuterRatio;
    final depth = outerR * _kDepthRatio;

    _draw3dDonut(canvas, center, innerR, outerR, depth);
    _drawPctLabels(canvas, center, innerR, outerR);
    _drawExternalLabels(canvas, size, center, outerR);
  }

  // ── 3-D donut ──────────────────────────────────────────────────────────────

  void _draw3dDonut(
    Canvas canvas,
    Offset center,
    double innerR,
    double outerR,
    double depth,
  ) {
    // Pass 1 – extruded side walls for front-half (drawn below top face)
    for (final s in segments) {
      _drawSideWall(canvas, center, outerR, innerR, depth, s);
    }

    // Pass 2 – top flat faces with shadow + gradient
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: _dark ? 0.30 : 0.09)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

    for (final s in segments) {
      _drawTopFace(canvas, center, innerR, outerR, s, shadowPaint);
    }

    // Pass 3 – highlight ring on top outer edge
    canvas.drawCircle(
      center,
      outerR - 1,
      Paint()
        ..color = Colors.white.withValues(alpha: _dark ? 0.10 : 0.20)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6,
    );
    // Subtle inner shadow ring
    canvas.drawCircle(
      center,
      innerR,
      Paint()
        ..color = Colors.black.withValues(alpha: _dark ? 0.20 : 0.08)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );
  }

  void _drawSideWall(
    Canvas canvas,
    Offset center,
    double outerR,
    double innerR,
    double depth,
    _PieSegment s,
  ) {
    final clipped = _clipToFrontHalf(s.startAngle, s.sweepAngle);
    if (clipped == null) return;
    final (cStart, cSweep) = clipped;

    // Outer wall – darkened slice colour
    final outerWallColor =
        Color.lerp(s.color, Colors.black, _dark ? 0.48 : 0.38)!.withValues(alpha: 0.95);
    _drawExtrudedBand(canvas, center, outerR, depth, cStart, cSweep, outerWallColor);

    // Inner wall – slightly lighter (ambient bounce)
    final innerWallColor =
        Color.lerp(s.color, Colors.black, _dark ? 0.30 : 0.22)!.withValues(alpha: 0.80);
    _drawExtrudedBand(canvas, center, innerR, depth, cStart, cSweep, innerWallColor);
  }

  void _drawExtrudedBand(
    Canvas canvas,
    Offset center,
    double r,
    double depth,
    double startAngle,
    double sweepAngle,
    Color color,
  ) {
    final path = Path();
    // Top arc
    path.moveTo(
      center.dx + r * math.cos(startAngle),
      center.dy + r * math.sin(startAngle),
    );
    path.arcTo(Rect.fromCircle(center: center, radius: r), startAngle, sweepAngle, false);
    // Right edge down
    final endAngle = startAngle + sweepAngle;
    path.lineTo(
      center.dx + r * math.cos(endAngle),
      center.dy + r * math.sin(endAngle) + depth,
    );
    // Bottom arc reversed
    path.arcTo(
      Rect.fromCircle(center: Offset(center.dx, center.dy + depth), radius: r),
      endAngle,
      -sweepAngle,
      false,
    );
    path.close();
    canvas.drawPath(path, Paint()..color = color..style = PaintingStyle.fill);
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.15)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.5,
    );
  }

  void _drawTopFace(
    Canvas canvas,
    Offset center,
    double innerR,
    double outerR,
    _PieSegment s,
    Paint shadowPaint,
  ) {
    if (s.sweepAngle <= 0) return;
    final path = _annularSectorPath(center, innerR, outerR, s.startAngle, s.sweepAngle);
    final bounds = path.getBounds();

    // Shadow
    canvas.save();
    canvas.translate(1.5, 2.0);
    canvas.drawPath(path, shadowPaint);
    canvas.restore();

    // Gradient: light top-left → darker bottom-right
    final light = Color.lerp(s.color, Colors.white, _dark ? 0.14 : 0.30)!;
    final dark2 = Color.lerp(s.color, Colors.black, _dark ? 0.28 : 0.20)!;
    canvas.drawPath(
      path,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(bounds.left, bounds.top),
          Offset(bounds.right, bounds.bottom),
          [light, dark2],
        )
        ..style = PaintingStyle.fill,
    );

    // Slice border
    canvas.drawPath(
      path,
      Paint()
        ..color = Color.lerp(s.color, Colors.black, 0.42)!.withValues(alpha: 0.50)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8,
    );
  }

  // ── % labels inside ring ───────────────────────────────────────────────────

  void _drawPctLabels(Canvas canvas, Offset center, double innerR, double outerR) {
    if (grandTotal <= 0) return;
    final bandR = (innerR + outerR) / 2;
    for (final s in segments) {
      if (s.sweepAngle < 0.10) continue;
      final mid = s.startAngle + s.sweepAngle / 2;
      final pctText = s.pctOfTotal >= 10
          ? '${s.pctOfTotal.round()}%'
          : '${s.pctOfTotal.toStringAsFixed(1)}%';
      final tp = TextPainter(
        text: TextSpan(text: pctText, style: pctStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(
        canvas,
        Offset(
          center.dx + bandR * math.cos(mid) - tp.width / 2,
          center.dy + bandR * math.sin(mid) - tp.height / 2,
        ),
      );
    }
  }


  // Labels placed in a ring around the pie at a fixed label radius.
  // Anchor angles start at each slice's mid-angle then get pushed apart
  // iteratively so no two labels overlap. Because labels stay in clockwise
  // slice order and each leader line goes from rim straight to its own
  // label anchor, lines NEVER cross. Bezier curve gives a clean look.
  void _drawExternalLabels(Canvas canvas, Size size, Offset center, double outerR) {
    if (segments.isEmpty) return;

    final n = segments.length;
    final minDim = math.min(size.width, size.height);
    final maxLabelW = (minDim * 0.26).clamp(55.0, 115.0);

    // Label anchors sit on a circle slightly outside the pie
    final labelR = outerR + outerR * 0.45;

    // Minimum angular gap between adjacent label anchors (~24px arc length)
    final minAngSep = 24.0 / labelR;

    // Collect mid-angles in original slice order
    final placed = segments
        .map((s) => s.startAngle + s.sweepAngle / 2)
        .toList();

    // Iteratively push overlapping anchors apart while preserving order
    for (var iter = 0; iter < 80; iter++) {
      final order = List<int>.generate(n, (i) => i)
        ..sort((a, b) => placed[a].compareTo(placed[b]));
      var changed = false;
      for (var k = 0; k < n; k++) {
        final a = order[k];
        final b = order[(k + 1) % n];
        var diff = placed[b] - placed[a];
        if (k == n - 1) diff += 2 * math.pi;
        if (diff < minAngSep) {
          final push = (minAngSep - diff) / 2.0;
          placed[a] -= push;
          placed[b] += push;
          changed = true;
        }
      }
      if (!changed) break;
    }

    const dotR = 2.5;

    for (var i = 0; i < n; i++) {
      final s        = segments[i];
      final sliceMid = s.startAngle + s.sweepAngle / 2;
      final labelAng = placed[i];
      final cosL     = math.cos(labelAng);
      final sinL     = math.sin(labelAng);
      final isRight  = cosL >= 0;

      // Rim dot
      final rimPt = Offset(
        center.dx + outerR * math.cos(sliceMid),
        center.dy + outerR * math.sin(sliceMid),
      );

      // Label anchor on the label ring
      final anchorPt = Offset(
        center.dx + labelR * cosL,
        center.dy + labelR * sinL,
      );

      // Bezier control: halfway between rim and anchor, pulled radially outward
      // along the bisecting angle -- gives a smooth outward-curving line
      final bisectAngle = sliceMid + _angleDiff(labelAng, sliceMid) * 0.5;
      final ctrlR = outerR + outerR * 0.18;
      final ctrlPt = Offset(
        center.dx + ctrlR * math.cos(bisectAngle),
        center.dy + ctrlR * math.sin(bisectAngle),
      );

      final linePaint = Paint()
        ..color = s.color.withValues(alpha: 0.68)
        ..strokeWidth = 1.0
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      canvas.drawPath(
        Path()
          ..moveTo(rimPt.dx, rimPt.dy)
          ..quadraticBezierTo(ctrlPt.dx, ctrlPt.dy, anchorPt.dx, anchorPt.dy),
        linePaint,
      );

      // Rim dot
      canvas.drawCircle(rimPt, dotR, Paint()..color = s.color);

      // Label: left-aligned on right half, right-aligned on left half
      final tp = TextPainter(
        text: TextSpan(text: s.label, style: labelStyle),
        textDirection: TextDirection.ltr,
        textAlign: isRight ? TextAlign.left : TextAlign.right,
        maxLines: 2,
        ellipsis: '...',
      )..layout(maxWidth: maxLabelW);

      final lx = isRight ? anchorPt.dx + 3 : anchorPt.dx - 3 - tp.width;
      final ly = anchorPt.dy - tp.height / 2;

      // Clamp within canvas
      final clampedLx = lx.clamp(2.0, size.width - tp.width - 2);
      final clampedLy = ly.clamp(2.0, size.height - tp.height - 2);
      tp.paint(canvas, Offset(clampedLx, clampedLy));
    }
  }

  // Signed angular difference from [from] to [to] in (-pi, pi]
  double _angleDiff(double to, double from) {
    var d = to - from;
    while (d > math.pi) d -= 2 * math.pi;
    while (d <= -math.pi) d += 2 * math.pi;
    return d;
  }


  // ── Geometry helpers ───────────────────────────────────────────────────────

  Path _annularSectorPath(
    Offset c,
    double innerR,
    double outerR,
    double start,
    double sweep,
  ) {
    final p = Path();
    p.moveTo(c.dx + outerR * math.cos(start), c.dy + outerR * math.sin(start));
    p.arcTo(Rect.fromCircle(center: c, radius: outerR), start, sweep, false);
    p.lineTo(
      c.dx + innerR * math.cos(start + sweep),
      c.dy + innerR * math.sin(start + sweep),
    );
    p.arcTo(Rect.fromCircle(center: c, radius: innerR), start + sweep, -sweep, false);
    p.close();
    return p;
  }

  /// Clips angle range to front-facing half (sin > 0 → angles 0..π).
  /// Returns null if entirely in the back half.
  (double, double)? _clipToFrontHalf(double start, double sweep) {
    // Normalise start into [−π, π] so arithmetic is consistent
    var s = start % (2 * math.pi);
    if (s > math.pi) s -= 2 * math.pi;
    if (s < -math.pi) s += 2 * math.pi;

    final end = s + sweep;
    final cs = math.max(s, 0.0);
    final ce = math.min(end, math.pi);
    if (ce <= cs + 1e-6) return null;
    return (cs, ce - cs);
  }

  @override
  bool shouldRepaint(covariant _BudgetMonthPiePainter old) =>
      old.segments != segments || old.grandTotal != grandTotal || old.theme != theme;
}