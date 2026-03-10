import 'package:flutter/material.dart';
import '../services/data_store.dart';
import '../services/database_service.dart';
import '../services/widget_sync_service.dart';
import '../widgets/icon_utils.dart';
import '../widgets/month_header.dart';
import '../widgets/section_tile.dart';

class BudgetsPage extends StatefulWidget {
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
    String? selectedCategory = budget?["category"];
    TextEditingController amountController =
        TextEditingController(text: budget?["amount"]?.toString());

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(budget == null ? "Create Budget" : "Edit Budget"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: selectedCategory,
                items: DataStore.categories
                    .where((cat) => cat["type"] == "expense")
                    .map((cat) => DropdownMenuItem<String>(
                          value: cat["name"],
                          child: Text(cat["name"]!),
                        ))
                    .toList(),
                onChanged: (value) {
                  selectedCategory = value;
                },
                decoration: InputDecoration(labelText: "Category"),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: "Amount"),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("Cancel"),
            ),
            TextButton(
              onPressed: () async {
                if (selectedCategory == null || amountController.text.isEmpty) return;

                double amount = double.parse(amountController.text);

                if (budget == null) {
                  await DatabaseService.insertBudget(
                    selectedCategory!,
                    amount,
                    currentMonth.month,
                    currentMonth.year,
                  );
                } else {
                  await DatabaseService.updateBudget(
                    budget["id"],
                    selectedCategory!,
                    amount,
                    currentMonth.month,
                    currentMonth.year,
                  );
                }

                Navigator.pop(context);
                loadBudgets();
              },
              child: Text("Save"),
            ),
          ],
        );
      },
    );
  }

  void deleteSelected() async {
    for (var index in selectedIndexes) {
      final id = filteredBudgets[index]["id"];
      await DatabaseService.deleteBudget(id);
    }

    selectedIndexes.clear();
    selectionMode = false;

    loadBudgets();
  }

  List<Map<String, dynamic>> get filteredBudgets {
    return budgets
        .where((b) => b["month"] == currentMonth.month && b["year"] == currentMonth.year)
        .toList();
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
    double totalBudget = filteredBudgets.fold(
      0,
      (sum, b) => sum + (b["amount"] as num).toDouble(),
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF3F5F9),
      floatingActionButton: FloatingActionButton(
        child: Icon(Icons.add),
        onPressed: () => showAddBudgetDialog(),
      ),
      body: Column(
        children: [
          if (selectionMode)
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                icon: const Icon(Icons.delete),
                onPressed: deleteSelected,
              ),
            ),
          MonthHeader(
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
          ),
          SectionTile(
            child: Column(
              children: [
                Text(
                  "Total Budget",
                  style: TextStyle(fontSize: 16, color: Colors.grey[700]),
                ),
                const SizedBox(height: 4),
                Text(
                  "₹${totalBudget.toStringAsFixed(0)}",
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          Expanded(
            child: SectionTile(
              child: filteredBudgets.isEmpty
                  ? Center(child: Text("No budgets set"))
                  : ListView.builder(
                    itemCount: filteredBudgets.length,
                    itemBuilder: (context, index) {
                      final budget = filteredBudgets[index];

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
                            : Icon(_categoryIcon(budget["category"])),
                        title: Text(budget["category"]),
                        trailing: Text(
                          "₹${budget["amount"]}",
                          style: TextStyle(fontWeight: FontWeight.bold),
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
    );
  }
}
