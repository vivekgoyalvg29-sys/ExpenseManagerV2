import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/account_subscription_service.dart';
import '../services/data_store.dart';
import '../services/data_service.dart';
import '../services/entitlement_service.dart';
import '../widgets/smart_budget_copy_sheet.dart';
import 'pro_purchase_flow.dart';
import '../services/widget_sync_service.dart';
import '../utils/indian_number_formatter.dart';
import '../widgets/icon_utils.dart';
import '../widgets/aggregation_section_header.dart';
import '../widgets/aggregation_bar_chart.dart';
import '../widgets/budget_month_pie_chart.dart';
import 'add_transaction_page.dart';
import 'categories_page.dart';
import '../widgets/month_section_card.dart';
import '../widgets/month_options_menu_button.dart';
import '../widgets/page_content_layout.dart';
import '../widgets/segmented_toggle.dart';
import '../widgets/section_tile.dart';
import '../widgets/side_overlay_sheet.dart';
import '../widgets/home_tab_scope.dart';

class BudgetsPage extends StatefulWidget {
  const BudgetsPage({super.key});

  @override
  State<BudgetsPage> createState() => _BudgetsPageState();
}

class _BudgetsPageState extends State<BudgetsPage> {
  static const _budgetAggregationKey = 'budget.aggregation';
  static const _budgetSortKey = 'budget.sort';
  static const _budgetShowPercentageKey = 'budget.showPercentage';
  static const _budgetChartGroupByKey = 'budget.chartGroupBy';

  DateTime currentMonth = DateTime.now();
  /// Month bar selection (calendar month 1–12) when chart is grouped by month.
  int? selectedChartBucket;
  /// Header month before a Till-month bar drill-down; restored on clear.
  DateTime? _monthBeforeChartBucket;
  List<Map<String, dynamic>> budgets = [];
  List<Map<String, dynamic>> _transactions = [];
  Set<int> selectedBudgetIds = {};
  bool selectionMode = false;
  UserTier _userTier = UserTier.free;
  BudgetAggregation budgetAggregation = BudgetAggregation.selectedMonth;
  BudgetSortOrder sortOrder = BudgetSortOrder.amount;
  bool showPercentage = true;
  BudgetChartGroupBy budgetChartGroupBy = BudgetChartGroupBy.month;
  @override
  void initState() {
    super.initState();
    DataStore.transactionMutationGeneration.addListener(_onBookDataMutation);
    DataStore.profileSwitchGeneration.addListener(_onProfileSwitch);
    _restorePreferences();
    _loadUserTier();
  }

  void _onBookDataMutation() {
    if (mounted) loadBudgets();
  }

  void _onProfileSwitch() {
    if (!mounted) return;
    final n = DateTime.now();
    setState(() {
      currentMonth = DateTime(n.year, n.month);
      selectedChartBucket = null;
      _monthBeforeChartBucket = null;
    });
    loadBudgets();
  }

  @override
  void dispose() {
    DataStore.transactionMutationGeneration.removeListener(_onBookDataMutation);
    DataStore.profileSwitchGeneration.removeListener(_onProfileSwitch);
    super.dispose();
  }

  Future<void> _loadUserTier() async {
    final t = await EntitlementService.getCurrentTier();
    if (mounted) setState(() => _userTier = t);
  }

  Future<void> _restorePreferences() async {
    final prefs = await SharedPreferences.getInstance();
    budgetAggregation = BudgetAggregation.values[prefs.getInt(_budgetAggregationKey) ?? budgetAggregation.index];
    sortOrder = BudgetSortOrder.values[prefs.getInt(_budgetSortKey) ?? sortOrder.index];
    showPercentage = prefs.getBool(_budgetShowPercentageKey) ?? true;
    final chartGroupIdx = prefs.getInt(_budgetChartGroupByKey);
    if (chartGroupIdx != null &&
        chartGroupIdx >= 0 &&
        chartGroupIdx < BudgetChartGroupBy.values.length) {
      budgetChartGroupBy = BudgetChartGroupBy.values[chartGroupIdx];
    }
    final tier = await EntitlementService.getCurrentTier();
    if (tier != UserTier.pro &&
        (budgetAggregation == BudgetAggregation.cumulativeToSelectedMonth ||
            budgetAggregation == BudgetAggregation.cumulativeYear)) {
      budgetAggregation = BudgetAggregation.selectedMonth;
      await prefs.setInt(_budgetAggregationKey, budgetAggregation.index);
    }
    if (!mounted) return;
    setState(() {});
    await loadBudgets();
  }

  Future<void> _persistPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_budgetAggregationKey, budgetAggregation.index);
    await prefs.setInt(_budgetSortKey, sortOrder.index);
    await prefs.setBool(_budgetShowPercentageKey, showPercentage);
    await prefs.setInt(_budgetChartGroupByKey, budgetChartGroupBy.index);
  }

  String? _budgetAggregationSubtitle() {
    switch (budgetAggregation) {
      case BudgetAggregation.selectedMonth:
        return null;
      case BudgetAggregation.cumulativeToSelectedMonth:
        return 'Till month';
      case BudgetAggregation.cumulativeYear:
        return 'Year';
    }
  }

  (DateTime, DateTime) _budgetTransactionQueryRange() {
    switch (budgetAggregation) {
      case BudgetAggregation.selectedMonth:
        return (
          DateTime(currentMonth.year, currentMonth.month, 1),
          DateTime(currentMonth.year, currentMonth.month + 1, 0),
        );
      case BudgetAggregation.cumulativeToSelectedMonth:
        return (
          DateTime(currentMonth.year, 1, 1),
          DateTime(currentMonth.year, currentMonth.month + 1, 0),
        );
      case BudgetAggregation.cumulativeYear:
        return (
          DateTime(currentMonth.year, 1, 1),
          DateTime(currentMonth.year, 12, 31),
        );
    }
  }

  bool _isTransactionInBudgetChartBucket(DateTime date) {
    if (selectedChartBucket == null) return true;
    switch (budgetAggregation) {
      case BudgetAggregation.selectedMonth:
        return true;
      case BudgetAggregation.cumulativeToSelectedMonth:
        return date.year == currentMonth.year && date.month <= selectedChartBucket!;
      case BudgetAggregation.cumulativeYear:
        return date.year == currentMonth.year && date.month == selectedChartBucket;
    }
  }

  /// Expense transactions for [category] matching aggregation + chart bucket; [restrictToMonth] for per-row month view.
  List<Map<String, dynamic>> _expenseTransactionsForCategory(
    String category, {
    int? restrictToMonth,
  }) {
    final c = category.trim();
    final out = <Map<String, dynamic>>[];
    for (final t in _transactions) {
      if (t['type'] != 'expense') continue;
      if ((t['title'] as String?)?.trim() != c) continue;
      final d = DateTime.parse(t['date'] as String);
      if (!_isTransactionInBudgetChartBucket(d)) continue;
      if (restrictToMonth != null &&
          (d.year != currentMonth.year || d.month != restrictToMonth)) {
        continue;
      }
      out.add(t);
    }
    out.sort((a, b) {
      final da = DateTime.parse(a['date'] as String);
      final db = DateTime.parse(b['date'] as String);
      return db.compareTo(da);
    });
    return out;
  }

  Future<void> _editTransaction(Map<String, dynamic> transaction) async {
    if (DataStore.viewerReadOnly) {
      DataStore.showViewerReadOnlyNotice(context);
      return;
    }
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
    await loadBudgets();
  }

  void _showRelatedExpenseTransactions({
    required String category,
    int? restrictToMonth,
  }) {
    final grouped = _expenseTransactionsForCategory(
      category,
      restrictToMonth: restrictToMonth,
    );
    final dateFormat = DateFormat('dd MMM yyyy');
    final entry = _categoryDetails(category);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (bottomSheetContext) {
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
                        category,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${grouped.length} transactions • Newest first',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: grouped.isEmpty
                      ? const Center(child: Text('No related transactions found.'))
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          itemCount: grouped.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final transaction = grouped[index];
                            final amount = (transaction['amount'] as num).toDouble();
                            final date = DateTime.parse(transaction['date'] as String);
                            final comment = (transaction['comment'] as String? ?? '').trim();
                            final subtitle = (transaction['account'] as String?)?.trim() ?? '';

                            return Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(16),
                                onTap: () async {
                                  Navigator.of(bottomSheetContext).pop();
                                  await _editTransaction(transaction);
                                  if (mounted) {
                                    _showRelatedExpenseTransactions(
                                      category: category,
                                      restrictToMonth: restrictToMonth,
                                    );
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
                                          fallback: Icons.category,
                                        ),
                                        imagePath: entry?['icon_path']?.toString(),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              subtitle.isEmpty ? category : subtitle,
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
  }

  Future<void> _onBudgetMonthBarTapped(AggregationBarData item) async {
    final tappedBucket = item.bucket;
    final nextBucket = selectedChartBucket == tappedBucket ? null : tappedBucket;
    if (budgetAggregation == BudgetAggregation.cumulativeToSelectedMonth) {
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
    } else {
      setState(() => selectedChartBucket = nextBucket);
    }
    await loadBudgets();
  }

  Future<void> loadBudgets() async {
    final data = await DataService.getBudgets();
    final categories = await DataService.getCategories();
    final range = _budgetTransactionQueryRange();
    final tx = await DataService.getTransactions(startDate: range.$1, endDate: range.$2);
    setState(() {
      budgets = data;
      _transactions = tx;
      DataStore.replaceCategories(categories);
      if (selectedChartBucket != null && !_chartDataContainsBucket(selectedChartBucket)) {
        selectedChartBucket = null;
        if (_monthBeforeChartBucket != null) {
          currentMonth = _monthBeforeChartBucket!;
          _monthBeforeChartBucket = null;
        }
      }
    });
    await WidgetSyncService.syncFromStoredConfiguration();
  }

  Future<void> showAddBudgetDialog({Map<String, dynamic>? budget}) async {
    final allCategories = await DataService.getCategories();
    final hasExpenseCategory = allCategories.any((c) => c['type'] == 'expense');
    if (!hasExpenseCategory) {
      if (!mounted) return;
      final pageContext = context;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('No categories'),
          content: const Text('Add an expense category first.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('OK'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                final scope = HomeTabScope.maybeOf(pageContext);
                if (scope != null) {
                  scope.openCategoriesTab();
                } else {
                  unawaited(
                    Navigator.of(pageContext).push<void>(
                      MaterialPageRoute<void>(builder: (_) => const CategoriesPage()),
                    ),
                  );
                }
              },
              child: const Text('Categories'),
            ),
            FilledButton(
              onPressed: () async {
                Navigator.of(ctx).pop();
                final scope = HomeTabScope.maybeOf(pageContext);
                if (scope != null) {
                  await scope.runInitializeDefaultsForActiveProfile();
                }
                if (pageContext.mounted) loadBudgets();
              },
              child: const Text('Add defaults'),
            ),
          ],
        ),
      );
      return;
    }

    if (!mounted) return;
    // Capture the page context so we can show a SnackBar from inside the dialog.
    final pageContext = context;
    String? selectedCategory = budget?['category'];
    final amountController = TextEditingController(text: budget?['amount']?.toString());

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          bool saving = false;
          return StatefulBuilder(
            builder: (dialogContext, setInnerState) {
              final fieldLabelStyle = Theme.of(dialogContext).textTheme.bodyMedium;
              final fieldTextStyle = Theme.of(dialogContext).textTheme.bodyLarge;
              return AlertDialog(
              title: Text(
                budget == null ? 'Create Budget' : 'Edit Budget',
                style: Theme.of(dialogContext).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    key: ValueKey(selectedCategory ?? ''),
                    initialValue: selectedCategory,
                    items: DataStore.categories
                        .where((cat) => cat['type'] == 'expense')
                        .map((cat) => DropdownMenuItem<String>(
                              value: cat['name'],
                              child: Text(cat['name']!),
                            ))
                        .toList(),
                    onChanged: (value) => setDialogState(() => selectedCategory = value),
                    style: fieldTextStyle,
                    decoration: InputDecoration(
                      labelText: 'Category',
                      labelStyle: fieldLabelStyle,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: amountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: fieldTextStyle,
                    decoration: InputDecoration(
                      labelText: 'Amount',
                      labelStyle: fieldLabelStyle,
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: saving ? null : () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: saving
                      ? null
                      : () async {
                          if (selectedCategory == null || amountController.text.trim().isEmpty) return;
                          final amount = double.tryParse(amountController.text.trim());
                          if (amount == null) {
                            if (pageContext.mounted) {
                              ScaffoldMessenger.of(pageContext).showSnackBar(
                                const SnackBar(content: Text('Please enter a valid number for the amount.')),
                              );
                            }
                            return;
                          }
                          setInnerState(() => saving = true);
                          try {
                            if (budget == null) {
                              await DataService.insertBudget(
                                selectedCategory!, amount,
                                currentMonth.month, currentMonth.year,
                              );
                            } else {
                              await DataService.updateBudget(
                                budget['id'], selectedCategory!, amount,
                                currentMonth.month, currentMonth.year,
                              );
                            }
                            if (!dialogContext.mounted) return;
                            Navigator.pop(dialogContext);
                            loadBudgets();
                          } catch (e) {
                            setInnerState(() => saving = false);
                            if (pageContext.mounted) {
                              ScaffoldMessenger.of(pageContext).showSnackBar(
                                SnackBar(content: Text('Could not save budget: $e')),
                              );
                            }
                          }
                        },
                  child: saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    ),
    );
    amountController.addListener(() {});
  }

  void clearSelection() {
    setState(() {
      selectedBudgetIds.clear();
      selectionMode = false;
    });
  }

  void _clearBudgetChartBucketSelection() {
    selectedChartBucket = null;
    if (_monthBeforeChartBucket != null) {
      currentMonth = _monthBeforeChartBucket!;
      _monthBeforeChartBucket = null;
    }
  }

  bool get _budgetMonthBarsActive =>
      _isCategoryAggregatedView && _effectiveChartGroupBy == BudgetChartGroupBy.month;

  bool _chartDataContainsBucket(int? bucket) {
    if (bucket == null) return true;
    return _budgetChartData().any((item) => item.bucket == bucket);
  }

  Future<void> deleteSelected() async {
    for (final id in selectedBudgetIds) {
      await DataService.deleteBudget(id);
    }
    clearSelection();
    loadBudgets();
  }

  void _sortBudgetList(List<Map<String, dynamic>> list) {
    list.sort((a, b) {
      if (budgetAggregation != BudgetAggregation.selectedMonth) {
        final aYear = (a['year'] as num?)?.toInt() ?? 0;
        final bYear = (b['year'] as num?)?.toInt() ?? 0;
        final yearCompare = aYear.compareTo(bYear);
        if (yearCompare != 0) return yearCompare;
        final aMonth = (a['month'] as num?)?.toInt() ?? 0;
        final bMonth = (b['month'] as num?)?.toInt() ?? 0;
        final monthCompare = aMonth.compareTo(bMonth);
        if (monthCompare != 0) return monthCompare;
      }
      if (sortOrder == BudgetSortOrder.amount) {
        final amountCompare = ((b['amount'] as num?) ?? 0).compareTo((a['amount'] as num?) ?? 0);
        if (amountCompare != 0) return amountCompare;
      }
      return (a['category'] as String).compareTo(b['category'] as String);
    });
  }

  List<Map<String, dynamic>> get filteredBudgets {
    final current = budgets.where(_isBudgetInRange).toList();
    _sortBudgetList(current);
    return current;
  }

  /// Source rows for the bottom list (month bar selected = that calendar month only).
  Iterable<Map<String, dynamic>> get _budgetsForListSource {
    if (!_budgetMonthBarsActive || selectedChartBucket == null) {
      return filteredBudgets;
    }
    if (budgetAggregation == BudgetAggregation.cumulativeToSelectedMonth) {
      final cap = selectedChartBucket!;
      return filteredBudgets.where(
        (b) => ((b['month'] as num?)?.toInt() ?? 0) <= cap,
      );
    }
    if (budgetAggregation == BudgetAggregation.cumulativeYear) {
      return filteredBudgets.where(
        (b) => ((b['month'] as num?)?.toInt() ?? 0) == selectedChartBucket,
      );
    }
    return filteredBudgets;
  }

  List<Map<String, dynamic>> _aggregateBudgetsByCategory(Iterable<Map<String, dynamic>> source) {
    final grouped = <String, double>{};
    for (final budget in source) {
      final category = (budget['category'] as String?)?.trim() ?? '';
      if (category.isEmpty) continue;
      grouped[category] = (grouped[category] ?? 0) + (budget['amount'] as num).toDouble();
    }

    final rows = grouped.entries
        .map((entry) => <String, dynamic>{
              'category': entry.key,
              'amount': entry.value,
            })
        .toList();

    rows.sort((a, b) {
      if (sortOrder == BudgetSortOrder.alphabetical) {
        return (a['category'] as String).compareTo(b['category'] as String);
      }
      final amountCompare = ((b['amount'] as num?) ?? 0).compareTo((a['amount'] as num?) ?? 0);
      if (amountCompare != 0) return amountCompare;
      return (a['category'] as String).compareTo(b['category'] as String);
    });

    return rows;
  }

  bool get _isCategoryAggregatedView => budgetAggregation != BudgetAggregation.selectedMonth;

  BudgetChartGroupBy get _effectiveChartGroupBy {
    if (budgetAggregation == BudgetAggregation.selectedMonth) {
      return BudgetChartGroupBy.category;
    }
    // Till month & Year: always month-wise bars for drill-down (regression fix).
    return BudgetChartGroupBy.month;
  }

  static String _monthChartLabel(int month) {
    return DateFormat.MMM().format(DateTime(2020, month));
  }

  List<Map<String, dynamic>> get displayBudgetsForList {
    if (!_isCategoryAggregatedView) {
      final rows = List<Map<String, dynamic>>.from(_budgetsForListSource);
      _sortBudgetList(rows);
      return rows;
    }
    return _aggregateBudgetsByCategory(_budgetsForListSource);
  }

  /// Full-range total for the summary card (unchanged when a month bar is selected).
  double get _totalBudgetForSummary {
    if (!_isCategoryAggregatedView) {
      return filteredBudgets.fold(0.0, (sum, b) => sum + (b['amount'] as num).toDouble());
    }
    return _aggregateBudgetsByCategory(filteredBudgets)
        .fold(0.0, (sum, b) => sum + (b['amount'] as num).toDouble());
  }

  bool _isBudgetInRange(Map<String, dynamic> budget) {
    final year = (budget['year'] as num?)?.toInt() ?? 0;
    if (year != currentMonth.year) return false;
    final month = (budget['month'] as num?)?.toInt() ?? 0;
    if (budgetAggregation == BudgetAggregation.selectedMonth) return month == currentMonth.month;
    if (budgetAggregation == BudgetAggregation.cumulativeToSelectedMonth) return month <= currentMonth.month;
    return true;
  }

  List<AggregationBarData> _budgetChartDataByCategory() {
    final grouped = <String, double>{};
    for (final budget in filteredBudgets) {
      final category = (budget['category'] as String?)?.trim() ?? '';
      if (category.isEmpty) continue;
      grouped[category] = (grouped[category] ?? 0) + (budget['amount'] as num).toDouble();
    }
    final rows = grouped.entries.toList();
    rows.sort((a, b) {
      if (sortOrder == BudgetSortOrder.alphabetical) return a.key.compareTo(b.key);
      final amountCompare = b.value.compareTo(a.value);
      if (amountCompare != 0) return amountCompare;
      return a.key.compareTo(b.key);
    });
    return rows
        .asMap()
        .entries
        .map(
          (entry) => AggregationBarData(
            label: entry.value.key,
            value: entry.value.value,
            bucket: entry.key,
          ),
        )
        .toList();
  }

  List<AggregationBarData> _budgetChartDataByMonth() {
    if (filteredBudgets.isEmpty) return [];
    final totals = <int, double>{};
    for (final budget in filteredBudgets) {
      final month = (budget['month'] as num?)?.toInt() ?? 0;
      if (month < 1 || month > 12) continue;
      totals[month] = (totals[month] ?? 0) + (budget['amount'] as num).toDouble();
    }
    final lastMonth = budgetAggregation == BudgetAggregation.cumulativeToSelectedMonth
        ? currentMonth.month
        : 12;
    final data = <AggregationBarData>[];
    for (var m = 1; m <= lastMonth; m++) {
      data.add(
        AggregationBarData(
          label: _monthChartLabel(m),
          value: totals[m] ?? 0,
          bucket: m,
        ),
      );
    }
    return data;
  }

  List<AggregationBarData> _budgetChartData() {
    switch (_effectiveChartGroupBy) {
      case BudgetChartGroupBy.category:
        return _budgetChartDataByCategory();
      case BudgetChartGroupBy.month:
        return _budgetChartDataByMonth();
    }
  }

  Future<void> _applyBudgetPreferenceChange(VoidCallback updateParent) async {
    setState(updateParent);
    await _persistPreferences();
  }

  Future<void> _trySetBudgetAggregation(
    BudgetAggregation value,
    BuildContext pageContext,
    StateSetter setModalState,
    Future<void> Function(VoidCallback) apply,
  ) async {
    final needsPro = value == BudgetAggregation.cumulativeToSelectedMonth ||
        value == BudgetAggregation.cumulativeYear;
    if (needsPro) {
      if (await EntitlementService.getCurrentTier() != UserTier.pro) {
        final ok = await ensureSignedInThenProComparisonAndPurchase(pageContext);
        if (!mounted || !pageContext.mounted) return;
        if (ok) {
          await AccountSubscriptionService.syncEntitlementFromFirestore();
        }
        if (!mounted || !pageContext.mounted) return;
        if (await EntitlementService.getCurrentTier() != UserTier.pro) {
          setModalState(() {});
          return;
        }
        await _loadUserTier();
        setModalState(() {});
      }
    }
    await apply(() => budgetAggregation = value);
  }

  Future<void> _showBudgetOptions() async {
    await _loadUserTier();
    if (!mounted) return;
    final pageContext = context;
    showSideOverlaySheet<void>(
      context: context,
      direction: SideOverlayDirection.right,
      builder: (drawerContext) {
        return StatefulBuilder(
          builder: (modalContext, setModalState) {
            Future<void> apply(VoidCallback updateParent) async {
              await _applyBudgetPreferenceChange(() {
                updateParent();
                selectedChartBucket = null;
                _monthBeforeChartBucket = null;
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
                          'Budget options',
                          style: Theme.of(modalContext).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
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
                ListTile(
                  leading: const Icon(Icons.copy_all_outlined),
                  title: Text(
                    _userTier == UserTier.pro ? 'Copy budget' : 'Copy budget (Pro)',
                  ),
                  onTap: () async {
                    Navigator.of(drawerContext).pop();
                    await Future<void>.delayed(Duration.zero);
                    if (!mounted) return;
                    if (_userTier != UserTier.pro) {
                      await ensureSignedInThenProComparisonAndPurchase(pageContext);
                      if (!mounted) return;
                      await _loadUserTier();
                      if (_userTier != UserTier.pro) return;
                    }
                    if (DataStore.viewerReadOnly) {
                      DataStore.showViewerReadOnlyNotice(pageContext);
                      return;
                    }
                    await showSmartBudgetCopyDialog(
                      context: pageContext,
                      onCopied: loadBudgets,
                    );
                  },
                ),
                const Divider(height: 1),
                AggregationSectionHeader(showProBadge: _userTier != UserTier.pro),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: SegmentedToggle<BudgetAggregation>(
                    options: const [
                      SegmentedToggleOption(value: BudgetAggregation.selectedMonth, label: 'Month'),
                      SegmentedToggleOption(value: BudgetAggregation.cumulativeToSelectedMonth, label: 'Till month'),
                      SegmentedToggleOption(value: BudgetAggregation.cumulativeYear, label: 'Year'),
                    ],
                    selectedValue: budgetAggregation,
                    onChanged: (value) =>
                        _trySetBudgetAggregation(value, pageContext, setModalState, apply),
                  ),
                ),
                const Divider(height: 1),
                const _MenuSectionHeader('Sort'),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: SegmentedToggle<BudgetSortOrder>(
                    options: const [
                      SegmentedToggleOption(value: BudgetSortOrder.amount, label: 'Amount'),
                      SegmentedToggleOption(value: BudgetSortOrder.alphabetical, label: 'A-Z'),
                    ],
                    selectedValue: sortOrder,
                    onChanged: (value) => apply(() => sortOrder = value),
                  ),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  dense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  value: showPercentage,
                  title: const Text('Show percentage'),
                  onChanged: (value) => apply(() => showPercentage = value),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Map<String, dynamic>? _categoryDetails(String categoryName) {
    return DataStore.categories
        .cast<Map<String, dynamic>?>()
        .firstWhere((c) => c?['name'] == categoryName, orElse: () => null);
  }

  /// Rank 0 = largest share of [totalBudget]; used for red / yellow / green tiers.
  Map<int, int> _shareRankByRowIndex(List<Map<String, dynamic>> rows, double totalBudget) {
    if (rows.isEmpty || totalBudget <= 0) return {};
    final n = rows.length;
    final order = List<int>.generate(n, (i) => i);
    order.sort((a, b) {
      final aa = (rows[a]['amount'] as num).toDouble() / totalBudget;
      final ba = (rows[b]['amount'] as num).toDouble() / totalBudget;
      final c = ba.compareTo(aa);
      if (c != 0) return c;
      return a.compareTo(b);
    });
    return {for (var r = 0; r < order.length; r++) order[r]: r};
  }

  Color _budgetShareTierBase(int rank) {
    if (rank < 5) return const Color(0xFFEF4444);
    if (rank < 10) return const Color(0xFFF59E0B);
    return const Color(0xFF22C55E);
  }

  LinearGradient _budgetShareTierGradient(int rank) {
    final base = _budgetShareTierBase(rank);
    return LinearGradient(
      colors: [
        base,
        Color.lerp(Colors.white, base, 0.45) ?? base,
      ],
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
    );
  }

  TextStyle _budgetBarOverlayStyle(BuildContext context, double widthFactor) {
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

  @override
  Widget build(BuildContext context) {
    final visibleBudgets = displayBudgetsForList;
    final totalBudget = _totalBudgetForSummary;
    final shareRank = _shareRankByRowIndex(visibleBudgets, totalBudget);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      floatingActionButton: DataStore.viewerReadOnly
          ? null
          : selectionMode
          ? Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                FloatingActionButton.small(
                  heroTag: 'cancelBudgetSelection',
                  onPressed: clearSelection,
                  tooltip: 'Cancel selection',
                  child: const Icon(Icons.close),
                ),
                const SizedBox(height: 10),
                FloatingActionButton.extended(
                  heroTag: 'deleteSelectedBudgets',
                  onPressed: deleteSelected,
                  icon: const Icon(Icons.delete),
                  label: Text('Delete (${selectedBudgetIds.length})'),
                ),
              ],
            )
          : FloatingActionButton(
              child: const Icon(Icons.add),
              onPressed: () {
                unawaited(showAddBudgetDialog());
              },
            ),
      body: PageContentLayout(
        child: Column(
          children: [
            MonthSectionCard(
              currentMonth: currentMonth,
              aggregationSubtitle: _budgetAggregationSubtitle(),
              useInnerPanelTint: true,
              onPrev: () {
                setState(() {
                  selectedChartBucket = null;
                  _monthBeforeChartBucket = null;
                  currentMonth = DateTime(currentMonth.year, currentMonth.month - 1);
                });
              },
              onNext: () {
                setState(() {
                  selectedChartBucket = null;
                  _monthBeforeChartBucket = null;
                  currentMonth = DateTime(currentMonth.year, currentMonth.month + 1);
                });
              },
              monthTrailing: MonthOptionsMenuButton(
                onPressed: _showBudgetOptions,
                tooltip: 'Budget options',
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(4, 0, 4, 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total budget',
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                        color: cs.onSurfaceVariant.withValues(alpha: 0.9),
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        formatIndianCurrency(totalBudget),
                        style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              letterSpacing: -0.6,
                              color: cs.primary,
                              height: 1.05,
                            ) ??
                            TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w600,
                              letterSpacing: -0.6,
                              color: cs.primary,
                              height: 1.05,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
              child: Builder(
                builder: (context) {
                  final chartSeries = _budgetChartData();
                  final chartHint = _budgetMonthBarsActive
                      ? 'Tap a month to filter the list below.'
                      : (_effectiveChartGroupBy == BudgetChartGroupBy.category
                          ? 'Budget by category for this month.'
                          : null);
                  if (budgetAggregation == BudgetAggregation.selectedMonth) {
                    return BudgetMonthPieChart(
                      data: chartSeries,
                      headerHint: chartHint,
                    );
                  }
                  final csChart = Theme.of(context).colorScheme;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (chartHint != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            chartHint,
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                  color: csChart.onSurfaceVariant,
                                  height: 1.25,
                                ),
                          ),
                        ),
                      AggregationBarChart(
                        data: chartSeries,
                        emptyMessage: 'No budget data available for this aggregation.',
                        chartHeight: 220,
                        selectedBucket: _budgetMonthBarsActive ? selectedChartBucket : null,
                        onBarTap: _budgetMonthBarsActive
                            ? (item) => _onBudgetMonthBarTapped(item)
                            : null,
                        onLabelTap: _budgetMonthBarsActive
                            ? (item) => _onBudgetMonthBarTapped(item)
                            : null,
                        labelBuilder: (context, item) {
                          return RotatedBox(
                            quarterTurns: 3,
                            child: Text(
                              item.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: csChart.onSurfaceVariant.withValues(alpha: 0.92),
                                  ),
                            ),
                          );
                        },
                        trailing: _budgetMonthBarsActive && selectedChartBucket != null
                            ? IconButton(
                                onPressed: () async {
                                  setState(_clearBudgetChartBucketSelection);
                                  await loadBudgets();
                                },
                                icon: const Icon(Icons.close_rounded, size: 16),
                                visualDensity: VisualDensity.compact,
                                padding: const EdgeInsets.all(4),
                                constraints: const BoxConstraints(
                                  minWidth: 28,
                                  minHeight: 28,
                                ),
                                splashRadius: 14,
                                tooltip: 'Clear filter',
                              )
                            : null,
                      ),
                    ],
                  );
                },
              ),
            ),
            Expanded(
              child: SectionTile(
                child: visibleBudgets.isEmpty
                    ? const Center(child: Text('No budgets set'))
                    : ListView.separated(
                        padding: EdgeInsets.zero,
                        itemCount: visibleBudgets.length,
                        separatorBuilder: (ctx, __) => Divider(
                          height: 1,
                          thickness: 1,
                          color: cs.outlineVariant.withValues(
                            alpha: Theme.of(ctx).brightness == Brightness.dark ? 0.22 : 0.28,
                          ),
                        ),
                        itemBuilder: (context, index) {
                          final budget = visibleBudgets[index];
                          final rowId = (budget['id'] as int?) ??
                              Object.hash(
                                budget['category'],
                                budget['month'] ?? 0,
                                index,
                              );
                          final amount = (budget['amount'] as num).toDouble();
                          final category = _categoryDetails(budget['category'] as String);
                          final shareVsTotal =
                              totalBudget <= 0 ? 0.0 : (amount / totalBudget).clamp(0.0, 999.0);
                          final progress = totalBudget <= 0
                              ? 0.0
                              : (amount == 0 ? 0.02 : shareVsTotal.clamp(0.0, 1.0));
                          final pctOfTotal = (shareVsTotal * 100).isFinite
                              ? (shareVsTotal * 100).clamp(0, 999).round()
                              : 0;
                          final tierRank = shareRank[index] ?? 0;

                          void onRowTap() {
                            if (DataStore.viewerReadOnly && !selectionMode) {
                              DataStore.showViewerReadOnlyNotice(context);
                              return;
                            }
                            if (selectionMode) {
                              setState(() => selectedBudgetIds.contains(rowId)
                                  ? selectedBudgetIds.remove(rowId)
                                  : selectedBudgetIds.add(rowId));
                              return;
                            }
                            final cat = budget['category'] as String;
                            final restrictMonth = _isCategoryAggregatedView
                                ? null
                                : ((budget['month'] as num?)?.toInt() ?? currentMonth.month);
                            _showRelatedExpenseTransactions(
                              category: cat,
                              restrictToMonth: restrictMonth,
                            );
                          }

                          return InkWell(
                            onTap: onRowTap,
                            onLongPress: _isCategoryAggregatedView || DataStore.viewerReadOnly
                                ? null
                                : () => setState(() {
                                      selectionMode = true;
                                      selectedBudgetIds.add(rowId);
                                    }),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (selectionMode)
                                    Checkbox(
                                      value: selectedBudgetIds.contains(rowId),
                                      onChanged: (v) => setState(() => v == true
                                          ? selectedBudgetIds.add(rowId)
                                          : selectedBudgetIds.remove(rowId)),
                                    )
                                  else
                                    AppPageIcon(
                                      icon: iconFromCodePoint(category?['icon'], fallback: Icons.category),
                                      imagePath: category?['icon_path']?.toString(),
                                    ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.stretch,
                                      children: [
                                        Text(
                                          budget['category'] as String,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Stack(
                                                alignment: Alignment.centerLeft,
                                                children: [
                                                  Container(
                                                    height: 16,
                                                    decoration: BoxDecoration(
                                                      color: Theme.of(context)
                                                          .colorScheme
                                                          .surfaceContainerHighest,
                                                      borderRadius: BorderRadius.circular(999),
                                                    ),
                                                  ),
                                                  FractionallySizedBox(
                                                    widthFactor: progress.clamp(0.0, 1.0),
                                                    child: Container(
                                                      height: 16,
                                                      decoration: BoxDecoration(
                                                        gradient: _budgetShareTierGradient(tierRank),
                                                        borderRadius: BorderRadius.circular(999),
                                                      ),
                                                    ),
                                                  ),
                                                  Padding(
                                                    padding: const EdgeInsets.symmetric(horizontal: 8),
                                                    child: Text(
                                                      '${formatIndianCurrency(amount)} / ${formatIndianCurrency(totalBudget)}',
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                      style: _budgetBarOverlayStyle(
                                                        context,
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
                                                  '$pctOfTotal%',
                                                  textAlign: TextAlign.right,
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w700,
                                                    color: _budgetShareTierBase(tierRank),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (!_isCategoryAggregatedView &&
                                      !selectionMode &&
                                      !DataStore.viewerReadOnly)
                                    IconButton(
                                      tooltip: 'Edit budget',
                                      onPressed: () {
                                        unawaited(showAddBudgetDialog(budget: budget));
                                      },
                                      icon: const Icon(Icons.edit_outlined, size: 20),
                                      visualDensity: VisualDensity.compact,
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(
                                        minWidth: 36,
                                        minHeight: 36,
                                      ),
                                    ),
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

enum BudgetSortOrder {
  amount,
  alphabetical,
}

enum BudgetAggregation {
  selectedMonth,
  cumulativeToSelectedMonth,
  cumulativeYear,
}

enum BudgetChartGroupBy {
  category,
  month,
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
              color: const Color(0xFF52606D),
            ),
      ),
    );
  }
}

