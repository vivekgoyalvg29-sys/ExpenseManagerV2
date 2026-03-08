import 'package:flutter/material.dart';
import '../widgets/month_header.dart';
import '../services/data_store.dart';

class BudgetsPage extends StatefulWidget {
  @override
  _BudgetsPageState createState() => _BudgetsPageState();
}

class _BudgetsPageState extends State<BudgetsPage> {

  DateTime currentMonth = DateTime.now();

  List<Map<String, dynamic>> budgets = [];

  void showAddBudgetDialog() {

    String? selectedCategory;
    TextEditingController amountController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {

        return AlertDialog(
          title: Text("Create Budget"),

          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [

              DropdownButtonFormField<String>(
                items: DataStore.categories
                    .map((cat) => DropdownMenuItem(
                        value: cat["name"],
                        child: Text(cat["name"]!)))
                    .toList(),
                onChanged: (value) {
                  selectedCategory = value;
                },
                decoration: InputDecoration(
                  labelText: "Category",
                ),
              ),

              const SizedBox(height: 10),

              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: "Amount",
                ),
              ),

            ],
          ),

          actions: [

            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text("Cancel"),
            ),

            TextButton(
              onPressed: () {

                if (selectedCategory == null ||
                    amountController.text.isEmpty) {
                  return;
                }

                setState(() {

                  budgets.add({
                    "category": selectedCategory,
                    "amount": double.parse(amountController.text),
                    "month": currentMonth.month,
                    "year": currentMonth.year
                  });

                });

                Navigator.pop(context);

              },
              child: Text("Save"),
            ),

          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {

    final filteredBudgets = budgets.where((b) =>
        b["month"] == currentMonth.month &&
        b["year"] == currentMonth.year).toList();

    double totalBudget = filteredBudgets.fold(
      0,
      (sum, b) => sum + b["amount"],
    );

    return Scaffold(

      floatingActionButton: FloatingActionButton(
        child: Icon(Icons.add),
        onPressed: showAddBudgetDialog,
      ),

      body: Column(
        children: [

          MonthHeader(
            currentMonth: currentMonth,
            onPrev: () {
              setState(() {
                currentMonth =
                    DateTime(currentMonth.year, currentMonth.month - 1);
              });
            },
            onNext: () {
              setState(() {
                currentMonth =
                    DateTime(currentMonth.year, currentMonth.month + 1);
              });
            },
          ),

          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [

                Text(
                  "Total Budget",
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[700],
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  "₹${totalBudget.toStringAsFixed(0)}",
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),

              ],
            ),
          ),

          Expanded(
            child: filteredBudgets.isEmpty
                ? Center(child: Text("No budgets set"))
                : ListView.builder(
                    itemCount: filteredBudgets.length,
                    itemBuilder: (context, index) {

                      final budget = filteredBudgets[index];

                      return ListTile(
                        leading: Icon(Icons.account_balance),
                        title: Text(budget["category"]),
                        trailing: Text(
                          "₹${budget["amount"]}",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      );
                    },
                  ),
          ),

        ],
      ),
    );
  }
}
