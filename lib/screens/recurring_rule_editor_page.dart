import 'package:flutter/material.dart';

import '../services/data_service.dart';
import '../services/data_store.dart';
import '../services/recurring_expense_service.dart';
import '../services/recurring_schedule.dart';
import '../services/widget_sync_service.dart';

/// Add/edit a single recurring transaction rule; list-first flow opens this from +.
class RecurringRuleEditorPage extends StatefulWidget {
  const RecurringRuleEditorPage({super.key, this.existingMaster});

  final Map<String, dynamic>? existingMaster;

  @override
  State<RecurringRuleEditorPage> createState() => _RecurringRuleEditorPageState();
}

class _RecurringRuleEditorPageState extends State<RecurringRuleEditorPage> {
  final _amountController = TextEditingController();
  final _commentController = TextEditingController();

  String _transactionType = 'expense';
  String? _account;
  String? _category;
  String _scheduleKind = RecurringScheduleKind.monthlyDay;
  int _dayOfMonth = 1;
  int _monthOrdinal = 1;
  int _monthWeekday = DateTime.monday;
  int _weeklyWeekday = DateTime.monday;

  int? _editingId;
  bool _loading = true;
  final List<String> _sessionSummaries = [];

  static const _fieldStyle = VisualDensity.compact;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final accounts = await DataService.getAccounts();
    final categories = await DataService.getCategories();
    if (!mounted) return;
    DataStore.replaceAccounts(accounts);
    DataStore.replaceCategories(categories);
    if (widget.existingMaster != null) {
      _fillFromMaster(widget.existingMaster!);
    }
    setState(() => _loading = false);
  }

  @override
  void dispose() {
    _amountController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  void _resetForm() {
    _editingId = null;
    _amountController.clear();
    _commentController.clear();
    _transactionType = 'expense';
    _account = null;
    _category = null;
    _scheduleKind = RecurringScheduleKind.monthlyDay;
    _dayOfMonth = 1;
    _monthOrdinal = 1;
    _monthWeekday = DateTime.monday;
    _weeklyWeekday = DateTime.monday;
  }

  void _fillFromMaster(Map<String, dynamic> row) {
    _editingId = row['id'] as int?;
    _transactionType = (row['type'] ?? 'expense').toString();
    _account = row['account']?.toString();
    _category = row['title']?.toString();
    _commentController.text = row['comment']?.toString() ?? '';
    _amountController.text = (row['amount'] as num?)?.toString() ?? '';
    _scheduleKind = (row['schedule_kind'] ?? RecurringScheduleKind.monthlyDay).toString();
    final sched = parseScheduleJson((row['schedule_json'] ?? '{}').toString());
    _dayOfMonth = (sched['day'] as num?)?.toInt() ?? 1;
    _monthOrdinal = (sched['ordinal'] as num?)?.toInt() ?? 1;
    final wd = (sched['weekday'] as num?)?.toInt() ?? DateTime.monday;
    if (_scheduleKind == RecurringScheduleKind.weekly) {
      _weeklyWeekday = wd;
    } else {
      _monthWeekday = wd;
    }
  }

  Map<String, dynamic> _buildScheduleMap() {
    switch (_scheduleKind) {
      case RecurringScheduleKind.monthlyDay:
        return scheduleMonthlyDayJson(_dayOfMonth);
      case RecurringScheduleKind.monthlyWeekday:
        return scheduleMonthlyWeekdayJson(ordinal: _monthOrdinal, weekday: _monthWeekday);
      case RecurringScheduleKind.weekly:
        return scheduleWeeklyJson(_weeklyWeekday);
      default:
        return scheduleMonthlyDayJson(1);
    }
  }

  Future<void> _saveMaster({required bool closeAfter}) async {
    if (DataStore.viewerReadOnly) {
      DataStore.showViewerReadOnlyNotice(context);
      return;
    }
    if (_account == null || _category == null || _amountController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choose account, category, and amount.')),
      );
      return;
    }
    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid amount.')),
      );
      return;
    }
    final map = _buildScheduleMap();
    final wasEditing = _editingId != null;
    try {
      if (_editingId != null) {
        await DataService.updateRecurringMaster(
          id: _editingId!,
          title: _category!,
          amount: amount,
          type: _transactionType,
          account: _account!,
          comment: _commentController.text.trim(),
          scheduleKind: _scheduleKind,
          scheduleMap: map,
        );
      } else {
        await DataService.insertRecurringMaster(
          title: _category!,
          amount: amount,
          type: _transactionType,
          account: _account!,
          comment: _commentController.text.trim(),
          scheduleKind: _scheduleKind,
          scheduleMap: map,
        );
      }
      await WidgetSyncService.syncFromStoredConfiguration();
      if (!mounted) return;

      final summary = formatRuleSummaryParts(
        scheduleSummary: describeSchedule(_scheduleKind, map),
        category: _category!,
        amount: amount,
        account: _account!,
        comment: _commentController.text.trim(),
      );
      if (closeAfter) {
        if (!mounted) return;
        Navigator.of(context).pop(true);
        return;
      }
      setState(() {
        if (!wasEditing) _sessionSummaries.add(summary);
        _resetForm();
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(wasEditing ? 'Updated.' : 'Saved.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save: $e')),
        );
      }
    }
  }

  Future<void> _openSelector({required bool isAccount}) async {
    final entries = (isAccount ? DataStore.accounts : DataStore.categories)
        .where((item) => isAccount || item['type'] == _transactionType)
        .toList();
    final selected = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          isAccount ? 'Select account' : 'Select category',
                          style: Theme.of(dialogContext).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        icon: const Icon(Icons.close, size: 20),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                SizedBox(
                  height: 240,
                  child: ListView.builder(
                    itemCount: entries.length,
                    itemBuilder: (context, index) {
                      final item = entries[index];
                      return ListTile(
                        title: Text(item['name'].toString()),
                        onTap: () => Navigator.pop(dialogContext, item['name'].toString()),
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
    if (selected == null) return;
    setState(() {
      if (isAccount) {
        _account = selected;
      } else {
        _category = selected;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final labelStyle = theme.textTheme.bodyMedium;
    final isEdit = _editingId != null;

    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Transaction Rule')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isEdit ? 'Edit Transaction Rule' : 'Add Transaction Rule',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            fontSize: 22,
          ),
        ),
      ),
      body: DataStore.viewerReadOnly
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'View-only access. You cannot edit rules.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge,
                ),
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        DropdownButtonFormField<String>(
                          initialValue: _transactionType,
                          items: const [
                            DropdownMenuItem(value: 'expense', child: Text('Expense')),
                            DropdownMenuItem(value: 'income', child: Text('Income')),
                          ],
                          onChanged: (v) => setState(() {
                            _transactionType = v!;
                            _account = null;
                            _category = null;
                          }),
                          decoration: InputDecoration(
                            labelText: 'Type',
                            labelStyle: labelStyle,
                            visualDensity: _fieldStyle,
                          ),
                        ),
                        const SizedBox(height: 10),
                        InkWell(
                          onTap: () => _openSelector(isAccount: true),
                          child: InputDecorator(
                            decoration: InputDecoration(
                              labelText: 'Account',
                              labelStyle: labelStyle,
                              visualDensity: _fieldStyle,
                            ),
                            child: Text(_account ?? 'Tap to choose'),
                          ),
                        ),
                        const SizedBox(height: 10),
                        InkWell(
                          onTap: () => _openSelector(isAccount: false),
                          child: InputDecorator(
                            decoration: InputDecoration(
                              labelText: 'Category',
                              labelStyle: labelStyle,
                              visualDensity: _fieldStyle,
                            ),
                            child: Text(_category ?? 'Tap to choose'),
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _commentController,
                          minLines: 1,
                          maxLines: 2,
                          decoration: InputDecoration(
                            labelText: 'Comment',
                            labelStyle: labelStyle,
                            visualDensity: _fieldStyle,
                            alignLabelWithHint: true,
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _amountController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(
                            labelText: 'Amount',
                            labelStyle: labelStyle,
                            visualDensity: _fieldStyle,
                          ),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          initialValue: _scheduleKind,
                          items: const [
                            DropdownMenuItem(
                              value: RecurringScheduleKind.monthlyDay,
                              child: Text('Day of each month'),
                            ),
                            DropdownMenuItem(
                              value: RecurringScheduleKind.monthlyWeekday,
                              child: Text('Weekday of each month'),
                            ),
                            DropdownMenuItem(
                              value: RecurringScheduleKind.weekly,
                              child: Text('Every week'),
                            ),
                          ],
                          onChanged: (v) => setState(() => _scheduleKind = v!),
                          decoration: InputDecoration(
                            labelText: 'Schedule',
                            labelStyle: labelStyle,
                            visualDensity: _fieldStyle,
                          ),
                        ),
                        if (_scheduleKind == RecurringScheduleKind.monthlyDay) ...[
                          const SizedBox(height: 10),
                          DropdownButtonFormField<int>(
                            initialValue: _dayOfMonth.clamp(1, 31),
                            items: List.generate(
                              31,
                              (i) => DropdownMenuItem(value: i + 1, child: Text('${i + 1}')),
                            ),
                            onChanged: (v) => setState(() => _dayOfMonth = v ?? 1),
                            decoration: const InputDecoration(
                              labelText: 'Day',
                              isDense: true,
                              visualDensity: _fieldStyle,
                            ),
                          ),
                        ],
                        if (_scheduleKind == RecurringScheduleKind.monthlyWeekday) ...[
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: DropdownButtonFormField<int>(
                                  initialValue: _monthOrdinal,
                                  items: const [
                                    DropdownMenuItem(value: 1, child: Text('First')),
                                    DropdownMenuItem(value: 2, child: Text('Second')),
                                    DropdownMenuItem(value: 3, child: Text('Third')),
                                    DropdownMenuItem(value: 4, child: Text('Fourth')),
                                    DropdownMenuItem(value: -1, child: Text('Last')),
                                  ],
                                  onChanged: (v) => setState(() => _monthOrdinal = v ?? 1),
                                  decoration: const InputDecoration(
                                    labelText: 'Occurrence',
                                    isDense: true,
                                    visualDensity: _fieldStyle,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: DropdownButtonFormField<int>(
                                  initialValue: _monthWeekday,
                                  items: _weekdayItems(),
                                  onChanged: (v) =>
                                      setState(() => _monthWeekday = v ?? DateTime.monday),
                                  decoration: const InputDecoration(
                                    labelText: 'Weekday',
                                    isDense: true,
                                    visualDensity: _fieldStyle,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                        if (_scheduleKind == RecurringScheduleKind.weekly) ...[
                          const SizedBox(height: 10),
                          DropdownButtonFormField<int>(
                            initialValue: _weeklyWeekday,
                            items: _weekdayItems(),
                            onChanged: (v) =>
                                setState(() => _weeklyWeekday = v ?? DateTime.monday),
                            decoration: const InputDecoration(
                              labelText: 'Weekday',
                              isDense: true,
                              visualDensity: _fieldStyle,
                            ),
                          ),
                        ],
                        if (_sessionSummaries.isNotEmpty) ...[
                          const SizedBox(height: 20),
                          Divider(color: theme.colorScheme.outline.withValues(alpha: 0.35)),
                          const SizedBox(height: 8),
                          Text(
                            'Added this session',
                            style: labelStyle?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 8),
                          ..._sessionSummaries.map(
                            (s) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Text(s, style: theme.textTheme.bodySmall),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                Material(
                  elevation: 6,
                  child: SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.of(context).pop(false),
                              child: const Text('Cancel'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: FilledButton.tonal(
                              onPressed: () => _saveMaster(closeAfter: false),
                              child: Text(isEdit ? 'Save' : 'Create'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: FilledButton(
                              onPressed: () => _saveMaster(closeAfter: true),
                              child: Text(isEdit ? 'Save & Close' : 'Create & Close'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  List<DropdownMenuItem<int>> _weekdayItems() {
    const names = [
      '',
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    return List.generate(7, (i) {
      final w = i + 1;
      return DropdownMenuItem(value: w, child: Text(names[w]));
    });
  }
}
