import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'database_helper.dart';
import 'models.dart';

void main() {
  runApp(const ExpenseApp());
}

class ExpenseApp extends StatelessWidget {

  const ExpenseApp({super.key});

  @override
  Widget build(BuildContext context) {

    return MaterialApp(
      title: "Expense Manager",
      theme: ThemeData(
        primarySwatch: Colors.indigo,
      ),
      debugShowCheckedModeBanner: false,
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {

  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {

  int index = 0;

  DateTime month = DateTime.now();

  DBHelper dbHelper = DBHelper();

  void changeMonth(int dir) {

    setState(() {
      month = DateTime(month.year, month.month + dir);
    });

  }

  @override
  Widget build(BuildContext context) {

    List pages = [
      const Center(child: Text("Transactions UI")),
      const Center(child: Text("Categories UI")),
      const Center(child: Text("Budget UI")),
      const Center(child: Text("Analysis UI"))
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text("Expense Manager"),
        actions: [

          IconButton(
              icon: const Icon(Icons.arrow_left),
              onPressed: () => changeMonth(-1)),

          Center(child: Text(DateFormat("MMM yyyy").format(month))),

          IconButton(
              icon: const Icon(Icons.arrow_right),
              onPressed: () => changeMonth(1))
        ],
      ),

      body: pages[index],

      bottomNavigationBar: BottomNavigationBar(
        currentIndex: index,
        onTap: (i) {

          setState(() {
            index = i;
          });

        },
        items: const [

          BottomNavigationBarItem(
              icon: Icon(Icons.list),
              label: "Transactions"),

          BottomNavigationBarItem(
              icon: Icon(Icons.category),
              label: "Categories"),

          BottomNavigationBarItem(
              icon: Icon(Icons.account_balance),
              label: "Budget"),

          BottomNavigationBarItem(
              icon: Icon(Icons.pie_chart),
              label: "Analysis"),
        ],
      ),

      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () {},
      ),
    );
  }
}
