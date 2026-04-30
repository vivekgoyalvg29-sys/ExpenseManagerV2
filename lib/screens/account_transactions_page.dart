import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/data_service.dart';
import '../services/data_store.dart';
import '../utils/aggregation_date_range.dart';
import '../utils/indian_number_formatter.dart';
import 'add_transaction_page.dart';
import 'analysis_page.dart';

/// All transactions for one account in the active aggregation window.
class AccountTransactionsPage extends StatefulWidget {
  final Map<String, dynamic> account;
  final DateTime currentMonth;
  final AnalysisMode aggregationMode;

  const AccountTransactionsPage({
    super.key,
    required this.account,
    required this.currentMonth,
    required this.aggregationMode,
  });

  @override
  State<AccountTransactionsPage> createState() => _AccountTransactionsPageState();
}

class _AccountTransactionsPageState extends State<AccountTransactionsPage> {
  List<Map<String, dynamic>> _transactions = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    DataStore.transactionMutationGeneration.addListener(_onDataChange);
    _load();
  }

  @override
  void dispose() {
    DataStore.transactionMutationGeneration.removeListener(_onDataChange);
    super.dispose();
  }

  void _onDataChange() {
    if (mounted) _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final range = dateRangeInclusiveForAggregation(widget.currentMonth, widget.aggregationMode);
    final all = await DataService.getTransactions(startDate: range.$1, endDate: range.$2);
    final name = (widget.account['name'] ?? '').toString().trim();
    final filtered = all.where((t) => (t['account'] ?? '').toString().trim() == name).toList();
    int typeRank(String? t) => t == 'income' ? 0 : 1;
    filtered.sort((a, b) {
      final ta = typeRank(a['type']?.toString());
      final tb = typeRank(b['type']?.toString());
      if (ta != tb) return ta.compareTo(tb);
      final da = DateTime.parse(a['date'] as String);
      final db = DateTime.parse(b['date'] as String);
      return db.compareTo(da);
    });
    if (!mounted) return;
    setState(() {
      _transactions = filtered;
      _loading = false;
    });
  }

  Future<void> _edit(Map<String, dynamic> transaction) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => AddTransactionPage(
        existingTransaction: transaction,
        modalStyle: true,
      ),
    );
    if (result == null) return;
    await DataService.updateTransaction(
      transaction['id'] as int,
      result['title'] as String,
      result['amount'] as double,
      result['date'] as DateTime,
      result['type'] as String,
      (result['account'] ?? '').toString(),
      (result['comment'] ?? '').toString(),
    );
    if (mounted) await _load();
  }

  String _periodLabel() {
    final sub = aggregationSubtitleForMode(widget.aggregationMode);
    if (sub == null) {
      return DateFormat('MMMM yyyy').format(widget.currentMonth);
    }
    if (widget.aggregationMode == AnalysisMode.cumulativeYear) {
      return '${widget.currentMonth.year} (year)';
    }
    return '${DateFormat('MMMM yyyy').format(widget.currentMonth)} ($sub)';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = (widget.account['name'] ?? '').toString();
    final dateFormat = DateFormat('dd MMM yyyy');

    return Scaffold(
      appBar: AppBar(
        title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(28),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
              child: Text(
                _periodLabel(),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _transactions.isEmpty
              ? Center(
                  child: Text(
                    'No transactions for this account in this period.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  itemCount: _transactions.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final transaction = _transactions[index];
                    final amount = (transaction['amount'] as num).toDouble();
                    final date = DateTime.parse(transaction['date'] as String);
                    final comment = (transaction['comment'] as String? ?? '').trim();
                    final title = (transaction['title'] ?? '').toString();
                    final type = (transaction['type'] ?? '').toString();

                    return Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => _edit(transaction),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: theme.colorScheme.outline.withValues(alpha: 0.35),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                type == 'income' ? Icons.trending_up : Icons.trending_down,
                                color: type == 'income'
                                    ? const Color(0xFF22C55E).withValues(alpha: 0.88)
                                    : const Color(0xFFEF4444).withValues(alpha: 0.85),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontWeight: FontWeight.w600),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      dateFormat.format(date),
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: theme.colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                    if (comment.isNotEmpty) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        comment,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: theme.colorScheme.onSurfaceVariant
                                              .withValues(alpha: 0.85),
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
                                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Tap to edit',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: theme.colorScheme.onSurfaceVariant,
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
    );
  }
}
