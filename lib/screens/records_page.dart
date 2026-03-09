import 'package:flutter/material.dart';
import '../widgets/month_header.dart';
import '../widgets/month_summary.dart';
import 'add_transaction_page.dart';
import '../services/database_service.dart';

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
        .map((i) => filteredTransactions[i]["id"])
        .toList();

    for (var id in idsToDelete) {
      await DatabaseService.deleteTransaction(id);
    }

    selectedIndexes.clear();
    selectionMode = false;

    loadTransactions();
  }

  List<Map<String, dynamic>> get filteredTransactions {

    return transactions.where((tx) {

      DateTime date = DateTime.parse(tx["date"]);

      return date.month == currentMonth.month &&
          date.year == currentMonth.year;

    }).toList();

  }

  @override
  Widget build(BuildContext context) {

    double income = 0;
    double expense = 0;

    for (var tx in filteredTransactions) {

      double amount = (tx["amount"] as num).toDouble();

      if (amount >= 0)
        income += amount;
      else
        expense += amount.abs();

    }

    return Scaffold(

      appBar: AppBar(

        title: Text(
            selectionMode
                ? "${selectedIndexes.length} selected"
                : "Records"
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

          MonthSummary(
            income: income,
            expense: expense,
          ),

          Expanded(
            child: filteredTransactions.isEmpty
                ? Center(child: Text("No transactions"))
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
                                child: Icon(Icons.money),
                              ),

                        title: Text(tx["title"]),

                        subtitle: Text(
                          "${date.day}/${date.month}/${date.year}"
                        ),

                        trailing: Text(
                          "₹${tx["amount"]}",
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
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

                              if (selectedIndexes.contains(index))
                                selectedIndexes.remove(index);
                              else
                                selectedIndexes.add(index);

                            });

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
