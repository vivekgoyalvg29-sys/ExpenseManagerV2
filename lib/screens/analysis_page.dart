import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/data_store.dart';
import '../services/database_service.dart';
import '../services/widget_sync_service.dart';
import '../utils/indian_number_formatter.dart';
import '../widgets/icon_utils.dart';
import '../widgets/month_summary.dart';
import '../widgets/page_content_layout.dart';
import '../widgets/section_tile.dart';
import '../widgets/side_overlay_sheet.dart';
import 'add_transaction_page.dart';

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
  static const _analysisModeKey = 'analysis.mode';
  static const _analysisTypeKey = 'analysis.type';
  static const _analysisSortKey = 'analysis.sort';
  static const _analysisShowPercentageKey = 'analysis.showPercentage';

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
    _restorePreferences();
  }

  Future<void> _restorePreferences() async {
    final prefs = await SharedPreferences.getInstance();
    analysisMode = AnalysisMode.values[prefs.getInt(_analysisModeKey) ?? analysisMode.index];
    analysisType = AnalysisType.values[prefs.getInt(_analysisTypeKey) ?? analysisType.index];
    transactionSortOrder = TransactionSortOrder.values[
      prefs.getInt(_analysisSortKey) ?? transactionSortOrder.index
    ];
    showPercentage = prefs.getBool(_analysisShowPercentageKey) ?? showPercentage;
    if (!mounted) return;
    setState(() {});
    await loadAnalysis();
  }

  Future<void> _persistPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_analysisModeKey, analysisMode.index);
    await prefs.setInt(_analysisTypeKey, analysisType.index);
    await prefs.setInt(_analysisSortKey, transactionSortOrder.index);
    await prefs.setBool(_analysisShowPercentageKey, showPercentage);
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
      if (key.isEmpty) continue;

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
          if (category.isEmpty) continue;
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
      if (amountCompare != 0) return amountCompare;

      final bDate = b['latestDate'] as DateTime?;
      final aDate = a['latestDate'] as DateTime?;
      if (aDate != null && bDate != null) {
        final dateCompare = bDate.compareTo(aDate);
        if (dateCompare != 0) return dateCompare;
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
      if (transaction['type'] != 'expense') return false;
      final rawDate = transaction['date'];
      if (rawDate == null) return false;
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
    if (analysisMode == AnalysisMode.selectedMonth) return date.month == currentMonth.month;
    if (analysisMode == AnalysisMode.cumulativeToSelectedMonth) return date.month <= currentMonth.month;
    return true;
  }

  bool _isBudgetInActiveRange(Map<String, dynamic> budgetData) {
    final year = _toInt(budgetData['year']);
    if (year != currentMonth.year) return false;
    final month = _toInt(budgetData['month']);
    if (analysisMode == AnalysisMode.selectedMonth) return month == currentMonth.month;
    if (analysisMode == AnalysisMode.cumulativeToSelectedMonth) return month <= currentMonth.month;
    return true;
  }

  int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString()) ?? 0;
  }

  Map<String, dynamic>? _entryForLabel(String label) {
    final source = analysisType == AnalysisType.category ? DataStore.categories : DataStore.accounts;
    return source.cast<Map<String, dynamic>?>().firstWhere(
      (item) => item?['name'] == label,
      orElse: () => null,
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
    if (ratio <= 0.5) return const Color(0xFF22C55E);
    if (ratio <= 1) return const Color(0xFFF59E0B);
    return const Color(0xFFEF4444);
  }

  Future<void> _applyAnalysisPreferenceChange(VoidCallback updateParent) async {
    updateParent();
    await _persistPreferences();
    await loadAnalysis();
  }

  void _showAnalysisOptions() {
    showSideOverlaySheet<void>(
      context: context,
      direction: SideOverlayDirection.right,
      builder: (drawerContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            Future<void> applyChanges(VoidCallback updateParent) async {
              await _applyAnalysisPreferenceChange(() {
                setState(updateParent);
                setModalState(() {});
              });
            }

            return ListView(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 12, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Analysis options',
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(drawerContext).pop(),
                        icon: const Icon(Icons.close),
                        tooltip: 'Close options',
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                const _MenuSectionHeader('Aggregation'),
                RadioListTile<AnalysisMode>(
                  dense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  value: AnalysisMode.selectedMonth,
                  groupValue: analysisMode,
                  title: const Text('Selected month'),
                  onChanged: (value) {
                    if (value == null) return;
                    applyChanges(() => analysisMode = value);
                  },
                ),
                RadioListTile<AnalysisMode>(
                  dense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  value: AnalysisMode.cumulativeToSelectedMonth,
                  groupValue: analysisMode,
                  title: const Text('Cumulative till selected month'),
                  onChanged: (value) {
                    if (value == null) return;
                    applyChanges(() => analysisMode = value);
                  },
                ),
                RadioListTile<AnalysisMode>(
                  dense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  value: AnalysisMode.cumulativeYear,
                  groupValue: analysisMode,
                  title: const Text('Cumulative full year'),
                  onChanged: (value) {
                    if (value == null) return;
                    applyChanges(() => analysisMode = value);
                  },
                ),
                const Divider(height: 1),
                const _MenuSectionHeader('Type'),
                RadioListTile<AnalysisType>(
                  dense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  value: AnalysisType.category,
                  groupValue: analysisType,
                  title: const Text('Category'),
                  onChanged: (value) {
                    if (value == null) return;
                    applyChanges(() => analysisType = value);
                  },
                ),
                RadioListTile<AnalysisType>(
                  dense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  value: AnalysisType.account,
                  groupValue: analysisType,
                  title: const Text('Account'),
                  onChanged: (value) {
                    if (value == null) return;
                    applyChanges(() => analysisType = value);
                  },
                ),
                const Divider(height: 1),
                const _MenuSectionHeader('Sort'),
                RadioListTile<TransactionSortOrder>(
                  dense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  value: TransactionSortOrder.newestFirst,
                  groupValue: transactionSortOrder,
                  title: const Text('Newest first'),
                  onChanged: (value) async {
                    if (value == null) return;
                    setState(() => transactionSortOrder = value);
                    setModalState(() {});
                    await _persistPreferences();
                  },
                ),
                RadioListTile<TransactionSortOrder>(
                  dense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  value: TransactionSortOrder.oldestFirst,
                  groupValue: transactionSortOrder,
                  title: const Text('Oldest first'),
                  onChanged: (value) async {
                    if (value == null) return;
                    setState(() => transactionSortOrder = value);
                    setModalState(() {});
                    await _persistPreferences();
                  },
                ),
                const Divider(height: 1),
                SwitchListTile(
                  dense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  value: showPercentage,
                  title: const Text('Show percentage'),
                  onChanged: (value) async {
                    setState(() => showPercentage = value);
                    setModalState(() {});
                    await _persistPreferences();
                  },
                ),
                const SizedBox(height: 12),
              ],
            );
          },
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

  Future<void> _editTransaction(Map<String, dynamic> transaction) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddTransactionPage(existingTransaction: transaction),
      ),
    );

    if (result == null) return;

    await DatabaseService.updateTransaction(
      transaction['id'] as int,
      result['title'] as String,
      result['amount'] as double,
      result['date'] as DateTime,
      result['type'] as String,
      (result['account'] ?? '').toString(),
      (result['comment'] ?? '').toString(),
    );

    if (!mounted) return;
    await loadAnalysis();
  }

  void _showRelatedTransactions(Map<String, dynamic> data) {
    final label = data['label'] as String;
    final dateFormat = DateFormat('dd MMM yyyy');

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (bottomSheetContext) {
        return StatefulBuilder(
          builder: (context, _) {
            final groupedTransactions = _transactionsForLabel(label);
            return SafeArea(
              child: SizedBox(
                height: MediaQuery.of(context).size.height * 0.68,
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
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              itemCount: groupedTransactions.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 8),
                              itemBuilder: (context, index) {
                                final transaction = groupedTransactions[index];
                                final amount = (transaction['amount'] as num).toDouble();
                                final date = DateTime.parse(transaction['date'] as String);
                                final comment = (transaction['comment'] as String? ?? '').trim();
                                final subtitle = analysisType == AnalysisType.category
                                    ? (transaction['account'] as String?)?.trim() ?? ''
                                    : (transaction['title'] as String?)?.trim() ?? '';

                                final entry = _entryForLabel(label);

                                return Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(16),
                                    onTap: () async {
                                      Navigator.of(bottomSheetContext).pop();
                                      await _editTransaction(transaction);
                                      if (mounted) {
                                        _showRelatedTransactions(data);
                                      }
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(color: const Color(0xFFE3E7EE)),
                                      ),
                                      child: Row(
                                        children: [
                                          AppPageIcon(
                                            icon: iconFromCodePoint(
                                              entry?['icon'],
                                              fallback: analysisType == AnalysisType.category ? Icons.category : Icons.account_balance_wallet,
                                            ),
                                            imagePath: entry?['icon_path']?.toString(),
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
                                                if (comment.isNotEmpty) ...[
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    comment,
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color: Colors.grey[600],
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.end,
                                            children: [
                                              Text(
                                                formatIndianCurrency(amount),
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 14,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                'Tap to edit',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: Colors.grey[600],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
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
                          final remaining = budget - spent;
                          final amountSummary = analysisType == AnalysisType.category
                              ? '${formatIndianCurrency(spent)} / ${formatIndianCurrency(budget)}${showPercentage ? ' ($percentage%)' : ''}'
                              : '${formatIndianCurrency(spent)}${showPercentage ? ' ($percentage%)' : ''}';

                          final entry = _entryForLabel(label);
                          return InkWell(
                            onTap: () => _showRelatedTransactions(data),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      AppPageIcon(
                                        icon: iconFromCodePoint(
                                          entry?['icon'],
                                          fallback: analysisType == AnalysisType.category ? Icons.category : Icons.account_balance_wallet,
                                        ),
                                        imagePath: entry?['icon_path']?.toString(),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    label,
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                                                  ),
                                                ),
                                                if (analysisType == AnalysisType.category) ...[
                                                  const SizedBox(width: 12),
                                                  Flexible(
                                                    child: Text(
                                                      'Remaining ${formatIndianCurrency(remaining)}',
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                      textAlign: TextAlign.end,
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        color: remaining >= 0 ? const Color(0xFF0F766E) : const Color(0xFFB91C1C),
                                                        fontWeight: FontWeight.w700,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              amountSummary,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(fontSize: 12.5, color: Colors.grey[700], fontWeight: FontWeight.w600),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (analysisType == AnalysisType.category) ...[
                                    const SizedBox(height: 10),
                                    Row(
                                      children: [
                                        Expanded(child: ModernProgressBar(value: progress, color: _progressColor(ratio))),
                                        const SizedBox(width: 10),
                                        Text(
                                          '${(ratio * 100).isFinite ? (ratio * 100).clamp(0, 999).toStringAsFixed(0) : '0'}%',
                                          style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700, color: _progressColor(ratio)),
                                        ),
                                      ],
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
