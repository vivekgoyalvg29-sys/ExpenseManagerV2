import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/data_service.dart';
import '../services/data_store.dart';
import '../utils/indian_number_formatter.dart';
import '../widgets/insights_budget_race_chart.dart';
import '../widgets/insights_income_savings_chart.dart';
import '../widgets/page_content_layout.dart';

/// Premium read-only insights for the current month and recent history.
class InsightsPage extends StatefulWidget {
  const InsightsPage({super.key});

  @override
  State<InsightsPage> createState() => _InsightsPageState();
}

enum _InsightsRaceAggregation {
  monthly,
  tillMonth,
  yearly,
}

class _InsightsPageState extends State<InsightsPage> {
  static const _prefsKeywordsKey = 'insights.one_time_expense_keywords';
  static const _prefsRaceAggKey = 'insights.race_aggregation';

  bool _loading = true;
  List<Map<String, dynamic>> _tx = [];
  List<Map<String, dynamic>> _budgets = [];
  String _oneTimeKeywords = '';
  _InsightsRaceAggregation _raceAgg = _InsightsRaceAggregation.monthly;

  @override
  void initState() {
    super.initState();
    DataStore.transactionMutationGeneration.addListener(_onDataChanged);
    DataStore.profileSwitchGeneration.addListener(_onDataChanged);
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await _restorePrefs();
    if (mounted) await _load();
  }

  void _onDataChanged() {
    if (mounted) _load();
  }

  @override
  void dispose() {
    DataStore.transactionMutationGeneration.removeListener(_onDataChanged);
    DataStore.profileSwitchGeneration.removeListener(_onDataChanged);
    super.dispose();
  }

  Future<void> _restorePrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _oneTimeKeywords = prefs.getString(_prefsKeywordsKey) ?? '';
      final idx = prefs.getInt(_prefsRaceAggKey);
      if (idx != null &&
          idx >= 0 &&
          idx < _InsightsRaceAggregation.values.length) {
        _raceAgg = _InsightsRaceAggregation.values[idx];
      }
    });
  }

  Future<void> _persistKeywords(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKeywordsKey, value);
  }

  Future<void> _persistRaceAgg(_InsightsRaceAggregation v) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_prefsRaceAggKey, v.index);
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final now = DateTime.now();
      final start = DateTime(now.year - 5, 1, 1);
      final end = DateTime(now.year, 12, 31);
      final tx = await DataService.getTransactions(startDate: start, endDate: end);
      final budgets = await DataService.getBudgets();
      if (!mounted) return;
      setState(() {
        _tx = tx;
        _budgets = budgets;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _tx = [];
        _budgets = [];
        _loading = false;
      });
    }
  }

  List<String> _keywordList() {
    return _oneTimeKeywords
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  bool _commentMatchesKeyword(String? comment, List<String> keys) {
    if (keys.isEmpty) return false;
    final c = (comment ?? '').toLowerCase();
    if (c.isEmpty) return false;
    for (final k in keys) {
      if (k.isEmpty) continue;
      if (c.contains(k.toLowerCase())) return true;
    }
    return false;
  }

  double _oneTimeExpenseSum(List<Map<String, dynamic>> monthTx, List<String> keys) {
    if (keys.isEmpty) return 0;
    var s = 0.0;
    for (final t in monthTx) {
      if ((t['type'] as String?) != 'expense') continue;
      if (!_commentMatchesKeyword(t['comment'] as String?, keys)) continue;
      s += (t['amount'] as num).toDouble().abs();
    }
    return s;
  }

  Future<void> _showOneTimeExpenseDialog() async {
    final controller = TextEditingController(text: _oneTimeKeywords);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('One-time expense keywords'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Comma-separated words or phrases matched against transaction comments. '
                'Matched amounts count toward spending but are not used to extrapolate daily burn, '
                'so big early-month one-offs do not distort your month-end forecast.',
                style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                      color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: 'e.g. Rent, maid, electricity',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      setState(() => _oneTimeKeywords = controller.text);
      await _persistKeywords(_oneTimeKeywords);
    }
    controller.dispose();
  }

  double _budgetForMonth(int year, int month) {
    return _budgets
        .where(
          (b) =>
              (b['year'] as num?)?.toInt() == year &&
              (b['month'] as num?)?.toInt() == month,
        )
        .fold<double>(
          0,
          (s, b) => s + (b['amount'] as num).toDouble(),
        );
  }

  double _cumulativeExpenseThrough(DateTime endInclusive) {
    var s = 0.0;
    for (final t in _tx) {
      if ((t['type'] as String?) != 'expense') continue;
      final d = _parseTxDate(t);
      if (d.isAfter(endInclusive)) continue;
      s += (t['amount'] as num).toDouble().abs();
    }
    return s;
  }

  static DateTime _parseTxDate(Map<String, dynamic> t) {
    return DateTime.parse(t['date'] as String);
  }

  static DateTime _addMonths(DateTime from, int monthsToAdd) {
    var y = from.year;
    var m = from.month + monthsToAdd;
    while (m > 12) {
      m -= 12;
      y++;
    }
    while (m < 1) {
      m += 12;
      y--;
    }
    return DateTime(y, m, 1);
  }

  static bool _inRange(DateTime d, DateTime start, DateTime end) =>
      !d.isBefore(start) && !d.isAfter(end);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    if (_loading) {
      return PageContentLayout(
        child: Center(
          child: SizedBox(
            height: 300,
            child: Center(
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: cs.primary,
              ),
            ),
          ),
        ),
      );
    }

    if (_tx.isEmpty) {
      return PageContentLayout(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.insights_rounded,
                  size: 48,
                  color: cs.onSurfaceVariant,
                ),
                const SizedBox(height: 16),
                Text(
                  'No data yet',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: cs.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Start adding transactions to see your insights here.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    final monthEnd = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
    final daysInMonth = monthEnd.day;
    final todayDay = now.day;

    final monthTx = _tx.where((t) {
      final d = _parseTxDate(t);
      return _inRange(d, monthStart, monthEnd);
    }).toList();

    // —— Card 1: Expense forecast ——
    final keys = _keywordList();
    double expenseSoFar = 0;
    for (final t in monthTx) {
      if ((t['type'] as String?) == 'expense') {
        expenseSoFar += (t['amount'] as num).toDouble().abs();
      }
    }
    final oneTimeSum = _oneTimeExpenseSum(monthTx, keys);
    final scalableSpend = math.max(0.0, expenseSoFar - oneTimeSum);
    final daysElapsed = math.max(1, todayDay);
    final avgDailyScaled = scalableSpend / daysElapsed;
    final projectedMonthExpense =
        avgDailyScaled * daysInMonth + oneTimeSum;

    double incomeThisMonth = 0;
    for (final t in monthTx) {
      if ((t['type'] as String?) == 'income') {
        incomeThisMonth += (t['amount'] as num).toDouble().abs();
      }
    }

    // —— Card 2: Budget race ——
    final budgetsThisMonth = _budgets.where((b) {
      final y = (b['year'] as num?)?.toInt() ?? 0;
      final m = (b['month'] as num?)?.toInt() ?? 0;
      return y == now.year && m == now.month;
    }).toList();
    final totalMonthBudget = budgetsThisMonth.fold<double>(
      0,
      (s, b) => s + (b['amount'] as num).toDouble(),
    );
    final showBudgetRace = totalMonthBudget > 0;
    final dailyBudgetAllowance = showBudgetRace ? totalMonthBudget / daysInMonth : 0.0;

    final dailyExpense = List<double>.filled(daysInMonth, 0);
    for (final t in monthTx) {
      if ((t['type'] as String?) != 'expense') continue;
      final d = _parseTxDate(t);
      final day = d.day;
      if (day >= 1 && day <= daysInMonth) {
        dailyExpense[day - 1] += (t['amount'] as num).toDouble().abs();
      }
    }
    final cumulativeExpenseByDay = List<double>.generate(daysInMonth, (i) {
      var s = 0.0;
      for (var j = 0; j <= i; j++) {
        s += dailyExpense[j];
      }
      return s;
    });
    final cumToday = cumulativeExpenseByDay[todayDay - 1];
    final budgetTodayPace = dailyBudgetAllowance * todayDay;
    final paceDiff = budgetTodayPace - cumToday;

    InsightsRaceMonthlyData? monthRace;
    if (showBudgetRace && _raceAgg != _InsightsRaceAggregation.monthly) {
      final y = now.year;
      final n = _raceAgg == _InsightsRaceAggregation.tillMonth ? now.month : 12;
      final cumE = <double>[];
      final cumB = <double>[];
      final labels = <String>[];
      var bRun = 0.0;
      for (var m = 1; m <= n; m++) {
        bRun += _budgetForMonth(y, m);
        cumB.add(bRun);
        final end = m < now.month
            ? DateTime(y, m + 1, 0, 23, 59, 59)
            : DateTime(now.year, now.month, now.day, 23, 59, 59);
        cumE.add(_cumulativeExpenseThrough(end));
        labels.add(DateFormat.MMM().format(DateTime(y, m)));
      }
      monthRace = InsightsRaceMonthlyData(
        cumulativeExpense: cumE,
        cumulativeBudget: cumB,
        labels: labels,
        progressIndex: now.month - 1,
      );
    }

    // —— Card 3: Category creep ——
    final curStart = DateTime(now.year, now.month, 1);
    final mOldest = _addMonths(curStart, -3);
    final mMid = _addMonths(curStart, -2);
    final mNew = _addMonths(curStart, -1);
    final endOldest = DateTime(mOldest.year, mOldest.month + 1, 0, 23, 59, 59);
    final endMid = DateTime(mMid.year, mMid.month + 1, 0, 23, 59, 59);
    final endNew = DateTime(mNew.year, mNew.month + 1, 0, 23, 59, 59);

    final distinctMonthKeys = <String>{};
    for (final t in _tx) {
      final d = _parseTxDate(t);
      distinctMonthKeys.add('${d.year}-${d.month}');
    }
    final hasThreeMonthsHistory = distinctMonthKeys.length >= 3;

    Map<String, double> spendInRange(DateTime start, DateTime end) {
      final map = <String, double>{};
      for (final t in _tx) {
        if ((t['type'] as String?) != 'expense') continue;
        final d = _parseTxDate(t);
        if (_inRange(d, start, end)) {
          final cat = (t['title'] as String?)?.trim() ?? '';
          if (cat.isEmpty) continue;
          final a = (t['amount'] as num).toDouble().abs();
          map[cat] = (map[cat] ?? 0) + a;
        }
      }
      return map;
    }

    final s1 = spendInRange(mOldest, endOldest);
    final s2 = spendInRange(mMid, endMid);
    final s3 = spendInRange(mNew, endNew);
    final allCats = {...s1.keys, ...s2.keys, ...s3.keys};

    final growing = <({String name, double pct})>[];
    final declining = <({String name, double pct})>[];
    if (hasThreeMonthsHistory) {
      for (final cat in allCats) {
        final a = s1[cat] ?? 0;
        final b = s2[cat] ?? 0;
        final c = s3[cat] ?? 0;
        if (a < b && b < c) {
          final pct = a > 0 ? (c - a) / a * 100 : 100.0;
          growing.add((name: cat, pct: pct));
        }
        if (a > b && b > c) {
          final pct = a > 0 ? (a - c) / a * 100 : 100.0;
          declining.add((name: cat, pct: pct));
        }
      }
      growing.sort((u, v) => v.pct.compareTo(u.pct));
      declining.sort((u, v) => v.pct.compareTo(u.pct));
    }

    // —— Income baseline (projected savings on expense card) ——
    final monthlyIncomeTotals = <DateTime, double>{};
    for (final t in _tx) {
      if ((t['type'] as String?) != 'income') continue;
      final d = _parseTxDate(t);
      final key = DateTime(d.year, d.month, 1);
      monthlyIncomeTotals[key] =
          (monthlyIncomeTotals[key] ?? 0) + (t['amount'] as num).toDouble().abs();
    }
    final monthsWithIncome = monthlyIncomeTotals.keys.toList()..sort();
    final nIncomeMonths = monthsWithIncome.length;
    double? baselineIncome;
    if (nIncomeMonths >= 1) {
      if (nIncomeMonths == 1) {
        baselineIncome = monthlyIncomeTotals[monthsWithIncome.first]!;
      } else {
        final sum =
            monthlyIncomeTotals.values.fold<double>(0, (a, b) => a + b);
        baselineIncome = sum / nIncomeMonths;
      }
    }
    final showSavingsForecast = baselineIncome != null && nIncomeMonths >= 1;
    var forecastedSavingsVal = 0.0;
    var savingsRateVal = 0.0;
    var baselineIncomeVal = 0.0;
    if (showSavingsForecast) {
      baselineIncomeVal = baselineIncome;
      forecastedSavingsVal = baselineIncomeVal - projectedMonthExpense;
      savingsRateVal =
          baselineIncomeVal > 0 ? (forecastedSavingsVal / baselineIncomeVal) * 100 : 0;
    }

    // —— Card 5: Year overview ——
    final yearStart = DateTime(now.year, 1, 1);
    final yearEnd = DateTime(now.year, 12, 31, 23, 59, 59);
    final yearTx =
        _tx.where((t) => _inRange(_parseTxDate(t), yearStart, yearEnd)).toList();

    final perMonthIncome = <int, double>{};
    final perMonthExpense = <int, double>{};
    final monthHasIncome = <int, bool>{};
    for (final t in yearTx) {
      final d = _parseTxDate(t);
      final mo = d.month;
      final typ = t['type'] as String?;
      final amt = (t['amount'] as num).toDouble().abs();
      if (typ == 'income') {
        perMonthIncome[mo] = (perMonthIncome[mo] ?? 0) + amt;
        monthHasIncome[mo] = true;
      } else if (typ == 'expense') {
        perMonthExpense[mo] = (perMonthExpense[mo] ?? 0) + amt;
      }
    }
    final qualifyingMonths = monthHasIncome.keys.toList()..sort();
    final showYearChart = qualifyingMonths.length >= 2;

    int? bestMonth;
    double bestSavings = double.negativeInfinity;
    if (showYearChart) {
      for (final mo in qualifyingMonths) {
        final inc = perMonthIncome[mo] ?? 0;
        final exp = perMonthExpense[mo] ?? 0;
        final sav = inc - exp;
        if (sav > bestSavings) {
          bestSavings = sav;
          bestMonth = mo;
        }
      }
    }

    const monthLetters = [
      'J',
      'F',
      'M',
      'A',
      'M',
      'J',
      'J',
      'A',
      'S',
      'O',
      'N',
      'D',
    ];
    final yearChartData = <InsightsIncomeSavingsMonthDatum>[];
    if (showYearChart) {
      final useOneLetter = qualifyingMonths.length > 6;
      for (final mo in qualifyingMonths) {
        final inc = perMonthIncome[mo] ?? 0;
        final exp = perMonthExpense[mo] ?? 0;
        final sav = inc - exp;
        final full = DateFormat.MMM().format(DateTime(now.year, mo));
        final label = useOneLetter ? monthLetters[mo - 1] : full;
        yearChartData.add(
          InsightsIncomeSavingsMonthDatum(
            monthIndex: mo,
            label: label,
            income: inc,
            expense: exp,
            savings: sav,
          ),
        );
      }
    }

    final cards = <Widget>[
      _insightCard(
        context: context,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    'Expense Forecast',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: cs.onSurface,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: _showOneTimeExpenseDialog,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('One-time expense'),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Based on $daysElapsed days of spending',
              style: theme.textTheme.labelSmall?.copyWith(
                color: cs.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Projected spend uses recurring daily burn; one-time amounts from keywords are added back at month end.',
              style: theme.textTheme.labelSmall?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Spent so far',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 4),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          formatIndianCurrency(expenseSoFar),
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: cs.onSurface,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Projected by month end',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 4),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          formatIndianCurrency(projectedMonthExpense),
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: cs.tertiary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Divider(
              height: 1,
              thickness: 1,
              color: cs.outline.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 12),
            if (incomeThisMonth > 0) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Income this month',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 4),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            formatIndianCurrency(incomeThisMonth),
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: cs.onSurface,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Projected surplus / shortfall',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 4),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            formatIndianCurrency(
                              incomeThisMonth - projectedMonthExpense,
                            ),
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: (incomeThisMonth - projectedMonthExpense) >= 0
                                  ? cs.primary
                                  : cs.error,
                            ),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          (incomeThisMonth - projectedMonthExpense) >= 0
                              ? 'surplus'
                              : 'shortfall',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ] else
              Text(
                'Add income transactions to see surplus or shortfall',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                  fontStyle: FontStyle.italic,
                ),
              ),
            if (showSavingsForecast) ...[
              const SizedBox(height: 12),
              Divider(
                height: 1,
                thickness: 1,
                color: cs.outline.withValues(alpha: 0.3),
              ),
              const SizedBox(height: 12),
              Text(
                'Projected savings this month',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  formatIndianCurrency(forecastedSavingsVal),
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: forecastedSavingsVal >= 0 ? cs.primary : cs.error,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Based on typical income vs projected expense',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: cs.onSurfaceVariant,
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Typical income',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          formatIndianCurrency(baselineIncomeVal),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Savings rate',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${savingsRateVal.toStringAsFixed(1)}%',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: savingsRateVal >= 0 ? cs.primary : cs.error,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (nIncomeMonths == 1) ...[
                const SizedBox(height: 8),
                Text(
                  'Add more income history for a steadier typical income estimate',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: cs.onSurfaceVariant,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    ];

    final monthRacePaceDiff = monthRace != null && monthRace.cumulativeBudget.isNotEmpty
        ? monthRace.cumulativeBudget[monthRace.progressIndex.clamp(
              0,
              monthRace.cumulativeBudget.length - 1,
            )] -
            monthRace.cumulativeExpense[monthRace.progressIndex.clamp(
              0,
              monthRace.cumulativeExpense.length - 1,
            )]
        : 0.0;

    if (showBudgetRace) {
      cards.add(const SizedBox(height: 16));
      cards.add(
        _insightCard(
          context: context,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Budget Race',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Compares cumulative actual spending to linear budget pace (expense/day vs budget/day).',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 10),
              SegmentedButton<_InsightsRaceAggregation>(
                segments: const [
                  ButtonSegment(
                    value: _InsightsRaceAggregation.monthly,
                    label: Text('Month'),
                  ),
                  ButtonSegment(
                    value: _InsightsRaceAggregation.tillMonth,
                    label: Text('Till month'),
                  ),
                  ButtonSegment(
                    value: _InsightsRaceAggregation.yearly,
                    label: Text('Year'),
                  ),
                ],
                selected: {_raceAgg},
                onSelectionChanged: (s) async {
                  setState(() => _raceAgg = s.first);
                  await _persistRaceAgg(_raceAgg);
                },
                style: ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                showSelectedIcon: false,
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  _LegendDot(color: cs.error),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      'Actual',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  _LegendDash(color: cs.primary),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      'Budget pace',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              InsightsBudgetRaceChart(
                daysInMonth: daysInMonth,
                todayDay: todayDay,
                dailyBudgetAllowance: dailyBudgetAllowance,
                totalMonthBudget: totalMonthBudget,
                cumulativeExpenseByDay: cumulativeExpenseByDay,
                todayCumulativeLabel: formatIndianCurrency(cumToday),
                budgetEndLabel: formatIndianCurrency(totalMonthBudget),
                colorScheme: cs,
                monthly: monthRace,
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  monthRace != null
                      ? (monthRacePaceDiff >= 0
                          ? "You're ${formatIndianCurrency(monthRacePaceDiff)} ahead of budget pace (YTD)"
                          : "You're ${formatIndianCurrency(-monthRacePaceDiff)} over budget pace (YTD)")
                      : (paceDiff >= 0
                          ? "You're ${formatIndianCurrency(paceDiff)} ahead of budget pace"
                          : "You're ${formatIndianCurrency(-paceDiff)} over budget pace"),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: (monthRace != null ? monthRacePaceDiff : paceDiff) >= 0
                        ? cs.primary
                        : cs.error,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    cards.add(const SizedBox(height: 16));
    cards.add(
      _insightCard(
        context: context,
        child: showYearChart && bestMonth != null
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Income & Savings Overview',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: cs.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'This calendar year',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(
                        Icons.emoji_events_rounded,
                        color: const Color(0xFFFFC107),
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Best month: ${DateFormat.MMMM().format(DateTime(now.year, bestMonth))}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: cs.onSurface,
                          ),
                        ),
                      ),
                      Text(
                        formatIndianCurrency(bestSavings),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: cs.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  InsightsIncomeSavingsChart(
                    data: yearChartData,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 12,
                    runSpacing: 6,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _LegendBox(color: InsightsIncomeSavingsChart.incomeLineColor),
                          const SizedBox(width: 6),
                          Text(
                            'Income',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _LegendBox(color: InsightsIncomeSavingsChart.expenseLineColor),
                          const SizedBox(width: 6),
                          Text(
                            'Expense',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _LegendBox(color: InsightsIncomeSavingsChart.savingsLineColor),
                          const SizedBox(width: 6),
                          Text(
                            'Savings',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Income & Savings Overview',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: cs.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'This calendar year',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Icon(
                    Icons.hourglass_empty,
                    size: 32,
                    color: cs.onSurfaceVariant,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Not enough data yet',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: cs.onSurface,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'You need at least two months with income this year to see this chart.',
                    textAlign: TextAlign.center,
                    maxLines: 3,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
      ),
    );

    cards.add(const SizedBox(height: 16));
    cards.add(
      _insightCard(
        context: context,
        child: hasThreeMonthsHistory
            ? _categoryCreepContent(
                context,
                growing: growing.take(3).toList(),
                declining: declining.take(3).toList(),
              )
            : _categoryCreepEmpty(context),
      ),
    );

    cards.add(const SizedBox(height: 24));

    return PageContentLayout(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Insights',
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Your financial picture, clearly.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            ...cards,
          ],
        ),
      ),
    );
  }

  Widget _categoryCreepContent(
    BuildContext context, {
    required List<({String name, double pct})> growing,
    required List<({String name, double pct})> declining,
  }) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Spending Trends',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: cs.onSurface,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Based on last 3 months',
          style: theme.textTheme.labelSmall?.copyWith(
            color: cs.onSurfaceVariant,
            fontStyle: FontStyle.italic,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Icon(Icons.trending_up, color: cs.error, size: 16),
            const SizedBox(width: 6),
            Text(
              'Rising',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (growing.isEmpty)
          Text(
            'No categories rising consistently',
            style: theme.textTheme.bodySmall?.copyWith(
              color: cs.onSurfaceVariant,
              fontStyle: FontStyle.italic,
            ),
          )
        else
          ...growing.map((e) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        e.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                    Text(
                      '+${e.pct.toStringAsFixed(0)}%',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: cs.error,
                      ),
                    ),
                  ],
                ),
              )),
        const SizedBox(height: 16),
        Row(
          children: [
            Icon(Icons.trending_down, color: cs.primary, size: 16),
            const SizedBox(width: 6),
            Text(
              'Easing',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (declining.isEmpty)
          Text(
            'No categories easing consistently',
            style: theme.textTheme.bodySmall?.copyWith(
              color: cs.onSurfaceVariant,
              fontStyle: FontStyle.italic,
            ),
          )
        else
          ...declining.map((e) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        e.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                    Text(
                      '-${e.pct.toStringAsFixed(0)}%',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: cs.primary,
                      ),
                    ),
                  ],
                ),
              )),
      ],
    );
  }

  Widget _categoryCreepEmpty(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Column(
      children: [
        Text(
          'Spending Trends',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: cs.onSurface,
          ),
        ),
        const SizedBox(height: 16),
        Icon(
          Icons.hourglass_empty,
          size: 32,
          color: cs.onSurfaceVariant,
        ),
        const SizedBox(height: 8),
        Text(
          'Not enough data yet',
          style: theme.textTheme.titleSmall?.copyWith(
            color: cs.onSurface,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Come back after a few months of transactions to see your spending trends.',
          textAlign: TextAlign.center,
          maxLines: 3,
          style: theme.textTheme.bodySmall?.copyWith(
            color: cs.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _insightCard({
    required BuildContext context,
    required Widget child,
  }) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cs.surface.withValues(
          alpha: theme.brightness == Brightness.dark ? 0.92 : 0.98,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: cs.outline.withValues(
            alpha: theme.brightness == Brightness.dark ? 0.28 : 0.22,
          ),
          width: 0.8,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: theme.brightness == Brightness.dark ? 0.18 : 0.04,
            ),
            blurRadius: 12,
            spreadRadius: -3,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _LegendBox extends StatelessWidget {
  const _LegendBox({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }
}

class _LegendDash extends StatelessWidget {
  const _LegendDash({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 16,
      height: 2,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(1),
      ),
    );
  }
}
