import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'aggregation_bar_chart.dart';

/// Smooth line chart for the same [AggregationBarData] series as [AggregationBarChart].
///
/// Shows at most [maxViewportPoints] buckets in the viewport width; additional points
/// are reached by horizontal scrolling.
class AggregationSmoothLineChart extends StatefulWidget {
  final List<AggregationBarData> data;
  final String emptyMessage;
  final Widget Function(BuildContext context, AggregationBarData item)? labelBuilder;
  final double chartHeight;
  final ValueChanged<AggregationBarData>? onPointTap;
  final int? selectedBucket;
  final Widget? trailing;
  /// Optional row inside the chart card (e.g. Day / Week toggle), above the plot.
  final Widget? chartHeader;
  /// Placed at the top-right inside the plot area (e.g. Day/Week toggle, clear filter).
  final Widget? plotTopRightOverlay;
  /// Icons or widgets aligned above each bucket (e.g. category icons on Budget month view).
  final Widget Function(BuildContext context, AggregationBarData item)? topIconRowBuilder;
  /// When true, x-axis labels (and optional [pointValueLabels]) are drawn vertically to save width.
  final bool verticalAxisLabels;
  /// Optional per-point spend labels (e.g. currency), same length as [data].
  final List<String>? pointValueLabels;
  /// How many data points fit in the visible width before horizontal scroll is needed.
  final int maxViewportPoints;
  /// When true, y-axis uses min..max of the series (with padding) so flat series fills the plot.
  final bool compactYRange;

  const AggregationSmoothLineChart({
    super.key,
    required this.data,
    required this.emptyMessage,
    this.labelBuilder,
    this.chartHeight = 200,
    this.onPointTap,
    this.selectedBucket,
    this.trailing,
    this.chartHeader,
    this.plotTopRightOverlay,
    this.topIconRowBuilder,
    this.verticalAxisLabels = false,
    this.pointValueLabels,
    this.maxViewportPoints = 12,
    this.compactYRange = false,
  });

  /// Month / bucket label font size when many points share the width.
  static double axisLabelFontSizeForCount(int n) {
    if (n > 18) return 8;
    if (n > 12) return 9.5;
    return 11;
  }

  static BoxDecoration _shellDecoration(BuildContext context) {
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
  State<AggregationSmoothLineChart> createState() => _AggregationSmoothLineChartState();
}

class _AggregationSmoothLineChartState extends State<AggregationSmoothLineChart> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToEndIfNeeded());
  }

  @override
  void didUpdateWidget(covariant AggregationSmoothLineChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Only auto-scroll when the series actually changes (not selection-only rebuilds).
    if (!listEquals(oldWidget.data, widget.data)) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToEndIfNeeded());
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToEndIfNeeded() {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    if (pos.maxScrollExtent > 0) {
      _scrollController.jumpTo(pos.maxScrollExtent);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    if (widget.data.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
        decoration: AggregationSmoothLineChart._shellDecoration(context),
        child: Text(
          widget.emptyMessage,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: cs.onSurfaceVariant,
            fontWeight: FontWeight.w500,
            height: 1.35,
          ),
        ),
      );
    }

    final maxValue = widget.data.fold<double>(0, (m, item) => item.value > m ? item.value : m);
    final normalizedMax = maxValue <= 0 ? 1.0 : maxValue;
    final axisFs = AggregationSmoothLineChart.axisLabelFontSizeForCount(widget.data.length);
    final valueFs = widget.data.length > 14 ? 8.0 : 9.0;
    final accentColors = [for (final item in widget.data) aggregationBarAccentColor(context, item)];
    final valueLabels = widget.pointValueLabels;
    final showValues =
        valueLabels != null && valueLabels.length == widget.data.length;

    return Container(
      decoration: AggregationSmoothLineChart._shellDecoration(context),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.chartHeader != null ||
              (widget.trailing != null && widget.plotTopRightOverlay == null))
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (widget.chartHeader != null)
                    Flexible(child: widget.chartHeader!),
                  if (widget.trailing != null) ...[
                    const Spacer(),
                    Material(
                      type: MaterialType.transparency,
                      child: widget.trailing!,
                    ),
                  ],
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(2, 0, 2, 2),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final viewportW = constraints.maxWidth;
                final n = widget.data.length;
                final maxPts = widget.maxViewportPoints.clamp(1, 999);
                final slotW = viewportW / maxPts;
                final chartW = n <= maxPts ? viewportW : slotW * n;

                return SingleChildScrollView(
                  controller: _scrollController,
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: chartW,
                    child: _ChartBody(
                      data: widget.data,
                      normalizedMax: normalizedMax,
                      accentColors: accentColors,
                      selectedBucket: widget.selectedBucket,
                      chartHeight: widget.chartHeight,
                      onPointTap: widget.onPointTap,
                      labelBuilder: widget.labelBuilder,
                      verticalAxisLabels: widget.verticalAxisLabels,
                      valueLabels: showValues ? valueLabels : null,
                      contentWidth: chartW,
                      plotTopRightOverlay: widget.plotTopRightOverlay,
                      topIconRowBuilder: widget.topIconRowBuilder,
                      compactYRange: widget.compactYRange,
                      axisLabelFontSize: axisFs,
                      valueLabelFontSize: valueFs,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Frosted pill for axis labels (day / week / month text).
Widget glassAggregationAxisLabel(
  BuildContext context,
  String text, {
  bool vertical = false,
  double fontSize = 11,
}) {
  final theme = Theme.of(context);
  final cs = theme.colorScheme;
  final child = Text(
    text,
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
    textAlign: TextAlign.center,
    style: theme.textTheme.labelMedium?.copyWith(
      fontSize: fontSize,
      fontWeight: FontWeight.w600,
      color: cs.onSurface.withValues(alpha: 0.92),
    ),
  );
  final padded = Padding(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
    child: vertical
        ? RotatedBox(
            quarterTurns: 3,
            child: child,
          )
        : child,
  );
  return ClipRRect(
    borderRadius: BorderRadius.circular(999),
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: cs.surface.withValues(alpha: theme.brightness == Brightness.dark ? 0.38 : 0.72),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: cs.outline.withValues(alpha: 0.22),
          ),
        ),
        child: padded,
      ),
    ),
  );
}

class _ChartBody extends StatelessWidget {
  const _ChartBody({
    required this.data,
    required this.normalizedMax,
    required this.accentColors,
    required this.selectedBucket,
    required this.chartHeight,
    required this.onPointTap,
    required this.labelBuilder,
    required this.verticalAxisLabels,
    required this.valueLabels,
    required this.contentWidth,
    this.plotTopRightOverlay,
    this.topIconRowBuilder,
    this.compactYRange = false,
    this.axisLabelFontSize = 11,
    this.valueLabelFontSize = 9,
  });

  final List<AggregationBarData> data;
  final double normalizedMax;
  final List<Color> accentColors;
  final int? selectedBucket;
  final double chartHeight;
  final ValueChanged<AggregationBarData>? onPointTap;
  final Widget Function(BuildContext context, AggregationBarData item)? labelBuilder;
  final bool verticalAxisLabels;
  final List<String>? valueLabels;
  /// Total painted width (scrollable content width).
  final double contentWidth;
  final Widget? plotTopRightOverlay;
  final Widget Function(BuildContext context, AggregationBarData item)? topIconRowBuilder;
  final bool compactYRange;
  final double axisLabelFontSize;
  final double valueLabelFontSize;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final showValues = valueLabels != null && valueLabels!.length == data.length;
    final chartW = contentWidth;
    final yRange = _yRangeForLine(data, normalizedMax, compactYRange);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (topIconRowBuilder != null) ...[
          SizedBox(
            height: 26,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final item in data)
                  SizedBox(
                    width: chartW / data.length,
                    child: Center(child: topIconRowBuilder!(context, item)),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 4),
        ],
        SizedBox(
          height: chartHeight,
          child: LayoutBuilder(
            builder: (context, c) {
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTapUp: (d) {
                        final box = context.findRenderObject() as RenderBox?;
                        if (box == null) return;
                        final local = box.globalToLocal(d.globalPosition);
                        final idx = _indexForTapX(local.dx, chartW, data.length);
                        if (idx != null) {
                          HapticFeedback.selectionClick();
                          onPointTap?.call(data[idx]);
                        }
                      },
                      child: CustomPaint(
                        size: Size(c.maxWidth, c.maxHeight),
                        painter: _SmoothLineChartPainter(
                          data: data,
                          maxValue: normalizedMax,
                          yMin: yRange.min,
                          yMax: yRange.max,
                          selectedBucket: selectedBucket,
                          lineColor: cs.primary.withValues(alpha: 0.92),
                          surfaceColor: cs.surface,
                          accentColors: accentColors,
                        ),
                      ),
                    ),
                  ),
                  if (plotTopRightOverlay != null)
                    Positioned(
                      top: 2,
                      right: 4,
                      child: Material(
                        type: MaterialType.transparency,
                        child: plotTopRightOverlay!,
                      ),
                    ),
                ],
              );
            },
          ),
        ),
        if (showValues) ...[
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              for (var i = 0; i < data.length; i++)
                SizedBox(
                  width: chartW / data.length,
                  child: Center(
                    child: verticalAxisLabels
                        ? RotatedBox(
                            quarterTurns: 3,
                            child: Text(
                              valueLabels![i],
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: theme.textTheme.labelSmall?.copyWith(
                                fontSize: valueLabelFontSize,
                                fontWeight: FontWeight.w500,
                                color: cs.onSurfaceVariant.withValues(alpha: 0.65),
                              ),
                            ),
                          )
                        : Text(
                            valueLabels![i],
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontSize: valueLabelFontSize + 1,
                              fontWeight: FontWeight.w500,
                              color: cs.onSurfaceVariant.withValues(alpha: 0.65),
                            ),
                          ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 2),
        ],
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            for (final item in data)
              SizedBox(
                width: chartW / data.length,
                child: Center(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: onPointTap == null
                        ? null
                        : () {
                            HapticFeedback.selectionClick();
                            onPointTap!(item);
                          },
                    child: labelBuilder != null
                        ? labelBuilder!(context, item)
                        : glassAggregationAxisLabel(
                            context,
                            item.label,
                            vertical: verticalAxisLabels,
                            fontSize: axisLabelFontSize,
                          ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

({double min, double max}) _yRangeForLine(
  List<AggregationBarData> data,
  double normalizedMax,
  bool compactYRange,
) {
  if (data.isEmpty) return (min: 0.0, max: normalizedMax <= 0 ? 1.0 : normalizedMax);
  if (!compactYRange) {
    final m = normalizedMax <= 0 ? 1.0 : normalizedMax;
    return (min: 0.0, max: m);
  }
  final vals = data.map((e) => e.value).toList();
  var minV = vals.reduce(math.min);
  var maxV = vals.reduce(math.max);
  var span = maxV - minV;
  if (span <= 0) {
    final m = maxV <= 0 ? 1.0 : maxV;
    return (min: 0.0, max: m);
  }
  final pad = span * 0.12;
  minV = (minV - pad).clamp(0.0, double.infinity);
  maxV = maxV + pad;
  if (maxV <= minV) maxV = minV + 1e-6;
  return (min: minV, max: maxV);
}

int? _indexForTapX(double x, double width, int n) {
  if (n <= 0) return null;
  if (n == 1) return 0;
  const pad = 12.0;
  final inner = width - 2 * pad;
  if (inner <= 0) return null;
  final t = ((x - pad) / inner).clamp(0.0, 1.0);
  final idx = (t * (n - 1)).round();
  return idx.clamp(0, n - 1);
}

class _SmoothLineChartPainter extends CustomPainter {
  _SmoothLineChartPainter({
    required this.data,
    required this.maxValue,
    required this.yMin,
    required this.yMax,
    required this.selectedBucket,
    required this.lineColor,
    required this.surfaceColor,
    required this.accentColors,
  });

  final List<AggregationBarData> data;
  final double maxValue;
  final double yMin;
  final double yMax;
  final int? selectedBucket;
  final Color lineColor;
  final Color surfaceColor;
  final List<Color> accentColors;

  static const _padH = 12.0;
  static const _padV = 14.0;

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;
    final n = data.length;
    final pts = <Offset>[];
    final innerW = size.width - 2 * _padH;
    final innerH = size.height - 2 * _padV;
    final denom = (yMax - yMin).abs() < 1e-9 ? 1.0 : (yMax - yMin);
    for (var i = 0; i < n; i++) {
      final x = n == 1 ? size.width / 2 : _padH + innerW * (i / (n - 1));
      final v = data[i].value.clamp(yMin, yMax);
      final ratio = ((v - yMin) / denom).clamp(0.0, 1.0);
      final y = _padV + innerH * (1.0 - ratio);
      pts.add(Offset(x, y));
    }

    final smooth = _smoothPath(pts);
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    canvas.save();
    canvas.translate(0, 2);
    canvas.drawPath(smooth, shadowPaint);
    canvas.restore();

    final linePaint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(smooth, linePaint);

    for (var i = 0; i < n; i++) {
      final p = pts[i];
      final selected = selectedBucket != null && selectedBucket == data[i].bucket;
      final accent = accentColors[i];
      final fill = selected ? Colors.white : surfaceColor;
      final ring = selected ? accent : lineColor;
      canvas.drawCircle(
        p,
        selected ? 7.0 : 4.5,
        Paint()..color = fill,
      );
      canvas.drawCircle(
        p,
        selected ? 7.0 : 4.5,
        Paint()
          ..color = ring
          ..style = PaintingStyle.stroke
          ..strokeWidth = selected ? 2.2 : 1.2,
      );
    }
  }

  Path _smoothPath(List<Offset> pts) {
    final path = Path();
    if (pts.isEmpty) return path;
    if (pts.length == 1) {
      path.moveTo(pts[0].dx, pts[0].dy);
      return path;
    }
    path.moveTo(pts[0].dx, pts[0].dy);
    for (var i = 0; i < pts.length - 1; i++) {
      final p0 = i > 0 ? pts[i - 1] : pts[i];
      final p1 = pts[i];
      final p2 = pts[i + 1];
      final p3 = i + 2 < pts.length ? pts[i + 2] : p2;
      final cp1 = Offset(
        p1.dx + (p2.dx - p0.dx) / 6,
        p1.dy + (p2.dy - p0.dy) / 6,
      );
      final cp2 = Offset(
        p2.dx - (p3.dx - p1.dx) / 6,
        p2.dy - (p3.dy - p1.dy) / 6,
      );
      path.cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, p2.dx, p2.dy);
    }
    return path;
  }

  @override
  bool shouldRepaint(covariant _SmoothLineChartPainter oldDelegate) {
    return oldDelegate.data != data ||
        oldDelegate.maxValue != maxValue ||
        oldDelegate.yMin != yMin ||
        oldDelegate.yMax != yMax ||
        oldDelegate.selectedBucket != selectedBucket ||
        oldDelegate.lineColor != lineColor ||
        oldDelegate.surfaceColor != surfaceColor ||
        oldDelegate.accentColors != accentColors;
  }
}
