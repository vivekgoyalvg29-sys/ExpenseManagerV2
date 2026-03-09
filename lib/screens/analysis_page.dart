import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../widgets/month_header.dart';
import '../services/database_service.dart';

class AnalysisPage extends StatefulWidget {
  @override
  _AnalysisPageState createState() => _AnalysisPageState();
}

class _AnalysisPageState extends State<AnalysisPage> {

  DateTime currentMonth = DateTime.now();

  List<Map<String, dynamic>> analysisData = [];

  final List<Color> pieColors = [
    Colors.blue,
    Colors.red,
    Colors.green,
    Colors.orange,
    Colors.purple,
    Colors.teal,
    Colors.brown,
  ];

  @override
  void initState() {
    super.initState();
    loadAnalysis();
  }

  Future<void> loadAnalysis() async {

    final transactions = await DatabaseService.getTransactions();
    final budgets = await DatabaseService.getBudgets();

    Map<String, double> categorySpent = {};
    Map<String, double> categoryBudget = {};

    // Calculate spending
    for (var t in transactions) {

      DateTime date = DateTime.parse(t["date"]);

      if (date.month == currentMonth.month &&
          date.year == currentMonth.year) {

        String category = t["title"];
        double amount = (t["amount"] as num).toDouble();

        categorySpent[category] =
            (categorySpent[category] ?? 0) + amount;
      }
    }

    // Load budgets
    for (var b in budgets) {

      if (b["month"] == currentMonth.month &&
          b["year"] == currentMonth.year) {

        categoryBudget[b["category"]] =
            (b["amount"] as num).toDouble();
      }
    }

    List<Map<String, dynamic>> result = [];

    for (var category in categoryBudget.keys) {

      result.add({
        "category": category,
        "spent": categorySpent[category] ?? 0,
        "budget": categoryBudget[category] ?? 0
      });

    }

    setState(() {
      analysisData = result;
    });

  }

  Widget buildPieChart() {

    double totalSpent = analysisData.fold(
        0, (sum, item) => sum + item["spent"]);

    if (totalSpent == 0) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: Text("No spending this month"),
      );
    }

    return SizedBox(
      height: 220,
      child: PieChart(
        PieChartData(
          sections: analysisData.asMap().entries.map((entry) {

            int index = entry.key;
            var data = entry.value;

            double value = data["spent"];
            double percent = (value / totalSpent) * 100;

            return PieChartSectionData(
              color: pieColors[index % pieColors.length],
              value: value,
              title: "${percent.toStringAsFixed(0)}%",
              radius: 80,
              titleStyle: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            );

          }).toList(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {

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

          const SizedBox(height: 10),

          buildPieChart(),

          const SizedBox(height: 10),

          Expanded(
            child: analysisData.isEmpty
                ? Center(child: Text("No analysis data"))
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
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),

                                Text(
                                  "₹${spent.toStringAsFixed(0)} / ₹${budget.toStringAsFixed(0)}",
                                  style: const TextStyle(
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
