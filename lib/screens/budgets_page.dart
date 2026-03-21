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
  State<BudgetsPage> createState() => _BudgetsPageState();
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
      builder: (context) => AlertDialog(
        title: Text(budget == null ? 'Create Budget' : 'Edit Budget'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              value: selectedCategory,
              items: DataStore.categories.where((cat) => cat['type'] == 'expense').map((cat) => DropdownMenuItem<String>(value: cat['name'], child: Text(cat['name']!))).toList(),
              onChanged: (value) => selectedCategory = value,
              decoration: const InputDecoration(labelText: 'Category'),
            ),
            const SizedBox(height: 10),
            TextField(controller: amountController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Amount')),
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

  List<Map<String, dynamic>> get filteredBudgets => budgets.where((b) => b['month'] == currentMonth.month && b['year'] == currentMonth.year).toList();

  Map<String, dynamic>? _categoryDetails(String categoryName) {
    return DataStore.categories.cast<Map<String, dynamic>?>().firstWhere((c) => c?['name'] == categoryName, orElse: () => null);
  }

  @override
  Widget build(BuildContext context) {
    final totalBudget = filteredBudgets.fold(0.0, (sum, b) => sum + (b['amount'] as num).toDouble());
    final headingStyle = Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700);
    final summaryLabelStyle = Theme.of(context).textTheme.labelLarge?.copyWith(color: const Color(0xFF52606D), fontWeight: FontWeight.w600);

    return Scaffold(
      backgroundColor: const Color(0xFFF3F5F9),
      floatingActionButton: selectionMode
          ? Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                FloatingActionButton.small(heroTag: 'cancelBudgetSelection', onPressed: clearSelection, tooltip: 'Cancel selection', child: const Icon(Icons.close)),
                const SizedBox(height: 10),
                FloatingActionButton.extended(heroTag: 'deleteSelectedBudgets', onPressed: deleteSelected, icon: const Icon(Icons.delete), label: Text('Delete (${selectedIndexes.length})')),
              ],
            )
          : FloatingActionButton(child: const Icon(Icons.add), onPressed: () => showAddBudgetDialog()),
      body: PageContentLayout(
        child: Column(
          children: [
            MonthSectionCard(
              currentMonth: currentMonth,
              onPrev: () => setState(() => currentMonth = DateTime(currentMonth.year, currentMonth.month - 1)),
              onNext: () => setState(() => currentMonth = DateTime(currentMonth.year, currentMonth.month + 1)),
              child: Row(
                children: [
                  Expanded(child: _BudgetSummaryStat(label: 'Categories', value: '${filteredBudgets.length}', labelStyle: summaryLabelStyle, valueStyle: headingStyle)),
                  const SizedBox(width: 12),
                  Expanded(child: _BudgetSummaryStat(label: 'Total Budget', value: formatIndianCurrency(totalBudget), labelStyle: summaryLabelStyle, valueStyle: headingStyle?.copyWith(fontSize: 18))),
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
                          final category = _categoryDetails(budget['category'] as String);
                          return ListTile(
                            minVerticalPadding: 6,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            leading: selectionMode
                                ? Checkbox(value: selectedIndexes.contains(index), onChanged: (v) => setState(() => v == true ? selectedIndexes.add(index) : selectedIndexes.remove(index)))
                                : AppPageIcon(icon: iconFromCodePoint(category?['icon'], fallback: Icons.category), imagePath: category?['icon_path']?.toString()),
                            title: Row(
                              children: [
                                Expanded(child: Text(budget['category'] as String, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600))),
                                const SizedBox(width: 12),
                                Text(formatIndianCurrency(amount), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                              ],
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text('${percentage.toStringAsFixed(1)}% of total budget', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: const Color(0xFF52606D), fontWeight: FontWeight.w600)),
                            ),
                            onLongPress: () => setState(() { selectionMode = true; selectedIndexes.add(index); }),
                            onTap: () {
                              if (selectionMode) {
                                setState(() => selectedIndexes.contains(index) ? selectedIndexes.remove(index) : selectedIndexes.add(index));
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
  final TextStyle? labelStyle;
  final TextStyle? valueStyle;

  const _BudgetSummaryStat({required this.label, required this.value, this.labelStyle, this.valueStyle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: labelStyle),
        const SizedBox(height: 6),
        Text(value, style: valueStyle, maxLines: 1, overflow: TextOverflow.ellipsis),
      ],
    );
  }
}
