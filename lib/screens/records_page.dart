import 'package:flutter/material.dart';
import '../widgets/month_header.dart';

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

    return Column(
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

        Expanded(
          child: transactions.isEmpty
              ? Center(child: Text("No transactions yet"))
              : ListView.builder(
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
                ),
        ),

      ],
    );
  }
}
