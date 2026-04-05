import 'package:home_widget/home_widget.dart';
import 'package:intl/intl.dart';

import '../utils/indian_number_formatter.dart';
import 'data_service.dart';
import 'visual_settings.dart';

/// Pushes aggregated totals and display strings to the **phone home screen widget**
/// (Android App Widget + iOS WidgetKit), not in-app UI.
class WidgetSyncService {
  static const String androidWidgetProvider = 'ExpenseHomeWidgetProvider';
  static const String androidWidgetCompactProvider =
      'ExpenseHomeWidgetCompactProvider';
  static const String iOSWidgetName = 'ExpenseHomeWidget';

  static const String _modeKey = 'widget_mode';
  static const String _monthKey = 'widget_month';
  static const String _yearKey = 'widget_year';

  static const String selectedMonth = 'selectedMonth';
  static const String cumulativeToSelectedMonth = 'cumulativeToSelectedMonth';
  static const String cumulativeYear = 'cumulativeYear';

  /// Keys read by native widget code (Android + iOS).
  static const String keyCardPeriodTitle = 'widget_card_period_title';
  static const String keyExpenseDisplay = 'widget_expense_display';
  static const String keyCalendarDay = 'widget_calendar_day';
  static const String keyPaceVisible = 'widget_pace_visible';
  static const String keyPaceLabel = 'widget_pace_label';
  static const String keyPaceIsHigh = 'widget_pace_is_high';
  static const String keyBarProgressThousandths = 'widget_bar_progress_thousandths';
  static const String keyGaugeProgressThousandths = 'widget_gauge_progress_thousandths';
  static const String keyIncomeMode = 'widget_income_mode';
  static const String keyModeShort = 'widget_mode_short';

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

  static bool _dateInWindow(DateTime date, String mode, int year, int anchorMonth) {
    if (date.year != year) return false;
    if (mode == selectedMonth) return date.month == anchorMonth;
    if (mode == cumulativeToSelectedMonth) return date.month <= anchorMonth;
    return true;
  }

  static List<int> _monthsInWindow(String mode, int anchorMonth) {
    switch (mode) {
      case selectedMonth:
        return [anchorMonth];
      case cumulativeToSelectedMonth:
        return List.generate(anchorMonth, (i) => i + 1);
      case cumulativeYear:
        return List.generate(12, (i) => i + 1);
      default:
        return [anchorMonth];
    }
  }

  static bool _everyWindowMonthHasBudget(
    List<Map<String, dynamic>> budgets,
    int year,
    List<int> months,
  ) {
    for (final m in months) {
      final has = budgets.any((b) {
        final y = (b['year'] as num?)?.toInt() ?? 0;
        final mo = (b['month'] as num?)?.toInt() ?? 0;
        return y == year && mo == m;
      });
      if (!has) return false;
    }
    return true;
  }

  static String _cardPeriodTitle(String mode, int year, int month) {
    final yy = (year % 100).toString().padLeft(2, '0');
    if (mode == selectedMonth) {
      return '${DateFormat('MMMM').format(DateTime(year, month))}-$yy';
    }
    if (mode == cumulativeToSelectedMonth) {
      final start = DateFormat('MMM').format(DateTime(year, 1));
      final end = DateFormat('MMM').format(DateTime(year, month));
      return '$start–$end $yy';
    }
    return year.toString();
  }

  static String _modeShortLabel(String mode) {
    if (mode == cumulativeToSelectedMonth) return 'Till month';
    if (mode == cumulativeYear) return 'Year';
    return 'Month';
  }

  static Future<void> sync({
    required String mode,
    required int month,
    required int year,
  }) async {
    final tx = await DataService.getTransactions();
    final budgets = await DataService.getBudgets();

    ComparisonMode comparisonMode = ComparisonMode.budgetVsExpense;
    try {
      final visual = await VisualSettings.load();
      comparisonMode = visual.comparisonMode;
    } catch (_) {}

    final isIncomeMode = comparisonMode == ComparisonMode.incomeVsExpense;

    final expense = tx.where((t) {
      if (t['type'] != 'expense') return false;
      final date = DateTime.parse(t['date'] as String);
      return _dateInWindow(date, mode, year, month);
    }).fold<double>(0.0, (sum, t) => sum + (t['amount'] as num).toDouble());

    final income = tx.where((t) {
      if (t['type'] != 'income') return false;
      final date = DateTime.parse(t['date'] as String);
      return _dateInWindow(date, mode, year, month);
    }).fold<double>(0.0, (sum, t) => sum + (t['amount'] as num).toDouble());

    final budget = budgets.where((b) {
      final by = (b['year'] as num?)?.toInt() ?? 0;
      if (by != year) return false;
      final budgetMonth = (b['month'] as num).toInt();
      if (mode == selectedMonth) return budgetMonth == month;
      if (mode == cumulativeToSelectedMonth) return budgetMonth <= month;
      return true;
    }).fold<double>(0.0, (sum, b) => sum + (b['amount'] as num).toDouble());

    final windowMonths = _monthsInWindow(mode, month);
    final allMonthsHaveBudget =
        _everyWindowMonthHasBudget(budgets, year, windowMonths);

    final reference = isIncomeMode ? income : budget;
    final barRatio = reference > 0 && expense.isFinite
        ? (expense / reference).clamp(0.0, 1.0)
        : 0.0;
    final thousandths = (barRatio * 1000).round().clamp(0, 1000);

    final paceVisible = !isIncomeMode && allMonthsHaveBudget;
    final paceIsHigh = paceVisible && expense > budget;
    final paceLabel = paceVisible ? (paceIsHigh ? 'High' : 'Controlled') : '';

    final now = DateTime.now();
    final calendarDay =
        (now.year == year && now.month == month) ? now.day : 1;

    final selectedDate = DateTime(year, month, 1);

    // Legacy + new keys (native code may read either).
    await HomeWidget.saveWidgetData<String>('title', 'Expenses');
    await HomeWidget.saveWidgetData<String>('modeLabel', _modeLabel(mode));
    await HomeWidget.saveWidgetData<String>(
      'periodLabel',
      DateFormat('MMMM yyyy').format(selectedDate),
    );
    await HomeWidget.saveWidgetData<double>('budget', budget);
    await HomeWidget.saveWidgetData<double>('expense', expense);
    await HomeWidget.saveWidgetData<double>('remaining', budget - expense);
    await HomeWidget.saveWidgetData<double>('income', income);

    await HomeWidget.saveWidgetData<String>(
      keyCardPeriodTitle,
      _cardPeriodTitle(mode, year, month),
    );
    await HomeWidget.saveWidgetData<String>(
      keyExpenseDisplay,
      formatIndianCurrency(expense, decimalDigits: 0),
    );
    await HomeWidget.saveWidgetData<int>(keyCalendarDay, calendarDay);
    await HomeWidget.saveWidgetData<int>(keyPaceVisible, paceVisible ? 1 : 0);
    await HomeWidget.saveWidgetData<String>(keyPaceLabel, paceLabel);
    await HomeWidget.saveWidgetData<int>(keyPaceIsHigh, paceIsHigh ? 1 : 0);
    await HomeWidget.saveWidgetData<int>(keyBarProgressThousandths, thousandths);
    await HomeWidget.saveWidgetData<int>(keyGaugeProgressThousandths, thousandths);
    await HomeWidget.saveWidgetData<int>(keyIncomeMode, isIncomeMode ? 1 : 0);
    await HomeWidget.saveWidgetData<String>(keyModeShort, _modeShortLabel(mode));

    // Optional: still expose current calendar month for debugging / old builds.
    final currentMonthExpense = tx.where((t) {
      if (t['type'] != 'expense') return false;
      final date = DateTime.parse(t['date'] as String);
      return date.year == now.year && date.month == now.month;
    }).fold<double>(0.0, (sum, t) => sum + (t['amount'] as num).toDouble());

    final currentMonthBudget = budgets.where((b) {
      return b['year'] == now.year && b['month'] == now.month;
    }).fold<double>(0.0, (sum, b) => sum + (b['amount'] as num).toDouble());

    final currentMonthPercentage = currentMonthBudget <= 0
        ? 0.0
        : (currentMonthExpense / currentMonthBudget) * 100;

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
    await HomeWidget.updateWidget(
      androidName: androidWidgetCompactProvider,
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
