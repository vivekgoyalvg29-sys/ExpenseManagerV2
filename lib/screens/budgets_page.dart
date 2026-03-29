import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/data_store.dart';
import '../services/database_service.dart';
import '../services/widget_sync_service.dart';
import '../utils/indian_number_formatter.dart';
import '../widgets/icon_utils.dart';
import '../widgets/aggregation_bar_chart.dart';
import '../widgets/month_section_card.dart';
import '../widgets/page_content_layout.dart';
import '../widgets/section_tile.dart';
import '../widgets/side_overlay_sheet.dart';

class BudgetsPage extends StatefulWidget {
  const BudgetsPage({super.key});

  @override
  State<BudgetsPage> createState() => _BudgetsPageState();
}

class _BudgetsPageState extends State<BudgetsPage> {
  static const _budgetAggregationKey = 'budget.aggregation';
  static const _budgetSortKey = 'budget.sort';
  static const _budgetShowPercentageKey = 'budget.showPercentage';

  DateTime currentMonth = DateTime.now();
  List<Map<String, dynamic>> budgets = [];
  Set<int> selectedIndexes = {};
  bool selectionMode = false;
  BudgetAggregation budgetAggregation = BudgetAggregation.selectedMonth;
  BudgetSortOrder sortOrder = BudgetSortOrder.amount;
  bool showPercentage = true;

  @override
  void initState() {
    super.initState();
    _restorePreferences();
  }

  Future<void> _restorePreferences() async {
    final prefs = await SharedPreferences.getInstance();
    budgetAggregation = BudgetAggregation.values[prefs.getInt(_budgetAggregationKey) ?? budgetAggregation.index];
    sortOrder = BudgetSortOrder.values[prefs.getInt(_budgetSortKey) ?? sortOrder.index];
    showPercentage = prefs.getBool(_budgetShowPercentageKey) ?? true;
    if (!mounted) return;
    setState(() {});
    await loadBudgets();
  }

  Future<void> _persistPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_budgetAggregationKey, budgetAggregation.index);
    await prefs.setInt(_budgetSortKey, sortOrder.index);
    await prefs.setBool(_budgetShowPercentageKey, showPercentage);
  }

  Future<void> loadBudgets() async {
    final data = await DatabaseService.getBudgets();
    final categories = await DatabaseService.getCategories();
    setState(() {
      budgets = data;
      DataStore.categories = categories;
    });
    await WidgetSyncService.syncFromStoredConfiguration();
  }

  void showAddBudgetDialog({Map<String, dynamic>? budget}) {
    String? selectedCategory = budget?['category'];
    final amountController = TextEditingController(text: budget?['amount']?.toString());
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(budget == null ? 'Create Budget' : 'Edit Budget'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              value: selectedCategory,
              items: DataStore.categories
                  .where((cat) => cat['type'] == 'expense')
                  .map((cat) => DropdownMenuItem<String>(
                        value: cat['name'],
                        child: Text(cat['name']!),
                      ))
                  .toList(),
              onChanged: (value) => selectedCategory = value,
              decoration: const InputDecoration(labelText: 'Category'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Amount'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              if (selectedCategory == null || amountController.text.isEmpty) return;
              final amount = double.parse(amountController.text);
              if (budget == null) {
                await DatabaseService.insertBudget(selectedCategory!, amount, currentMonth.month, currentMonth.year);
              } else {
                await DatabaseService.updateBudget(budget['id'], selectedCategory!, amount, currentMonth.month, currentMonth.year);
              }
              if (!context.mounted) return;
              Navigator.pop(context);
              loadBudgets();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void clearSelection() {
    setState(() {
      selectedIndexes.clear();
      selectionMode = false;
    });
  }

  Future<void> deleteSelected() async {
    for (final index in selectedIndexes) {
      final id = filteredBudgets[index]['id'];
      await DatabaseService.deleteBudget(id);
    }
    clearSelection();
    loadBudgets();
  }

  List<Map<String, dynamic>> get filteredBudgets {
    final current = budgets.where(_isBudgetInRange)
        .toList();
    current.sort((a, b) {
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
    return current;
  }

  bool _isBudgetInRange(Map<String, dynamic> budget) {
    final year = (budget['year'] as num?)?.toInt() ?? 0;
    if (year != currentMonth.year) return false;
    final month = (budget['month'] as num?)?.toInt() ?? 0;
    if (budgetAggregation == BudgetAggregation.selectedMonth) return month == currentMonth.month;
    if (budgetAggregation == BudgetAggregation.cumulativeToSelectedMonth) return month <= currentMonth.month;
    return true;
  }

  List<AggregationBarData> _budgetChartData() {
    if (budgetAggregation == BudgetAggregation.selectedMonth) {
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
      return rows.map((e) => AggregationBarData(label: e.key, value: e.value)).toList();
    }

    final groupedByMonth = <int, double>{};
    for (final budget in filteredBudgets) {
      final month = (budget['month'] as num?)?.toInt() ?? 0;
      groupedByMonth[month] = (groupedByMonth[month] ?? 0) + (budget['amount'] as num).toDouble();
    }
    final ordered = groupedByMonth.keys.toList()..sort();
    return ordered
        .map(
          (month) => AggregationBarData(
            label: DateFormat('MMM').format(DateTime(currentMonth.year, month)),
            value: groupedByMonth[month] ?? 0,
          ),
        )
        .toList();
  }

  Future<void> _applyBudgetPreferenceChange(VoidCallback updateParent) async {
    setState(updateParent);
    await _persistPreferences();
  }

  void _showBudgetOptions() {
    showSideOverlaySheet<void>(
      context: context,
      direction: SideOverlayDirection.right,
      builder: (drawerContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            Future<void> apply(VoidCallback updateParent) async {
              await _applyBudgetPreferenceChange(() {
                updateParent();
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
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
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
                RadioListTile<BudgetAggregation>(
                  dense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  value: BudgetAggregation.selectedMonth,
                  groupValue: budgetAggregation,
                  title: const Text('Selected month'),
                  onChanged: (value) {
                    if (value == null) return;
                    apply(() => budgetAggregation = value);
                  },
                ),
                RadioListTile<BudgetAggregation>(
                  dense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  value: BudgetAggregation.cumulativeToSelectedMonth,
                  groupValue: budgetAggregation,
                  title: const Text('Cumulative till selected month'),
                  onChanged: (value) {
                    if (value == null) return;
                    apply(() => budgetAggregation = value);
                  },
                ),
                RadioListTile<BudgetAggregation>(
                  dense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  value: BudgetAggregation.cumulativeYear,
                  groupValue: budgetAggregation,
                  title: const Text('Cumulative full year'),
                  onChanged: (value) {
                    if (value == null) return;
                    apply(() => budgetAggregation = value);
                  },
                ),
                const Divider(height: 1),
                const _MenuSectionHeader('Sort'),
                RadioListTile<BudgetSortOrder>(
                  dense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  value: BudgetSortOrder.amount,
                  groupValue: sortOrder,
                  title: const Text('Amount'),
                  onChanged: (value) {
                    if (value == null) return;
                    apply(() => sortOrder = value);
                  },
                ),
                RadioListTile<BudgetSortOrder>(
                  dense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  value: BudgetSortOrder.alphabetical,
                  groupValue: sortOrder,
                  title: const Text('Alphabetical'),
                  onChanged: (value) {
                    if (value == null) return;
                    apply(() => sortOrder = value);
                  },
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

  @override
  Widget build(BuildContext context) {
    final totalBudget = filteredBudgets.fold(0.0, (sum, b) => sum + (b['amount'] as num).toDouble());
    final summaryLabelStyle = Theme.of(context).textTheme.labelLarge?.copyWith(
          color: const Color(0xFF52606D),
          fontWeight: FontWeight.w700,
          fontSize: 12,
        );
    final summaryValueStyle = Theme.of(context).textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.bold,
          fontSize: 18,
        );

    return Scaffold(
      backgroundColor: const Color(0xFFF3F5F9),
      floatingActionButton: selectionMode
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
                  label: Text('Delete (${selectedIndexes.length})'),
                ),
              ],
            )
          : FloatingActionButton(
              child: const Icon(Icons.add),
              onPressed: () => showAddBudgetDialog(),
            ),
      body: PageContentLayout(
        child: Column(
          children: [
            MonthSectionCard(
              currentMonth: currentMonth,
              onPrev: () {
                setState(() => currentMonth = DateTime(currentMonth.year, currentMonth.month - 1));
              },
              onNext: () {
                setState(() => currentMonth = DateTime(currentMonth.year, currentMonth.month + 1));
              },
              monthTrailing: IconButton(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: const Icon(Icons.more_vert, size: 20),
                onPressed: _showBudgetOptions,
                tooltip: 'Budget options',
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Expanded(
                    child: _BudgetSummaryStat(
                      label: 'Categories',
                      value: '${filteredBudgets.length}',
                      labelStyle: summaryLabelStyle,
                      valueStyle: summaryValueStyle,
                    ),
                  ),
                  Container(width: 1, height: 36, color: const Color(0xFFE3E7EE)),
                  Expanded(
                    child: _BudgetSummaryStat(
                      label: 'Total Budget',
                      value: formatIndianCurrency(totalBudget),
                      labelStyle: summaryLabelStyle,
                      valueStyle: summaryValueStyle,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
              child: AggregationBarChart(
                data: _budgetChartData(),
                emptyMessage: 'No budget data available for this aggregation.',
              ),
            ),
            Expanded(
              child: SectionTile(
                child: filteredBudgets.isEmpty
                    ? const Center(child: Text('No budgets set'))
                    : ListView.separated(
                        padding: EdgeInsets.zero,
                        itemCount: filteredBudgets.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final budget = filteredBudgets[index];
                          final amount = (budget['amount'] as num).toDouble();
                          final percentage = totalBudget == 0
                              ? 0
                              : (amount / totalBudget * 100).round();
                          final category = _categoryDetails(budget['category'] as String);
                          final monthYearLabel = DateFormat('MMM yyyy').format(
                            DateTime(
                              (budget['year'] as num?)?.toInt() ?? currentMonth.year,
                              (budget['month'] as num?)?.toInt() ?? currentMonth.month,
                            ),
                          );

                          return ListTile(
                            visualDensity: VisualDensity.compact,
                            minVerticalPadding: 6,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                            leading: selectionMode
                                ? Checkbox(
                                    value: selectedIndexes.contains(index),
                                    onChanged: (v) => setState(() => v == true
                                        ? selectedIndexes.add(index)
                                        : selectedIndexes.remove(index)),
                                  )
                                : AppPageIcon(
                                    icon: iconFromCodePoint(category?['icon'], fallback: Icons.category),
                                    imagePath: category?['icon_path']?.toString(),
                                  ),
                            title: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    budget['category'] as String,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  showPercentage
                                      ? '${formatIndianCurrency(amount)} ($percentage%)'
                                      : formatIndianCurrency(amount),
                                  style: const TextStyle(fontWeight: FontWeight.w400, fontSize: 13.5),
                                ),
                              ],
                            ),
                            subtitle: budgetAggregation == BudgetAggregation.selectedMonth
                                ? null
                                : Text(
                                    monthYearLabel,
                                    style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                                  ),
                            onLongPress: () => setState(() {
                              selectionMode = true;
                              selectedIndexes.add(index);
                            }),
                            onTap: () {
                              if (selectionMode) {
                                setState(() => selectedIndexes.contains(index)
                                    ? selectedIndexes.remove(index)
                                    : selectedIndexes.add(index));
                              } else {
                                showAddBudgetDialog(budget: budget);
                              }
                            },
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

class _BudgetSummaryStat extends StatelessWidget {
  final String label;
  final String value;
  final TextStyle? labelStyle;
  final TextStyle? valueStyle;

  const _BudgetSummaryStat({
    required this.label,
    required this.value,
    this.labelStyle,
    this.valueStyle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: labelStyle,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        LayoutBuilder(
          builder: (context, constraints) {
            return SizedBox(
              width: constraints.maxWidth,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.center,
                child: Text(
                  value,
                  maxLines: 1,
                  style: valueStyle?.copyWith(fontSize: 16.5),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
