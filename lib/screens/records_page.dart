import 'package:flutter/material.dart';

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

  List<Transaction> transactions = [
    Transaction(title: "Eat Out", amount: 120, date: DateTime.now()),
    Transaction(title: "Trips Outings", amount: 300, date: DateTime.now()),
    Transaction(title: "Medicines", amount: 500, date: DateTime.now()),
  ];

  void deleteTransaction(int index) {
    setState(() {
      transactions.removeAt(index);
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

    if (transactions.isEmpty) {
      return Center(child: Text("No transactions yet"));
    }

    return ListView.builder(
      itemCount: transactions.length,

      itemBuilder: (context, index) {

        final tx = transactions[index];

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
    );
  }
}
