import 'package:flutter/material.dart';
import 'records_page.dart';
import 'analysis_page.dart';
import 'budgets_page.dart';
import 'accounts_page.dart';
import 'categories_page.dart';
import 'add_transaction_page.dart';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {

  int currentIndex = 0;

  final pages = [
    RecordsPage(),
    AnalysisPage(),
    BudgetsPage(),
    AccountsPage(),
    CategoriesPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("MyMoney"),
      ),

      body: pages[currentIndex],

      floatingActionButton: FloatingActionButton(
        child: Icon(Icons.add),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AddTransactionPage(),
            ),
          );
        },
      ),

      bottomNavigationBar: BottomNavigationBar(
        currentIndex: currentIndex,
        type: BottomNavigationBarType.fixed,

        onTap: (index) {
          setState(() {
            currentIndex = index;
          });
        },

        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.list), label: "Records"),
          BottomNavigationBarItem(
              icon: Icon(Icons.pie_chart), label: "Analysis"),
          BottomNavigationBarItem(
              icon: Icon(Icons.account_balance), label: "Budgets"),
          BottomNavigationBarItem(
              icon: Icon(Icons.account_balance_wallet), label: "Accounts"),
          BottomNavigationBarItem(
              icon: Icon(Icons.category), label: "Categories"),
        ],
      ),
    );
  }
}
