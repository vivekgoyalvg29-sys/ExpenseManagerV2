import 'package:home_widget/home_widget.dart';
import 'package:intl/intl.dart';

import '../utils/indian_number_formatter.dart';
import 'data_service.dart';

class WidgetSyncService {
  static const String androidWidgetProvider = 'ExpenseHomeWidgetProvider';
  static const String iOSWidgetName = 'ExpenseHomeWidget';

  static const String _modeKey = 'widget_mode';
  static const String _monthKey = 'widget_month';
  static const String _yearKey = 'widget_year';

  static const String selectedMonth = 'selectedMonth';
  static const String cumulativeToSelectedMonth = 'cumulativeToSelectedMonth';
  static const String cumulativeYear = 'cumulativeYear';

  static Future<void> updateConfiguration({
    required String mode,
    required int month,
    required int year,
  }) async {
    await HomeWidget.saveWidgetData<String>(_modeKey, mode);
    await HomeWidget.saveWidgetData<int>(_monthKey, month);
    await HomeWidget.saveWidgetData<int>(_yearKey, year);

    await sync(mode: mode, month: month, year: year);
  }

  static Future<void> syncFromStoredConfiguration() async {
    final now = DateTime.now();

    final mode = await HomeWidget.getWidgetData<String>(
          _modeKey,
          defaultValue: selectedMonth,
        ) ??
        selectedMonth;

    final month = await HomeWidget.getWidgetData<int>(
          _monthKey,
          defaultValue: now.month,
        ) ??
        now.month;

    final year = await HomeWidget.getWidgetData<int>(
          _yearKey,
          defaultValue: now.year,
        ) ??
        now.year;

    await sync(mode: mode, month: month, year: year);
  }

  static Future<void> sync({
    required String mode,
    required int month,
    required int year,
  }) async {
    final tx = await DataService.getTransactions();
    final budgets = await DataService.getBudgets();

    final expense = tx.where((t) {
      if (t['type'] != 'expense') return false;

      final date = DateTime.parse(t['date']);
      if (date.year != year) return false;

      if (mode == selectedMonth) return date.month == month;
      if (mode == cumulativeToSelectedMonth) return date.month <= month;
      return true;
    }).fold<double>(0.0, (sum, t) => sum + (t['amount'] as num).toDouble());

    final budget = budgets.where((b) {
      if (b['year'] != year) return false;
      final budgetMonth = b['month'] as int;

      if (mode == selectedMonth) return budgetMonth == month;
      if (mode == cumulativeToSelectedMonth) return budgetMonth <= month;
      return true;
    }).fold<double>(0.0, (sum, b) => sum + (b['amount'] as num).toDouble());

    final selectedDate = DateTime(year, month, 1);
    final now = DateTime.now();

    final currentMonthExpense = tx.where((t) {
      if (t['type'] != 'expense') return false;
      final date = DateTime.parse(t['date']);
      return date.year == now.year && date.month == now.month;
    }).fold<double>(0.0, (sum, t) => sum + (t['amount'] as num).toDouble());

    final currentMonthBudget = budgets.where((b) {
      return b['year'] == now.year && b['month'] == now.month;
    }).fold<double>(0.0, (sum, b) => sum + (b['amount'] as num).toDouble());

    final currentMonthPercentage = currentMonthBudget <= 0
        ? 0.0
        : (currentMonthExpense / currentMonthBudget) * 100;

    await HomeWidget.saveWidgetData<String>('title', 'Budget vs Expense');
    await HomeWidget.saveWidgetData<String>('modeLabel', _modeLabel(mode));
    await HomeWidget.saveWidgetData<String>(
      'periodLabel',
      DateFormat('MMMM yyyy').format(selectedDate),
    );
    await HomeWidget.saveWidgetData<double>('budget', budget);
    await HomeWidget.saveWidgetData<double>('expense', expense);
    await HomeWidget.saveWidgetData<double>('remaining', budget - expense);
    await HomeWidget.saveWidgetData<String>(
      'currentPeriodLabel',
      DateFormat('MMMM').format(now),
    );
    await HomeWidget.saveWidgetData<double>('currentMonthBudget', currentMonthBudget);
    await HomeWidget.saveWidgetData<double>('currentMonthExpense', currentMonthExpense);
    await HomeWidget.saveWidgetData<double>('currentMonthPercentage', currentMonthPercentage);
    await HomeWidget.saveWidgetData<String>(
      'currentMonthPercentageLabel',
      '${currentMonthPercentage.toStringAsFixed(1)}%',
    );
    await HomeWidget.saveWidgetData<String>(
      'currentMonthExpenseLabel',
      _formatCurrency(currentMonthExpense),
    );

    await HomeWidget.updateWidget(
      androidName: androidWidgetProvider,
      iOSName: iOSWidgetName,
    );
  }

  static String _formatCurrency(double value) {
    return formatIndianCurrency(value);
  }

  static String _modeLabel(String mode) {
    if (mode == cumulativeToSelectedMonth) {
      return 'Cumulative till selected month';
    }

    if (mode == cumulativeYear) {
      return 'Cumulative full year';
    }

    return 'Selected month';
  }
}
