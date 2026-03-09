import 'package:flutter/material.dart';
import '../widgets/month_header.dart';
import '../widgets/month_summary.dart';
import '../services/database_service.dart';

class AnalysisPage extends StatefulWidget {
  @override
  _AnalysisPageState createState() => _AnalysisPageState();
}

class _AnalysisPageState extends State<AnalysisPage> {

  DateTime currentMonth = DateTime.now();

  List<Map<String, dynamic>> analysisData = [];
  List<Map<String, dynamic>> transactions = [];

  @override
  void initState() {
    super.initState();
    loadAnalysis();
  }

  Future<void> loadAnalysis() async {

    final tx = await DatabaseService.getTransactions();
    final budgets = await DatabaseService.getBudgets();

    transactions = tx;

    Map<String, double> spent = {};
    Map<String, double> budget = {};

    // Calculate category spending (ONLY expenses)
    for (var t in tx) {

      DateTime date = DateTime.parse(t["date"]);

      if (date.month == currentMonth.month &&
          date.year == currentMonth.year &&
          t["type"] == "expense") {

        String category = t["title"];
        double amount = (t["amount"] as num).toDouble();

        spent[category] = (spent[category] ?? 0) + amount;
      }
    }

    // Load budgets
    for (var b in budgets) {

      if (b["month"] == currentMonth.month &&
          b["year"] == currentMonth.year) {

        budget[b["category"]] =
            (b["amount"] as num).toDouble();
      }
    }

    List<Map<String, dynamic>> result = [];

    for (var category in budget.keys) {

      result.add({
        "category": category,
        "spent": spent[category] ?? 0,
        "budget": budget[category] ?? 0
      });

    }

    setState(() {
      analysisData = result;
    });

  }

  @override
  Widget build(BuildContext context) {

    double income = 0;
    double expense = 0;

    for (var t in transactions) {

      DateTime date = DateTime.parse(t["date"]);

      if (date.month == currentMonth.month &&
          date.year == currentMonth.year) {

        double amount = (t["amount"] as num).toDouble();

        if (t["type"] == "income") {
          income += amount;
        } else {
          expense += amount;
        }

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
              loadAnalysis();
            },
            onNext: () {
              setState(() {
                currentMonth =
                    DateTime(currentMonth.year, currentMonth.month + 1);
              });
              loadAnalysis();
            },
          ),

          MonthSummary(
            income: income,
            expense: expense,
          ),

          Expanded(
            child: analysisData.isEmpty
                ? const Center(child: Text("No analysis data"))
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
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold),
                                ),

                                Text(
                                  "₹${spent.toStringAsFixed(0)} / ₹${budget.toStringAsFixed(0)}",
                                ),

                              ],
                            ),

                            const SizedBox(height: 6),

                            LinearProgressIndicator(
                              value: progress,
                              minHeight: 8,
                              backgroundColor: Colors.grey[300],
                              color: progress > 1
                                  ? Colors.red
                                  : Colors.blue,
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
