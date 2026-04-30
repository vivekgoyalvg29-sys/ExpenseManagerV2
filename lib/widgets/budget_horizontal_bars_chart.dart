import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../utils/indian_number_formatter.dart';
import 'aggregation_bar_chart.dart';

/// Scrollable horizontal bars: label + amount (currency) + bar length by value. No percentages.
class BudgetHorizontalBarsChart extends StatelessWidget {
  const BudgetHorizontalBarsChart({
    super.key,
    required this.data,
    required this.emptyMessage,
    this.onBarTap,
    this.selectedBucket,
    this.plotTopRightOverlay,
    this.headerHint,
    this.leadingBuilder,
    this.categoryLabelMaxLen = 0,
    this.maxBodyHeight = 240,
  });

  final List<AggregationBarData> data;
  final String emptyMessage;
  final ValueChanged<AggregationBarData>? onBarTap;
  final int? selectedBucket;
  final Widget? plotTopRightOverlay;
  final String? headerHint;
  final Widget Function(BuildContext context, AggregationBarData item)? leadingBuilder;
  /// When > 0, category names are truncated to this many characters with `..`.
  final int categoryLabelMaxLen;
  final double maxBodyHeight;

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

  String _displayLabel(String raw) {
    if (categoryLabelMaxLen <= 0 || raw.length <= categoryLabelMaxLen) return raw;
    return '${raw.substring(0, categoryLabelMaxLen)}..';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    if (data.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
        decoration: _shellDecoration(context),
        child: Text(
          emptyMessage,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: cs.onSurfaceVariant,
            fontWeight: FontWeight.w500,
            height: 1.35,
          ),
        ),
      );
    }

    var maxV = 0.0;
    for (final item in data) {
      if (item.value > maxV) maxV = item.value;
    }
    if (maxV <= 0) maxV = 1.0;

    return Container(
      width: double.infinity,
      decoration: _shellDecoration(context),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (plotTopRightOverlay != null || headerHint != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (headerHint != null)
                    Expanded(
                      child: Text(
                        headerHint!,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: cs.onSurfaceVariant,
                          height: 1.25,
                        ),
                      ),
                    )
                  else
                    const Spacer(),
                  if (plotTopRightOverlay != null)
                    Material(
                      type: MaterialType.transparency,
                      child: plotTopRightOverlay!,
                    ),
                ],
              ),
            ),
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxBodyHeight),
            child: Scrollbar(
              thumbVisibility: data.length > 6,
              child: ListView.separated(
                shrinkWrap: true,
                physics: const ClampingScrollPhysics(),
                itemCount: data.length,
                separatorBuilder: (_, __) => const SizedBox(height: 4),
                itemBuilder: (context, index) {
                  final item = data[index];
                  final selected =
                      selectedBucket != null && selectedBucket == item.bucket;
                  final accent = aggregationBarAccentColor(context, item);
                  final label = categoryLabelMaxLen > 0
                      ? _displayLabel(item.label)
                      : item.label;
                  final amt = formatIndianCurrency(item.value);
                  final t = onBarTap;

                  return Material(
                    color: selected
                        ? cs.primaryContainer.withValues(alpha: 0.35)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    child: InkWell(
                      onTap: t == null
                          ? null
                          : () {
                              HapticFeedback.selectionClick();
                              t(item);
                            },
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 6,
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            if (leadingBuilder != null) ...[
                              leadingBuilder!(context, item),
                              const SizedBox(width: 6),
                            ],
                            Expanded(
                              flex: 5,
                              child: Text(
                                label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: cs.onSurface,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 6,
                              child: LayoutBuilder(
                                builder: (context, c) {
                                  final w =
                                      c.maxWidth * (item.value / maxV).clamp(0.0, 1.0);
                                  return Stack(
                                    clipBehavior: Clip.none,
                                    alignment: Alignment.centerLeft,
                                    children: [
                                      Container(
                                        height: 10,
                                        width: c.maxWidth,
                                        decoration: BoxDecoration(
                                          color: cs.surfaceContainerHighest
                                              .withValues(alpha: 0.9),
                                          borderRadius:
                                              BorderRadius.circular(999),
                                          border: Border.all(
                                            color: cs.outline
                                                .withValues(alpha: 0.15),
                                          ),
                                        ),
                                      ),
                                      Container(
                                        height: 10,
                                        width: w,
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: [
                                              accent,
                                              Color.lerp(
                                                    Colors.white,
                                                    accent,
                                                    0.35,
                                                  ) ??
                                                  accent,
                                            ],
                                          ),
                                          borderRadius:
                                              BorderRadius.circular(999),
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 78,
                              child: Text(
                                amt,
                                textAlign: TextAlign.right,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 11,
                                  color: cs.onSurface,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
