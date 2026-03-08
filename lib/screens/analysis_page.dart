import 'package:flutter/material.dart';
import '../widgets/month_header.dart';
import '../services/data_store.dart';

class AnalysisPage extends StatefulWidget {
  @override
  _AnalysisPageState createState() => _AnalysisPageState();
}

class _AnalysisPageState extends State<AnalysisPage> {

  DateTime currentMonth = DateTime.now();

  @override
  Widget build(BuildContext context) {

    List<Map<String, dynamic>> analysisData = [];

    for (var category in DataStore.categories) {

      String name = category["name"]!;

      double spent = DataStore.transactions
          .where((t) =>
              t["title"] == name &&
              t["date"].month == currentMonth.month &&
              t["date"].year == currentMonth.year)
          .fold(0, (sum, t) => sum + t["amount"]);

      double budget = DataStore.budgets
          .where((b) =>
              b["category"] == name &&
              b["month"] == currentMonth.month &&
              b["year"] == currentMonth.year)
          .fold(0, (sum, b) => sum + b["amount"]);

      if (spent > 0 || budget > 0) {
        analysisData.add({
          "category": name,
          "spent": spent,
          "budget": budget
        });
      }
    }

    return Scaffold(

      body: Column(
        children: [

          MonthHeader(
            currentMonth: currentMonth,
            onPrev: () {
              setState(() {
                currentMonth =
                    DateTime(currentMonth.year, currentMonth.month - 1);
              });
            },
            onNext: () {
              setState(() {
                currentMonth =
                    DateTime(currentMonth.year, currentMonth.month + 1);
              });
            },
          ),

          Expanded(
            child: analysisData.isEmpty
                ? Center(child: Text("No data available"))
                : ListView.builder(
                    itemCount: analysisData.length,
                    itemBuilder: (context, index) {

                      final data = analysisData[index];

                      double spent = data["spent"];
                      double budget = data["budget"];

                      double progress =
                          budget == 0 ? 0 : (spent / budget).clamp(0, 1);

                      return Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),

                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,

                          children: [

                            Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              children: [

                                Text(
                                  data["category"],
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),

                                Text(
                                  "₹${spent.toStringAsFixed(0)} / ₹${budget.toStringAsFixed(0)}",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),

                              ],
                            ),

                            const SizedBox(height: 6),

                            LinearProgressIndicator(
                              value: progress,
                              minHeight: 8,
                            ),

                          ],
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
