import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/data_store.dart';
import '../services/database_service.dart';
import '../services/widget_sync_service.dart';
import '../utils/indian_number_formatter.dart';
import '../widgets/icon_utils.dart';
import '../widgets/month_summary.dart';
import '../widgets/page_content_layout.dart';
import '../widgets/section_tile.dart';

enum AnalysisMode {
  selectedMonth,
  cumulativeToSelectedMonth,
  cumulativeYear,
}

enum AnalysisType {
  category,
  account,
}

enum TransactionSortOrder {
  newestFirst,
  oldestFirst,
}

class AnalysisPage extends StatefulWidget {
  const AnalysisPage({super.key});

  @override
  State<AnalysisPage> createState() => _AnalysisPageState();
}

class _AnalysisPageState extends State<AnalysisPage> {
  DateTime currentMonth = DateTime.now();
  AnalysisMode analysisMode = AnalysisMode.selectedMonth;
  AnalysisType analysisType = AnalysisType.category;
  TransactionSortOrder transactionSortOrder = TransactionSortOrder.newestFirst;
  bool showPercentage = true;

  List<Map<String, dynamic>> analysisData = [];
  List<Map<String, dynamic>> transactions = [];
  List<Map<String, dynamic>> budgets = [];

  @override
  void initState() {
    super.initState();
    loadAnalysis();
  }

  Future<void> loadAnalysis() async {
    final tx = await DatabaseService.getTransactions();
    final budgetData = await DatabaseService.getBudgets();
    final categories = await DatabaseService.getCategories();
    final accounts = await DatabaseService.getAccounts();

    transactions = tx;
    budgets = budgetData;
    DataStore.categories = categories;
    DataStore.accounts = accounts;

    final filteredExpenses = _filteredExpenseTransactions();
    final totalExpense = filteredExpenses.fold<double>(
      0.0,
      (sum, transaction) => sum + (transaction['amount'] as num).toDouble(),
    );

    final groupedSpent = <String, double>{};
    final latestDates = <String, DateTime>{};

    for (final transaction in filteredExpenses) {
      final key = _analysisKeyForTransaction(transaction);
      if (key.isEmpty) {
        continue;
      }

      final amount = (transaction['amount'] as num).toDouble();
      final date = DateTime.parse(transaction['date'] as String);
      groupedSpent[key] = (groupedSpent[key] ?? 0) + amount;

      final previousLatest = latestDates[key];
      if (previousLatest == null || date.isAfter(previousLatest)) {
        latestDates[key] = date;
      }
    }

    final groupedBudget = <String, double>{};
    if (analysisType == AnalysisType.category) {
      for (final budgetData in budgets) {
        if (_isBudgetInActiveRange(budgetData)) {
          final category = (budgetData['category'] as String?)?.trim() ?? '';
          if (category.isEmpty) {
            continue;
          }

          final amount = (budgetData['amount'] as num).toDouble();
          groupedBudget[category] = (groupedBudget[category] ?? 0) + amount;
        }
      }
    }

    final activeKeys = analysisType == AnalysisType.category
        ? <String>{...groupedBudget.keys, ...groupedSpent.keys}
        : groupedSpent.keys.toSet();

    final result = activeKeys
        .map(
          (key) => {
            'label': key,
            'spent': groupedSpent[key] ?? 0.0,
            'budget': groupedBudget[key] ?? 0.0,
            'percentage': totalExpense == 0 ? 0 : (((groupedSpent[key] ?? 0.0) / totalExpense) * 100).round(),
            'latestDate': latestDates[key],
          },
        )
        .toList();

    result.sort((a, b) {
      final amountCompare = ((b['spent'] as num?) ?? 0).compareTo((a['spent'] as num?) ?? 0);
      if (amountCompare != 0) {
        return amountCompare;
      }

      final bDate = b['latestDate'] as DateTime?;
      final aDate = a['latestDate'] as DateTime?;
      if (aDate != null && bDate != null) {
        final dateCompare = bDate.compareTo(aDate);
        if (dateCompare != 0) {
          return dateCompare;
        }
      }
      if (bDate != null) return 1;
      if (aDate != null) return -1;

      return (a['label'] as String).compareTo(b['label'] as String);
    });

    if (!mounted) return;

    setState(() {
      analysisData = result;
    });

    await WidgetSyncService.updateConfiguration(
      mode: _widgetMode(),
      month: currentMonth.month,
      year: currentMonth.year,
    );
  }

  List<Map<String, dynamic>> _filteredExpenseTransactions() {
    return transactions.where((transaction) {
      if (transaction['type'] != 'expense') {
        return false;
      }

      final rawDate = transaction['date'];
      if (rawDate == null) {
        return false;
      }

      return _isDateInActiveRange(DateTime.parse(rawDate as String));
    }).toList();
  }

  String _analysisKeyForTransaction(Map<String, dynamic> transaction) {
    if (analysisType == AnalysisType.account) {
      return (transaction['account'] as String?)?.trim() ?? '';
    }
    return (transaction['title'] as String?)?.trim() ?? '';
  }

  bool _isDateInActiveRange(DateTime date) {
    if (date.year != currentMonth.year) return false;

    if (analysisMode == AnalysisMode.selectedMonth) {
      return date.month == currentMonth.month;
    }

    if (analysisMode == AnalysisMode.cumulativeToSelectedMonth) {
      return date.month <= currentMonth.month;
    }

    return true;
  }

  bool _isBudgetInActiveRange(Map<String, dynamic> budgetData) {
    final year = _toInt(budgetData['year']);
    if (year != currentMonth.year) return false;

    final month = _toInt(budgetData['month']);

    if (analysisMode == AnalysisMode.selectedMonth) {
      return month == currentMonth.month;
    }

    if (analysisMode == AnalysisMode.cumulativeToSelectedMonth) {
      return month <= currentMonth.month;
    }

    return true;
  }

  int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString()) ?? 0;
  }

  IconData _iconForLabel(String label) {
    final source = analysisType == AnalysisType.category ? DataStore.categories : DataStore.accounts;
    final entry = source.cast<Map<String, dynamic>?>().firstWhere(
          (item) => item?['name'] == label,
          orElse: () => null,
        );

    return iconFromCodePoint(
      entry?['icon'],
      fallback: analysisType == AnalysisType.category ? Icons.category : Icons.account_balance_wallet,
    );
  }

  double _activeTotalExpense() {
    return _filteredExpenseTransactions().fold<double>(
      0.0,
      (sum, transaction) => sum + (transaction['amount'] as num).toDouble(),
    );
  }

  double _activeTotalBudget() {
    return budgets.where(_isBudgetInActiveRange).fold<double>(
          0.0,
          (sum, budget) => sum + (budget['amount'] as num).toDouble(),
        );
  }

  Color _progressColor(double ratio) {
    if (ratio <= 0.5) {
      return const Color(0xFF9CCC65);
    }
    if (ratio <= 1) {
      return const Color(0xFFFFF176);
    }
    return const Color(0xFFEF9A9A);
  }

  void _showAnalysisOptions() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: StatefulBuilder(
            builder: (context, setModalState) {
              Future<void> applyChanges(VoidCallback updateParent) async {
                updateParent();
                setModalState(() {});
                await loadAnalysis();
              }

              return ListView(
                shrinkWrap: true,
                children: [
                  const ListTile(
                    title: Text(
                      'Analysis options',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  const _MenuSectionHeader('Aggregation'),
                  RadioListTile<AnalysisMode>(
                    value: AnalysisMode.selectedMonth,
                    groupValue: analysisMode,
                    title: const Text('Selected month'),
                    onChanged: (value) {
                      if (value == null) return;
                      applyChanges(() => setState(() => analysisMode = value));
                    },
                  ),
                  RadioListTile<AnalysisMode>(
                    value: AnalysisMode.cumulativeToSelectedMonth,
                    groupValue: analysisMode,
                    title: const Text('Cumulative till selected month'),
                    onChanged: (value) {
                      if (value == null) return;
                      applyChanges(() => setState(() => analysisMode = value));
                    },
                  ),
                  RadioListTile<AnalysisMode>(
                    value: AnalysisMode.cumulativeYear,
                    groupValue: analysisMode,
                    title: const Text('Cumulative full year'),
                    onChanged: (value) {
                      if (value == null) return;
                      applyChanges(() => setState(() => analysisMode = value));
                    },
                  ),
                  const Divider(height: 1),
                  const _MenuSectionHeader('Type'),
                  RadioListTile<AnalysisType>(
                    value: AnalysisType.category,
                    groupValue: analysisType,
                    title: const Text('Category'),
                    onChanged: (value) {
                      if (value == null) return;
                      applyChanges(() => setState(() => analysisType = value));
                    },
                  ),
                  RadioListTile<AnalysisType>(
                    value: AnalysisType.account,
                    groupValue: analysisType,
                    title: const Text('Account'),
                    onChanged: (value) {
                      if (value == null) return;
                      applyChanges(() => setState(() => analysisType = value));
                    },
                  ),
                  const Divider(height: 1),
                  const _MenuSectionHeader('Sort'),
                  RadioListTile<TransactionSortOrder>(
                    value: TransactionSortOrder.newestFirst,
                    groupValue: transactionSortOrder,
                    title: const Text('Newest first'),
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => transactionSortOrder = value);
                      setModalState(() {});
                    },
                  ),
                  RadioListTile<TransactionSortOrder>(
                    value: TransactionSortOrder.oldestFirst,
                    groupValue: transactionSortOrder,
                    title: const Text('Oldest first'),
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => transactionSortOrder = value);
                      setModalState(() {});
                    },
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    value: showPercentage,
                    title: const Text('Show percentage'),
                    onChanged: (value) {
                      setState(() => showPercentage = value);
                      setModalState(() {});
                    },
                  ),
                  const SizedBox(height: 12),
                ],
              );
            },
          ),
        );
      },
    );
  }

  String _widgetMode() {
    switch (analysisMode) {
      case AnalysisMode.cumulativeToSelectedMonth:
        return WidgetSyncService.cumulativeToSelectedMonth;
      case AnalysisMode.cumulativeYear:
        return WidgetSyncService.cumulativeYear;
      case AnalysisMode.selectedMonth:
        return WidgetSyncService.selectedMonth;
    }
  }

  String _emptyStateMessage() {
    final label = analysisType == AnalysisType.category ? 'category' : 'account';

    switch (analysisMode) {
      case AnalysisMode.cumulativeToSelectedMonth:
        return 'No $label expense data up to this month.';
      case AnalysisMode.cumulativeYear:
        return 'No $label expense data for this year.';
      case AnalysisMode.selectedMonth:
        return 'No $label expense data for this month.';
    }
  }

  List<Map<String, dynamic>> _transactionsForLabel(String label) {
    final matching = _filteredExpenseTransactions().where((transaction) {
      return _analysisKeyForTransaction(transaction) == label;
    }).toList();

    matching.sort((a, b) {
      final aDate = DateTime.parse(a['date'] as String);
      final bDate = DateTime.parse(b['date'] as String);
      final comparison = aDate.compareTo(bDate);
      return transactionSortOrder == TransactionSortOrder.newestFirst ? -comparison : comparison;
    });

    return matching;
  }

  void _showRelatedTransactions(Map<String, dynamic> data) {
    final label = data['label'] as String;
    final groupedTransactions = _transactionsForLabel(label);
    final dateFormat = DateFormat('dd MMM yyyy');

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.62,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${groupedTransactions.length} transactions • ${transactionSortOrder == TransactionSortOrder.newestFirst ? 'Newest first' : 'Oldest first'}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.grey[700],
                            ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: groupedTransactions.isEmpty
                      ? const Center(child: Text('No related transactions found.'))
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          itemCount: groupedTransactions.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final transaction = groupedTransactions[index];
                            final amount = (transaction['amount'] as num).toDouble();
                            final date = DateTime.parse(transaction['date'] as String);
                            final subtitle = analysisType == AnalysisType.category
                                ? (transaction['account'] as String?)?.trim() ?? ''
                                : (transaction['title'] as String?)?.trim() ?? '';

                            return Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: const Color(0xFFE3E7EE)),
                              ),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 18,
                                    backgroundColor: const Color(0xFFE9EEF6),
                                    child: Icon(
                                      _iconForLabel(label),
                                      size: 18,
                                      color: const Color(0xFF425466),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          subtitle.isEmpty ? label : subtitle,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontWeight: FontWeight.w600),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          dateFormat.format(date),
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[700],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    formatIndianCurrency(amount),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final expense = _activeTotalExpense();
    final budgetTotal = _activeTotalBudget();

    return Scaffold(
      backgroundColor: const Color(0xFFF3F5F9),
      body: PageContentLayout(
        child: Column(
          children: [
            MonthSummary(
              currentMonth: currentMonth,
              onPrev: () {
                setState(() {
                  currentMonth = DateTime(currentMonth.year, currentMonth.month - 1);
                });
                loadAnalysis();
              },
              onNext: () {
                setState(() {
                  currentMonth = DateTime(currentMonth.year, currentMonth.month + 1);
                });
                loadAnalysis();
              },
              budget: budgetTotal,
              expense: expense,
              trailing: IconButton(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: const Icon(Icons.more_vert, size: 20),
                onPressed: _showAnalysisOptions,
                tooltip: 'Analysis options',
              ),
            ),
            Expanded(
              child: SectionTile(
                child: analysisData.isEmpty
                    ? Center(child: Text(_emptyStateMessage()))
                    : ListView.builder(
                        padding: EdgeInsets.zero,
                        itemCount: analysisData.length,
                        itemBuilder: (context, index) {
                          final data = analysisData[index];
                          final label = data['label'] as String;
                          final spent = (data['spent'] as num).toDouble();
                          final budget = (data['budget'] as num).toDouble();
                          final ratio = analysisType == AnalysisType.account
                              ? 0.0
                              : (budget == 0 ? (spent > 0 ? 1.01 : 0.0) : spent / budget);
                          final progress = analysisType == AnalysisType.account
                              ? 0.0
                              : (budget == 0
                                  ? (spent > 0 ? 1.0 : 0.0)
                                  : (spent == 0 ? 0.02 : ratio.clamp(0.0, 1.0).toDouble()));
                          final percentage = data['percentage'] as int? ?? 0;

                          return InkWell(
                            onTap: () => _showRelatedTransactions(data),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Row(
                                          children: [
                                            Icon(_iconForLabel(label), size: 18),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                label,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 15,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                            analysisType == AnalysisType.category
                                                ? '${formatIndianCurrency(spent)} / ${formatIndianCurrency(budget)}'
                                                : formatIndianCurrency(spent),
                                            style: const TextStyle(fontSize: 14),
                                          ),
                                          if (showPercentage)
                                            Text(
                                              '($percentage%)',
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: Colors.grey[700],
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  if (analysisType == AnalysisType.category) ...[
                                    const SizedBox(height: 6),
                                    LinearProgressIndicator(
                                      value: progress,
                                      minHeight: 8,
                                      backgroundColor: Colors.grey[300],
                                      color: _progressColor(ratio),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuSectionHeader extends StatelessWidget {
  final String title;

  const _MenuSectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Text(
        title,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: const Color(0xFF52606D),
            ),
      ),
    );
  }
}
