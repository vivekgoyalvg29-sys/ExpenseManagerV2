import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/data_store.dart';
import '../services/database_service.dart';

class AddTransactionPage extends StatefulWidget {
  final Map<String, dynamic>? existingTransaction;
  final Future<void> Function(Map<String, dynamic> result)? onSaveResult;
  const AddTransactionPage({
    super.key,
    this.existingTransaction,
    this.onSaveResult,
  });

  @override
  _AddTransactionPageState createState() => _AddTransactionPageState();
}

class _AddTransactionPageState extends State<AddTransactionPage> {
  DateTime selectedDate = DateTime.now();

  final commentController = TextEditingController();
  final amountController = TextEditingController();

  String transactionType = 'expense';
  String? selectedAccount;
  String? selectedCategory;

  @override
  void initState() {
    super.initState();
    _loadData();

    if (widget.existingTransaction != null) {
      commentController.text = widget.existingTransaction!['title'] ?? '';
      amountController.text = widget.existingTransaction!['amount'].toString();
      selectedDate = DateTime.parse(widget.existingTransaction!['date']);
      selectedCategory = widget.existingTransaction!['title'];
    }
  }

  Future<void> _loadData() async {
    final accounts = await DatabaseService.getAccounts();
    final categories = await DatabaseService.getCategories();

    setState(() {
      DataStore.accounts = accounts;
      DataStore.categories = categories;
    });
  }

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

  Future<void> _save() async {
    if (selectedAccount == null || selectedCategory == null || amountController.text.isEmpty) {
      return;
    }

    final amount = double.tryParse(amountController.text) ?? 0;
    final result = {
      'title': selectedCategory,
      'amount': amount,
      'date': selectedDate,
      'type': transactionType,
      'account': selectedAccount,
      'comments': commentController.text.trim(),
    };

    if (widget.onSaveResult != null) {
      await widget.onSaveResult!(result);
      return;
    }

    if (!mounted) {
      return;
    }

    Navigator.pop(context, result);
  }

  @override
  Widget build(BuildContext context) {
    final filteredAccounts = DataStore.accounts
        .where((acc) => acc['type'] == transactionType)
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existingTransaction == null ? 'Add Transaction' : 'Edit Transaction'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            children: [
              DropdownButtonFormField<String>(
                value: transactionType,
                items: const [
                  DropdownMenuItem(child: Text('Expense'), value: 'expense'),
                  DropdownMenuItem(child: Text('Income'), value: 'income'),
                ],
                onChanged: (v) {
                  setState(() {
                    transactionType = v!;
                    selectedCategory = null;
                    selectedAccount = null;
                  });
                },
                decoration: const InputDecoration(labelText: 'Type'),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: selectedAccount,
                items: filteredAccounts
                    .map(
                      (acc) => DropdownMenuItem<String>(
                        value: acc['name'],
                        child: Text(acc['name']),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    selectedAccount = value;
                  });
                },
                decoration: const InputDecoration(labelText: 'Account'),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: selectedCategory,
                items: DataStore.categories
                    .where((cat) => cat['type'] == transactionType)
                    .map(
                      (cat) => DropdownMenuItem<String>(
                        value: cat['name'],
                        child: Text(cat['name']),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    selectedCategory = value;
                  });
                },
                decoration: const InputDecoration(labelText: 'Category'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: commentController,
                decoration: const InputDecoration(labelText: 'Comments'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: amountController,
                decoration: const InputDecoration(labelText: 'Amount'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 20),
              ListTile(
                title: const Text('Date'),
                subtitle: Text(DateFormat('dd MMM yyyy').format(selectedDate)),
                trailing: const Icon(Icons.calendar_today),
                onTap: pickDate,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _save,
                child: const Text('Save'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
