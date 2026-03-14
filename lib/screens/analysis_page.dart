import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../services/data_store.dart';
import '../services/database_service.dart';
import '../services/widget_sync_service.dart';
import '../widgets/icon_utils.dart';
import '../widgets/month_summary.dart';
import '../widgets/section_tile.dart';

enum AnalysisMode {
  selectedMonth,
  cumulativeToSelectedMonth,
  cumulativeYear,
}

enum PieContributionMode {
  expense,
  budget,
}

class AnalysisPage extends StatefulWidget {
  @override
  _AnalysisPageState createState() => _AnalysisPageState();
}

class _AnalysisPageState extends State<AnalysisPage> {
  DateTime currentMonth = DateTime.now();
  AnalysisMode analysisMode = AnalysisMode.selectedMonth;
  PieContributionMode pieContributionMode = PieContributionMode.expense;

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

    final spent = <String, double>{};
    final budget = <String, double>{};

    for (final t in tx) {
      final date = DateTime.parse(t['date']);

      if (_isDateInActiveRange(date) && t['type'] == 'expense') {
        final category = t['title'] as String;
        final amount = (t['amount'] as num).toDouble();
        spent[category] = (spent[category] ?? 0) + amount;
      }
    }

    for (final b in budgetData) {
      if (_isBudgetInActiveRange(b)) {
        final category = b['category'] as String;
        final amount = (b['amount'] as num).toDouble();
        budget[category] = (budget[category] ?? 0) + amount;
      }
    }

    final result = <Map<String, dynamic>>[];
    final configuredCategories = categories
        .map((category) => category['name'])
        .whereType<String>()
        .toSet();
    final categoriesUnion = <String>{...configuredCategories, ...budget.keys, ...spent.keys};

    for (final category in categoriesUnion) {
      result.add({
        'category': category,
        'spent': spent[category] ?? 0,
        'budget': budget[category] ?? 0,
      });
    }

    result.sort((a, b) => (b['spent'] as double).compareTo(a['spent'] as double));

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
    final year = _toInt(budgetData['year']);
    if (year != currentMonth.year) return false;

    final month = _toInt(budgetData['month']);

    if (analysisMode == AnalysisMode.selectedMonth) {
      return month == currentMonth.month;
    }

    if (analysisMode == AnalysisMode.cumulativeToSelectedMonth) {
      return month <= currentMonth.month;
    }

    return true;
  }

  int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString()) ?? 0;
  }

  IconData _categoryIcon(String categoryName) {
    final category = DataStore.categories.cast<Map<String, dynamic>?>().firstWhere(
          (c) => c?['name'] == categoryName,
          orElse: () => null,
        );
    return iconFromCodePoint(category?['icon'], fallback: Icons.category);
  }

  double _activeTotalExpense() {
    return transactions
        .where((t) => _isDateInActiveRange(DateTime.parse(t['date'])) && t['type'] == 'expense')
        .fold(0.0, (sum, t) => sum + (t['amount'] as num).toDouble());
  }

  double _activeTotalBudget() {
    return budgets
        .where(_isBudgetInActiveRange)
        .fold(0.0, (sum, b) => sum + (b['amount'] as num).toDouble());
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

    final denominator = pieContributionMode == PieContributionMode.expense
        ? _activeTotalExpense()
        : _activeTotalBudget();

    var i = 0;
    return analysisData.where((d) {
      final contribution = pieContributionMode == PieContributionMode.expense
          ? (d['spent'] as num).toDouble()
          : (d['budget'] as num).toDouble();
      return contribution > 0;
    }).map((data) {
      final color = colors[i % colors.length];
      i++;
      final contribution = pieContributionMode == PieContributionMode.expense
          ? (data['spent'] as num).toDouble()
          : (data['budget'] as num).toDouble();
      final percentage = denominator == 0 ? 0 : (contribution / denominator) * 100;

      return PieChartSectionData(
        color: color,
        value: contribution,
        title: '${data['category']}\n${percentage.toStringAsFixed(1)}%',
        titleStyle: const TextStyle(
          fontSize: 10,
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
        radius: 72,
      );
    }).toList();
  }

  Color _progressColor(double ratio) {
    if (ratio <= 0.5) {
      return const Color(0xFF9CCC65);
    }
    if (ratio <= 1) {
      return const Color(0xFFFFF176);
    }
    return const Color(0xFFEF9A9A);
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

  @override
  Widget build(BuildContext context) {
    final expense = _activeTotalExpense();
    final budgetTotal = _activeTotalBudget();

    return Scaffold(
      backgroundColor: const Color(0xFFF3F5F9),
      body: Column(
        children: [
          MonthSummary(
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
            budget: budgetTotal,
            expense: expense,
            trailing: PopupMenuButton<AnalysisMode>(
              icon: const Icon(Icons.more_vert),
              onSelected: _changeMode,
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: AnalysisMode.selectedMonth,
                  child: Row(
                    children: [
                      const Expanded(child: Text('Selected month analysis')),
                      if (analysisMode == AnalysisMode.selectedMonth) const Icon(Icons.check, size: 18),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: AnalysisMode.cumulativeToSelectedMonth,
                  child: Row(
                    children: [
                      const Expanded(child: Text('Cumulative till selected month')),
                      if (analysisMode == AnalysisMode.cumulativeToSelectedMonth)
                        const Icon(Icons.check, size: 18),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: AnalysisMode.cumulativeYear,
                  child: Row(
                    children: [
                      const Expanded(child: Text('Cumulative full year')),
                      if (analysisMode == AnalysisMode.cumulativeYear) const Icon(Icons.check, size: 18),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (analysisData.any((d) => d['spent'] > 0))
            SectionTile(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        pieContributionMode == PieContributionMode.expense
                            ? 'Contribution vs total expense'
                            : 'Contribution vs total budget',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                      PopupMenuButton<PieContributionMode>(
                        icon: const Icon(Icons.more_vert),
                        onSelected: (mode) {
                          setState(() {
                            pieContributionMode = mode;
                          });
                        },
                        itemBuilder: (context) => [
                          PopupMenuItem(
                            value: PieContributionMode.expense,
                            child: Row(
                              children: [
                                const Expanded(child: Text('Against total expense')),
                                if (pieContributionMode == PieContributionMode.expense)
                                  const Icon(Icons.check, size: 18),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: PieContributionMode.budget,
                            child: Row(
                              children: [
                                const Expanded(child: Text('Against total budget')),
                                if (pieContributionMode == PieContributionMode.budget)
                                  const Icon(Icons.check, size: 18),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 210,
                    child: PieChart(
                      PieChartData(
                        sections: buildPieSections(),
                        centerSpaceRadius: 32,
                        sectionsSpace: 2,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: SectionTile(
              child: analysisData.isEmpty
                  ? const Center(child: Text('No analysis data'))
                  : ListView.builder(
                      padding: EdgeInsets.zero,
                      itemCount: analysisData.length,
                      itemBuilder: (context, index) {
                        final data = analysisData[index];

                        final spent = (data['spent'] as num).toDouble();
                        final budget = (data['budget'] as num).toDouble();
                        final ratio = budget == 0 ? (spent > 0 ? 1.01 : 0.0) : spent / budget;
                        final progress =
                            budget == 0 ? (spent > 0 ? 1.0 : 0.0) : ratio.clamp(0.0, 1.0).toDouble();

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
                                      Icon(_categoryIcon(data['category'] as String), size: 18),
                                      const SizedBox(width: 8),
                                      Text(
                                        data['category'] as String,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    '₹${spent.toStringAsFixed(0)} / ₹${budget.toStringAsFixed(0)}',
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              LinearProgressIndicator(
                                value: progress,
                                minHeight: 8,
                                backgroundColor: Colors.grey[300],
                                color: _progressColor(ratio),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
