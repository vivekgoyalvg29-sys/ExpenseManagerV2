import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/data_store.dart';
import '../services/database_service.dart';
import '../services/widget_sync_service.dart';
import '../utils/indian_number_formatter.dart';
import '../widgets/icon_utils.dart';
import '../widgets/month_summary.dart';
import '../widgets/page_content_layout.dart';
import '../widgets/section_tile.dart';
import 'add_transaction_page.dart';

class RecordsPage extends StatefulWidget {
  const RecordsPage({super.key});

  @override
  _RecordsPageState createState() => _RecordsPageState();
}

class _RecordsPageState extends State<RecordsPage> {
  DateTime currentMonth = DateTime.now();
  List<Map<String, dynamic>> transactions = [];
  List<Map<String, dynamic>> budgets = [];

  Set<int> selectedIndexes = {};
  bool selectionMode = false;

  @override
  void initState() {
    super.initState();
    loadTransactions();
  }

  Future<void> loadTransactions() async {
    final txData = await DatabaseService.getTransactions();
    final budgetData = await DatabaseService.getBudgets();
    final categoryData = await DatabaseService.getCategories();

    setState(() {
      transactions = txData;
      budgets = budgetData;
      DataStore.categories = categoryData;
    });

    await WidgetSyncService.syncFromStoredConfiguration();
  }

  List<Map<String, dynamic>> get filteredTransactions {
    return transactions.where((tx) {
      DateTime date = DateTime.parse(tx["date"]);
      return date.month == currentMonth.month && date.year == currentMonth.year;
    }).toList();
  }

  double get monthBudgetTotal {
    return budgets
        .where((b) => b['month'] == currentMonth.month && b['year'] == currentMonth.year)
        .fold(0.0, (sum, b) => sum + (b['amount'] as num).toDouble());
  }

  void clearSelection() {
    setState(() {
      selectedIndexes.clear();
      selectionMode = false;
    });
  }

  void deleteSelected() async {
    final idsToDelete = selectedIndexes.map((i) => filteredTransactions[i]["id"]).toList();

    for (var id in idsToDelete) {
      await DatabaseService.deleteTransaction(id);
    }

    clearSelection();

    loadTransactions();
  }

  IconData _categoryIcon(String categoryName) {
    final category = DataStore.categories.cast<Map<String, dynamic>?>().firstWhere(
          (c) => c?["name"] == categoryName,
          orElse: () => null,
        );
    return iconFromCodePoint(category?["icon"], fallback: Icons.category);
  }

  @override
  Widget build(BuildContext context) {
    double expense = 0;

    for (var tx in filteredTransactions) {
      if (tx["type"] == "expense") {
        expense += (tx["amount"] as num).toDouble();
      }
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF3F5F9),
      floatingActionButton: selectionMode
          ? Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                FloatingActionButton.small(
                  heroTag: 'cancelRecordSelection',
                  onPressed: clearSelection,
                  tooltip: 'Cancel selection',
                  child: const Icon(Icons.close),
                ),
                const SizedBox(height: 10),
                FloatingActionButton.extended(
                  heroTag: 'deleteSelectedRecords',
                  onPressed: deleteSelected,
                  icon: const Icon(Icons.delete),
                  label: Text('Delete (${selectedIndexes.length})'),
                ),
              ],
            )
          : FloatingActionButton(
              child: const Icon(Icons.add),
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => AddTransactionPage()),
                );

                if (result != null) {
                  await DatabaseService.insertTransaction(
                    result["title"],
                    result["amount"],
                    result["date"],
                    result["type"],
                    (result["account"] ?? '').toString(),
                    (result["comment"] ?? '').toString(),
                  );

                  loadTransactions();
                }
              },
            ),
      body: PageContentLayout(
        child: Column(
          children: [
            MonthSummary(
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
              budget: monthBudgetTotal,
              expense: expense,
            ),
            Expanded(
              child: SectionTile(
                child: filteredTransactions.isEmpty
                    ? const Center(child: Text("No transactions"))
                    : ListView.builder(
                        padding: EdgeInsets.zero,
                        itemCount: filteredTransactions.length,
                        itemBuilder: (context, index) {
                          final tx = filteredTransactions[index];
                          final date = DateTime.parse(tx["date"]);
                          final previousTx = index > 0 ? filteredTransactions[index - 1] : null;
                          final previousDate = previousTx != null
                              ? DateTime.parse(previousTx["date"])
                              : null;
                          final showDateHeader = previousDate == null ||
                              previousDate.year != date.year ||
                              previousDate.month != date.month ||
                              previousDate.day != date.day;
                          final comment = (tx["comment"] ?? '').toString().trim();
                          final amount = (tx["amount"] as num).toDouble();

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (showDateHeader) ...[
                                if (index > 0) const SizedBox(height: 8),
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
                                  child: Text(
                                    DateFormat('MMM d, EEEE').format(date),
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF0E5D5B),
                                    ),
                                  ),
                                ),
                                const Divider(height: 1, thickness: 1),
                              ],
                              ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 3,
                                ),
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
                                    : AppPageIcon(icon: _categoryIcon(tx["title"])),
                                title: Text(
                                  tx["title"],
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                subtitle: comment.isEmpty
                                    ? null
                                    : Padding(
                                        padding: const EdgeInsets.only(top: 4),
                                        child: Text(
                                          comment,
                                          style: const TextStyle(fontSize: 13),
                                        ),
                                      ),
                                trailing: Text(
                                  "${tx["type"] == "income" ? '+' : '-'}${formatIndianCurrency(amount, decimalDigits: 2)}",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: tx["type"] == "income"
                                        ? Colors.green
                                        : Colors.red,
                                  ),
                                ),
                                onLongPress: () {
                                  setState(() {
                                    selectionMode = true;
                                    selectedIndexes.add(index);
                                  });
                                },
                                onTap: () async {
                                  if (selectionMode) {
                                    setState(() {
                                      if (selectedIndexes.contains(index)) {
                                        selectedIndexes.remove(index);
                                      } else {
                                        selectedIndexes.add(index);
                                      }
                                    });
                                    return;
                                  }

                                  final result = await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => AddTransactionPage(
                                        existingTransaction: tx,
                                      ),
                                    ),
                                  );

                                  if (result != null) {
                                    await DatabaseService.updateTransaction(
                                      tx['id'] as int,
                                      result['title'] as String,
                                      result['amount'] as double,
                                      result['date'] as DateTime,
                                      result['type'] as String,
                                      (result['account'] ?? '').toString(),
                                      (result['comment'] ?? '').toString(),
                                    );

                                    await loadTransactions();
                                  }
                                },
                              ),
                              if (index < filteredTransactions.length - 1)
                                const Padding(
                                  padding: EdgeInsets.only(left: 88),
                                  child: Divider(height: 1),
                                ),
                            ],
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
