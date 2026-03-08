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

  List<Transaction> transactions = [];

  void deleteTransaction(int index) {
    setState(() {
      transactions.removeAt(index);
      DataStore.transactions.removeAt(index);
    });
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
            onPressed: () {
              deleteTransaction(index);
              Navigator.pop(context);
            },
            child: Text("Delete"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {

    final filteredTransactions = transactions.where((tx) =>
        tx.date.month == currentMonth.month &&
        tx.date.year == currentMonth.year).toList();

    double totalSpent = filteredTransactions.fold(
      0,
      (sum, tx) => sum + tx.amount,
    );

    return Scaffold(

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

            setState(() {

              transactions.add(
                Transaction(
                  title: result["title"],
                  amount: result["amount"],
                  date: result["date"],
                ),
              );

              DataStore.transactions.add({
                "title": result["title"],
                "amount": result["amount"],
                "date": result["date"],
              });

            });

            await DatabaseService.insertTransaction(
              result["title"],
              result["amount"],
              result["date"],
            );

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

                      return ListTile(

                        leading: CircleAvatar(
                          child: Icon(Icons.money_off),
                        ),

                        title: Text(tx.title),

                        subtitle: Text(
                          "${tx.date.day}/${tx.date.month}/${tx.date.year}"
                        ),

                        trailing: Text(
                          "₹${tx.amount}",
                          style: TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        onLongPress: () {
                          confirmDelete(index);
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
