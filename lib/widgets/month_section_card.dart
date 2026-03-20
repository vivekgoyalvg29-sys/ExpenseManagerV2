import 'package:flutter/material.dart';

import 'month_navigator_row.dart';
import 'section_tile.dart';

class MonthSectionCard extends StatelessWidget {
  final DateTime currentMonth;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final Widget child;
  final Widget? action;

  const MonthSectionCard({
    super.key,
    required this.currentMonth,
    required this.onPrev,
    required this.onNext,
    required this.child,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return SectionTile(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                MonthNavigatorRow(
                  currentMonth: currentMonth,
                  onPrev: onPrev,
                  onNext: onNext,
                ),
                if (action != null)
                  Positioned(
                    right: 0,
                    child: action!,
                  ),
              ],
            ),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }
}
