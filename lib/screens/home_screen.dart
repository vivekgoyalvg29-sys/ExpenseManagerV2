import 'package:flutter/material.dart';
import '../widgets/section_tile.dart';
import 'load_expenses_from_messages_page.dart';
import 'records_page.dart';
import 'analysis_page.dart';
import 'budgets_page.dart';
import 'accounts_page.dart';
import 'categories_page.dart';
import 'sms_page.dart';

class HomeScreen extends StatefulWidget {
  final int initialIndex;

  const HomeScreen({super.key, this.initialIndex = 0});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late int currentIndex;

  final List<Widget> pages = [
    RecordsPage(),
    AnalysisPage(),
    BudgetsPage(),
    AccountsPage(),
    CategoriesPage(),
    SmsPage(),
  ];

  @override
  void initState() {
    super.initState();
    currentIndex = widget.initialIndex;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F5F9),
      appBar: AppBar(
        title: const SizedBox.shrink(),
        leading: PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert),
          position: PopupMenuPosition.under,
          onSelected: (value) async {
            if (value == 'load_messages') {
              final loaded = await Navigator.push<bool>(
                context,
                MaterialPageRoute(builder: (_) => const LoadExpensesFromMessagesPage()),
              );

              if (loaded == true && mounted) {
                setState(() {
                  currentIndex = 5;
                });
              }
            }
          },
          itemBuilder: (context) => const [
            PopupMenuItem<String>(
              value: 'load_messages',
              child: Text('Load expense from messages'),
            ),
          ],
        ),
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
              BottomNavigationBarItem(icon: Icon(Icons.sms), label: "SMSs"),
            ],
          ),
        ),
      ),
    );
  }
}
