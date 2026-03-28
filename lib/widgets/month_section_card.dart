import 'package:flutter/material.dart';

import 'month_navigator_row.dart';
import 'section_tile.dart';

class MonthSectionCard extends StatelessWidget {
  final DateTime currentMonth;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final Widget child;
  final Widget? monthTrailing;
  final double contentHeight;

  const MonthSectionCard({
    super.key,
    required this.currentMonth,
    required this.onPrev,
    required this.onNext,
    required this.child,
    this.monthTrailing,
    this.contentHeight = 58,
  });

  @override
  Widget build(BuildContext context) {
    return SectionTile(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Column(
          children: [
            MonthNavigatorRow(
              currentMonth: currentMonth,
              onPrev: onPrev,
              onNext: onNext,
              trailing: monthTrailing,
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: contentHeight,
              child: Center(child: child),
            ),
          ],
        ),
      ),
    );
  }
}
