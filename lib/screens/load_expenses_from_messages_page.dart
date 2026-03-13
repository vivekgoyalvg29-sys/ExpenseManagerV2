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

  DateTime singleMonth = DateTime(DateTime.now().year, DateTime.now().month);
  late DateTime singleStartDate = _firstDayOfMonth(singleMonth);
  late DateTime singleEndDate = _lastDayOfMonth(singleMonth);

  DateTime rangeStart = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime rangeEnd = DateTime(DateTime.now().year, DateTime.now().month);
  late DateTime rangeStartDate = _firstDayOfMonth(rangeStart);
  late DateTime rangeEndDate = _lastDayOfMonth(rangeEnd);

  static DateTime _firstDayOfMonth(DateTime month) => DateTime(month.year, month.month, 1);

  static DateTime _lastDayOfMonth(DateTime month) =>
      DateTime(month.year, month.month + 1, 0, 23, 59, 59);

  static DateTime _clampDateToMonth(DateTime date, DateTime month) {
    final lastDay = DateTime(month.year, month.month + 1, 0).day;
    final clampedDay = date.day > lastDay ? lastDay : date.day;

    return DateTime(
      month.year,
      month.month,
      clampedDay,
      date.hour,
      date.minute,
      date.second,
    );
  }

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
        singleStartDate = _firstDayOfMonth(selected);
        singleEndDate = _lastDayOfMonth(selected);
      } else if (isStart) {
        rangeStart = selected;
        if (rangeStart.isAfter(rangeEnd)) {
          rangeEnd = rangeStart;
        }
        rangeStartDate = _clampDateToMonth(rangeStartDate, rangeStart);
        rangeEndDate = _clampDateToMonth(rangeEndDate, rangeEnd);
      } else {
        rangeEnd = selected;
        if (rangeEnd.isBefore(rangeStart)) {
          rangeStart = rangeEnd;
        }
        rangeStartDate = _clampDateToMonth(rangeStartDate, rangeStart);
        rangeEndDate = _clampDateToMonth(rangeEndDate, rangeEnd);
      }

      if (rangeStartDate.isAfter(rangeEndDate)) {
        rangeStartDate = _firstDayOfMonth(rangeStart);
        rangeEndDate = _lastDayOfMonth(rangeEnd);
      }
    });
  }

  Future<void> _pickDate({required bool isStart, required bool single}) async {
    final selectedDate = single
        ? (isStart ? singleStartDate : singleEndDate)
        : (isStart ? rangeStartDate : rangeEndDate);
    final currentMonth = single
        ? singleMonth
        : (isStart ? rangeStart : rangeEnd);

    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(currentMonth.year, currentMonth.month, 1),
      lastDate: DateTime(currentMonth.year, currentMonth.month + 1, 0),
      helpText: 'Select date',
    );

    if (picked == null) return;

    setState(() {
      if (single) {
        if (isStart) {
          singleStartDate = DateTime(picked.year, picked.month, picked.day);
          if (singleStartDate.isAfter(singleEndDate)) {
            singleEndDate = DateTime(picked.year, picked.month, picked.day, 23, 59, 59);
          }
        } else {
          singleEndDate = DateTime(picked.year, picked.month, picked.day, 23, 59, 59);
          if (singleEndDate.isBefore(singleStartDate)) {
            singleStartDate = DateTime(picked.year, picked.month, picked.day);
          }
        }
      } else {
        if (isStart) {
          rangeStartDate = DateTime(picked.year, picked.month, picked.day);
          if (rangeStartDate.isAfter(rangeEndDate)) {
            rangeEndDate = DateTime(picked.year, picked.month, picked.day, 23, 59, 59);
          }
        } else {
          rangeEndDate = DateTime(picked.year, picked.month, picked.day, 23, 59, 59);
          if (rangeEndDate.isBefore(rangeStartDate)) {
            rangeStartDate = DateTime(picked.year, picked.month, picked.day);
          }
        }
      }
    });
  }

  Future<void> _loadExpenses() async {
    final start = isRangeMode ? rangeStartDate : singleStartDate;
    final end = isRangeMode ? rangeEndDate : singleEndDate;

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
                    title: const Text('Month'),
                    subtitle: Text(DateFormat('MMMM yyyy').format(singleMonth)),
                    trailing: const Icon(Icons.calendar_month),
                    onTap: () => _pickMonth(isStart: true, single: true),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('From date'),
                    subtitle: Text(DateFormat('dd MMM yyyy').format(singleStartDate)),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () => _pickDate(isStart: true, single: true),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('To date'),
                    subtitle: Text(DateFormat('dd MMM yyyy').format(singleEndDate)),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () => _pickDate(isStart: false, single: true),
                  ),
                ],
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
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('From date'),
                subtitle: Text(DateFormat('dd MMM yyyy').format(rangeStartDate)),
                trailing: const Icon(Icons.calendar_today),
                onTap: () => _pickDate(isStart: true, single: false),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('To date'),
                subtitle: Text(DateFormat('dd MMM yyyy').format(rangeEndDate)),
                trailing: const Icon(Icons.calendar_today),
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
