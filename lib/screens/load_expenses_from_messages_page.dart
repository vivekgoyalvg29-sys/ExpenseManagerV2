import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/message_expense_service.dart';

class LoadExpensesFromMessagesPage extends StatefulWidget {
  const LoadExpensesFromMessagesPage({super.key});

  @override
  State<LoadExpensesFromMessagesPage> createState() => _LoadExpensesFromMessagesPageState();
}

class _LoadExpensesFromMessagesPageState extends State<LoadExpensesFromMessagesPage> {
  bool isRangeMode = false;
  bool isLoading = false;

  DateTime singleMonth = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime rangeStart = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime rangeEnd = DateTime(DateTime.now().year, DateTime.now().month);

  Future<void> _pickMonth({required bool isStart, bool single = false}) async {
    final initialDate = single ? singleMonth : (isStart ? rangeStart : rangeEnd);

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020, 1),
      lastDate: DateTime(2100, 12),
      initialDatePickerMode: DatePickerMode.year,
      helpText: 'Select month and year',
    );

    if (picked == null) return;

    setState(() {
      final selected = DateTime(picked.year, picked.month);
      if (single) {
        singleMonth = selected;
      } else if (isStart) {
        rangeStart = selected;
        if (rangeStart.isAfter(rangeEnd)) {
          rangeEnd = rangeStart;
        }
      } else {
        rangeEnd = selected;
        if (rangeEnd.isBefore(rangeStart)) {
          rangeStart = rangeEnd;
        }
      }
    });
  }

  Future<void> _loadExpenses() async {
    final start = isRangeMode
        ? DateTime(rangeStart.year, rangeStart.month, 1)
        : DateTime(singleMonth.year, singleMonth.month, 1);

    final end = isRangeMode
        ? DateTime(rangeEnd.year, rangeEnd.month + 1, 0, 23, 59, 59)
        : DateTime(singleMonth.year, singleMonth.month + 1, 0, 23, 59, 59);

    setState(() => isLoading = true);

    try {
      final expenses = await MessageExpenseService.fetchExpensesFromMessages(start: start, end: end);

      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => MessageExpenseResultsPage(
            expenses: expenses,
            rangeLabel: isRangeMode
                ? '${DateFormat('MMM yyyy').format(rangeStart)} - ${DateFormat('MMM yyyy').format(rangeEnd)}'
                : DateFormat('MMMM yyyy').format(singleMonth),
          ),
        ),
      );
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
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Month'),
                subtitle: Text(DateFormat('MMMM yyyy').format(singleMonth)),
                trailing: const Icon(Icons.calendar_month),
                onTap: () => _pickMonth(isStart: true, single: true),
              )
            else ...[
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Start month'),
                subtitle: Text(DateFormat('MMMM yyyy').format(rangeStart)),
                trailing: const Icon(Icons.calendar_month),
                onTap: () => _pickMonth(isStart: true),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('End month'),
                subtitle: Text(DateFormat('MMMM yyyy').format(rangeEnd)),
                trailing: const Icon(Icons.calendar_month),
                onTap: () => _pickMonth(isStart: false),
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

class MessageExpenseResultsPage extends StatelessWidget {
  final List<Map<String, dynamic>> expenses;
  final String rangeLabel;

  const MessageExpenseResultsPage({
    super.key,
    required this.expenses,
    required this.rangeLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Messages: $rangeLabel'),
        actions: [
          TextButton(
            onPressed: () => Navigator.popUntil(context, (route) => route.isFirst),
            child: const Text('Close', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: expenses.isEmpty
          ? const Center(child: Text('No expenses found in messages for selected range.'))
          : ListView.separated(
              itemCount: expenses.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final expense = expenses[index];
                final date = expense['date'] as DateTime;

                return ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.sms)),
                  title: Text(expense['title'].toString()),
                  subtitle: Text(DateFormat('dd MMM yyyy').format(date)),
                  trailing: Text(
                    '₹${(expense['amount'] as num).toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                  ),
                );
              },
            ),
    );
  }
}
