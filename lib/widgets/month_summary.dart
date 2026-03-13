import 'package:flutter/material.dart';
import 'section_tile.dart';

class MonthSummary extends StatelessWidget {
  final double budget;
  final double expense;
  final Widget? trailing;

  const MonthSummary({
    super.key,
    required this.budget,
    required this.expense,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final remaining = budget - expense;

    return SectionTile(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          children: [
            if (trailing != null)
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [trailing!],
              ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: const [
                Text("Budget", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                Text("Expense", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                Text("Remaining", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Text(
                  "₹${budget.toStringAsFixed(0)}",
                  style: const TextStyle(
                    color: Colors.green,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  "₹${expense.toStringAsFixed(0)}",
                  style: const TextStyle(
                    color: Colors.red,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  "₹${remaining.toStringAsFixed(0)}",
                  style: TextStyle(
                    color: remaining >= 0 ? Colors.blue : Colors.red,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
