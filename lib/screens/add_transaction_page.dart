import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/data_store.dart';

class AddTransactionPage extends StatefulWidget {

  final Map<String, dynamic>? existingTransaction;

  AddTransactionPage({this.existingTransaction});

  @override
  _AddTransactionPageState createState() => _AddTransactionPageState();
}
  @override
  _AddTransactionPageState createState() => _AddTransactionPageState();
}

class _AddTransactionPageState extends State<AddTransactionPage> {

  DateTime selectedDate = DateTime.now();

  final commentController = TextEditingController();
  final amountController = TextEditingController();

  String transactionType = "expense";
  String? selectedAccount;
  String? selectedCategory;

  Future<void> pickDate() async {

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      setState(() {
        selectedDate = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {

    // Filter accounts based on transaction type
    final filteredAccounts = DataStore.accounts
        .where((acc) => acc["type"] == transactionType)
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: Text("Add Transaction"),
      ),

      body: Padding(
        padding: const EdgeInsets.all(16),

        child: SingleChildScrollView(
          child: Column(
            children: [

              DropdownButtonFormField<String>(
                value: transactionType,
                items: const [
                  DropdownMenuItem(child: Text("Expense"), value: "expense"),
                  DropdownMenuItem(child: Text("Income"), value: "income"),
                ],
                onChanged: (v) {
                  setState(() {
                    transactionType = v!;
                    selectedCategory = null;
                    selectedAccount = null;
                  });
                },
                decoration: InputDecoration(labelText: "Type"),
              ),

              const SizedBox(height: 10),

              DropdownButtonFormField<String>(
                value: selectedAccount,
                items: filteredAccounts
                    .map((acc) => DropdownMenuItem<String>(
                        value: acc["name"],
                        child: Text(acc["name"]!)))
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    selectedAccount = value;
                  });
                },
                decoration: InputDecoration(labelText: "Account"),
              ),

              const SizedBox(height: 10),

              DropdownButtonFormField<String>(
                value: selectedCategory,
                items: DataStore.categories
                    .where((cat) => cat["type"] == transactionType)
                    .map((cat) => DropdownMenuItem<String>(
                        value: cat["name"],
                        child: Text(cat["name"]!)))
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    selectedCategory = value;
                  });
                },
                decoration: InputDecoration(labelText: "Category"),
              ),

              const SizedBox(height: 10),

              TextField(
                controller: commentController,
                decoration: InputDecoration(labelText: "Comments"),
              ),

              const SizedBox(height: 10),

              TextField(
                controller: amountController,
                decoration: InputDecoration(labelText: "Amount"),
                keyboardType: TextInputType.number,
              ),

              const SizedBox(height: 20),

              ListTile(
                title: Text("Date"),
                subtitle: Text(
                  DateFormat('dd MMM yyyy').format(selectedDate),
                ),
                trailing: Icon(Icons.calendar_today),
                onTap: pickDate,
              ),

              const SizedBox(height: 20),

              ElevatedButton(
                onPressed: () {

                  if (selectedAccount == null ||
                      selectedCategory == null ||
                      amountController.text.isEmpty) {
                    return;
                  }

                  final amount = double.tryParse(amountController.text) ?? 0;

                  Navigator.pop(context, {
                    "title": selectedCategory,
                    "amount": amount,
                    "date": selectedDate
                  });

                },
                child: Text("Save"),
              )

            ],
          ),
        ),
      ),
    );
  }
}
