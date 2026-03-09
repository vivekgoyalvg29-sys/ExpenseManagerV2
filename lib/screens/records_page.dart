import 'package:flutter/material.dart';
import '../widgets/month_header.dart';
import 'add_transaction_page.dart';
import '../services/data_store.dart';
import '../services/database_service.dart';

class Transaction {
  final String title;
  final double amount;
  final DateTime date;

  Transaction({
    required this.title,
    required this.amount,
    required this.date,
  });
}

class RecordsPage extends StatefulWidget {
  @override
  _RecordsPageState createState() => _RecordsPageState();
}

class _RecordsPageState extends State<RecordsPage> {

  DateTime currentMonth = DateTime.now();

  List<Map<String, dynamic>> transactions = [];

  Set<int> selectedIndexes = {};
  bool selectionMode = false;

  @override
  void initState() {
    super.initState();
    loadTransactions();
  }

  Future<void> loadTransactions() async {

    final data = await DatabaseService.getTransactions();

    setState(() {
      transactions = data;
    });

  }

  void deleteSelected() async {

    final idsToDelete = selectedIndexes
        .map((i) => transactions[i]["id"])
        .toList();

    for (var id in idsToDelete) {
      await DatabaseService.deleteTransaction(id);
    }

    selectedIndexes.clear();
    selectionMode = false;

    await loadTransactions();
  }

  void confirmDelete(int index) {

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Delete Transaction"),
        content: Text("Are you sure you want to delete this record?"),
        actions: [

          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: Text("Cancel"),
          ),

          TextButton(
            onPressed: () async {

              await DatabaseService.deleteTransaction(
                  transactions[index]["id"]);

              Navigator.pop(context);
              loadTransactions();

            },
            child: Text("Delete"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {

    final filteredTransactions = transactions.where((tx) {

      DateTime date = DateTime.parse(tx["date"]);

      return date.month == currentMonth.month &&
          date.year == currentMonth.year;

    }).toList();

    double totalSpent = filteredTransactions.fold(
      0,
      (sum, tx) => sum + (tx["amount"] as num).toDouble(),
    );

    return Scaffold(

      appBar: AppBar(

        title: Text(
            selectionMode
                ? "${selectedIndexes.length} selected"
                : "MyExp"
        ),

        actions: [

          if (selectionMode)
            IconButton(
              icon: Icon(Icons.delete),
              onPressed: deleteSelected,
            )

        ],
      ),

      floatingActionButton: FloatingActionButton(
        child: Icon(Icons.add),

        onPressed: () async {

          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AddTransactionPage(),
            ),
          );

          if (result != null) {

            await DatabaseService.insertTransaction(
              result["title"],
              result["amount"],
              result["date"],
            );

            loadTransactions();
          }

        },
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
                  "Total Spent",
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[700],
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  "₹${totalSpent.toStringAsFixed(0)}",
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),

              ],
            ),
          ),

          Expanded(
            child: filteredTransactions.isEmpty
                ? Center(child: Text("No transactions for this month"))
                : ListView.builder(
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

                                    if (v == true)
                                      selectedIndexes.add(index);
                                    else
                                      selectedIndexes.remove(index);

                                  });

                                },
                              )
                            : CircleAvatar(
                                child: Icon(Icons.money_off),
                              ),

                        title: Text(tx["title"]),

                        subtitle: Text(
                            "${date.day}/${date.month}/${date.year}"
                        ),

                        trailing: Text(
                          "₹${tx["amount"]}",
                          style: TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
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

      if (selectedIndexes.contains(index))
        selectedIndexes.remove(index);
      else
        selectedIndexes.add(index);

    });

  } else {

    final tx = filteredTransactions[index];

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
        tx["id"],
        result["title"],
        result["amount"],
        result["date"],
      );

      loadTransactions();
    }
  }

},

                      );
                    },
                  ),
          ),

        ],
      ),
    );
  }
}
