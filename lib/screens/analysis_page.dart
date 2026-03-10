import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../services/data_store.dart';
import '../services/database_service.dart';
import '../services/widget_sync_service.dart';
import '../widgets/icon_utils.dart';
import '../widgets/month_header.dart';
import '../widgets/month_summary.dart';

enum AnalysisMode {
  selectedMonth,
  cumulativeToSelectedMonth,
  cumulativeYear,
}

class AnalysisPage extends StatefulWidget {
  @override
  _AnalysisPageState createState() => _AnalysisPageState();
}

class _AnalysisPageState extends State<AnalysisPage> {
  DateTime currentMonth = DateTime.now();
  AnalysisMode analysisMode = AnalysisMode.selectedMonth;

  List<Map<String, dynamic>> analysisData = [];
  List<Map<String, dynamic>> transactions = [];
  List<Map<String, dynamic>> budgets = [];

  @override
  void initState() {
    super.initState();
    loadAnalysis();
  }

  Future<void> loadAnalysis() async {
    final tx = await DatabaseService.getTransactions();
    final budgetData = await DatabaseService.getBudgets();
    final categories = await DatabaseService.getCategories();

    transactions = tx;
    budgets = budgetData;
    DataStore.categories = categories;

    Map<String, double> spent = {};
    Map<String, double> budget = {};

    for (var t in tx) {
      DateTime date = DateTime.parse(t["date"]);

      if (_isDateInActiveRange(date) && t["type"] == "expense") {
        String category = t["title"];
        double amount = (t["amount"] as num).toDouble();
        spent[category] = (spent[category] ?? 0) + amount;
      }
    }

    for (var b in budgetData) {
      if (_isBudgetInActiveRange(b)) {
        String category = b["category"];
        double amount = (b["amount"] as num).toDouble();
        budget[category] = (budget[category] ?? 0) + amount;
      }
    }

    List<Map<String, dynamic>> result = [];
    final categoriesUnion = <String>{...budget.keys, ...spent.keys};

    for (var category in categoriesUnion) {
      result.add({
        "category": category,
        "spent": spent[category] ?? 0,
        "budget": budget[category] ?? 0,
      });
    }

    result.sort((a, b) => (b["spent"] as double).compareTo(a["spent"] as double));

    setState(() {
      analysisData = result;
    });

    await WidgetSyncService.updateConfiguration(
      mode: _widgetMode(),
      month: currentMonth.month,
      year: currentMonth.year,
    );
  }

  bool _isDateInActiveRange(DateTime date) {
    if (date.year != currentMonth.year) return false;

    if (analysisMode == AnalysisMode.selectedMonth) {
      return date.month == currentMonth.month;
    }

    if (analysisMode == AnalysisMode.cumulativeToSelectedMonth) {
      return date.month <= currentMonth.month;
    }

    return true;
  }

  bool _isBudgetInActiveRange(Map<String, dynamic> budgetData) {
    if (budgetData["year"] != currentMonth.year) return false;

    int month = budgetData["month"];

    if (analysisMode == AnalysisMode.selectedMonth) {
      return month == currentMonth.month;
    }

    if (analysisMode == AnalysisMode.cumulativeToSelectedMonth) {
      return month <= currentMonth.month;
    }

    return true;
  }

  IconData _categoryIcon(String categoryName) {
    final category = DataStore.categories.cast<Map<String, dynamic>?>().firstWhere(
          (c) => c?["name"] == categoryName,
          orElse: () => null,
        );
    return iconFromCodePoint(category?["icon"], fallback: Icons.category);
  }

  List<PieChartSectionData> buildPieSections() {
    final colors = [
      Colors.blue,
      Colors.orange,
      Colors.green,
      Colors.purple,
      Colors.red,
      Colors.teal,
      Colors.amber,
    ];

    int i = 0;

    return analysisData.where((d) => d["spent"] > 0).map((data) {
      final color = colors[i % colors.length];
      i++;
      final icon = _categoryIcon(data["category"]);

      return PieChartSectionData(
        color: color,
        value: data["spent"],
        title: String.fromCharCode(icon.codePoint),
        titleStyle: const TextStyle(
          fontFamily: 'MaterialIcons',
          fontSize: 16,
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
        radius: 70,
      );
    }).toList();
  }

  void _changeMode(AnalysisMode mode) {
    setState(() {
      analysisMode = mode;
    });
    loadAnalysis();
  }


  String _widgetMode() {
    switch (analysisMode) {
      case AnalysisMode.cumulativeToSelectedMonth:
        return WidgetSyncService.cumulativeToSelectedMonth;
      case AnalysisMode.cumulativeYear:
        return WidgetSyncService.cumulativeYear;
      case AnalysisMode.selectedMonth:
        return WidgetSyncService.selectedMonth;
    }
  }
  String _modeLabel() {
    switch (analysisMode) {
      case AnalysisMode.selectedMonth:
        return "Selected month";
      case AnalysisMode.cumulativeToSelectedMonth:
        return "Cumulative till selected month";
      case AnalysisMode.cumulativeYear:
        return "Cumulative full year";
    }
  }

  @override
  Widget build(BuildContext context) {
    double expense = 0;

    for (var t in transactions) {
      DateTime date = DateTime.parse(t["date"]);

      if (_isDateInActiveRange(date) && t["type"] == "expense") {
        expense += (t["amount"] as num).toDouble();
      }
    }

    final budgetTotal = budgets
        .where((b) => _isBudgetInActiveRange(b))
        .fold(0.0, (sum, b) => sum + (b["amount"] as num).toDouble());

    return Scaffold(
      body: Column(
        children: [
          MonthHeader(
            currentMonth: currentMonth,
            onPrev: () {
              setState(() {
                currentMonth = DateTime(currentMonth.year, currentMonth.month - 1);
              });
              loadAnalysis();
            },
            onNext: () {
              setState(() {
                currentMonth = DateTime(currentMonth.year, currentMonth.month + 1);
              });
              loadAnalysis();
            },
            trailing: PopupMenuButton<AnalysisMode>(
              icon: const Icon(Icons.more_vert),
              onSelected: _changeMode,
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: AnalysisMode.selectedMonth,
                  child: Text("Selected month analysis"),
                ),
                PopupMenuItem(
                  value: AnalysisMode.cumulativeToSelectedMonth,
                  child: Text("Cumulative till selected month"),
                ),
                PopupMenuItem(
                  value: AnalysisMode.cumulativeYear,
                  child: Text("Cumulative full year"),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              _modeLabel(),
              style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.black54),
            ),
          ),
          MonthSummary(
            budget: budgetTotal,
            expense: expense,
          ),
          if (analysisData.any((d) => d["spent"] > 0))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: SizedBox(
                height: 200,
                child: PieChart(
                  PieChartData(
                    sections: buildPieSections(),
                    centerSpaceRadius: 40,
                    sectionsSpace: 2,
                  ),
                ),
              ),
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
                      double progress = budget == 0 ? 0 : (spent / budget).clamp(0, 1);

                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Icon(_categoryIcon(data["category"]), size: 18),
                                    const SizedBox(width: 8),
                                    Text(
                                      data["category"],
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                                Text("₹${spent.toStringAsFixed(0)} / ₹${budget.toStringAsFixed(0)}"),
                              ],
                            ),
                            const SizedBox(height: 6),
                            LinearProgressIndicator(
                              value: progress,
                              minHeight: 8,
                              backgroundColor: Colors.grey[300],
                              color: progress >= 1 ? Colors.red : Colors.blue,
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
