import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/data_store.dart';
import '../services/data_service.dart';
import '../services/visual_settings.dart';
import '../services/widget_sync_service.dart';
import '../utils/indian_number_formatter.dart';
import '../widgets/icon_utils.dart';
import '../widgets/aggregation_bar_chart.dart';
import '../widgets/month_summary.dart';
import '../widgets/mini_progress_bar.dart';
import '../widgets/page_content_layout.dart';
import '../widgets/segmented_toggle.dart';
import '../widgets/section_tile.dart';
import '../widgets/side_overlay_sheet.dart';
import '../widgets/income_expense_pie_chart.dart';
import '../widgets/income_mode_radial_chart.dart';
import 'add_transaction_page.dart';

enum AnalysisMode {
  selectedMonth,
  cumulativeToSelectedMonth,
  cumulativeYear,
}

enum AnalysisType {
  category,
  account,
}

enum TransactionSortOrder {
  newestFirst,
  oldestFirst,
}

enum AnalysisSortField {
  budget,
  expense,
}

class AnalysisPage extends StatefulWidget {
  const AnalysisPage({super.key});

  @override
  State<AnalysisPage> createState() => _AnalysisPageState();
}

class _AnalysisPageState extends State<AnalysisPage> {
  static const _analysisModeKey = 'analysis.mode';
  static const _analysisTypeKey = 'analysis.type';
  static const _analysisSortKey = 'analysis.sort';
  static const _analysisMainSortKey = 'analysis.mainSort';
  static const _analysisShowPercentageKey = 'analysis.showPercentage';

  DateTime currentMonth = DateTime.now();
  AnalysisMode analysisMode = AnalysisMode.selectedMonth;
  AnalysisType analysisType = AnalysisType.category;
  AnalysisSortField analysisSortField = AnalysisSortField.budget;
  TransactionSortOrder transactionSortOrder = TransactionSortOrder.newestFirst;
  bool showPercentage = true;
  int? selectedChartBucket;
  IncomeExpensePieSlice? selectedPieSlice;
  bool? _lastWasIncomeMode;
  /// Month shown in [MonthSummary] before a non–current-month bar filter was applied (budget mode).
  DateTime? _monthBeforeChartBucket;

  List<Map<String, dynamic>> analysisData = [];
  List<Map<String, dynamic>> transactions = [];
  List<Map<String, dynamic>> budgets = [];
  bool _isAnalysisLoading = true;

  ComparisonMode get _comparisonMode => VisualSettingsScope.of(context).value.comparisonMode;
  bool get _isIncomeVsExpense => _comparisonMode == ComparisonMode.incomeVsExpense;

  @override
  void initState() {
    super.initState();
    _restorePreferences();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final isIncomeMode = _isIncomeVsExpense;
    if (_lastWasIncomeMode == null) {
      _lastWasIncomeMode = isIncomeMode;
      return;
    }
    if (_lastWasIncomeMode != isIncomeMode) {
      // Switching comparison mode should reset drill-down selections.
      selectedChartBucket = null;
      selectedPieSlice = null;
      _lastWasIncomeMode = isIncomeMode;
      // Reload so chart/bottom list reflects the new mode.
      // Use a post-frame to avoid calling setState during build.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        loadAnalysis();
      });
    }
  }

  Future<void> _restorePreferences() async {
    final prefs = await SharedPreferences.getInstance();
    analysisMode = AnalysisMode.values[prefs.getInt(_analysisModeKey) ?? analysisMode.index];
    analysisType = AnalysisType.values[prefs.getInt(_analysisTypeKey) ?? analysisType.index];
    analysisSortField = AnalysisSortField.values[
      prefs.getInt(_analysisMainSortKey) ?? analysisSortField.index
    ];
    transactionSortOrder = TransactionSortOrder.values[
      prefs.getInt(_analysisSortKey) ?? transactionSortOrder.index
    ];
    showPercentage = prefs.getBool(_analysisShowPercentageKey) ?? showPercentage;
    if (!mounted) return;
    setState(() {});
    await loadAnalysis();
  }

  Future<void> _persistPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_analysisModeKey, analysisMode.index);
    await prefs.setInt(_analysisTypeKey, analysisType.index);
    await prefs.setInt(_analysisMainSortKey, analysisSortField.index);
    await prefs.setInt(_analysisSortKey, transactionSortOrder.index);
    await prefs.setBool(_analysisShowPercentageKey, showPercentage);
  }

  Future<void> loadAnalysis() async {
    final DateTime startDate;
    final DateTime endDate;
    switch (analysisMode) {
      case AnalysisMode.selectedMonth:
        startDate = DateTime(currentMonth.year, currentMonth.month, 1);
        endDate = DateTime(currentMonth.year, currentMonth.month + 1, 0);
      case AnalysisMode.cumulativeToSelectedMonth:
        startDate = DateTime(currentMonth.year, 1, 1);
        endDate = DateTime(currentMonth.year, currentMonth.month + 1, 0);
      case AnalysisMode.cumulativeYear:
        startDate = DateTime(currentMonth.year, 1, 1);
        endDate = DateTime(currentMonth.year, 12, 31);
    }
    if (mounted) {
      setState(() => _isAnalysisLoading = true);
    }
    try {
    final tx = await DataService.getTransactions(startDate: startDate, endDate: endDate);
    final budgetData = await DataService.getBudgets();
    final categories = await DataService.getCategories();
    final accounts = await DataService.getAccounts();

    transactions = tx;
    budgets = budgetData;
    DataStore.categories = categories;
    DataStore.accounts = accounts;
    if (_isIncomeVsExpense) {
      // Income mode uses pie selection; time bucket (bar) selection must not affect the bottom list.
      selectedChartBucket = null;

      final incomeTx = _filteredTransactionsOfType('income');
      final expenseTx = _filteredTransactionsOfType('expense');

      final groupedIncome = <String, double>{};
      final groupedExpense = <String, double>{};
      final latestIncomeDates = <String, DateTime>{};
      final latestExpenseDates = <String, DateTime>{};

      for (final transaction in incomeTx) {
        final key = _incomeKeyForTransaction(transaction);
        if (key.isEmpty) continue;
        final amount = (transaction['amount'] as num).toDouble();
        final date = DateTime.parse(transaction['date'] as String);
        groupedIncome[key] = (groupedIncome[key] ?? 0) + amount;
        final previous = latestIncomeDates[key];
        if (previous == null || date.isAfter(previous)) latestIncomeDates[key] = date;
      }

      for (final transaction in expenseTx) {
        final key = _expenseKeyForTransaction(transaction);
        if (key.isEmpty) continue;
        final amount = (transaction['amount'] as num).toDouble();
        final date = DateTime.parse(transaction['date'] as String);
        groupedExpense[key] = (groupedExpense[key] ?? 0) + amount;
        final previous = latestExpenseDates[key];
        if (previous == null || date.isAfter(previous)) latestExpenseDates[key] = date;
      }

      final totalIncomeAggregation = groupedIncome.values.fold<double>(0.0, (sum, v) => sum + v);
      final totalExpenseAggregation = groupedExpense.values.fold<double>(0.0, (sum, v) => sum + v);

      if (selectedPieSlice == IncomeExpensePieSlice.budget) {
        if (mounted) {
          setState(() {
            analysisData = [];
          });
        }
      } else {
        final result = <Map<String, dynamic>>[];

        final showIncome = selectedPieSlice == null || selectedPieSlice == IncomeExpensePieSlice.income;
        final showExpense = selectedPieSlice == null || selectedPieSlice == IncomeExpensePieSlice.expense;

        if (showIncome) {
          if (selectedPieSlice == IncomeExpensePieSlice.income) {
          final incomeDetails = incomeTx
              .where((tx) => _incomeKeyForTransaction(tx).isNotEmpty)
              .toList()
            ..sort((a, b) {
              final aKey = _incomeKeyForTransaction(a);
              final bKey = _incomeKeyForTransaction(b);
              final byKey = aKey.compareTo(bKey);
              if (byKey != 0) return byKey;
              final aDate = DateTime.parse(a['date'] as String);
              final bDate = DateTime.parse(b['date'] as String);
              return bDate.compareTo(aDate);
            });
          for (final tx in incomeDetails) {
            final key = _incomeKeyForTransaction(tx);
            final amount = (tx['amount'] as num).toDouble();
            final date = DateTime.parse(tx['date'] as String);
            final percentage = totalIncomeAggregation == 0
                ? 0
                : (((amount / totalIncomeAggregation) * 100).clamp(0, 999)).round();
            result.add({
              'rowType': 'income_tx',
              'label': key,
              'spent': 0.0,
              'income': amount,
              'budget': 0.0,
              'net': amount,
              'percentage': percentage,
              'totalIncomeAggregation': totalIncomeAggregation,
              'totalExpenseAggregation': totalExpenseAggregation,
              'latestDate': date,
              'txId': tx['id'],
              'txComment': (tx['comment'] ?? '').toString().trim(),
              'txDate': tx['date'],
            });
          }
          } else {
            for (final entry in groupedIncome.entries) {
              if (entry.value <= 0) continue;
              final percentage = totalIncomeAggregation == 0
                  ? 0
                  : (((entry.value / totalIncomeAggregation) * 100).clamp(0, 999)).round();
              result.add({
                'rowType': 'income',
                'label': entry.key,
                'spent': 0.0,
                'income': entry.value,
                'budget': 0.0,
                'net': entry.value,
                'percentage': percentage,
                'totalIncomeAggregation': totalIncomeAggregation,
                'totalExpenseAggregation': totalExpenseAggregation,
                'latestDate': latestIncomeDates[entry.key],
              });
            }
          }
        }

        if (showExpense) {
          for (final entry in groupedExpense.entries) {
            if (entry.value <= 0) continue;
            final percentage = totalExpenseAggregation == 0
                ? 0
                : (((entry.value / totalExpenseAggregation) * 100).clamp(0, 999)).round();
            result.add({
              'rowType': 'expense',
              'label': entry.key,
              'spent': entry.value,
              'income': 0.0,
              'budget': 0.0,
              'net': -entry.value,
              'percentage': percentage,
              'totalIncomeAggregation': totalIncomeAggregation,
              'totalExpenseAggregation': totalExpenseAggregation,
              'latestDate': latestExpenseDates[entry.key],
            });
          }
        }

        // Sorting rules:
        // - When a pie slice is selected: sort by that side's amount desc (menu sorting ignored).
        // - When no slice is selected: use existing menu sorting (based on analysisSortField).
        result.sort((a, b) {
          final aRow = a['rowType'] as String;
          final bRow = b['rowType'] as String;

          if (selectedPieSlice == IncomeExpensePieSlice.income) {
            final cmp = (b['income'] as num).compareTo(a['income'] as num);
            return cmp != 0 ? cmp : (a['label'] as String).compareTo(b['label'] as String);
          }
          if (selectedPieSlice == IncomeExpensePieSlice.expense) {
            final cmp = (b['spent'] as num).compareTo(a['spent'] as num);
            return cmp != 0 ? cmp : (a['label'] as String).compareTo(b['label'] as String);
          }

          num aPrimary;
          num bPrimary;
          if (analysisSortField == AnalysisSortField.budget) {
            // In income mode, "Budget" label in menu corresponds to Income sorting.
            aPrimary = aRow == 'income' ? (a['income'] as num) : 0;
            bPrimary = bRow == 'income' ? (b['income'] as num) : 0;
          } else {
            // "Expense" label in menu.
            aPrimary = aRow == 'expense' ? (a['spent'] as num) : 0;
            bPrimary = bRow == 'expense' ? (b['spent'] as num) : 0;
          }

          final amountCompare = bPrimary.compareTo(aPrimary);
          if (amountCompare != 0) return amountCompare;

          final secondaryCompare = (b['spent'] as num).compareTo(a['spent'] as num);
          if (secondaryCompare != 0) return secondaryCompare;

          final aDate = a['latestDate'] as DateTime?;
          final bDate = b['latestDate'] as DateTime?;
          if (aDate != null && bDate != null) {
            final dateCompare = bDate.compareTo(aDate);
            if (dateCompare != 0) return dateCompare;
          }

          return (a['label'] as String).compareTo(b['label'] as String);
        });

        if (!mounted) return;
        setState(() {
          analysisData = result;
        });
      }
    } else {
      // Budget mode uses the bar-chart time bucket selection to filter the bottom list.
      final filteredExpenses = _filteredTransactionsOfTypeForBottom('expense');
      final totalIncomeAggregation = _filteredTransactionsOfType('income').fold<double>(
        0.0,
        (sum, transaction) => sum + (transaction['amount'] as num).toDouble(),
      );
      final totalExpense = filteredExpenses.fold<double>(
        0.0,
        (sum, transaction) => sum + (transaction['amount'] as num).toDouble(),
      );

      final groupedExpense = <String, double>{};
      final groupedIncome = <String, double>{};
      final latestDates = <String, DateTime>{};

      for (final transaction in filteredExpenses) {
        final key = _analysisKeyForTransaction(transaction);
        if (key.isEmpty) continue;

        final amount = (transaction['amount'] as num).toDouble();
        final date = DateTime.parse(transaction['date'] as String);
        groupedExpense[key] = (groupedExpense[key] ?? 0) + amount;

        final previousLatest = latestDates[key];
        if (previousLatest == null || date.isAfter(previousLatest)) {
          latestDates[key] = date;
        }
      }

      // groupedIncome is only used when building rows in income/budget combined mode earlier;
      // keep it for compatibility with the existing UI.
      if (analysisMode != AnalysisMode.cumulativeYear) {
        final filteredIncome = _filteredTransactionsOfTypeForBottom('income');
        for (final transaction in filteredIncome) {
          final key = _analysisKeyForTransaction(transaction);
          if (key.isEmpty) continue;
          final amount = (transaction['amount'] as num).toDouble();
          final date = DateTime.parse(transaction['date'] as String);
          groupedIncome[key] = (groupedIncome[key] ?? 0) + amount;
          final previousLatest = latestDates[key];
          if (previousLatest == null || date.isAfter(previousLatest)) {
            latestDates[key] = date;
          }
        }
      }

      final groupedBudget = <String, double>{};
      if (analysisType == AnalysisType.category) {
        for (final budgetData in budgets) {
          if (_isBudgetInActiveRange(budgetData)) {
            final category = (budgetData['category'] as String?)?.trim() ?? '';
            if (category.isEmpty) continue;
            final amount = (budgetData['amount'] as num).toDouble();
            groupedBudget[category] = (groupedBudget[category] ?? 0) + amount;
          }
        }
      }

      final activeKeys = analysisType == AnalysisType.category
          ? <String>{...groupedBudget.keys, ...groupedExpense.keys}
          : groupedExpense.keys.toSet();

      final result = activeKeys
          .map((key) => {
                'rowType': 'expense',
                'label': key,
                'spent': groupedExpense[key] ?? 0.0,
                'budget': groupedBudget[key] ?? 0.0,
                'income': groupedIncome[key] ?? 0.0,
                'net': (groupedIncome[key] ?? 0.0) - (groupedExpense[key] ?? 0.0),
                'percentage': totalExpense == 0
                    ? 0
                    : (((groupedExpense[key] ?? 0.0) / totalExpense) * 100).round(),
                'totalIncomeAggregation': totalIncomeAggregation,
                'totalExpenseAggregation': totalExpense,
                'latestDate': latestDates[key],
              })
          .toList();

      if (selectedChartBucket != null) {
        result.removeWhere((entry) => ((entry['spent'] as num?) ?? 0) <= 0);
      }

      result.sort((a, b) {
        if (selectedChartBucket != null) {
          final spentCompare = ((b['spent'] as num?) ?? 0).compareTo((a['spent'] as num?) ?? 0);
          if (spentCompare != 0) return spentCompare;
          final bDate = b['latestDate'] as DateTime?;
          final aDate = a['latestDate'] as DateTime?;
          if (aDate != null && bDate != null) {
            final dateCompare = bDate.compareTo(aDate);
            if (dateCompare != 0) return dateCompare;
          }
          if (bDate != null) return 1;
          if (aDate != null) return -1;
          return (a['label'] as String).compareTo(b['label'] as String);
        }

        final aPrimary = analysisSortField == AnalysisSortField.budget
            ? (a['budget'] as num?) ?? 0
            : (a['spent'] as num?) ?? 0;
        final bPrimary = analysisSortField == AnalysisSortField.budget
            ? (b['budget'] as num?) ?? 0
            : (b['spent'] as num?) ?? 0;

        final amountCompare = bPrimary.compareTo(aPrimary);
        if (amountCompare != 0) return amountCompare;

        final secondaryCompare = ((b['spent'] as num?) ?? 0).compareTo((a['spent'] as num?) ?? 0);
        if (secondaryCompare != 0) return secondaryCompare;

        final bDate = b['latestDate'] as DateTime?;
        final aDate = a['latestDate'] as DateTime?;
        if (aDate != null && bDate != null) {
          final dateCompare = bDate.compareTo(aDate);
          if (dateCompare != 0) return dateCompare;
        }
        if (bDate != null) return 1;
        if (aDate != null) return -1;

        return (a['label'] as String).compareTo(b['label'] as String);
      });

      if (!mounted) return;
      setState(() {
        analysisData = result;
        if (!_chartDataContainsBucket(selectedChartBucket)) {
          selectedChartBucket = null;
        }
      });
    }

    await WidgetSyncService.updateConfiguration(
      mode: _widgetMode(),
      month: currentMonth.month,
      year: currentMonth.year,
    );
    } finally {
      if (mounted) {
        setState(() => _isAnalysisLoading = false);
      }
    }
  }

  List<Map<String, dynamic>> _filteredTransactionsOfType(String type) {
    return transactions.where((transaction) {
      if (transaction['type'] != type) return false;
      final rawDate = transaction['date'];
      if (rawDate == null) return false;
      final date = DateTime.parse(rawDate as String);
      return _isDateInActiveRange(date);
    }).toList();
  }

  List<Map<String, dynamic>> _filteredExpenseTransactions() => _filteredTransactionsOfType('expense');

  List<Map<String, dynamic>> _filteredIncomeTransactions() => _filteredTransactionsOfType('income');

  List<Map<String, dynamic>> _filteredTransactionsOfTypeForBottom(String type) {
    return _filteredTransactionsOfType(type).where((transaction) {
      final rawDate = transaction['date'];
      if (rawDate == null) return false;
      return _isDateInSelectedChartBucket(DateTime.parse(rawDate as String));
    }).toList();
  }

  String _analysisKeyForTransaction(Map<String, dynamic> transaction) {
    if (analysisType == AnalysisType.account) {
      return (transaction['account'] as String?)?.trim() ?? '';
    }
    return (transaction['title'] as String?)?.trim() ?? '';
  }

  String _incomeKeyForTransaction(Map<String, dynamic> transaction) {
    if (analysisType == AnalysisType.account) {
      return (transaction['account'] as String?)?.trim() ?? '';
    }
    return (transaction['title'] as String?)?.trim() ?? '';
  }

  String _expenseKeyForTransaction(Map<String, dynamic> transaction) {
    // In both modes, expense grouping respects the analysis menu type.
    if (analysisType == AnalysisType.account) {
      return (transaction['account'] as String?)?.trim() ?? '';
    }
    return (transaction['title'] as String?)?.trim() ?? '';
  }

  bool _isDateInActiveRange(DateTime date) {
    if (date.year != currentMonth.year) return false;
    if (analysisMode == AnalysisMode.selectedMonth) return date.month == currentMonth.month;
    if (analysisMode == AnalysisMode.cumulativeToSelectedMonth) return date.month <= currentMonth.month;
    return true;
  }

  bool _isDateInSelectedChartBucket(DateTime date) {
    if (selectedChartBucket == null) return true;
    if (analysisMode == AnalysisMode.selectedMonth) {
      return date.day == selectedChartBucket;
    }
    return date.month == selectedChartBucket;
  }

  bool _chartDataContainsBucket(int? bucket) {
    if (bucket == null) return true;
    return _analysisChartData().any((item) => item.bucket == bucket);
  }

  bool _isBudgetInActiveRange(Map<String, dynamic> budgetData) {
    final year = _toInt(budgetData['year']);
    if (year != currentMonth.year) return false;
    final month = _toInt(budgetData['month']);
    if (analysisMode == AnalysisMode.selectedMonth) return month == currentMonth.month;
    if (analysisMode == AnalysisMode.cumulativeToSelectedMonth) return month <= currentMonth.month;
    return true;
  }

  int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString()) ?? 0;
  }

  Map<String, dynamic>? _entryForLabel(String label, {String rowType = 'expense'}) {
    final source = _isIncomeVsExpense && rowType == 'income'
        ? DataStore.accounts
        : (analysisType == AnalysisType.category ? DataStore.categories : DataStore.accounts);

    return source.cast<Map<String, dynamic>?>().firstWhere(
      (item) => item?['name'] == label,
      orElse: () => null,
    );
  }

  double _activeTotalExpense() {
    return _filteredExpenseTransactions().fold<double>(
      0.0,
      (sum, transaction) => sum + (transaction['amount'] as num).toDouble(),
    );
  }

  double _activeTotalIncome() {
    return _filteredIncomeTransactions().fold<double>(
      0.0,
      (sum, transaction) => sum + (transaction['amount'] as num).toDouble(),
    );
  }

  double _activeTotalBudget() {
    return budgets.where(_isBudgetInActiveRange).fold<double>(
          0.0,
          (sum, budget) => sum + (budget['amount'] as num).toDouble(),
        );
  }

  List<AggregationBarData> _analysisChartData() {
    final filtered = _isIncomeVsExpense ? _filteredTransactionsOfType('income') : _filteredExpenseTransactions();
    if (analysisMode == AnalysisMode.selectedMonth) {
      final grouped = <int, double>{};
      for (final transaction in filtered) {
        final date = DateTime.parse(transaction['date'] as String);
        grouped[date.day] = (grouped[date.day] ?? 0) + (transaction['amount'] as num).toDouble();
      }
      final sortedDays = grouped.keys.toList()
        ..sort();
      return sortedDays
          .map((day) => AggregationBarData(label: '$day', value: grouped[day] ?? 0, bucket: day))
          .toList();
    }

    final groupedByMonth = <int, double>{};
    for (final transaction in filtered) {
      final date = DateTime.parse(transaction['date'] as String);
      groupedByMonth[date.month] = (groupedByMonth[date.month] ?? 0) + (transaction['amount'] as num).toDouble();
    }
    final sortedMonths = groupedByMonth.keys.toList()..sort();
    return sortedMonths
        .map(
          (month) => AggregationBarData(
            label: DateFormat('MMM').format(DateTime(currentMonth.year, month)),
            value: groupedByMonth[month] ?? 0,
            bucket: month,
          ),
        )
        .toList();
  }

  Color _progressColor(double ratio) {
    if (ratio <= 0.5) return const Color(0xFF22C55E);
    if (ratio <= 1) return const Color(0xFFF59E0B);
    return const Color(0xFFEF4444);
  }

  /// Keeps overlaid bar labels readable on both the colored fill and the grey track.
  TextStyle _progressBarOverlayStyle(BuildContext context, double ratio, double widthFactor) {
    final theme = Theme.of(context);
    final onFill = widthFactor > 0.14;
    return TextStyle(
      fontSize: 10,
      fontWeight: FontWeight.w700,
      color: onFill ? Colors.white : theme.colorScheme.onSurface,
      shadows: onFill
          ? const [
              Shadow(color: Colors.black54, blurRadius: 3),
              Shadow(color: Colors.black26, blurRadius: 1),
            ]
          : [
              Shadow(color: theme.colorScheme.surface, blurRadius: 2),
            ],
    );
  }

  List<_BreakdownRow> _topFiveExpenseBreakdown() {
    final map = <String, double>{};
    for (final t in _filteredTransactionsOfType('expense')) {
      final k = _expenseKeyForTransaction(t);
      if (k.isEmpty) continue;
      map[k] = (map[k] ?? 0) + (t['amount'] as num).toDouble();
    }
    final sorted = map.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(5).map((e) => _BreakdownRow(e.key, e.value)).toList();
  }

  List<_BreakdownRow> _topFiveIncomeBreakdown() {
    final map = <String, double>{};
    for (final t in _filteredTransactionsOfType('income')) {
      final k = _incomeKeyForTransaction(t);
      if (k.isEmpty) continue;
      map[k] = (map[k] ?? 0) + (t['amount'] as num).toDouble();
    }
    final sorted = map.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(5).map((e) => _BreakdownRow(e.key, e.value)).toList();
  }

  /// Top categories by budget amount for the active analysis window (income-mode side panel).
  List<_BreakdownRow> _topFiveBudgetByCategory() {
    final map = <String, double>{};
    for (final b in budgets.where(_isBudgetInActiveRange)) {
      final category = (b['category'] as String?)?.trim() ?? '';
      if (category.isEmpty) continue;
      map[category] = (map[category] ?? 0) + (b['amount'] as num).toDouble();
    }
    final sorted = map.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(5).map((e) => _BreakdownRow(e.key, e.value)).toList();
  }

  List<_BreakdownRow> _incomeModeSidePanelRows() {
    switch (selectedPieSlice) {
      case IncomeExpensePieSlice.budget:
        return _topFiveBudgetByCategory();
      case IncomeExpensePieSlice.expense:
        return _topFiveExpenseBreakdown();
      case IncomeExpensePieSlice.income:
        return _topFiveIncomeBreakdown();
      case null:
        return _topFiveExpenseBreakdown();
    }
  }

  String _incomeModeSidePanelTitle() {
    switch (selectedPieSlice) {
      case IncomeExpensePieSlice.budget:
        return 'Top budget (category)';
      case IncomeExpensePieSlice.expense:
        return 'Top expense';
      case IncomeExpensePieSlice.income:
        return 'Top income';
      case null:
        return 'Top expense';
    }
  }

  String _incomeModeSidePanelRowType() {
    switch (selectedPieSlice) {
      case IncomeExpensePieSlice.budget:
      case IncomeExpensePieSlice.expense:
      case null:
        return 'expense';
      case IncomeExpensePieSlice.income:
        return 'income';
    }
  }

  Color _incomeModeSidePanelAmountColor(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    switch (selectedPieSlice) {
      case IncomeExpensePieSlice.budget:
        return Color.lerp(scheme.primary, Colors.white, 0.25) ?? scheme.primary;
      case IncomeExpensePieSlice.income:
        return const Color(0xFF22C55E).withValues(alpha: 0.88);
      case IncomeExpensePieSlice.expense:
      case null:
        return const Color(0xFFEF4444).withValues(alpha: 0.85);
    }
  }

  LinearGradient _progressGradient(double ratio) {
    final base = _progressColor(ratio);
    return LinearGradient(
      colors: [
        base,
        Color.lerp(Colors.white, base, 0.45) ?? base,
      ],
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
    );
  }

  Future<void> _applyAnalysisPreferenceChange(VoidCallback updateParent) async {
    updateParent();
    await _persistPreferences();
    await loadAnalysis();
  }

  void _showAnalysisOptions() {
    showSideOverlaySheet<void>(
      context: context,
      direction: SideOverlayDirection.right,
      builder: (drawerContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            Future<void> applyChanges(VoidCallback updateParent) async {
              await _applyAnalysisPreferenceChange(() {
                setState(updateParent);
                setModalState(() {});
              });
            }

            return ListView(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 8, 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Analysis options',
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(drawerContext).pop(),
                        icon: const Icon(Icons.close),
                        tooltip: 'Close options',
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                const _MenuSectionHeader('Aggregation'),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: SegmentedToggle<AnalysisMode>(
                    options: const [
                      SegmentedToggleOption(value: AnalysisMode.selectedMonth, label: 'Month'),
                      SegmentedToggleOption(value: AnalysisMode.cumulativeToSelectedMonth, label: 'Till month'),
                      SegmentedToggleOption(value: AnalysisMode.cumulativeYear, label: 'Year'),
                    ],
                    selectedValue: analysisMode,
                    onChanged: (value) => applyChanges(() => analysisMode = value),
                  ),
                ),
                const Divider(height: 1),
                const _MenuSectionHeader('Type'),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: SegmentedToggle<AnalysisType>(
                    options: const [
                      SegmentedToggleOption(value: AnalysisType.category, label: 'Category'),
                      SegmentedToggleOption(value: AnalysisType.account, label: 'Account'),
                    ],
                    selectedValue: analysisType,
                    onChanged: (value) => applyChanges(() => analysisType = value),
                  ),
                ),
                const Divider(height: 1),
                const _MenuSectionHeader('Sort'),
                const _MenuSectionHeader('Main analysis'),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: SegmentedToggle<AnalysisSortField>(
                    options: [
                      SegmentedToggleOption(value: AnalysisSortField.budget, label: _isIncomeVsExpense ? 'Income' : 'Budget'),
                      const SegmentedToggleOption(value: AnalysisSortField.expense, label: 'Expense'),
                    ],
                    selectedValue: analysisSortField,
                    onChanged: (value) => applyChanges(() => analysisSortField = value),
                  ),
                ),
                const _MenuSectionHeader('Sub menu'),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: SegmentedToggle<TransactionSortOrder>(
                    options: const [
                      SegmentedToggleOption(value: TransactionSortOrder.newestFirst, label: 'Newest'),
                      SegmentedToggleOption(value: TransactionSortOrder.oldestFirst, label: 'Oldest'),
                    ],
                    selectedValue: transactionSortOrder,
                    onChanged: (value) async {
                      setState(() => transactionSortOrder = value);
                      setModalState(() {});
                      await _persistPreferences();
                    },
                  ),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  dense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  value: showPercentage,
                  title: const Text('Show percentage'),
                  onChanged: (value) async {
                    setState(() => showPercentage = value);
                    setModalState(() {});
                    await _persistPreferences();
                  },
                ),
                const SizedBox(height: 12),
              ],
            );
          },
        );
      },
    );
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

  String _emptyStateMessage() {
    final label = analysisType == AnalysisType.category ? 'category' : 'account';
    final dataLabel = _isIncomeVsExpense ? 'income/expense' : 'expense';
    switch (analysisMode) {
      case AnalysisMode.cumulativeToSelectedMonth:
        return 'No $label $dataLabel data up to this month.';
      case AnalysisMode.cumulativeYear:
        return 'No $label $dataLabel data for this year.';
      case AnalysisMode.selectedMonth:
        return 'No $label $dataLabel data for this month.';
    }
  }

  List<Map<String, dynamic>> _transactionsForLabel(String label, {required String rowType}) {
    final base = !_isIncomeVsExpense
        ? _filteredTransactionsOfTypeForBottom('expense')
        : rowType == 'income'
            ? _filteredTransactionsOfType('income')
            : _filteredTransactionsOfType('expense');

    final matching = base.where((transaction) {
      if (_isIncomeVsExpense) {
        return rowType == 'income'
            ? _incomeKeyForTransaction(transaction) == label
            : _expenseKeyForTransaction(transaction) == label;
      }
      return _analysisKeyForTransaction(transaction) == label;
    }).toList();

    matching.sort((a, b) {
      final aDate = DateTime.parse(a['date'] as String);
      final bDate = DateTime.parse(b['date'] as String);
      final comparison = aDate.compareTo(bDate);
      return transactionSortOrder == TransactionSortOrder.newestFirst ? -comparison : comparison;
    });

    return matching;
  }

  String? _aggregationSubtitleForHeader() {
    switch (analysisMode) {
      case AnalysisMode.selectedMonth:
        return null;
      case AnalysisMode.cumulativeToSelectedMonth:
        return 'Till month';
      case AnalysisMode.cumulativeYear:
        return 'Year';
    }
  }

  Future<void> _editTransaction(Map<String, dynamic> transaction) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => AddTransactionPage(
        existingTransaction: transaction,
        modalStyle: true,
      ),
    );

    if (result == null) return;

    await DataService.updateTransaction(
      transaction['id'] as int,
      result['title'] as String,
      result['amount'] as double,
      result['date'] as DateTime,
      result['type'] as String,
      (result['account'] ?? '').toString(),
      (result['comment'] ?? '').toString(),
    );

    if (!mounted) return;
    await loadAnalysis();
  }

  void _showRelatedTransactions(Map<String, dynamic> data) {
    final label = data['label'] as String;
    final rowType = (data['rowType'] as String?) ?? 'expense';
    final dateFormat = DateFormat('dd MMM yyyy');

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (bottomSheetContext) {
        return StatefulBuilder(
          builder: (context, _) {
            final groupedTransactions = _transactionsForLabel(label, rowType: rowType);
            return SafeArea(
              child: SizedBox(
                height: MediaQuery.of(context).size.height * 0.68,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            label,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${groupedTransactions.length} transactions • ${transactionSortOrder == TransactionSortOrder.newestFirst ? 'Newest first' : 'Oldest first'}',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: groupedTransactions.isEmpty
                          ? const Center(child: Text('No related transactions found.'))
                          : ListView.separated(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              itemCount: groupedTransactions.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 8),
                              itemBuilder: (context, index) {
                                final transaction = groupedTransactions[index];
                                final amount = (transaction['amount'] as num).toDouble();
                                final date = DateTime.parse(transaction['date'] as String);
                                final comment = (transaction['comment'] as String? ?? '').trim();
                                final subtitle = analysisType == AnalysisType.category
                                    ? (transaction['account'] as String?)?.trim() ?? ''
                                    : (transaction['title'] as String?)?.trim() ?? '';
                                final entry = _entryForLabel(label, rowType: rowType);

                                return Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(16),
                                    onTap: () async {
                                      Navigator.of(bottomSheetContext).pop();
                                      await _editTransaction(transaction);
                                      if (mounted) {
                                        _showRelatedTransactions(data);
                                      }
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.35),
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          AppPageIcon(
                                            icon: iconFromCodePoint(
                                              entry?['icon'],
                                              fallback: analysisType == AnalysisType.category ? Icons.category : Icons.account_balance_wallet,
                                            ),
                                            imagePath: entry?['icon_path']?.toString(),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  subtitle.isEmpty ? label : subtitle,
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: const TextStyle(fontWeight: FontWeight.w600),
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  dateFormat.format(date),
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                                  ),
                                                ),
                                                if (comment.isNotEmpty) ...[
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    comment,
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color: Theme.of(context)
                                                          .colorScheme
                                                          .onSurfaceVariant
                                                          .withValues(alpha: 0.85),
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.end,
                                            children: [
                                              Text(
                                                formatIndianCurrency(amount),
                                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                'Tap to edit',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final expense = _activeTotalExpense();
    final income = _activeTotalIncome();
    final budgetTotal = _activeTotalBudget();
    final leftValue = _isIncomeVsExpense ? income : budgetTotal;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: PageContentLayout(
        child: Column(
          children: [
            MonthSummary(
              currentMonth: currentMonth,
              aggregationSubtitle: _aggregationSubtitleForHeader(),
              onPrev: () {
                setState(() {
                  currentMonth = DateTime(currentMonth.year, currentMonth.month - 1);
                  selectedChartBucket = null;
                  _monthBeforeChartBucket = null;
                });
                loadAnalysis();
              },
              onNext: () {
                setState(() {
                  currentMonth = DateTime(currentMonth.year, currentMonth.month + 1);
                  selectedChartBucket = null;
                  _monthBeforeChartBucket = null;
                });
                loadAnalysis();
              },
              budget: leftValue,
              expense: expense,
              leftLabel: _isIncomeVsExpense ? 'Income' : 'Budget',
              middleLabel: 'Expense',
              rightLabel: _isIncomeVsExpense ? 'Net' : 'Remaining',
              monthTrailing: IconButton(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: const Icon(Icons.more_vert, size: 20),
                onPressed: _showAnalysisOptions,
                tooltip: 'Analysis options',
              ),
            ),
            MiniProgressBar(
              expense: expense,
              reference: leftValue,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
              child: _isIncomeVsExpense
                  ? Builder(
                      builder: (context) {
                        final top5 = _incomeModeSidePanelRows();
                        final showSide = top5.isNotEmpty;
                        return SizedBox(
                          height: 228,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                flex: showSide ? 5 : 1,
                                child: IncomeModeRadialChart(
                                  incomeTotal: income,
                                  budgetTotal: budgetTotal,
                                  expenseTotal: expense,
                                  selectedSlice: selectedPieSlice,
                                  chartHeight: 218,
                                  onSliceTap: (slice) async {
                                    setState(() {
                                      selectedPieSlice = selectedPieSlice == slice ? null : slice;
                                    });
                                    await loadAnalysis();
                                  },
                                  onClear: selectedPieSlice != null
                                      ? () async {
                                          setState(() {
                                            selectedPieSlice = null;
                                          });
                                          await loadAnalysis();
                                        }
                                      : null,
                                ),
                              ),
                              if (showSide) ...[
                                const SizedBox(width: 10),
                                Expanded(
                                  flex: 5,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _incomeModeSidePanelTitle(),
                                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                              fontWeight: FontWeight.w700,
                                            ),
                                      ),
                                      const SizedBox(height: 6),
                                      Expanded(
                                        child: ListView.separated(
                                          padding: EdgeInsets.zero,
                                          itemCount: top5.length,
                                          separatorBuilder: (_, __) => const SizedBox(height: 6),
                                          itemBuilder: (context, index) {
                                            final row = top5[index];
                                            final rowType = _incomeModeSidePanelRowType();
                                            final entry = _entryForLabel(row.label, rowType: rowType);
                                            return Row(
                                              children: [
                                                AppPageIcon(
                                                  icon: iconFromCodePoint(
                                                    entry?['icon'],
                                                    fallback: analysisType == AnalysisType.category
                                                        ? Icons.category
                                                        : Icons.account_balance_wallet,
                                                  ),
                                                  imagePath: entry?['icon_path']?.toString(),
                                                ),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: Text(
                                                    row.label,
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                    style: const TextStyle(
                                                      fontWeight: FontWeight.w600,
                                                      fontSize: 13,
                                                    ),
                                                  ),
                                                ),
                                                Text(
                                                  formatIndianCurrency(row.amount),
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.w700,
                                                    fontSize: 12,
                                                    color: _incomeModeSidePanelAmountColor(context),
                                                  ),
                                                ),
                                              ],
                                            );
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    )
                  : AggregationBarChart(
                      data: _analysisChartData(),
                      emptyMessage: 'No expense data available for this aggregation.',
                      selectedBucket: selectedChartBucket,
                      onBarTap: (item) async {
                        final tappedBucket = item.bucket;
                        final nextBucket = selectedChartBucket == tappedBucket ? null : tappedBucket;
                        if (analysisMode == AnalysisMode.selectedMonth) {
                          setState(() {
                            selectedChartBucket = nextBucket;
                          });
                        } else {
                          if (nextBucket != null) {
                            _monthBeforeChartBucket ??= DateTime(currentMonth.year, currentMonth.month);
                            setState(() {
                              currentMonth = DateTime(currentMonth.year, nextBucket, 1);
                              selectedChartBucket = nextBucket;
                            });
                          } else {
                            setState(() {
                              selectedChartBucket = null;
                              if (_monthBeforeChartBucket != null) {
                                currentMonth = _monthBeforeChartBucket!;
                                _monthBeforeChartBucket = null;
                              }
                            });
                          }
                        }
                        await loadAnalysis();
                      },
                      trailing: selectedChartBucket != null
                          ? IconButton(
                              onPressed: () async {
                                setState(() {
                                  selectedChartBucket = null;
                                  if (_monthBeforeChartBucket != null) {
                                    currentMonth = _monthBeforeChartBucket!;
                                    _monthBeforeChartBucket = null;
                                  }
                                });
                                await loadAnalysis();
                              },
                              icon: const Icon(Icons.close_rounded, size: 16),
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.all(4),
                              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                              splashRadius: 14,
                              tooltip: 'Clear filter',
                            )
                          : null,
                    ),
            ),
            Expanded(
              child: SectionTile(
                child: analysisData.isEmpty
                    ? Center(
                        child: _isAnalysisLoading
                            ? const Padding(
                                padding: EdgeInsets.all(24),
                                child: CircularProgressIndicator(),
                              )
                            : Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 24),
                                child: Text(
                                  _isIncomeVsExpense &&
                                          selectedPieSlice == IncomeExpensePieSlice.budget
                                      ? 'Switch to budget mode for budget analysis.'
                                      : _emptyStateMessage(),
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                                      ),
                                ),
                              ),
                      )
                    : ListView.builder(
                        padding: EdgeInsets.zero,
                        itemCount: analysisData.length,
                        itemBuilder: (context, index) {
                          final data = analysisData[index];
                          final label = data['label'] as String;
                          final rowType = (data['rowType'] as String?) ?? 'expense';
                          final isIncomeTransactionRow = rowType == 'income_tx';
                          final spent = (data['spent'] as num).toDouble();
                          final budget = (data['budget'] as num).toDouble();
                          final incomeAmount = (data['income'] as num?)?.toDouble() ?? 0.0;
                          final totalIncomeAggregation = (data['totalIncomeAggregation'] as num?)?.toDouble() ?? 0.0;
                          final totalExpenseAggregation = (data['totalExpenseAggregation'] as num?)?.toDouble() ?? 0.0;

                          final ratio = !_isIncomeVsExpense
                              ? (analysisType == AnalysisType.account
                                  ? 0.0
                                  : (budget == 0 ? (spent > 0 ? 1.01 : 0.0) : spent / budget))
                              : rowType == 'income'
                                  ? (totalIncomeAggregation == 0 ? 0.0 : incomeAmount / totalIncomeAggregation)
                                  : (totalExpenseAggregation == 0 ? 0.0 : spent / totalExpenseAggregation);

                          final progress = !_isIncomeVsExpense
                              ? (analysisType == AnalysisType.account
                                  ? 0.0
                                  : (budget == 0
                                      ? (spent > 0 ? 1.0 : 0.0)
                                      : (spent == 0 ? 0.02 : ratio.clamp(0.0, 1.0).toDouble())))
                              : (rowType == 'income'
                                  ? (totalIncomeAggregation == 0
                                      ? 0.0
                                      : (incomeAmount == 0 ? 0.0 : ratio.clamp(0.0, 1.0).toDouble()))
                                  : (totalExpenseAggregation == 0
                                      ? 0.0
                                      : (spent == 0 ? 0.0 : ratio.clamp(0.0, 1.0).toDouble())));

                          final budgetRatio = (ratio * 100).isFinite ? (ratio * 100).clamp(0, 999).round() : 0;

                          final entry = _entryForLabel(label, rowType: rowType);

                          return InkWell(
                            onTap: isIncomeTransactionRow
                                ? () async {
                                    final txId = data['txId'];
                                    if (txId is! int) return;
                                    final selected = transactions.where((tx) => tx['id'] == txId).toList();
                                    if (selected.isEmpty) return;
                                    await _editTransaction(selected.first);
                                  }
                                : () => _showRelatedTransactions(data),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Category name + icon row
                                  Row(
                                    children: [
                                      AppPageIcon(
                                        icon: iconFromCodePoint(
                                          entry?['icon'],
                                          fallback: rowType == 'income'
                                              ? Icons.account_balance_wallet
                                              : (analysisType == AnalysisType.category ? Icons.category : Icons.account_balance_wallet),
                                        ),
                                        imagePath: entry?['icon_path']?.toString(),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          isIncomeTransactionRow
                                              ? ((data['txComment'] as String?)?.isNotEmpty ?? false
                                                  ? '$label • ${data['txComment']}'
                                                  : label)
                                              : label,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 15.5,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  // Progress bar with overlaid text + % at end
                                  if (isIncomeTransactionRow) ...[
                                    Text(
                                      '${DateFormat('dd MMM yyyy').format(DateTime.parse((data['txDate'] as String?) ?? DateTime.now().toIso8601String()))} • ${formatIndianCurrency(incomeAmount)}',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ] else if (!_isIncomeVsExpense && analysisType == AnalysisType.category) ...[
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Stack(
                                            alignment: Alignment.centerLeft,
                                            children: [
                                              Container(
                                                height: 16,
                                                decoration: BoxDecoration(
                                                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                                  borderRadius: BorderRadius.circular(999),
                                                ),
                                              ),
                                              FractionallySizedBox(
                                                widthFactor: progress.clamp(0.0, 1.0),
                                                child: Container(
                                                  height: 16,
                                                  decoration: BoxDecoration(
                                                    gradient: _progressGradient(ratio),
                                                    borderRadius: BorderRadius.circular(999),
                                                  ),
                                                ),
                                              ),
                                              Padding(
                                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                                child: Text(
                                                  '${formatIndianCurrency(spent)} / ${formatIndianCurrency(budget)}',
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: _progressBarOverlayStyle(
                                                    context,
                                                    ratio,
                                                    progress.clamp(0.0, 1.0),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        if (showPercentage) ...[
                                          const SizedBox(width: 8),
                                          SizedBox(
                                            width: 42,
                                            child: Text(
                                              '$budgetRatio%',
                                              textAlign: TextAlign.right,
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w700,
                                                color: _progressColor(ratio),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ] else if (!_isIncomeVsExpense) ...[
                                    Text(
                                      formatIndianCurrency(spent),
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ] else ...[
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Stack(
                                            alignment: Alignment.centerLeft,
                                            children: [
                                              Container(
                                                height: 16,
                                                decoration: BoxDecoration(
                                                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                                  borderRadius: BorderRadius.circular(999),
                                                ),
                                              ),
                                              FractionallySizedBox(
                                                widthFactor: progress.clamp(0.0, 1.0),
                                                child: Container(
                                                  height: 16,
                                                  decoration: BoxDecoration(
                                                    gradient: _progressGradient(ratio),
                                                    borderRadius: BorderRadius.circular(999),
                                                  ),
                                                ),
                                              ),
                                              Padding(
                                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                                child: Text(
                                                  rowType == 'income'
                                                      ? '${formatIndianCurrency(incomeAmount)} / ${formatIndianCurrency(totalIncomeAggregation)}'
                                                      : '${formatIndianCurrency(spent)} / ${formatIndianCurrency(totalExpenseAggregation)}',
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: _progressBarOverlayStyle(
                                                    context,
                                                    ratio,
                                                    progress.clamp(0.0, 1.0),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        if (showPercentage) ...[
                                          const SizedBox(width: 8),
                                          SizedBox(
                                            width: 42,
                                            child: Text(
                                              '$budgetRatio%',
                                              textAlign: TextAlign.right,
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w700,
                                                color: _progressColor(ratio),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuSectionHeader extends StatelessWidget {
  final String title;

  const _MenuSectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 2),
      child: Text(
        title,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
      ),
    );
  }
}

class _BreakdownRow {
  final String label;
  final double amount;

  _BreakdownRow(this.label, this.amount);
}
