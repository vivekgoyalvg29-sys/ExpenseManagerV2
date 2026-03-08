import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

void main() {
  runApp(const ExpenseApp());
}

class ExpenseApp extends StatelessWidget {
  const ExpenseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "Expense Manager",
      theme: ThemeData(primarySwatch: Colors.indigo),
      debugShowCheckedModeBanner: false,
      home: const HomePage(),
    );
  }
}

class TransactionModel {
  String type;
  String account;
  String category;
  String comment;
  double amount;
  DateTime date;

  TransactionModel({
    required this.type,
    required this.account,
    required this.category,
    required this.comment,
    required this.amount,
    required this.date,
  });
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {

  int index = 0;

  DateTime selectedMonth = DateTime.now();

  List<String> accounts = ["Cash"];

  List<String> expenseCategories = ["Food"];

  List<String> incomeCategories = ["Salary"];

  List<TransactionModel> transactions = [];

  void changeMonth(int dir) {
    setState(() {
      selectedMonth = DateTime(
          selectedMonth.year, selectedMonth.month + dir);
    });
  }

  void addAccount(String name) {
    setState(() {
      accounts.add(name);
    });
  }

  void addCategory(String name, String type) {
    setState(() {
      if (type == "Expense") {
        expenseCategories.add(name);
      } else {
        incomeCategories.add(name);
      }
    });
  }

  void addTransaction(TransactionModel tx) {
    setState(() {
      transactions.add(tx);
    });
  }

  @override
  Widget build(BuildContext context) {

    List pages = [

      TransactionsPage(transactions, selectedMonth),

      AccountsPage(accounts, addAccount),

      CategoriesPage(
          expenseCategories,
          incomeCategories,
          addCategory),

      const BudgetsPage(),

      AnalysisPage(transactions, selectedMonth)
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text("Expense Manager"),
        actions: [
          IconButton(
              icon: const Icon(Icons.arrow_left),
              onPressed: () => changeMonth(-1)),
          Center(
              child: Text(
                  DateFormat("MMM yyyy").format(selectedMonth))),
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
              icon: Icon(Icons.account_balance_wallet),
              label: "Accounts"),
          BottomNavigationBarItem(
              icon: Icon(Icons.category),
              label: "Categories"),
          BottomNavigationBarItem(
              icon: Icon(Icons.account_balance),
              label: "Budgets"),
          BottomNavigationBarItem(
              icon: Icon(Icons.pie_chart),
              label: "Analysis"),
        ],
      ),

      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () async {

          final tx = await Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => AddTransactionPage(
                        accounts,
                        expenseCategories,
                        incomeCategories,
                      )));

          if (tx != null) {
            addTransaction(tx);
          }
        },
      ),
    );
  }
}

class TransactionsPage extends StatelessWidget {

  final List<TransactionModel> transactions;
  final DateTime month;

  const TransactionsPage(this.transactions, this.month, {super.key});

  @override
  Widget build(BuildContext context) {

    final filtered = transactions.where((tx) =>
        tx.date.month == month.month &&
        tx.date.year == month.year).toList();

    if (filtered.isEmpty) {
      return const Center(child: Text("No transactions"));
    }

    return ListView.builder(
      itemCount: filtered.length,
      itemBuilder: (context, i) {

        final tx = filtered[i];

        return ListTile(
          title: Text(tx.category),
          subtitle: Text(tx.comment),
          trailing: Text("₹${tx.amount}"),
        );
      },
    );
  }
}

class AccountsPage extends StatelessWidget {

  final List<String> accounts;
  final Function addAccount;

  const AccountsPage(this.accounts, this.addAccount, {super.key});

  @override
  Widget build(BuildContext context) {

    TextEditingController controller = TextEditingController();

    return Column(
      children: [

        Expanded(
          child: ListView(
            children: accounts
                .map((e) => ListTile(title: Text(e)))
                .toList(),
          ),
        ),

        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [

              Expanded(
                child: TextField(
                  controller: controller,
                  decoration:
                      const InputDecoration(labelText: "New Account"),
                ),
              ),

              IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () {
                    addAccount(controller.text);
                    controller.clear();
                  })
            ],
          ),
        )
      ],
    );
  }
}

class CategoriesPage extends StatelessWidget {

  final List<String> expense;
  final List<String> income;
  final Function addCategory;

  const CategoriesPage(
      this.expense,
      this.income,
      this.addCategory,
      {super.key});

  @override
  Widget build(BuildContext context) {

    TextEditingController controller = TextEditingController();

    String type = "Expense";

    return Column(
      children: [

        Expanded(
          child: ListView(
            children: [

              const ListTile(title: Text("Expense Categories")),
              ...expense.map((e) => ListTile(title: Text(e))),

              const ListTile(title: Text("Income Categories")),
              ...income.map((e) => ListTile(title: Text(e)))
            ],
          ),
        ),

        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [

              DropdownButtonFormField(
                value: type,
                items: const [
                  DropdownMenuItem(
                      value: "Expense", child: Text("Expense")),
                  DropdownMenuItem(
                      value: "Income", child: Text("Income")),
                ],
                onChanged: (v) {
                  type = v.toString();
                },
              ),

              TextField(
                controller: controller,
                decoration: const InputDecoration(
                    labelText: "New Category"),
              ),

              ElevatedButton(
                  onPressed: () {
                    addCategory(controller.text, type);
                    controller.clear();
                  },
                  child: const Text("Add Category"))
            ],
          ),
        )
      ],
    );
  }
}

class BudgetsPage extends StatelessWidget {
  const BudgetsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
        child: Text("Budget feature coming next"));
  }
}

class AnalysisPage extends StatelessWidget {

  final List<TransactionModel> transactions;
  final DateTime month;

  const AnalysisPage(this.transactions, this.month, {super.key});

  @override
  Widget build(BuildContext context) {

    double income = 0;
    double expense = 0;

    for (var tx in transactions) {
      if (tx.date.month == month.month &&
          tx.date.year == month.year) {

        if (tx.type == "Income") {
          income += tx.amount;
        } else {
          expense += tx.amount;
        }
      }
    }

    return Column(
      children: [

        ListTile(
            title: const Text("Income"),
            trailing: Text("₹$income")),

        ListTile(
            title: const Text("Expense"),
            trailing: Text("₹$expense"))
      ],
    );
  }
}

class AddTransactionPage extends StatefulWidget {

  final List<String> accounts;
  final List<String> expenseCategories;
  final List<String> incomeCategories;

  const AddTransactionPage(
      this.accounts,
      this.expenseCategories,
      this.incomeCategories,
      {super.key});

  @override
  State<AddTransactionPage> createState() =>
      _AddTransactionPageState();
}

class _AddTransactionPageState
    extends State<AddTransactionPage> {

  String type = "Expense";
  String? account;
  String? category;

  final commentController = TextEditingController();
  final amountController = TextEditingController();

  @override
  Widget build(BuildContext context) {

    List categories = type == "Expense"
        ? widget.expenseCategories
        : widget.incomeCategories;

    return Scaffold(
      appBar: AppBar(title: const Text("Add Transaction")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [

            DropdownButtonFormField(
              value: type,
              items: const [
                DropdownMenuItem(
                    value: "Expense", child: Text("Expense")),
                DropdownMenuItem(
                    value: "Income", child: Text("Income")),
              ],
              onChanged: (v) {
                setState(() {
                  type = v.toString();
                });
              },
            ),

            DropdownButtonFormField(
              items: widget.accounts
                  .map((e) =>
                      DropdownMenuItem(value: e, child: Text(e)))
                  .toList(),
              onChanged: (v) {
                account = v.toString();
              },
              decoration:
                  const InputDecoration(labelText: "Account"),
            ),

            DropdownButtonFormField(
              items: categories
                  .map((e) =>
                      DropdownMenuItem(value: e, child: Text(e)))
                  .toList(),
              onChanged: (v) {
                category = v.toString();
              },
              decoration:
                  const InputDecoration(labelText: "Category"),
            ),

            TextField(
              controller: commentController,
              decoration:
                  const InputDecoration(labelText: "Comments"),
            ),

            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              decoration:
                  const InputDecoration(labelText: "Amount"),
            ),

            const SizedBox(height: 20),

            ElevatedButton(
                onPressed: () {

                  final tx = TransactionModel(
                      type: type,
                      account: account ?? "",
                      category: category ?? "",
                      comment: commentController.text,
                      amount: double.parse(
                          amountController.text),
                      date: DateTime.now());

                  Navigator.pop(context, tx);
                },
                child: const Text("Save"))
          ],
        ),
      ),
    );
  }
}
