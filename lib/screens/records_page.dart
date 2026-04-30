import 'dart:async';

import 'package:android_intent_plus/android_intent.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/data_service.dart';
import '../services/data_store.dart';
import '../services/firestore_service.dart';
import '../services/profile_service.dart';
import '../services/visual_settings.dart';
import '../services/widget_sync_service.dart';
import '../utils/indian_number_formatter.dart';
import '../widgets/icon_utils.dart';
import '../widgets/month_summary.dart';
import '../widgets/page_content_layout.dart';
import '../widgets/section_tile.dart';
import 'add_transaction_page.dart';

class RecordsPage extends StatefulWidget {
  const RecordsPage({super.key});

  @override
  _RecordsPageState createState() => _RecordsPageState();
}

class _RecordsPageState extends State<RecordsPage> {
  static const String _lastScannedQrKey = 'last_scanned_qr';

  DateTime currentMonth = DateTime.now();
  List<Map<String, dynamic>> transactions = [];
  List<Map<String, dynamic>> budgets = [];
  bool _isLoadingTransactions = true;

  Set<int> selectedIndexes = {};
  bool selectionMode = false;
  bool _isProcessingQr = false;

  /// Pull-to-refresh only for multi-user shared cloud books (Pro or Free).
  bool _recordsPullRefreshEnabled = false;

  @override
  void initState() {
    super.initState();
    DataStore.transactionMutationGeneration.addListener(_onBookDataMutation);
    DataStore.profileSwitchGeneration.addListener(_onProfileSwitch);
    unawaited(_updatePullRefreshAvailability());
    loadTransactions();
  }

  void _onBookDataMutation() {
    if (mounted) loadTransactions();
  }

  void _onProfileSwitch() {
    if (!mounted) return;
    final n = DateTime.now();
    setState(() {
      currentMonth = DateTime(n.year, n.month);
    });
    unawaited(_updatePullRefreshAvailability());
    loadTransactions();
  }

  Future<void> _updatePullRefreshAvailability() async {
    final v = await ProfileService().activeProfileIsSharedCollaborationBook();
    if (mounted) {
      setState(() => _recordsPullRefreshEnabled = v);
    }
  }

  Future<void> _onSharedBookRefresh() async {
    if (!_recordsPullRefreshEnabled) return;
    try {
      FirestoreService().clearCaches();
      await loadTransactions(preferServer: true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not refresh: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    DataStore.transactionMutationGeneration.removeListener(_onBookDataMutation);
    DataStore.profileSwitchGeneration.removeListener(_onProfileSwitch);
    super.dispose();
  }

  Future<void> loadTransactions({bool preferServer = false}) async {
    if (mounted) {
      setState(() => _isLoadingTransactions = true);
    }
    final startDate = DateTime(currentMonth.year, currentMonth.month, 1);
    final endDate = DateTime(currentMonth.year, currentMonth.month + 1, 0, 23, 59, 59, 999);
    try {
      final txData = await DataService.getTransactions(
        startDate: startDate,
        endDate: endDate,
        preferServer: preferServer,
      );
      final budgetData = await DataService.getBudgets(preferServer: preferServer);
      final categoryData = await DataService.getCategories(preferServer: preferServer);
      final accountData = await DataService.getAccounts(preferServer: preferServer);

      if (!mounted) return;
      setState(() {
        transactions = txData;
        budgets = budgetData;
        DataStore.replaceCategories(categoryData);
        DataStore.replaceAccounts(accountData);
        _isLoadingTransactions = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingTransactions = false);
      }
    }

    unawaited(WidgetSyncService.syncFromStoredConfiguration());
  }

  List<Map<String, dynamic>> get filteredTransactions {
    return transactions.where((tx) {
      DateTime date = DateTime.parse(tx["date"]);
      return date.month == currentMonth.month && date.year == currentMonth.year;
    }).toList();
  }

  double get monthBudgetTotal {
    return budgets
        .where((b) => b['month'] == currentMonth.month && b['year'] == currentMonth.year)
        .fold(0.0, (sum, b) => sum + (b['amount'] as num).toDouble());
  }

  ScrollPhysics? get _recordsScrollPhysics =>
      _recordsPullRefreshEnabled ? const AlwaysScrollableScrollPhysics() : null;

  Widget _recordsLoadingBody() {
    return ListView(
      physics: _recordsScrollPhysics,
      padding: EdgeInsets.zero,
      children: const [
        SizedBox(height: 80),
        Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: CircularProgressIndicator(),
          ),
        ),
      ],
    );
  }

  Widget _recordsEmptyBody() {
    return ListView(
      physics: _recordsScrollPhysics,
      padding: EdgeInsets.zero,
      children: const [
        SizedBox(height: 80),
        Center(child: Text('No transactions')),
      ],
    );
  }

  Widget _recordsTransactionList() {
    return ListView.builder(
      physics: _recordsScrollPhysics,
      padding: EdgeInsets.zero,
      itemCount: filteredTransactions.length,
      itemBuilder: (context, index) {
        final tx = filteredTransactions[index];
        final date = DateTime.parse(tx["date"]);
        final previousTx = index > 0 ? filteredTransactions[index - 1] : null;
        final previousDate =
            previousTx != null ? DateTime.parse(previousTx["date"]) : null;
        final showDateHeader = previousDate == null ||
            previousDate.year != date.year ||
            previousDate.month != date.month ||
            previousDate.day != date.day;
        final comment = (tx["comment"] ?? '').toString().trim();
        final amount = (tx["amount"] as num).toDouble();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showDateHeader) ...[
              if (index > 0) const SizedBox(height: 14),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 4, 10, 6),
                child: Text(
                  DateFormat('MMM d, EEEE').format(date),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0E5D5B),
                  ),
                ),
              ),
              const Divider(height: 1, thickness: 1),
            ],
            ListTile(
              visualDensity: VisualDensity.compact,
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 1),
              leading: selectionMode
                  ? Checkbox(
                      value: selectedIndexes.contains(index),
                      onChanged: (v) {
                        setState(() {
                          if (v == true) {
                            selectedIndexes.add(index);
                          } else {
                            selectedIndexes.remove(index);
                          }
                        });
                      },
                    )
                  : AppPageIcon(
                      icon: _categoryIcon(tx["title"]),
                      imagePath: _categoryDetails(
                        tx["title"].toString(),
                      )?['icon_path']?.toString(),
                    ),
              title: Text(
                tx["title"],
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: comment.isEmpty
                  ? null
                  : Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        comment,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF7C8794),
                        ),
                      ),
                    ),
              trailing: Text(
                "${tx["type"] == "income" ? '+' : '-'}${formatIndianCurrency(amount, decimalDigits: 2)}",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: tx["type"] == "income" ? Colors.green : Colors.red,
                ),
              ),
              onLongPress: DataStore.viewerReadOnly
                  ? null
                  : () {
                      setState(() {
                        selectionMode = true;
                        selectedIndexes.add(index);
                      });
                    },
              onTap: () async {
                if (DataStore.viewerReadOnly && !selectionMode) {
                  DataStore.showViewerReadOnlyNotice(context);
                  return;
                }
                if (selectionMode) {
                  setState(() {
                    if (selectedIndexes.contains(index)) {
                      selectedIndexes.remove(index);
                    } else {
                      selectedIndexes.add(index);
                    }
                  });
                  return;
                }

                final rawId = tx['id'];
                if (rawId is int && rawId < 0) return;

                final result = await showDialog<Map<String, dynamic>>(
                  context: context,
                  builder: (_) => AddTransactionPage(existingTransaction: tx),
                );

                if (result != null) {
                  await DataService.updateTransaction(
                    tx['id'] as int,
                    result['title'] as String,
                    result['amount'] as double,
                    result['date'] as DateTime,
                    result['type'] as String,
                    (result['account'] ?? '').toString(),
                    (result['comment'] ?? '').toString(),
                  );

                  await loadTransactions();
                }
              },
            ),
            if (index < filteredTransactions.length - 1)
              const Padding(
                padding: EdgeInsets.only(left: 88),
                child: Divider(height: 1, color: Color(0xFFE6EAF0)),
              ),
          ],
        );
      },
    );
  }

  Widget _buildRecordsTileBody() {
    final Widget inner = _isLoadingTransactions && filteredTransactions.isEmpty
        ? _recordsLoadingBody()
        : (!_isLoadingTransactions && filteredTransactions.isEmpty)
            ? _recordsEmptyBody()
            : _recordsTransactionList();
    if (_recordsPullRefreshEnabled) {
      return RefreshIndicator(
        onRefresh: _onSharedBookRefresh,
        child: inner,
      );
    }
    return inner;
  }

  void clearSelection() {
    setState(() {
      selectedIndexes.clear();
      selectionMode = false;
    });
  }

  void deleteSelected() async {
    final idsToDelete = selectedIndexes.map((i) => filteredTransactions[i]["id"]).toList();

    for (var id in idsToDelete) {
      await DataService.deleteTransaction(id);
    }

    clearSelection();

    loadTransactions();
  }

  IconData _categoryIcon(String categoryName) {
    final category = _categoryDetails(categoryName);
    return iconFromCodePoint(category?["icon"], fallback: Icons.category);
  }

  Map<String, dynamic>? _categoryDetails(String categoryName) {
    return DataStore.categories.cast<Map<String, dynamic>?>().firstWhere(
          (c) => c?["name"] == categoryName,
          orElse: () => null,
        );
  }

  Future<void> _openQrScannerFlow() async {
  if (_isProcessingQr) return;
  setState(() => _isProcessingQr = true);
  try {
    final qrPayload = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const _QrScanPage()),
    );

    if (!mounted || qrPayload == null || qrPayload.trim().isEmpty) return;
    final qrAmount = _extractUpiAmount(qrPayload);

    final draft = await _showQrTransactionDialog(
      prefilledAmount: qrAmount,
      lockAmountField: qrAmount != null,
    );
    if (!mounted || draft == null) return;

    // Always use the QR's own amount for the payment payload when present.
    // The draft.amount may have been manually entered only when no QR amount exists.
    final paymentAmount = qrAmount ?? draft.amount;
    final launchedPayload = await _launchPaymentAppFlow(qrPayload, paymentAmount);
    if (!mounted || launchedPayload == null) return;

    await DataService.insertTransaction(
      draft.category,
      draft.amount,   // save what was shown to the user
      draft.date,
      'expense',
      draft.account,
      draft.comment,
    );

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastScannedQrKey, launchedPayload);
    await loadTransactions();
  } finally {
    if (mounted) {
      setState(() => _isProcessingQr = false);
    }
  }
}

  Future<_QrExpenseDraft?> _showQrTransactionDialog({
    double? prefilledAmount,
    bool lockAmountField = false,
  }) async {
    String? selectedAccount;
    for (final account in DataStore.accounts) {
      selectedAccount = account['name']?.toString();
      if (selectedAccount != null && selectedAccount.isNotEmpty) break;
    }

    String? selectedCategory;
    for (final category in DataStore.categories) {
      if ((category['type'] ?? '').toString() != 'expense') continue;
      selectedCategory = category['name']?.toString();
      if (selectedCategory != null && selectedCategory.isNotEmpty) break;
    }

    final amountController = TextEditingController(
      text: prefilledAmount != null ? prefilledAmount.toStringAsFixed(2) : '',
    );
    final commentController = TextEditingController();
    DateTime selectedDate = DateTime.now();
    String? validationError;

    final draft = await showDialog<_QrExpenseDraft>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final tt = Theme.of(context).textTheme;
            final fieldLabelStyle = tt.bodyMedium;
            final fieldTextStyle = tt.bodyLarge;
            final expenseAccounts = DataStore.accounts.toList();
            final expenseCategories = DataStore.categories
                .where((cat) => (cat['type'] ?? '').toString() == 'expense')
                .toList();

            return Dialog(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Add Expense from QR',
                          style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          initialValue: 'Expense',
                          readOnly: true,
                          style: fieldTextStyle,
                          decoration: InputDecoration(
                            labelText: 'Type',
                            labelStyle: fieldLabelStyle,
                          ),
                        ),
                        const SizedBox(height: 10),
                        DropdownButtonFormField<String>(
                          key: ValueKey(selectedAccount ?? ''),
                          initialValue: selectedAccount,
                          items: expenseAccounts
                              .map(
                                (acc) => DropdownMenuItem<String>(
                                  value: acc['name'].toString(),
                                  child: Text(acc['name'].toString()),
                                ),
                              )
                              .toList(),
                          onChanged: (v) {
                            setDialogState(() {
                              selectedAccount = v;
                            });
                          },
                          style: fieldTextStyle,
                          decoration: InputDecoration(
                            labelText: 'Account',
                            labelStyle: fieldLabelStyle,
                          ),
                        ),
                        const SizedBox(height: 10),
                        DropdownButtonFormField<String>(
                          key: ValueKey(selectedCategory ?? ''),
                          initialValue: selectedCategory,
                          items: expenseCategories
                              .map(
                                (cat) => DropdownMenuItem<String>(
                                  value: cat['name'].toString(),
                                  child: Text(cat['name'].toString()),
                                ),
                              )
                              .toList(),
                          onChanged: (v) {
                            setDialogState(() {
                              selectedCategory = v;
                            });
                          },
                          style: fieldTextStyle,
                          decoration: InputDecoration(
                            labelText: 'Category',
                            labelStyle: fieldLabelStyle,
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: commentController,
                          minLines: 1,
                          maxLines: 3,
                          style: fieldTextStyle,
                          decoration: InputDecoration(
                            labelText: 'Comments',
                            labelStyle: fieldLabelStyle,
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: amountController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          readOnly: lockAmountField,
                          style: fieldTextStyle,
                          decoration: InputDecoration(
                            labelText: 'Amount',
                            labelStyle: fieldLabelStyle,
                            helperText: lockAmountField
                                ? 'Amount is taken from merchant QR.'
                                : null,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Date'),
                          subtitle: Text(DateFormat('dd MMM yyyy').format(selectedDate)),
                          trailing: const Icon(Icons.calendar_today),
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: dialogContext,
                              initialDate: selectedDate,
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2100),
                            );
                            if (picked == null) return;
                            setDialogState(() {
                              selectedDate = picked;
                            });
                          },
                        ),
                        if (validationError != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            validationError!,
                            style: const TextStyle(color: Colors.red),
                          ),
                        ],
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: () => Navigator.pop(dialogContext),
                              child: const Text('Cancel'),
                            ),
                            const SizedBox(width: 8),
                            FilledButton(
                              onPressed: () async {
                                final rawAmount = amountController.text.trim();
                                final amount = double.tryParse(rawAmount);
                                if (selectedAccount == null ||
                                    selectedCategory == null ||
                                    rawAmount.isEmpty ||
                                    amount == null ||
                                    amount <= 0) {
                                  setDialogState(() {
                                    validationError =
                                        'Account, category and valid amount are required.';
                                  });
                                  return;
                                }

                                if (!dialogContext.mounted) return;
                                Navigator.pop(
                                  dialogContext,
                                  _QrExpenseDraft(
                                    account: selectedAccount!,
                                    category: selectedCategory!,
                                    amount: amount,
                                    date: selectedDate,
                                    comment: commentController.text.trim(),
                                  ),
                                );
                              },
                              child: const Text('OK'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    amountController.dispose();
    commentController.dispose();

    return draft;
  }

  Future<String?> _launchPaymentAppFlow(String qrPayload, double enteredAmount) async {
    final payload = qrPayload.trim();
    if (payload.isEmpty) return null;
    final payloadWithAmount = _buildPaymentPayload(payload, enteredAmount);

    if (!mounted) return null;
    final launched = await _launchUpiWithSystemChooser(payloadWithAmount);
    if (!mounted) return null;

    if (!launched) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No app can open this UPI link. Install a UPI app or try again.',
          ),
        ),
      );
      return null;
    }

    return payloadWithAmount;
  }

  /// Opens the UPI URI with ACTION_VIEW and no target package — Android shows the system chooser.
  Future<bool> _launchUpiWithSystemChooser(String qrPayload) async {
    try {
      final intent = AndroidIntent(
        action: 'android.intent.action.VIEW',
        data: qrPayload,
      );
      await intent.launch();
      return true;
    } catch (_) {
      return false;
    }
  }

  String _buildPaymentPayload(String qrPayload, double enteredAmount) {
  final parsed = Uri.tryParse(qrPayload);
  if (parsed == null || parsed.scheme.toLowerCase() != 'upi') {
    return qrPayload;
  }

  final query = Map<String, String>.from(parsed.queryParameters);
  final existingAmount = _parsePositiveAmount(query['am']);

  if (existingAmount != null) {
    // Merchant QR already has a fixed amount — preserve it exactly as-is.
    // Overwriting it causes "Bank limit exceeded" because the merchant's
    // payment gateway validates the amount hasn't changed.
    return qrPayload;
  }

  // Dynamic QR (no amount) — remove am entirely so the payment app
  // shows its own amount entry screen without a pre-injected value.
  query.remove('am');

  return parsed.replace(queryParameters: query).toString();
}

  double? _extractUpiAmount(String qrPayload) {
    final parsed = Uri.tryParse(qrPayload.trim());
    if (parsed == null || parsed.scheme.toLowerCase() != 'upi') return null;
    return _parsePositiveAmount(parsed.queryParameters['am']);
  }

  double? _parsePositiveAmount(String? value) {
    if (value == null) return null;
    final parsed = double.tryParse(value.trim());
    if (parsed == null || parsed <= 0) return null;
    return parsed;
  }

  @override
  Widget build(BuildContext context) {
    double expense = 0;
    double income = 0;

    for (var tx in filteredTransactions) {
      if (tx["type"] == "expense") {
        expense += (tx["amount"] as num).toDouble();
      } else if (tx["type"] == "income") {
        income += (tx["amount"] as num).toDouble();
      }
    }

    final comparisonMode = VisualSettingsScope.of(context).value.comparisonMode;
    final isIncomeVsExpense = comparisonMode == ComparisonMode.incomeVsExpense;
    final leftValue = isIncomeVsExpense ? income : monthBudgetTotal;
    final middleValue = expense;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      floatingActionButton: DataStore.viewerReadOnly
          ? null
          : selectionMode
          ? Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                FloatingActionButton.small(
                  heroTag: 'cancelRecordSelection',
                  onPressed: clearSelection,
                  tooltip: 'Cancel selection',
                  child: const Icon(Icons.close),
                ),
                const SizedBox(height: 10),
                FloatingActionButton.extended(
                  heroTag: 'deleteSelectedRecords',
                  onPressed: deleteSelected,
                  icon: const Icon(Icons.delete),
                  label: Text('Delete (${selectedIndexes.length})'),
                ),
              ],
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // QR scanner temporarily hidden — will be re-enabled in a future release
                const SizedBox(height: 10),
                FloatingActionButton(
                  heroTag: 'addRecordFab',
                  child: const Icon(Icons.add),
                  onPressed: () async {
                    final result = await showDialog<Map<String, dynamic>>(
                      context: context,
                      builder: (_) => const AddTransactionPage(),
                    );

                    if (result != null) {
                      final tempId = -DateTime.now().millisecondsSinceEpoch;
                      final optimistic = <String, dynamic>{
                        'id': tempId,
                        'title': result['title'],
                        'amount': result['amount'],
                        'date': (result['date'] as DateTime).toIso8601String(),
                        'type': result['type'],
                        'account': (result['account'] ?? '').toString(),
                        'comment': (result['comment'] ?? '').toString(),
                      };
                      if (mounted) {
                        setState(() {
                          transactions = [optimistic, ...transactions];
                        });
                      }
                      try {
                        await DataService.insertTransaction(
                          result['title'] as String,
                          result['amount'] as double,
                          result['date'] as DateTime,
                          result['type'] as String,
                          (result['account'] ?? '').toString(),
                          (result['comment'] ?? '').toString(),
                        );
                        await loadTransactions();
                      } catch (e) {
                        if (mounted) {
                          setState(() {
                            transactions = transactions.where((t) => t['id'] != tempId).toList();
                          });
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Could not save transaction: $e')),
                          );
                        }
                      }
                    }
                  },
                ),
              ],
            ),
      body: PageContentLayout(
        child: Column(
          children: [
            MonthSummary(
              currentMonth: currentMonth,
              onPrev: () {
                setState(() {
                  currentMonth = DateTime(currentMonth.year, currentMonth.month - 1);
                });
                loadTransactions();
              },
              onNext: () {
                setState(() {
                  currentMonth = DateTime(currentMonth.year, currentMonth.month + 1);
                });
                loadTransactions();
              },
              budget: leftValue,
              expense: middleValue,
              leftLabel: isIncomeVsExpense ? 'Income' : 'Budget',
              middleLabel: 'Expense',
              rightLabel: isIncomeVsExpense ? 'Net' : 'Remaining',
              density: MonthSummaryDensity.compact,
            ),
            Expanded(
              child: SectionTile(
                child: _buildRecordsTileBody(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QrExpenseDraft {
  final String account;
  final String category;
  final double amount;
  final DateTime date;
  final String comment;

  const _QrExpenseDraft({
    required this.account,
    required this.category,
    required this.amount,
    required this.date,
    required this.comment,
  });
}

class _QrScanPage extends StatefulWidget {
  const _QrScanPage();

  @override
  State<_QrScanPage> createState() => _QrScanPageState();
}

class _QrScanPageState extends State<_QrScanPage> {
  bool _handled = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan QR')),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            onDetect: (capture) {
              if (_handled) return;
              final barcode = capture.barcodes.isNotEmpty ? capture.barcodes.first : null;
              final raw = barcode?.rawValue?.trim();
              if (raw == null || raw.isEmpty) return;
              _handled = true;
              Navigator.pop(context, raw);
            },
          ),
          Center(
            child: Container(
              width: 230,
              height: 230,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 2),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
