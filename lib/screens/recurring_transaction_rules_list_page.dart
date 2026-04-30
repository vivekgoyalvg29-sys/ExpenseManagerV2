import 'package:flutter/material.dart';

import '../services/data_service.dart';
import '../services/data_store.dart';
import '../services/recurring_expense_service.dart';
import '../services/widget_sync_service.dart';
import 'recurring_rule_editor_page.dart';

/// List-first screen for recurring rules (menu opens here).
class RecurringTransactionRulesListPage extends StatefulWidget {
  const RecurringTransactionRulesListPage({super.key});

  @override
  State<RecurringTransactionRulesListPage> createState() =>
      _RecurringTransactionRulesListPageState();
}

class _RecurringTransactionRulesListPageState
    extends State<RecurringTransactionRulesListPage> {
  bool _loading = true;
  List<Map<String, dynamic>> _masters = [];
  Set<int> _selectedRows = {};
  bool _selectionMode = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final m = await DataService.getRecurringMasters();
    final accounts = await DataService.getAccounts();
    final categories = await DataService.getCategories();
    if (!mounted) return;
    setState(() {
      _masters = m;
      DataStore.replaceAccounts(accounts);
      DataStore.replaceCategories(categories);
      _loading = false;
    });
  }

  Future<void> _openEditor({Map<String, dynamic>? existing}) async {
    if (DataStore.viewerReadOnly) {
      DataStore.showViewerReadOnlyNotice(context);
      return;
    }
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => RecurringRuleEditorPage(existingMaster: existing),
      ),
    );
    if (changed == true && mounted) await _load();
  }

  Future<void> _deleteSelected() async {
    if (_selectedRows.isEmpty) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete rules?'),
        content: Text(
          'Remove ${_selectedRows.length} rule(s)? Past transactions are not deleted.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await DataService.deleteRecurringMastersMany(_selectedRows);
    setState(() {
      _selectedRows.clear();
      _selectionMode = false;
    });
    await _load();
    await WidgetSyncService.syncFromStoredConfiguration();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final income = _masters.where((m) => (m['type'] ?? '') == 'income').toList();
    final expense = _masters.where((m) => (m['type'] ?? '') != 'income').toList();

    return Scaffold(
      appBar: AppBar(
        leading: _selectionMode
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => setState(() {
                  _selectionMode = false;
                  _selectedRows.clear();
                }),
              )
            : null,
        title: Text(
          'Recurring Transaction Rules',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            fontSize: 22,
          ),
        ),
        actions: [
          if (_selectionMode && _selectedRows.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: _deleteSelected,
              tooltip: 'Delete selected',
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : DataStore.viewerReadOnly
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'View-only access to this shared book. Rules cannot be edited.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyLarge,
                    ),
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 12, 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'All Rules',
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          IconButton.filledTonal(
                            onPressed: () => _openEditor(),
                            icon: const Icon(Icons.add),
                            tooltip: 'Add rule',
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: _masters.isEmpty
                          ? Center(
                              child: Text(
                                'No rules yet. Tap + to add a transaction rule.',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            )
                          : ListView(
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              children: [
                                if (income.isNotEmpty) ...[
                                  _sectionHeader(context, 'Income'),
                                  ...income.map((r) => _ruleTile(theme, r)),
                                ],
                                if (expense.isNotEmpty) ...[
                                  _sectionHeader(context, 'Expense'),
                                  ...expense.map((r) => _ruleTile(theme, r)),
                                ],
                              ],
                            ),
                    ),
                  ],
                ),
    );
  }

  Widget _sectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 6),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.primary,
            ),
      ),
    );
  }

  Widget _ruleTile(ThemeData theme, Map<String, dynamic> row) {
    final id = row['id'] as int;
    final selected = _selectedRows.contains(id);
    final line = formatRuleSummaryFromMasterRow(row);
    return ListTile(
      selected: selected,
      dense: true,
      leading: _selectionMode
          ? Checkbox(
              value: selected,
              onChanged: (v) {
                setState(() {
                  if (v == true) {
                    _selectedRows.add(id);
                  } else {
                    _selectedRows.remove(id);
                  }
                });
              },
            )
          : null,
      title: Text(
        line,
        style: theme.textTheme.bodySmall,
      ),
      onTap: () {
        if (_selectionMode) {
          setState(() {
            if (selected) {
              _selectedRows.remove(id);
            } else {
              _selectedRows.add(id);
            }
          });
          return;
        }
        _openEditor(existing: row);
      },
      onLongPress: () {
        if (DataStore.viewerReadOnly) return;
        setState(() {
          _selectionMode = true;
          _selectedRows.add(id);
        });
      },
    );
  }
}
