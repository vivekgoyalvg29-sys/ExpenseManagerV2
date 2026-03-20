import 'package:flutter/material.dart';

import '../services/data_store.dart';
import '../services/database_service.dart';
import '../services/widget_sync_service.dart';
import '../utils/indian_number_formatter.dart';
import '../widgets/icon_utils.dart';
import '../widgets/month_section_card.dart';
import '../widgets/page_content_layout.dart';
import '../widgets/section_tile.dart';

class BudgetsPage extends StatefulWidget {
  const BudgetsPage({super.key});

  @override
  _BudgetsPageState createState() => _BudgetsPageState();
}

class _BudgetsPageState extends State<BudgetsPage> {
  DateTime currentMonth = DateTime.now();
  List<Map<String, dynamic>> budgets = [];

  Set<int> selectedIndexes = {};
  bool selectionMode = false;

  @override
  void initState() {
    super.initState();
    loadBudgets();
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
      builder: (context) {
        return AlertDialog(
          title: Text(budget == null ? 'Create Budget' : 'Edit Budget'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: selectedCategory,
                items: DataStore.categories
                    .where((cat) => cat['type'] == 'expense')
                    .map(
                      (cat) => DropdownMenuItem<String>(
                        value: cat['name'],
                        child: Text(cat['name']!),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  selectedCategory = value;
                },
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
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                if (selectedCategory == null || amountController.text.isEmpty) return;

                final amount = double.parse(amountController.text);

                if (budget == null) {
                  await DatabaseService.insertBudget(
                    selectedCategory!,
                    amount,
                    currentMonth.month,
                    currentMonth.year,
                  );
                } else {
                  await DatabaseService.updateBudget(
                    budget['id'],
                    selectedCategory!,
                    amount,
                    currentMonth.month,
                    currentMonth.year,
                  );
                }

                Navigator.pop(context);
                loadBudgets();
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  void clearSelection() {
    setState(() {
      selectedIndexes.clear();
      selectionMode = false;
    });
  }

  void deleteSelected() async {
    for (final index in selectedIndexes) {
      final id = filteredBudgets[index]['id'];
      await DatabaseService.deleteBudget(id);
    }

    clearSelection();
    loadBudgets();
  }

  List<Map<String, dynamic>> get filteredBudgets {
    return budgets
        .where((b) => b['month'] == currentMonth.month && b['year'] == currentMonth.year)
        .toList();
  }

  IconData _categoryIcon(String categoryName) {
    final category = DataStore.categories.cast<Map<String, dynamic>?>().firstWhere(
          (c) => c?['name'] == categoryName,
          orElse: () => null,
        );

    return iconFromCodePoint(category?['icon'], fallback: Icons.category);
  }

  @override
  Widget build(BuildContext context) {
    final totalBudget = filteredBudgets.fold(0.0, (sum, b) => sum + (b['amount'] as num).toDouble());
    final headingStyle = Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700);
    final summaryLabelStyle = Theme.of(context).textTheme.labelLarge?.copyWith(
          color: const Color(0xFF52606D),
          fontWeight: FontWeight.w600,
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
                setState(() {
                  currentMonth = DateTime(currentMonth.year, currentMonth.month - 1);
                });
              },
              onNext: () {
                setState(() {
                  currentMonth = DateTime(currentMonth.year, currentMonth.month + 1);
                });
              },
              child: Row(
                children: [
                  Expanded(
                    child: _BudgetSummaryStat(
                      label: 'Categories',
                      value: '${filteredBudgets.length}',
                      alignment: CrossAxisAlignment.start,
                      labelStyle: summaryLabelStyle,
                      valueStyle: headingStyle,
                    ),
                  ),
                  Expanded(
                    child: _BudgetSummaryStat(
                      label: 'Total Budget',
                      value: formatIndianCurrency(totalBudget),
                      alignment: CrossAxisAlignment.end,
                      labelStyle: summaryLabelStyle,
                      valueStyle: headingStyle?.copyWith(fontSize: 19),
                    ),
                  ),
                ],
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
                          final percentage = totalBudget == 0 ? 0 : (amount / totalBudget) * 100;

                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            leading: selectionMode
                                ? Checkbox(
                                    value: selectedIndexes.contains(index),
                                    onChanged: (v) {
                                      setState(() {
                                        if (v == true) {
                                          selectedIndexes.add(index);
                                        } else {
                                          selectedIndexes.remove(index);
                                        }
                                      });
                                    },
                                  )
                                : CircleAvatar(
                                    backgroundColor: const Color(0xFFE8F5E9),
                                    foregroundColor: Colors.green[800],
                                    child: Icon(_categoryIcon(budget['category'] as String)),
                                  ),
                            title: Text(
                              budget['category'] as String,
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                '${percentage.toStringAsFixed(1)}% of this month\'s budget',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  formatIndianCurrency(amount),
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${percentage.toStringAsFixed(1)}%',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        color: const Color(0xFF52606D),
                                      ),
                                ),
                              ],
                            ),
                            onLongPress: () {
                              setState(() {
                                selectionMode = true;
                                selectedIndexes.add(index);
                              });
                            },
                            onTap: () {
                              if (selectionMode) {
                                setState(() {
                                  if (selectedIndexes.contains(index)) {
                                    selectedIndexes.remove(index);
                                  } else {
                                    selectedIndexes.add(index);
                                  }
                                });
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

class _BudgetSummaryStat extends StatelessWidget {
  final String label;
  final String value;
  final CrossAxisAlignment alignment;
  final TextStyle? labelStyle;
  final TextStyle? valueStyle;

  const _BudgetSummaryStat({
    required this.label,
    required this.value,
    required this.alignment,
    this.labelStyle,
    this.valueStyle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: alignment,
      children: [
        Text(label, style: labelStyle),
        const SizedBox(height: 4),
        Text(value, style: valueStyle),
      ],
    );
  }
}
