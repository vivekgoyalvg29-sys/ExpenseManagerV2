import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class MonthNavigatorRow extends StatelessWidget {
  final DateTime currentMonth;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final Widget? trailing;

  const MonthNavigatorRow({
    super.key,
    required this.currentMonth,
    required this.onPrev,
    required this.onNext,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          onPressed: onPrev,
          icon: const Icon(Icons.arrow_left),
          constraints: const BoxConstraints.tightFor(width: 36, height: 36),
          padding: EdgeInsets.zero,
          visualDensity: VisualDensity.compact,
        ),
        Expanded(
          child: Text(
            DateFormat('MMMM yyyy').format(currentMonth),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        IconButton(
          onPressed: onNext,
          icon: const Icon(Icons.arrow_right),
          constraints: const BoxConstraints.tightFor(width: 36, height: 36),
          padding: EdgeInsets.zero,
          visualDensity: VisualDensity.compact,
        ),
        if (trailing != null) ...[
          const SizedBox(width: 4),
          trailing!,
        ],
      ],
    );
  }
}
