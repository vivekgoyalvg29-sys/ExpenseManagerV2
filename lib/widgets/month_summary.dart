import 'package:flutter/material.dart';

class MonthSummary extends StatelessWidget {

  final double income;
  final double expense;

  const MonthSummary({
    required this.income,
    required this.expense,
  });

  @override
  Widget build(BuildContext context) {

    double remaining = income - expense;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),

      child: Column(
        children: [

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: const [

              Text("Income",
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14)),

              Text("Expense",
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14)),

              Text("Remaining",
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14)),

            ],
          ),

          const SizedBox(height: 6),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [

              Text("₹${income.toStringAsFixed(0)}",
                  style: TextStyle(
                      color: Colors.green,
                      fontSize: 18,
                      fontWeight: FontWeight.bold)),

              Text("₹${expense.toStringAsFixed(0)}",
                  style: TextStyle(
                      color: Colors.red,
                      fontSize: 18,
                      fontWeight: FontWeight.bold)),

              Text("₹${remaining.toStringAsFixed(0)}",
                  style: TextStyle(
                      color: remaining >= 0
                          ? Colors.blue
                          : Colors.red,
                      fontSize: 18,
                      fontWeight: FontWeight.bold)),

            ],
          )

        ],
      ),
    );
  }
}
