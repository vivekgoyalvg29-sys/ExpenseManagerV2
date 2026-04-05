import 'package:flutter/material.dart';

import 'month_navigator_row.dart';
import 'section_tile.dart';

class MonthSectionCard extends StatelessWidget {
  final DateTime currentMonth;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final Widget child;
  final Widget? monthTrailing;

  /// Shown in a very light line under the month row (e.g. aggregation mode).
  final String? aggregationSubtitle;

  const MonthSectionCard({
    super.key,
    required this.currentMonth,
    required this.onPrev,
    required this.onNext,
    required this.child,
    this.monthTrailing,
    this.aggregationSubtitle,
  });

  @override
  Widget build(BuildContext context) {
    return SectionTile(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            MonthNavigatorRow(
              currentMonth: currentMonth,
              onPrev: onPrev,
              onNext: onNext,
              trailing: monthTrailing,
            ),
            if (aggregationSubtitle != null && aggregationSubtitle!.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                aggregationSubtitle!,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontSize: 10.5,
                      height: 1.05,
                      fontWeight: FontWeight.w400,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurfaceVariant
                          .withValues(alpha: 0.55),
                    ),
              ),
            ],
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }
}
