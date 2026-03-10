import 'package:flutter/material.dart';
import '../widgets/section_tile.dart';
import 'records_page.dart';
import 'analysis_page.dart';
import 'budgets_page.dart';
import 'accounts_page.dart';
import 'categories_page.dart';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int currentIndex = 0;

  final List<Widget> pages = [
    RecordsPage(),
    AnalysisPage(),
    BudgetsPage(),
    AccountsPage(),
    CategoriesPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F5F9),
      appBar: AppBar(
        title: const Text("FinTrack"),
      ),
      body: pages[currentIndex],
      bottomNavigationBar: SafeArea(
        top: false,
        child: SectionTile(
          margin: const EdgeInsets.fromLTRB(12, 6, 12, 10),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: BottomNavigationBar(
            currentIndex: currentIndex,
            type: BottomNavigationBarType.fixed,
            elevation: 0,
            backgroundColor: Colors.transparent,
            selectedItemColor: Colors.green,
            unselectedItemColor: Colors.black54,
            onTap: (index) {
              setState(() {
                currentIndex = index;
              });
            },
            items: const [
              BottomNavigationBarItem(icon: Icon(Icons.list), label: "Records"),
              BottomNavigationBarItem(icon: Icon(Icons.pie_chart), label: "Analysis"),
              BottomNavigationBarItem(icon: Icon(Icons.account_balance), label: "Budgets"),
              BottomNavigationBarItem(
                icon: Icon(Icons.account_balance_wallet),
                label: "Accounts",
              ),
              BottomNavigationBarItem(icon: Icon(Icons.category), label: "Categories"),
            ],
          ),
        ),
      ),
    );
  }
}
