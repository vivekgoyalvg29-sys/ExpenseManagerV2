import 'package:flutter/material.dart';
import '../widgets/section_tile.dart';
import 'load_expenses_from_messages_page.dart';
import 'records_page.dart';
import 'analysis_page.dart';
import 'budgets_page.dart';
import 'accounts_page.dart';
import 'categories_page.dart';

class HomeScreen extends StatefulWidget {
  final int initialIndex;

  const HomeScreen({super.key, this.initialIndex = 0});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late int currentIndex;
  final GlobalKey<AnalysisPageState> analysisPageKey = GlobalKey<AnalysisPageState>();

  late final List<Widget> pages = [
    RecordsPage(),
    AnalysisPage(key: analysisPageKey),
    BudgetsPage(),
    AccountsPage(),
    CategoriesPage(),
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
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'FinTrack',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        leading: PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert),
          position: PopupMenuPosition.under,
          onSelected: (value) {
            switch (value) {
              case 'load_messages':
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const LoadExpensesFromMessagesPage()),
                );
                break;
              case 'analysis_selected_month':
                analysisPageKey.currentState?.changeMode(AnalysisMode.selectedMonth);
                break;
              case 'analysis_cumulative_month':
                analysisPageKey.currentState?.changeMode(AnalysisMode.cumulativeToSelectedMonth);
                break;
              case 'analysis_cumulative_year':
                analysisPageKey.currentState?.changeMode(AnalysisMode.cumulativeYear);
                break;
            }
          },
          itemBuilder: (context) {
            final isAnalysisTab = currentIndex == 1;

            return [
              const PopupMenuItem<String>(
                value: 'load_messages',
                child: Text('Load expense from messages'),
              ),
              if (isAnalysisTab) const PopupMenuDivider(),
              if (isAnalysisTab)
                const PopupMenuItem<String>(
                  value: 'analysis_selected_month',
                  child: Text('Selected month analysis'),
                ),
              if (isAnalysisTab)
                const PopupMenuItem<String>(
                  value: 'analysis_cumulative_month',
                  child: Text('Cumulative till selected month'),
                ),
              if (isAnalysisTab)
                const PopupMenuItem<String>(
                  value: 'analysis_cumulative_year',
                  child: Text('Cumulative full year'),
                ),
            ];
          },
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
            ],
          ),
        ),
      ),
    );
  }
}
