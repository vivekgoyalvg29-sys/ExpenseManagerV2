import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../utils/indian_number_formatter.dart';
import '../widgets/section_tile.dart';
import '../services/data_store.dart';
import 'load_expenses_from_messages_page.dart';

class SmsPage extends StatefulWidget {
  const SmsPage({super.key});

  @override
  State<SmsPage> createState() => _SmsPageState();
}

class _SmsPageState extends State<SmsPage> {
  int _seenVersion = -1;
  List<Map<String, dynamic>> _transactions = [];

  bool _selectionMode = false;
  final Set<String> _selectedTransactionKeys = <String>{};
  final Set<String> _collapsedMonths = <String>{};

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

    _selectedTransactionKeys.clear();
    _selectionMode = false;

    final availableMonths = _monthGroups.keys.toSet();
    _collapsedMonths.removeWhere((monthKey) => !availableMonths.contains(monthKey));
  }

  String _monthKey(DateTime date) => '${date.year}-${date.month.toString().padLeft(2, '0')}';

  String _transactionKey(Map<String, dynamic> tx, int index) {
    final date = tx['date'] as DateTime;
    return '$index-${date.millisecondsSinceEpoch}-${tx['title']}-${tx['amount']}';
  }

  Map<String, List<MapEntry<int, Map<String, dynamic>>>> get _monthGroups {
    final grouped = <String, List<MapEntry<int, Map<String, dynamic>>>>{};

    for (final entry in _transactions.asMap().entries) {
      final tx = entry.value;
      final date = tx['date'] as DateTime;
      final key = _monthKey(date);
      grouped.putIfAbsent(key, () => []).add(entry);
    }

    return grouped;
  }

  void _clearSelection() {
    setState(() {
      _selectedTransactionKeys.clear();
      _selectionMode = false;
    });
  }

  void _deleteSelected() {
    if (_selectedTransactionKeys.isEmpty) return;

    final updated = <Map<String, dynamic>>[];

    for (final entry in _transactions.asMap().entries) {
      final key = _transactionKey(entry.value, entry.key);
      if (!_selectedTransactionKeys.contains(key)) {
        updated.add(entry.value);
      }
    }

    DataStore.replaceSmsTransactions(updated);

    setState(() {
      _selectionMode = false;
      _selectedTransactionKeys.clear();
      _seenVersion = -1;
      _refreshIfChanged();
    });
  }

  void _toggleMonth(String monthKey) {
    setState(() {
      if (_collapsedMonths.contains(monthKey)) {
        _collapsedMonths.remove(monthKey);
      } else {
        _collapsedMonths.add(monthKey);
      }
    });
  }

  void _toggleAllMonths(List<String> monthKeys) {
    setState(() {
      final allCollapsed = _collapsedMonths.length == monthKeys.length && monthKeys.isNotEmpty;
      if (allCollapsed) {
        _collapsedMonths.clear();
      } else {
        _collapsedMonths
          ..clear()
          ..addAll(monthKeys);
      }
    });
  }

  Future<void> _loadFromMessages() async {
    final loaded = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const LoadExpensesFromMessagesPage()),
    );

    if (loaded == true && mounted) {
      setState(() {
        _seenVersion = -1;
        _refreshIfChanged();
      });
    }
  }

  void _clearLoadedTransactions() {
    DataStore.replaceSmsTransactions([]);
    setState(() {
      _seenVersion = -1;
      _refreshIfChanged();
    });
  }

  @override
  Widget build(BuildContext context) {
    _refreshIfChanged();

    final grouped = _monthGroups;
    final monthKeys = grouped.keys.toList()..sort((a, b) => b.compareTo(a));
    final allCollapsed = monthKeys.isNotEmpty && _collapsedMonths.length == monthKeys.length;

    return Scaffold(
      backgroundColor: const Color(0xFFF3F5F9),
      floatingActionButton: _selectionMode
          ? Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                FloatingActionButton.small(
                  heroTag: 'cancelSmsSelection',
                  onPressed: _clearSelection,
                  tooltip: 'Cancel selection',
                  child: const Icon(Icons.close),
                ),
                const SizedBox(height: 10),
                FloatingActionButton.extended(
                  heroTag: 'deleteSelectedSms',
                  onPressed: _deleteSelected,
                  icon: const Icon(Icons.delete),
                  label: Text('Delete (${_selectedTransactionKeys.length})'),
                ),
              ],
            )
          : null,
      body: Column(
        children: [
          Expanded(
            child: SectionTile(
              child: _transactions.isEmpty
                  ? Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.sms_failed_outlined,
                              size: 72,
                              color: Colors.black38,
                            ),
                            SizedBox(height: 14),
                            Text(
                              'No transactions loaded yet',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Load transactions from SMSs to see them here.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.black54),
                            ),
                            SizedBox(height: 16),
                            FilledButton.icon(
                              onPressed: _loadFromMessages,
                              icon: Icon(Icons.sms),
                              label: Text('Load expense from messages'),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 2),
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              FilledButton.icon(
                                onPressed: _loadFromMessages,
                                icon: const Icon(Icons.sms),
                                label: const Text('Load expense from messages'),
                              ),
                              OutlinedButton.icon(
                                onPressed: _clearLoadedTransactions,
                                icon: const Icon(Icons.delete_outline),
                                label: const Text('Clear loaded transactions'),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                          color: Colors.grey.shade50,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'All months',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                              ),
                              TextButton(
                                onPressed: () => _toggleAllMonths(monthKeys),
                                child: Text(
                                  allCollapsed ? 'Expand all months' : 'Collapse all months',
                                ),
                              ),
                            ],
                          ),
                        ),
                        ..._buildMonthSections(grouped, monthKeys),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildMonthSections(
    Map<String, List<MapEntry<int, Map<String, dynamic>>>> grouped,
    List<String> keys,
  ) {
    final widgets = <Widget>[];

    for (final key in keys) {
      final monthItems = grouped[key]!;
      final firstDate = monthItems.first.value['date'] as DateTime;
      final monthTotal = monthItems.fold<double>(
        0,
        (sum, entry) => sum + (entry.value['amount'] as num).toDouble(),
      );
      final isCollapsed = _collapsedMonths.contains(key);

      widgets.add(
        Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
          color: Colors.grey.shade100,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    DateFormat('MMMM yyyy').format(firstDate),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  Text(
                    formatIndianCurrency(monthTotal, decimalDigits: 2),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.red,
                    ),
                  ),
                ],
              ),
              TextButton(
                onPressed: () => _toggleMonth(key),
                child: Text(isCollapsed ? 'Expand month' : 'Collapse month'),
              ),
            ],
          ),
        ),
      );

      if (isCollapsed) {
        widgets.add(const Divider(height: 1));
        continue;
      }

      for (final entry in monthItems) {
        final tx = entry.value;
        final date = tx['date'] as DateTime;
        final txKey = _transactionKey(tx, entry.key);

        widgets.add(
          ListTile(
            leading: _selectionMode
                ? Checkbox(
                    value: _selectedTransactionKeys.contains(txKey),
                    onChanged: (selected) {
                      setState(() {
                        if (selected == true) {
                          _selectedTransactionKeys.add(txKey);
                        } else {
                          _selectedTransactionKeys.remove(txKey);
                          if (_selectedTransactionKeys.isEmpty) {
                            _selectionMode = false;
                          }
                        }
                      });
                    },
                  )
                : const CircleAvatar(child: Icon(Icons.sms)),
            title: Text(tx['title'].toString()),
            subtitle: Text(DateFormat('dd MMM yyyy').format(date)),
            trailing: Text(
              formatIndianCurrency((tx['amount'] as num).toDouble(), decimalDigits: 2),
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
            ),
            onLongPress: () {
              setState(() {
                _selectionMode = true;
                _selectedTransactionKeys.add(txKey);
              });
            },
            onTap: () {
              if (!_selectionMode) return;
              setState(() {
                if (_selectedTransactionKeys.contains(txKey)) {
                  _selectedTransactionKeys.remove(txKey);
                } else {
                  _selectedTransactionKeys.add(txKey);
                }

                if (_selectedTransactionKeys.isEmpty) {
                  _selectionMode = false;
                }
              });
            },
          ),
        );
        widgets.add(const Divider(height: 1));
      }
    }

    return widgets;
  }
}
