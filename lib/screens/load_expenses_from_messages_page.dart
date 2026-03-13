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
  bool isRangeMode = false;
  bool isLoading = false;

  DateTime singleDate = DateTime.now();
  DateTime rangeStartDate = DateTime.now();
  DateTime rangeEndDate = DateTime.now();

  Future<void> _pickDate({required bool isStart, required bool single}) async {
    final initialDate = single ? singleDate : (isStart ? rangeStartDate : rangeEndDate);

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
      if (single) {
        singleDate = picked;
      } else if (isStart) {
        rangeStartDate = picked;
        if (rangeStartDate.isAfter(rangeEndDate)) {
          rangeEndDate = picked;
        }
      } else {
        rangeEndDate = DateTime(picked.year, picked.month, picked.day, 23, 59, 59);
        if (rangeEndDate.isBefore(rangeStartDate)) {
          rangeStartDate = picked;
        }
      }
    });
  }

  Future<void> _loadExpenses() async {
    final start = isRangeMode
        ? DateTime(rangeStartDate.year, rangeStartDate.month, rangeStartDate.day)
        : DateTime(singleDate.year, singleDate.month, singleDate.day);
    final end = isRangeMode
        ? DateTime(rangeEndDate.year, rangeEndDate.month, rangeEndDate.day, 23, 59, 59)
        : DateTime(singleDate.year, singleDate.month, singleDate.day, 23, 59, 59);

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
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, label: Text('One month')),
                ButtonSegment(value: true, label: Text('Range of months')),
              ],
              selected: {isRangeMode},
              onSelectionChanged: (selection) {
                setState(() => isRangeMode = selection.first);
              },
            ),
            const SizedBox(height: 18),
            if (!isRangeMode)
              Column(
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Date'),
                    subtitle: Text(DateFormat('dd MMM yyyy').format(singleDate)),
                    trailing: const Icon(Icons.calendar_month),
                    onTap: () => _pickDate(isStart: true, single: true),
                  ),
                ],
              )
            else ...[
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Start date'),
                subtitle: Text(DateFormat('dd MMM yyyy').format(rangeStartDate)),
                trailing: const Icon(Icons.calendar_month),
                onTap: () => _pickDate(isStart: true, single: false),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('End date'),
                subtitle: Text(DateFormat('dd MMM yyyy').format(rangeEndDate)),
                trailing: const Icon(Icons.calendar_month),
                onTap: () => _pickDate(isStart: false, single: false),
              ),
            ],
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
