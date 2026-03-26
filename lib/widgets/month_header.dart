import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'section_tile.dart';

class MonthHeader extends StatelessWidget {
  final DateTime currentMonth;
  final Function onPrev;
  final Function onNext;
  final Widget? trailing;

  const MonthHeader({
    required this.currentMonth,
    required this.onPrev,
    required this.onNext,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return SectionTile(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [

          IconButton(
            icon: const Icon(Icons.arrow_left),
            onPressed: () => onPrev(),
          ),

          Text(
            DateFormat('MMMM yyyy').format(currentMonth),
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),

          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_right),
                onPressed: () => onNext(),
              ),
              if (trailing != null) trailing!,
            ],
          ),
        ],
      ),
    );
  }
}
