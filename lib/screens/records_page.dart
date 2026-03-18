import 'package:flutter/material.dart';
import '../services/data_store.dart';
import '../services/database_service.dart';
import '../services/widget_sync_service.dart';
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
                          DateTime date = DateTime.parse(tx["date"]);

                          return ListTile(
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
                                    child: Icon(
                                      _categoryIcon(tx["title"]),
                                      color: Colors.white,
                                    ),
                                  ),
                            title: Text(
                              tx["title"],
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                            ),
                            subtitle: Text(
                              "${date.day}/${date.month}/${date.year}",
                              style: const TextStyle(fontSize: 13),
                            ),
                            trailing: Text(
                              "₹${tx["amount"]}",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: tx["type"] == "income" ? Colors.green : Colors.red,
                              ),
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
