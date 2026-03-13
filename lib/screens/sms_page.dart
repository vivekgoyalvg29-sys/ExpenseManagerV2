import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/data_store.dart';
import '../widgets/section_tile.dart';

class SmsPage extends StatefulWidget {
  const SmsPage({super.key});

  @override
  State<SmsPage> createState() => _SmsPageState();
}

class _SmsPageState extends State<SmsPage> {
  int _seenVersion = -1;
  List<Map<String, dynamic>> _transactions = [];

  @override
  void initState() {
    super.initState();
    _refreshIfChanged();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _refreshIfChanged();
  }

  void _refreshIfChanged() {
    if (_seenVersion == DataStore.smsTransactionsVersion) {
      return;
    }

    _seenVersion = DataStore.smsTransactionsVersion;
    _transactions = List<Map<String, dynamic>>.from(DataStore.smsTransactions)
      ..sort((a, b) => (b['date'] as DateTime).compareTo(a['date'] as DateTime));
  }

  @override
  Widget build(BuildContext context) {
    _refreshIfChanged();

    return Scaffold(
      backgroundColor: const Color(0xFFF3F5F9),
      body: SectionTile(
        child: _transactions.isEmpty
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'No SMS expenses loaded. Use “Load expense from messages” to generate records.',
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            : ListView(
                children: _buildMonthSections(),
              ),
      ),
    );
  }

  List<Widget> _buildMonthSections() {
    final grouped = <String, List<Map<String, dynamic>>>{};

    for (final tx in _transactions) {
      final date = tx['date'] as DateTime;
      final key = '${date.year}-${date.month.toString().padLeft(2, '0')}';
      grouped.putIfAbsent(key, () => []).add(tx);
    }

    final keys = grouped.keys.toList()
      ..sort((a, b) => b.compareTo(a));

    final widgets = <Widget>[];

    for (final key in keys) {
      final monthItems = grouped[key]!;
      final firstDate = monthItems.first['date'] as DateTime;
      final monthTotal = monthItems.fold<double>(
        0,
        (sum, tx) => sum + (tx['amount'] as num).toDouble(),
      );

      widgets.add(
        Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
          color: Colors.grey.shade100,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                DateFormat('MMMM yyyy').format(firstDate),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              Text(
                '₹${monthTotal.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Colors.red,
                ),
              ),
            ],
          ),
        ),
      );

      for (final tx in monthItems) {
        final date = tx['date'] as DateTime;

        widgets.add(
          ListTile(
            leading: const CircleAvatar(child: Icon(Icons.sms)),
            title: Text(tx['title'].toString()),
            subtitle: Text(DateFormat('dd MMM yyyy').format(date)),
            trailing: Text(
              '₹${(tx['amount'] as num).toStringAsFixed(2)}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
            ),
          ),
        );
        widgets.add(const Divider(height: 1));
      }
    }

    return widgets;
  }
}
