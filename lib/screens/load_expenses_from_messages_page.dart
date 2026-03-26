import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/message_expense_service.dart';
import '../services/data_store.dart';

class LoadExpensesFromMessagesPage extends StatefulWidget {
  const LoadExpensesFromMessagesPage({super.key});

  @override
  State<LoadExpensesFromMessagesPage> createState() => _LoadExpensesFromMessagesPageState();
}

class _LoadExpensesFromMessagesPageState extends State<LoadExpensesFromMessagesPage> {
  bool isLoading = false;

  late DateTime startDate;
  late DateTime endDate;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    startDate = DateTime(now.year, now.month, 1);
    endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
  }

  Future<void> _pickDate({required bool isStart}) async {
    final initialDate = isStart ? startDate : endDate;

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020, 1),
      lastDate: DateTime(2100, 12),
      initialDatePickerMode: DatePickerMode.day,
      helpText: 'Select date',
    );

    if (picked == null) return;

    setState(() {
      if (isStart) {
        startDate = picked;
        if (startDate.isAfter(endDate)) {
          endDate = DateTime(picked.year, picked.month, picked.day, 23, 59, 59);
        }
      } else {
        endDate = DateTime(picked.year, picked.month, picked.day, 23, 59, 59);
        if (endDate.isBefore(startDate)) {
          startDate = picked;
        }
      }
    });
  }

  Future<void> _loadExpenses() async {
    final start = DateTime(startDate.year, startDate.month, startDate.day);
    final end = DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59);

    setState(() => isLoading = true);

    try {
      final expenses = await MessageExpenseService.fetchExpensesFromMessages(start: start, end: end);
      DataStore.replaceSmsTransactions(expenses);

      if (!mounted) return;
      Navigator.pop(context, true);
    } on MessageExpenseException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Load expense from messages'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Start date'),
              subtitle: Text(DateFormat('dd MMM yyyy').format(startDate)),
              trailing: const Icon(Icons.calendar_month),
              onTap: () => _pickDate(isStart: true),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('End date'),
              subtitle: Text(DateFormat('dd MMM yyyy').format(endDate)),
              trailing: const Icon(Icons.calendar_month),
              onTap: () => _pickDate(isStart: false),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isLoading ? null : _loadExpenses,
                child: isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('OK'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
