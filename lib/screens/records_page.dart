import 'dart:typed_data';

import 'package:android_intent_plus/android_intent.dart';
import 'package:flutter/material.dart';
import 'package:installed_apps/app_info.dart';
import 'package:installed_apps/installed_apps.dart';
import 'package:intl/intl.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/data_service.dart';
import '../services/data_store.dart';
import '../services/visual_settings.dart';
import '../services/widget_sync_service.dart';
import '../utils/indian_number_formatter.dart';
import '../widgets/icon_utils.dart';
import '../widgets/month_summary.dart';
import '../widgets/page_content_layout.dart';
import '../widgets/mini_progress_bar.dart';
import '../widgets/section_tile.dart';
import 'add_transaction_page.dart';

class RecordsPage extends StatefulWidget {
  const RecordsPage({super.key});

  @override
  _RecordsPageState createState() => _RecordsPageState();
}

class _RecordsPageState extends State<RecordsPage> {
  static const String _defaultPaymentPackageKey = 'default_payment_package';
  static const String _lastScannedQrKey = 'last_scanned_qr';
  static const Duration _appsCacheTtl = Duration(minutes: 20);
  static List<AppInfo>? _installedAppsCache;
  static DateTime? _installedAppsCacheTime;
  static List<AppInfo>? _smartAppsCache;
  static DateTime? _smartAppsCacheTime;

  DateTime currentMonth = DateTime.now();
  List<Map<String, dynamic>> transactions = [];
  List<Map<String, dynamic>> budgets = [];

  Set<int> selectedIndexes = {};
  bool selectionMode = false;
  bool _isProcessingQr = false;

  @override
  void initState() {
    super.initState();
    loadTransactions();
  }

  Future<void> loadTransactions() async {
    final startDate = DateTime(currentMonth.year, currentMonth.month, 1);
    final endDate = DateTime(currentMonth.year, currentMonth.month + 1, 0);
    final txData = await DataService.getTransactions(startDate: startDate, endDate: endDate);
    final budgetData = await DataService.getBudgets();
    final categoryData = await DataService.getCategories();
    final accountData = await DataService.getAccounts();

    setState(() {
      transactions = txData;
      budgets = budgetData;
      DataStore.categories = categoryData;
      DataStore.accounts = accountData;
    });

    await WidgetSyncService.syncFromStoredConfiguration();
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
      if ((account['type'] ?? '').toString() != 'expense') continue;
      selectedAccount = account['name']?.toString();
      if (selectedAccount != null && selectedAccount!.isNotEmpty) break;
    }

    String? selectedCategory;
    for (final category in DataStore.categories) {
      if ((category['type'] ?? '').toString() != 'expense') continue;
      selectedCategory = category['name']?.toString();
      if (selectedCategory != null && selectedCategory!.isNotEmpty) break;
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
            final expenseAccounts = DataStore.accounts
                .where((acc) => (acc['type'] ?? '').toString() == 'expense')
                .toList();
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
                        const Text(
                          'Add Expense from QR',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          initialValue: 'Expense',
                          readOnly: true,
                          decoration: const InputDecoration(labelText: 'Type'),
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
                          decoration: const InputDecoration(labelText: 'Account'),
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
                          decoration: const InputDecoration(labelText: 'Category'),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: commentController,
                          minLines: 1,
                          maxLines: 3,
                          decoration: const InputDecoration(labelText: 'Comments'),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: amountController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          readOnly: lockAmountField,
                          decoration: InputDecoration(
                            labelText: 'Amount',
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

    final prefs = await SharedPreferences.getInstance();
    final storedDefault = prefs.getString(_defaultPaymentPackageKey);

    final smartApps = await _getSmartPaymentApps();
    if (!mounted) return null;

    final packageToLaunch = await _showPaymentAppPicker(
      smartApps: smartApps,
      defaultPackage: storedDefault,
    );
    if (!mounted || packageToLaunch == null) return null;

    final launched = await _launchQrInApp(packageToLaunch, payloadWithAmount);
    if (!mounted) return null;

    if (!launched) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selected app cannot open this QR payload. Please choose another app.'),
        ),
      );
      return null;
    }

    await prefs.setString(_defaultPaymentPackageKey, packageToLaunch);
    return payloadWithAmount;
  }

  Future<List<AppInfo>> _getSmartPaymentApps() async {
    final now = DateTime.now();
    if (_smartAppsCache != null &&
        _smartAppsCacheTime != null &&
        now.difference(_smartAppsCacheTime!) <= _appsCacheTtl) {
      return _smartAppsCache!;
    }

    final installed = await _getInstalledAppsCached();
    final allApps = installed.where((app) {
      final name = app.name.toLowerCase();
      final package = app.packageName.toLowerCase();
      return name.contains('pay') ||
          name.contains('upi') ||
          name.contains('bank') ||
          package.contains('pay') ||
          package.contains('upi') ||
          package.contains('bank') ||
          package.contains('gpay') ||
          package.contains('phonepe');
    }).toList();

    const prioritizedPackages = <String>[
      'com.google.android.apps.nbu.paisa.user',
      'com.phonepe.app',
      'net.one97.paytm',
      'in.org.npci.upiapp',
      'com.amazon.mShop.android.shopping',
      'com.freecharge.android',
      'com.mobikwik_new',
    ];

    allApps.sort((a, b) {
      final aPriority = prioritizedPackages.indexOf(a.packageName);
      final bPriority = prioritizedPackages.indexOf(b.packageName);
      final normalizedA = aPriority == -1 ? 999 : aPriority;
      final normalizedB = bPriority == -1 ? 999 : bPriority;
      if (normalizedA != normalizedB) {
        return normalizedA.compareTo(normalizedB);
      }
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });

    _smartAppsCache = allApps;
    _smartAppsCacheTime = now;
    return allApps;
  }

  Future<String?> _showPaymentAppPicker({
    required List<AppInfo> smartApps,
    required String? defaultPackage,
  }) async {
    String? selectedPackage = defaultPackage;
    final selectedFromSmart = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Align(
                      alignment: Alignment.center,
                      child: Text(
                        'Pay with app',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (smartApps.isEmpty)
                      const Text('No expected payment apps found with smart logic.')
                    else
                      SizedBox(
                        height: 300,
                        child: SingleChildScrollView(
                          child: Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: smartApps.map((app) {
                              final isSelected = selectedPackage == app.packageName;
                              return _PaymentAppTile(
                                iconBytes: app.icon,
                                selected: isSelected,
                                onTap: () {
                                  setSheetState(() => selectedPackage = app.packageName);
                                },
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final picked = await _showFullInstalledAppsPicker(defaultPackage);
                        if (picked == null) return;
                        if (!sheetContext.mounted) return;
                        Navigator.pop(sheetContext, picked);
                      },
                      icon: const Icon(Icons.apps),
                      label: const Text('Choose another app from phone'),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(sheetContext),
                          child: const Text('Cancel'),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          onPressed: selectedPackage == null
                              ? null
                              : () => Navigator.pop(sheetContext, selectedPackage),
                          child: const Text('Continue'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    return selectedFromSmart;
  }

  Future<String?> _showFullInstalledAppsPicker(String? defaultPackage) async {
    final allApps = await _getInstalledAppsCached();
    allApps.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    if (!mounted) return null;

    String? selectedPackage = defaultPackage;
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Select app from phone',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: RadioGroup<String>(
                        groupValue: selectedPackage,
                        onChanged: (value) {
                          setSheetState(() => selectedPackage = value);
                        },
                        child: ListView.builder(
                          itemCount: allApps.length,
                          itemBuilder: (_, index) {
                            final app = allApps[index];
                            return RadioListTile<String>(
                              value: app.packageName,
                              secondary: _AppIcon(bytes: app.icon),
                              title: Text(app.name),
                              subtitle: Text(app.packageName),
                            );
                          },
                        ),
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(sheetContext),
                          child: const Text('Back'),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          onPressed: selectedPackage == null
                              ? null
                              : () => Navigator.pop(sheetContext, selectedPackage),
                          child: const Text('Use app'),
                        ),
                      ],
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

  Future<List<AppInfo>> _getInstalledAppsCached() async {
    final now = DateTime.now();
    if (_installedAppsCache != null &&
        _installedAppsCacheTime != null &&
        now.difference(_installedAppsCacheTime!) <= _appsCacheTtl) {
      return List<AppInfo>.from(_installedAppsCache!);
    }

    final installed = await InstalledApps.getInstalledApps(true, true);
    _installedAppsCache = installed;
    _installedAppsCacheTime = now;
    return List<AppInfo>.from(installed);
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

  Future<bool> _launchQrInApp(String packageName, String qrPayload) async {
    try {
      final intent = AndroidIntent(
        action: 'android.intent.action.VIEW',
        data: qrPayload,
        package: packageName,
      );
      await intent.launch();
      return true;
    } catch (_) {
      return false;
    }
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
      floatingActionButton: selectionMode
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
                      try {
                        await DataService.insertTransaction(
                          result["title"],
                          result["amount"],
                          result["date"],
                          result["type"],
                          (result["account"] ?? '').toString(),
                          (result["comment"] ?? '').toString(),
                        );
                        loadTransactions();
                      } catch (e) {
                        if (mounted) {
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
            ),
            MiniProgressBar(
              expense: middleValue,
              reference: leftValue,
            ),
            Expanded(
              child: SectionTile(
                child: filteredTransactions.isEmpty
                    ? const Center(child: Text("No transactions"))
                    : ListView.builder(
                        padding: EdgeInsets.zero,
                        itemCount: filteredTransactions.length,
                        itemBuilder: (context, index) {
                          final tx = filteredTransactions[index];
                          final date = DateTime.parse(tx["date"]);
                          final previousTx = index > 0 ? filteredTransactions[index - 1] : null;
                          final previousDate = previousTx != null
                              ? DateTime.parse(previousTx["date"])
                              : null;
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
                                onLongPress: () {
                                  setState(() {
                                    selectionMode = true;
                                    selectedIndexes.add(index);
                                  });
                                },
                                onTap: () async {
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
                      ),
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

class _AppIcon extends StatelessWidget {
  final dynamic bytes;
  const _AppIcon({required this.bytes});

  @override
  Widget build(BuildContext context) {
    if (bytes is! Uint8List || (bytes as Uint8List).isEmpty) {
      return const Icon(Icons.android);
    }
    return Image.memory(
      bytes as Uint8List,
      width: 28,
      height: 28,
      errorBuilder: (_, __, ___) => const Icon(Icons.android),
    );
  }
}

class _PaymentAppTile extends StatelessWidget {
  final Uint8List? iconBytes;
  final bool selected;
  final VoidCallback onTap;

  const _PaymentAppTile({
    required this.iconBytes,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        width: 76,
        height: 76,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? Theme.of(context).colorScheme.primary : Colors.grey.shade300,
            width: selected ? 2 : 1,
          ),
          color: selected
              ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.08)
              : null,
        ),
        padding: const EdgeInsets.all(10),
        child: _AppIcon(bytes: iconBytes),
      ),
    );
  }
}
