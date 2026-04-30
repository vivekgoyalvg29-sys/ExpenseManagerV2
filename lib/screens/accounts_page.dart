import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/account_subscription_service.dart';
import '../services/data_store.dart';
import '../services/data_service.dart';
import '../services/default_seed_icons.dart';
import '../services/entitlement_service.dart';
import '../services/icon_storage_service.dart';
import '../utils/aggregation_date_range.dart';
import '../utils/indian_number_formatter.dart';
import '../widgets/aggregation_section_header.dart';
import '../widgets/grouped_list_section.dart';
import '../widgets/icon_utils.dart';
import '../widgets/month_options_menu_button.dart';
import '../widgets/month_summary.dart';
import '../widgets/page_content_layout.dart';
import '../widgets/section_tile.dart';
import '../widgets/segmented_toggle.dart';
import '../widgets/side_overlay_sheet.dart';
import 'account_transactions_page.dart';
import 'analysis_page.dart';
import 'pro_purchase_flow.dart';

/// Create/edit account dialog (same UI as Accounts page). Returns saved name on success.
Future<String?> showAccountEditorDialog(
  BuildContext context, {
  Map<String, dynamic>? account,
  required Future<void> Function() afterSave,
}) async {
  final pageContext = context;
  final controller = TextEditingController(text: account?['name']);
  final isEdit = account != null;
  int selectedIcon = account?['icon'] ?? selectableIcons.first.codePoint;
  String? customIconPath = account?['icon_path']?.toString();
  var tierRefreshKey = 0;

  final result = await showDialog<String?>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, setDialogState) {
        bool saving = false;
        return StatefulBuilder(
          builder: (dialogContext, setInnerState) {
            final fieldLabelStyle = Theme.of(dialogContext).textTheme.bodyMedium;
            final fieldTextStyle = Theme.of(dialogContext).textTheme.bodyLarge;
            return AlertDialog(
              title: Text(
                isEdit ? 'Edit Account' : 'Create Account',
                style: Theme.of(dialogContext).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: controller,
                      onChanged: (_) => setDialogState(() {}),
                      style: fieldTextStyle,
                      decoration: InputDecoration(
                        labelText: 'Account Name',
                        labelStyle: fieldLabelStyle,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Icon',
                        style: Theme.of(dialogContext).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: selectableIcons.map((icon) {
                        final selected = customIconPath == null && selectedIcon == icon.codePoint;
                        return InkWell(
                          onTap: () => setDialogState(() {
                            selectedIcon = icon.codePoint;
                            customIconPath = null;
                          }),
                          child: CircleAvatar(
                            backgroundColor: selected ? Colors.green : Colors.grey.shade300,
                            child: Icon(
                              icon,
                              color: selected ? Colors.white : Theme.of(dialogContext).colorScheme.onSurface,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Default sample icons',
                        style: Theme.of(dialogContext).textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: DefaultSeedIcons.accountSamplePathsForEditor(
                        typedName: controller.text,
                        originalName: account?['name']?.toString(),
                      ).map((path) {
                        final selected = customIconPath == path;
                        return InkWell(
                          onTap: () => setDialogState(() {
                            customIconPath = path;
                          }),
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: selected ? Colors.green : Colors.transparent,
                                width: 2,
                              ),
                            ),
                            child: AppPageIcon(
                              icon: iconFromCodePoint(selectedIcon),
                              imagePath: path,
                              size: 18,
                              boxSize: 36,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 14),
                    InkWell(
                      onTap: () async {
                        if (await EntitlementService.getCurrentTier() == UserTier.pro) {
                          final picked = await IconStorageService.pickAndStoreIconImage();
                          if (picked == null) return;
                          setDialogState(() => customIconPath = picked);
                          return;
                        }
                        await ensureSignedInThenProComparisonAndPurchase(pageContext);
                        await AccountSubscriptionService.syncEntitlementFromFirestore();
                        if (!pageContext.mounted) return;
                        setDialogState(() => tierRefreshKey++);
                        if (await EntitlementService.getCurrentTier() != UserTier.pro) {
                          return;
                        }
                        final picked = await IconStorageService.pickAndStoreIconImage();
                        if (picked == null) return;
                        setDialogState(() => customIconPath = picked);
                      },
                      child: FutureBuilder<UserTier>(
                        key: ValueKey(tierRefreshKey),
                        future: EntitlementService.getCurrentTier(),
                        builder: (context, snap) {
                          final pro = snap.data == UserTier.pro;
                          return Row(
                            children: [
                              Expanded(
                                child: Text(
                                  pro ? 'Choose from gallery' : 'Choose from gallery (Pro)',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                                ),
                              ),
                              if (customIconPath != null)
                                IconButton(
                                  icon: const Icon(Icons.close, size: 18),
                                  onPressed: () => setDialogState(() => customIconPath = null),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                )
                              else
                                const Icon(Icons.photo_library_outlined, size: 22),
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: saving ? null : () => Navigator.pop(dialogContext, null),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: saving
                      ? null
                      : () async {
                          if (controller.text.trim().isEmpty) return;
                          setInnerState(() => saving = true);
                          try {
                            const unifiedType = 'expense';
                            final name = controller.text.trim();
                            if (!isEdit) {
                              await DataService.insertAccount(
                                name,
                                unifiedType,
                                selectedIcon,
                                iconPath: customIconPath,
                              );
                            } else {
                              await DataService.updateAccount(
                                account['id'] as int,
                                name,
                                (account['type'] ?? unifiedType).toString(),
                                selectedIcon,
                                iconPath: customIconPath,
                              );
                            }
                            if (!dialogContext.mounted) return;
                            Navigator.pop(dialogContext, name);
                            await afterSave();
                          } catch (e) {
                            setInnerState(() => saving = false);
                            if (pageContext.mounted) {
                              ScaffoldMessenger.of(pageContext).showSnackBar(
                                SnackBar(content: Text('Could not save account: $e')),
                              );
                            }
                          }
                        },
                  child: saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    ),
  );
  controller.dispose();
  return result;
}

class _AccountMetrics {
  double inSum = 0;
  double outSum = 0;
}

class AccountsPage extends StatefulWidget {
  const AccountsPage({super.key});

  @override
  State<AccountsPage> createState() => _AccountsPageState();
}

class _AccountsPageState extends State<AccountsPage> {
  static const _accountsModeKey = 'accounts.aggregationMode';
  static const _accountsShowPctKey = 'accounts.showPercentage';

  /// Account row ids (stable; avoids `indexOf` on maps failing when references differ).
  Set<int> selectedAccountIds = {};
  bool selectionMode = false;

  DateTime currentMonth = DateTime.now();
  AnalysisMode accountsMode = AnalysisMode.cumulativeToSelectedMonth;
  bool showPercentage = true;

  List<Map<String, dynamic>> _transactions = [];
  bool _txLoading = true;

  UserTier _optionsSheetTier = UserTier.free;

  @override
  void initState() {
    super.initState();
    DataStore.transactionMutationGeneration.addListener(_onBookDataMutation);
    DataStore.profileSwitchGeneration.addListener(_onProfileSwitch);
    _restorePreferences();
  }

  Future<void> _restorePreferences() async {
    final prefs = await SharedPreferences.getInstance();
    accountsMode =
        AnalysisMode.values[prefs.getInt(_accountsModeKey) ?? accountsMode.index];
    showPercentage = prefs.getBool(_accountsShowPctKey) ?? showPercentage;
    final tier = await EntitlementService.getCurrentTier();
    if (tier != UserTier.pro &&
        (accountsMode == AnalysisMode.cumulativeToSelectedMonth ||
            accountsMode == AnalysisMode.cumulativeYear)) {
      accountsMode = AnalysisMode.selectedMonth;
      await prefs.setInt(_accountsModeKey, accountsMode.index);
    }
    if (!mounted) return;
    setState(() {});
    await _reloadTransactionsAndAccounts();
  }

  Future<void> _persistPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_accountsModeKey, accountsMode.index);
    await prefs.setBool(_accountsShowPctKey, showPercentage);
  }

  Future<void> _applyPreferenceChange(VoidCallback updateParent) async {
    updateParent();
    await _persistPreferences();
    await _reloadTransactionsAndAccounts();
  }

  Future<void> _trySetAccountsAggregation(
    AnalysisMode value,
    BuildContext pageContext,
    StateSetter setModalState,
    Future<void> Function(VoidCallback) applyChanges,
  ) async {
    final needsPro = value == AnalysisMode.cumulativeToSelectedMonth ||
        value == AnalysisMode.cumulativeYear;
    if (needsPro) {
      if (await EntitlementService.getCurrentTier() != UserTier.pro) {
        final ok = await ensureSignedInThenProComparisonAndPurchase(pageContext);
        if (!mounted || !pageContext.mounted) return;
        if (ok) {
          await AccountSubscriptionService.syncEntitlementFromFirestore();
        }
        if (!mounted || !pageContext.mounted) return;
        if (await EntitlementService.getCurrentTier() != UserTier.pro) {
          setModalState(() {});
          return;
        }
        setState(() => _optionsSheetTier = UserTier.pro);
        setModalState(() {});
      }
    }
    await applyChanges(() => accountsMode = value);
  }

  Future<void> _showAccountsOptions() async {
    final t = await EntitlementService.getCurrentTier();
    if (!mounted) return;
    setState(() => _optionsSheetTier = t);
    final pageContext = context;
    showSideOverlaySheet<void>(
      context: context,
      direction: SideOverlayDirection.right,
      builder: (drawerContext) {
        return StatefulBuilder(
          builder: (modalContext, setModalState) {
            Future<void> applyChanges(VoidCallback updateParent) async {
              await _applyPreferenceChange(() {
                setState(updateParent);
                setModalState(() {});
              });
            }

            return ListView(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 8, 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Accounts options',
                          style: Theme.of(modalContext).textTheme.headlineSmall?.copyWith(
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
                AggregationSectionHeader(showProBadge: _optionsSheetTier != UserTier.pro),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: SegmentedToggle<AnalysisMode>(
                    options: const [
                      SegmentedToggleOption(value: AnalysisMode.selectedMonth, label: 'Month'),
                      SegmentedToggleOption(
                          value: AnalysisMode.cumulativeToSelectedMonth, label: 'Till month'),
                      SegmentedToggleOption(value: AnalysisMode.cumulativeYear, label: 'Year'),
                    ],
                    selectedValue: accountsMode,
                    onChanged: (value) =>
                        _trySetAccountsAggregation(value, pageContext, setModalState, applyChanges),
                  ),
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

  void _onBookDataMutation() {
    if (mounted) _reloadTransactionsAndAccounts();
  }

  void _onProfileSwitch() {
    if (!mounted) return;
    final n = DateTime.now();
    setState(() => currentMonth = DateTime(n.year, n.month));
    _reloadTransactionsAndAccounts();
  }

  @override
  void dispose() {
    DataStore.transactionMutationGeneration.removeListener(_onBookDataMutation);
    DataStore.profileSwitchGeneration.removeListener(_onProfileSwitch);
    super.dispose();
  }

  Future<void> loadAccounts() async {
    final data = await DataService.getAccounts();
    if (mounted) {
      setState(() => DataStore.replaceAccounts(data));
    }
  }

  Future<void> _reloadTransactionsAndAccounts() async {
    setState(() => _txLoading = true);
    final range = dateRangeInclusiveForAggregation(currentMonth, accountsMode);
    final data = await DataService.getAccounts();
    final txs = await DataService.getTransactions(startDate: range.$1, endDate: range.$2);
    if (!mounted) return;
    setState(() {
      DataStore.replaceAccounts(data);
      _transactions = txs;
      _txLoading = false;
    });
  }

  Map<String, _AccountMetrics> _metricsByAccountName() {
    final map = <String, _AccountMetrics>{};
    for (final t in _transactions) {
      final accName = (t['account'] ?? '').toString().trim();
      if (accName.isEmpty) continue;
      final m = map.putIfAbsent(accName, _AccountMetrics.new);
      final amt = (t['amount'] as num).toDouble();
      final ty = (t['type'] ?? '').toString();
      if (ty == 'income') m.inSum += amt;
      if (ty == 'expense') m.outSum += amt;
    }
    return map;
  }

  double get _totalIncome {
    return _transactions
        .where((t) => (t['type'] ?? '').toString() == 'income')
        .fold<double>(0, (s, t) => s + (t['amount'] as num).toDouble());
  }

  double get _totalExpense {
    return _transactions
        .where((t) => (t['type'] ?? '').toString() == 'expense')
        .fold<double>(0, (s, t) => s + (t['amount'] as num).toDouble());
  }

  void showAddAccountDialog({Map<String, dynamic>? account}) {
    showAccountEditorDialog(
      context,
      account: account,
      afterSave: () async {
        await loadAccounts();
        await _reloadTransactionsAndAccounts();
      },
    );
  }

  void clearSelection() {
    setState(() {
      selectedAccountIds.clear();
      selectionMode = false;
    });
  }

  Future<void> deleteSelected() async {
    for (final id in selectedAccountIds) {
      await DataService.deleteAccount(id);
    }
    clearSelection();
    await loadAccounts();
    await _reloadTransactionsAndAccounts();
  }

  static int _compareAccountFavoriteThenName(
    Map<String, dynamic> a,
    Map<String, dynamic> b,
  ) {
    final fa = DataStore.coerceFavoriteFlag(a['is_favorite']);
    final fb = DataStore.coerceFavoriteFlag(b['is_favorite']);
    if (fa != fb) return fa ? -1 : 1;
    return (a['name'] ?? '')
        .toString()
        .toLowerCase()
        .compareTo((b['name'] ?? '').toString().toLowerCase());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final allAccounts = List<Map<String, dynamic>>.from(DataStore.accounts)
      ..sort(_compareAccountFavoriteThenName);
    final total = allAccounts.length;
    final metrics = _metricsByAccountName();

    final income = _totalIncome;
    final expense = _totalExpense;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      floatingActionButton: DataStore.viewerReadOnly
          ? null
          : selectionMode
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    FloatingActionButton.small(
                      heroTag: 'cancelAccountSelection',
                      onPressed: clearSelection,
                      tooltip: 'Cancel selection',
                      child: const Icon(Icons.close),
                    ),
                    const SizedBox(height: 10),
                    FloatingActionButton.extended(
                      heroTag: 'deleteSelectedAccounts',
                      onPressed: deleteSelected,
                      icon: const Icon(Icons.delete),
                      label: Text('Delete (${selectedAccountIds.length})'),
                    ),
                  ],
                )
              : FloatingActionButton(
                  child: const Icon(Icons.add),
                  onPressed: () => showAddAccountDialog(),
                ),
      body: PageContentLayout(
        child: Column(
          children: [
            MonthSummary(
              currentMonth: currentMonth,
              aggregationSubtitle: aggregationSubtitleForMode(accountsMode),
              onPrev: () {
                setState(() {
                  currentMonth = DateTime(currentMonth.year, currentMonth.month - 1);
                });
                _reloadTransactionsAndAccounts();
              },
              onNext: () {
                setState(() {
                  currentMonth = DateTime(currentMonth.year, currentMonth.month + 1);
                });
                _reloadTransactionsAndAccounts();
              },
              budget: income,
              expense: expense,
              leftLabel: 'Income',
              middleLabel: 'Expense',
              rightLabel: 'Net',
              density: MonthSummaryDensity.compact,
              monthTrailing: MonthOptionsMenuButton(
                onPressed: _showAccountsOptions,
                tooltip: 'Accounts options',
              ),
            ),
            Expanded(
              child: _txLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView(
                      padding: const EdgeInsets.only(bottom: 88),
                      children: [
                        if (total == 0)
                          SectionTile(
                            margin: const EdgeInsets.fromLTRB(12, 6, 12, 6),
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.account_balance_wallet_outlined,
                                  size: 44,
                                  color: cs.onSurfaceVariant.withValues(alpha: 0.55),
                                ),
                                const SizedBox(height: 14),
                                Text(
                                  'No accounts yet',
                                  textAlign: TextAlign.center,
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: cs.onSurface,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Tap + to add an account.',
                                  textAlign: TextAlign.center,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: cs.onSurfaceVariant.withValues(alpha: 0.85),
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          GroupedListSection(
                            title: 'Accounts',
                            itemCount: allAccounts.length,
                            dividerIndent: selectionMode ? 52 : 56,
                            emptyHint: 'No accounts',
                            itemBuilder: (context, i) {
                              final acc = allAccounts[i];
                              final id = acc['id'] as int;
                              final name = (acc['name'] ?? '').toString();
                              final m = metrics[name] ?? _AccountMetrics();
                              final bal = m.inSum - m.outSum;
                              final pct = m.inSum > 0
                                  ? ((m.outSum / m.inSum) * 100).clamp(0, 999).round()
                                  : null;

                              return InkWell(
                                onLongPress: DataStore.viewerReadOnly
                                    ? null
                                    : () => setState(() {
                                          selectionMode = true;
                                          selectedAccountIds.add(id);
                                        }),
                                onTap: () {
                                  if (DataStore.viewerReadOnly && !selectionMode) {
                                    DataStore.showViewerReadOnlyNotice(context);
                                    return;
                                  }
                                  if (selectionMode) {
                                    setState(() => selectedAccountIds.contains(id)
                                        ? selectedAccountIds.remove(id)
                                        : selectedAccountIds.add(id));
                                  } else {
                                    Navigator.of(context).push(
                                      MaterialPageRoute<void>(
                                        builder: (_) => AccountTransactionsPage(
                                          account: acc,
                                          currentMonth: currentMonth,
                                          aggregationMode: accountsMode,
                                        ),
                                      ),
                                    );
                                  }
                                },
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      Row(
                                        children: [
                                          if (selectionMode)
                                            Checkbox(
                                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                              value: selectedAccountIds.contains(id),
                                              onChanged: (v) => setState(() {
                                                if (v == true) {
                                                  selectedAccountIds.add(id);
                                                } else {
                                                  selectedAccountIds.remove(id);
                                                }
                                              }),
                                            )
                                          else
                                            GroupedListIconWell(
                                              child: AppPageIcon(
                                                embedded: true,
                                                icon: iconFromCodePoint(acc['icon'],
                                                    fallback: Icons.account_balance_wallet),
                                                imagePath: acc['icon_path']?.toString(),
                                                size: 22,
                                                boxSize: 28,
                                              ),
                                            ),
                                          Expanded(
                                            child: Text(
                                              name,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: theme.textTheme.bodyLarge?.copyWith(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 15.5,
                                                color: cs.onSurface,
                                              ),
                                            ),
                                          ),
                                          IconButton(
                                            tooltip: 'Favorite',
                                            visualDensity: VisualDensity.compact,
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(
                                                minWidth: 36, minHeight: 36),
                                            onPressed: () async {
                                              if (DataStore.viewerReadOnly) {
                                                DataStore.showViewerReadOnlyNotice(context);
                                                return;
                                              }
                                              final current = acc['is_favorite'] == true;
                                              await DataService.setAccountFavorite(
                                                id: id,
                                                type: (acc['type'] ?? 'expense').toString(),
                                                isFavorite: !current,
                                              );
                                              await loadAccounts();
                                            },
                                            icon: Icon(
                                              (acc['is_favorite'] == true)
                                                  ? Icons.star_rounded
                                                  : Icons.star_outline_rounded,
                                              size: 22,
                                              color: (acc['is_favorite'] == true)
                                                  ? cs.primary
                                                  : cs.onSurfaceVariant.withValues(alpha: 0.65),
                                            ),
                                          ),
                                          if (!selectionMode && !DataStore.viewerReadOnly)
                                            IconButton(
                                              tooltip: 'Edit account',
                                              visualDensity: VisualDensity.compact,
                                              padding: EdgeInsets.zero,
                                              constraints: const BoxConstraints(
                                                  minWidth: 36, minHeight: 36),
                                              onPressed: () => showAddAccountDialog(account: acc),
                                              icon: Icon(
                                                Icons.edit_outlined,
                                                size: 20,
                                                color: cs.onSurfaceVariant.withValues(alpha: 0.85),
                                              ),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Padding(
                                        padding: EdgeInsets.only(
                                          left: selectionMode ? 52 : 40,
                                        ),
                                        child: Row(
                                          crossAxisAlignment: CrossAxisAlignment.end,
                                          children: [
                                            Expanded(
                                              child: Text.rich(
                                                TextSpan(
                                                  style: theme.textTheme.bodySmall?.copyWith(
                                                    fontWeight: FontWeight.w500,
                                                    fontSize: 12,
                                                    height: 1.25,
                                                  ),
                                                  children: [
                                                    TextSpan(
                                                      text: 'In ',
                                                      style: const TextStyle(
                                                        color: Color(0xFF22C55E),
                                                        fontWeight: FontWeight.w600,
                                                      ),
                                                    ),
                                                    TextSpan(
                                                      text: formatIndianCurrency(m.inSum),
                                                      style: const TextStyle(
                                                        color: Color(0xFF22C55E),
                                                        fontWeight: FontWeight.w600,
                                                      ),
                                                    ),
                                                    TextSpan(
                                                      text: '  ·  Out ',
                                                      style: TextStyle(
                                                        color: cs.onSurfaceVariant.withValues(alpha: 0.85),
                                                      ),
                                                    ),
                                                    TextSpan(
                                                      text: formatIndianCurrency(m.outSum),
                                                      style: const TextStyle(
                                                        color: Color(0xFFEF4444),
                                                        fontWeight: FontWeight.w600,
                                                      ),
                                                    ),
                                                    TextSpan(
                                                      text: '  ·  Bal ',
                                                      style: TextStyle(
                                                        color: cs.onSurfaceVariant.withValues(alpha: 0.85),
                                                      ),
                                                    ),
                                                    TextSpan(
                                                      text: formatIndianCurrency(bal),
                                                      style: TextStyle(
                                                        color: bal > 0
                                                            ? const Color(0xFFEAB308)
                                                            : const Color(0xFFF97316),
                                                        fontWeight: FontWeight.w700,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            if (showPercentage)
                                              Padding(
                                                padding: const EdgeInsets.only(left: 8),
                                                child: Text(
                                                  m.inSum > 0 ? '$pct%' : '—',
                                                  textAlign: TextAlign.right,
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w700,
                                                    color: cs.onSurfaceVariant.withValues(alpha: 0.95),
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
