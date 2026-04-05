import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/data_store.dart';
import '../services/data_service.dart';
import '../services/widget_sync_service.dart';
import '../utils/indian_number_formatter.dart';
import '../widgets/icon_utils.dart';
import '../widgets/aggregation_bar_chart.dart';
import '../widgets/month_section_card.dart';
import '../widgets/page_content_layout.dart';
import '../widgets/segmented_toggle.dart';
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

  Future<void> loadBudgets() async {
    final data = await DataService.getBudgets();
    final categories = await DataService.getCategories();
    setState(() {
      budgets = data;
      DataStore.categories = categories;
    });
    await WidgetSyncService.syncFromStoredConfiguration();
  }

  void showAddBudgetDialog({Map<String, dynamic>? budget}) {
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
      selectedIndexes.clear();
      selectionMode = false;
    });
  }

  Future<void> deleteSelected() async {
    for (final index in selectedIndexes) {
      final id = filteredBudgets[index]['id'];
      await DataService.deleteBudget(id);
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

  bool get _isCategoryAggregatedView => budgetAggregation != BudgetAggregation.selectedMonth;

  List<Map<String, dynamic>> get displayBudgets {
    if (!_isCategoryAggregatedView) return filteredBudgets;

    final grouped = <String, double>{};
    for (final budget in filteredBudgets) {
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

  bool _isBudgetInRange(Map<String, dynamic> budget) {
    final year = (budget['year'] as num?)?.toInt() ?? 0;
    if (year != currentMonth.year) return false;
    final month = (budget['month'] as num?)?.toInt() ?? 0;
    if (budgetAggregation == BudgetAggregation.selectedMonth) return month == currentMonth.month;
    if (budgetAggregation == BudgetAggregation.cumulativeToSelectedMonth) return month <= currentMonth.month;
    return true;
  }

  List<AggregationBarData> _budgetChartData() {
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
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Align(
                    alignment: Alignment.center,
                    child: SegmentedToggle<BudgetAggregation>(
                      axis: SegmentedToggleAxis.vertical,
                      shrinkWidth: true,
                      verticalCellHeight: 32,
                      options: const [
                        SegmentedToggleOption(value: BudgetAggregation.selectedMonth, label: 'Month'),
                        SegmentedToggleOption(value: BudgetAggregation.cumulativeToSelectedMonth, label: 'Till month'),
                        SegmentedToggleOption(value: BudgetAggregation.cumulativeYear, label: 'Year'),
                      ],
                      selectedValue: budgetAggregation,
                      onChanged: (value) => apply(() => budgetAggregation = value),
                    ),
                  ),
                ),
                const Divider(height: 1),
                const _MenuSectionHeader('Sort'),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Align(
                    alignment: Alignment.center,
                    child: SegmentedToggle<BudgetSortOrder>(
                      axis: SegmentedToggleAxis.vertical,
                      shrinkWidth: true,
                      verticalCellHeight: 32,
                      options: const [
                        SegmentedToggleOption(value: BudgetSortOrder.amount, label: 'Amount'),
                        SegmentedToggleOption(value: BudgetSortOrder.alphabetical, label: 'A-Z'),
                      ],
                      selectedValue: sortOrder,
                      onChanged: (value) => apply(() => sortOrder = value),
                    ),
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

  @override
  Widget build(BuildContext context) {
    final visibleBudgets = displayBudgets;
    final totalBudget = visibleBudgets.fold(0.0, (sum, b) => sum + (b['amount'] as num).toDouble());
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
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
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
              aggregationSubtitle: _budgetAggregationSubtitle(),
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
                      value: '${visibleBudgets.length}',
                      labelStyle: summaryLabelStyle,
                      valueStyle: summaryValueStyle,
                    ),
                  ),
                  Container(width: 1, height: 36, color: Theme.of(context).dividerColor),
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
                labelBuilder: (context, item) {
                  final category = _categoryDetails(item.label);
                  return AppPageIcon(
                    icon: iconFromCodePoint(category?['icon']),
                    imagePath: category?['icon_path']?.toString(),
                    size: 11,
                    boxSize: 22,
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
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final budget = visibleBudgets[index];
                          final amount = (budget['amount'] as num).toDouble();
                          final percentage = totalBudget == 0
                              ? 0
                              : (amount / totalBudget * 100).round();
                          final category = _categoryDetails(budget['category'] as String);
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
                            subtitle: null,
                            onLongPress: _isCategoryAggregatedView
                                ? null
                                : () => setState(() {
                                      selectionMode = true;
                                      selectedIndexes.add(index);
                                    }),
                            onTap: () {
                              if (_isCategoryAggregatedView) return;
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
