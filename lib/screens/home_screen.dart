import 'package:flutter/material.dart';

import '../services/data_store.dart';
import '../widgets/section_tile.dart';
import 'accounts_page.dart';
import 'analysis_page.dart';
import 'budgets_page.dart';
import 'categories_page.dart';
import 'load_expenses_from_messages_page.dart';
import 'records_page.dart';
import 'sms_page.dart';

class HomeScreen extends StatefulWidget {
  final int initialIndex;

  const HomeScreen({super.key, this.initialIndex = 0});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late int currentIndex;

  @override
  void initState() {
    super.initState();
    currentIndex = widget.initialIndex;
  }

  Widget _buildCurrentPage() {
    switch (currentIndex) {
      case 0:
        return RecordsPage();
      case 1:
        return AnalysisPage();
      case 2:
        return BudgetsPage();
      case 3:
        return AccountsPage();
      case 4:
        return CategoriesPage();
      case 5:
        return SmsPage(key: ValueKey(DataStore.smsTransactionsVersion));
      default:
        return RecordsPage();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSmsPage = currentIndex == 5;
    final hasSmsTransactions = DataStore.smsTransactions.isNotEmpty;
    final appBarTitle = isSmsPage
        ? (hasSmsTransactions ? 'SMSs' : 'Load transactions from SMSs')
        : 'FinTrack';

    Future<void> handleMenuSelection(String value) async {
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

      if (value == 'clear_messages') {
        DataStore.replaceSmsTransactions([]);
        if (!mounted) return;
        setState(() {});
      }
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF3F5F9),
      appBar: AppBar(
        title: Text(appBarTitle),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: isSmsPage
            ? [
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert),
                  position: PopupMenuPosition.under,
                  onSelected: handleMenuSelection,
                  itemBuilder: (context) => [
                    const PopupMenuItem<String>(
                      value: 'load_messages',
                      child: Text('Load expense from messages'),
                    ),
                    if (hasSmsTransactions)
                      const PopupMenuItem<String>(
                        value: 'clear_messages',
                        child: Text('Clear loaded transactions'),
                      ),
                  ],
                ),
              ]
            : null,
      ),
      body: _buildCurrentPage(),
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
              BottomNavigationBarItem(icon: Icon(Icons.list), label: 'Records'),
              BottomNavigationBarItem(icon: Icon(Icons.pie_chart), label: 'Analysis'),
              BottomNavigationBarItem(icon: Icon(Icons.account_balance), label: 'Budgets'),
              BottomNavigationBarItem(
                icon: Icon(Icons.account_balance_wallet),
                label: 'Accounts',
              ),
              BottomNavigationBarItem(icon: Icon(Icons.category), label: 'Categories'),
              BottomNavigationBarItem(icon: Icon(Icons.sms), label: 'SMSs'),
            ],
          ),
        ),
      ),
    );
  }
}
