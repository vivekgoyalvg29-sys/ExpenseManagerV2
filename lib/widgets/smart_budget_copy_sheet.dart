import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/data_service.dart';

/// Pro feature: copy expense budgets from one month into future months.
Future<void> showSmartBudgetCopyDialog({
  required BuildContext context,
  required VoidCallback onCopied,
}) async {
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => _SmartBudgetCopyDialog(onCopied: onCopied),
  );
}

List<DateTime> _copyFromMonthChoices() {
  final now = DateTime.now();
  final cur = DateTime(now.year, now.month);
  return List.generate(12, (i) => DateTime(cur.year, cur.month - i));
}

List<DateTime> _copyToMonthChoices() {
  final now = DateTime.now();
  final next = DateTime(now.year, now.month + 1);
  return List.generate(12, (i) => DateTime(next.year, next.month + i));
}

List<String> _categoryNamesWithBudgetInMonth(
  List<Map<String, dynamic>> budgets,
  DateTime month,
) {
  final y = month.year;
  final m = month.month;
  final names = <String>{};
  for (final b in budgets) {
    if ((b['month'] as num?)?.toInt() == m &&
        (b['year'] as num?)?.toInt() == y) {
      names.add((b['category'] as String?) ?? '');
    }
  }
  final list = names.where((n) => n.isNotEmpty).toList()..sort();
  return list;
}

bool _wouldOverwriteExisting(
  List<Map<String, dynamic>> budgets,
  List<String> categories,
  List<DateTime> targetMonths,
) {
  for (final t in targetMonths) {
    for (final c in categories) {
      for (final b in budgets) {
        if ((b['category'] as String?) == c &&
            (b['month'] as num?)?.toInt() == t.month &&
            (b['year'] as num?)?.toInt() == t.year) {
          return true;
        }
      }
    }
  }
  return false;
}

class _SmartBudgetCopyDialog extends StatefulWidget {
  const _SmartBudgetCopyDialog({required this.onCopied});

  final VoidCallback onCopied;

  @override
  State<_SmartBudgetCopyDialog> createState() => _SmartBudgetCopyDialogState();
}

class _SmartBudgetCopyDialogState extends State<_SmartBudgetCopyDialog> {
  /// Index into [_copyFromMonthChoices] (avoids DateTime identity issues in dropdowns).
  int _fromMonthIndex = 0;
  final Map<DateTime, bool> _toSelected = {};
  List<String> _categories = [];
  final Set<String> _selectedCategories = {};
  bool _loading = true;
  bool _applying = false;

  bool _openedCategoriesPicker = false;
  bool _openedCopyToPicker = false;

  DateTime get _fromMonth =>
      _copyFromMonthChoices()[_fromMonthIndex.clamp(0, 11)];

  @override
  void initState() {
    super.initState();
    for (final m in _copyToMonthChoices()) {
      _toSelected[m] = true;
    }
    _reloadCategories();
  }

  Future<void> _reloadCategories() async {
    setState(() => _loading = true);
    try {
      final budgets = await DataService.getBudgets();
      if (!mounted) return;
      final names = _categoryNamesWithBudgetInMonth(budgets, _fromMonth);
      setState(() {
        _categories = names;
        _selectedCategories
          ..clear()
          ..addAll(names);
        _loading = false;
        _openedCategoriesPicker = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openCategoriesSheet() async {
    if (_categories.isEmpty) return;
    setState(() => _openedCategoriesPicker = true);
    final fmt = DateFormat('MMM yyyy');
    final working = Set<String>.from(_selectedCategories);
    final picked = await showModalBottomSheet<Set<String>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
            ),
            child: StatefulBuilder(
              builder: (ctx, setSheet) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Categories (${fmt.format(_fromMonth)})',
                              style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              setSheet(() {
                                if (working.length == _categories.length) {
                                  working.clear();
                                } else {
                                  working
                                    ..clear()
                                    ..addAll(_categories);
                                }
                              });
                            },
                            child: Text(
                              working.length == _categories.length
                                  ? 'Clear all'
                                  : 'Select all',
                            ),
                          ),
                        ],
                      ),
                    ),
                    Flexible(
                      child: ListView(
                        shrinkWrap: true,
                        children: _categories.map((c) {
                          return CheckboxListTile(
                            dense: true,
                            value: working.contains(c),
                            title: Text(c, maxLines: 1, overflow: TextOverflow.ellipsis),
                            onChanged: (v) {
                              setSheet(() {
                                if (v == true) {
                                  working.add(c);
                                } else {
                                  working.remove(c);
                                }
                              });
                            },
                          );
                        }).toList(),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: () => Navigator.pop(ctx, working),
                          child: const Text('Done'),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
    if (picked != null && mounted) {
      setState(() => _selectedCategories
        ..clear()
        ..addAll(picked));
    }
  }

  Future<void> _openCopyToSheet() async {
    setState(() => _openedCopyToPicker = true);
    final toChoices = _copyToMonthChoices();
    final fmt = DateFormat('MMM yyyy');
    final working = <DateTime, bool>{};
    for (final m in toChoices) {
      working[m] = _toSelected[m] ?? false;
    }
    final picked = await showModalBottomSheet<Map<DateTime, bool>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
            ),
            child: StatefulBuilder(
              builder: (ctx, setSheet) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Copy to months',
                              style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              setSheet(() {
                                final allOn = working.values.every((v) => v);
                                for (final m in toChoices) {
                                  working[m] = !allOn;
                                }
                              });
                            },
                            child: Text(
                              working.values.every((v) => v) ? 'Clear all' : 'Select all',
                            ),
                          ),
                        ],
                      ),
                    ),
                    Flexible(
                      child: ListView(
                        shrinkWrap: true,
                        children: toChoices.map((m) {
                          return CheckboxListTile(
                            dense: true,
                            value: working[m] ?? false,
                            title: Text(fmt.format(m)),
                            onChanged: (v) {
                              setSheet(() => working[m] = v ?? false);
                            },
                          );
                        }).toList(),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: () => Navigator.pop(ctx, working),
                          child: const Text('Done'),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
    if (picked != null && mounted) {
      setState(() {
        _toSelected
          ..clear()
          ..addAll(picked);
      });
    }
  }

  Future<void> _runCopy() async {
    final targets =
        _copyToMonthChoices().where((m) => _toSelected[m] == true).toList();
    if (_selectedCategories.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least one category.')),
      );
      return;
    }
    if (targets.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least one destination month.')),
      );
      return;
    }

    final budgets = await DataService.getBudgets();
    if (!mounted) return;

    if (_wouldOverwriteExisting(
      budgets,
      _selectedCategories.toList(),
      targets,
    )) {
      final go = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Replace existing budgets?'),
          content: const Text(
            'Some selected months already have budgets for some of these categories. '
            'Continue to replace them, or go back to change your selection.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Continue'),
            ),
          ],
        ),
      );
      if (go != true || !mounted) return;
    }

    setState(() => _applying = true);
    try {
      await DataService.smartBudgetCopy(
        fromMonth: _fromMonth,
        categories: _selectedCategories.toList(),
        toMonths: targets,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      widget.onCopied();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Budgets copied.')),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not copy budgets: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _applying = false);
    }
  }

  String _copyToDetailLine(DateFormat fmt) {
    final months = _copyToMonthChoices().where((m) => _toSelected[m] == true).toList();
    if (months.isEmpty) return 'No destination months selected.';
    final labels = months.map(fmt.format).toList();
    return 'Copying to: ${labels.join(', ')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fromChoices = _copyFromMonthChoices();
    final fmt = DateFormat('MMM yyyy');

    return AlertDialog(
      title: const Text('Copy budget'),
      content: SizedBox(
        width: double.maxFinite,
        child: _loading
            ? const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              )
            : SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Copy from',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    InputDecorator(
                      decoration: const InputDecoration(
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(),
                      ),
                      child: SizedBox(
                        height: 40,
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<int>(
                            isExpanded: true,
                            value: _fromMonthIndex.clamp(0, fromChoices.length - 1),
                            items: List.generate(
                              fromChoices.length,
                              (i) => DropdownMenuItem(
                                value: i,
                                child: Text(fmt.format(fromChoices[i])),
                              ),
                            ),
                            onChanged: (v) {
                              if (v == null) return;
                              setState(() => _fromMonthIndex = v);
                              _reloadCategories();
                            },
                          ),
                        ),
                      ),
                    ),
                    if (!_loading) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Copying from ${fmt.format(_fromMonth)}.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    Text(
                      'Categories',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: _categories.isEmpty ? null : _openCategoriesSheet,
                      borderRadius: BorderRadius.circular(4),
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          isDense: true,
                          contentPadding: EdgeInsets.fromLTRB(12, 10, 4, 10),
                          border: OutlineInputBorder(),
                          suffixIcon: Icon(Icons.arrow_drop_down),
                        ),
                        child: SizedBox(
                          height: 40,
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Tap to choose',
                              style: theme.textTheme.bodyLarge?.copyWith(
                                color: _categories.isEmpty
                                    ? theme.colorScheme.onSurfaceVariant
                                    : theme.colorScheme.onSurface,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (_openedCategoriesPicker && _categories.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        '${_selectedCategories.length} of ${_categories.length} categories selected.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                    if (_categories.isEmpty && !_loading)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          'No budgets in this month to copy.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.error,
                          ),
                        ),
                      ),
                    const SizedBox(height: 12),
                    Text(
                      'Copy to',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: _openCopyToSheet,
                      borderRadius: BorderRadius.circular(4),
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          isDense: true,
                          contentPadding: EdgeInsets.fromLTRB(12, 10, 4, 10),
                          border: OutlineInputBorder(),
                          suffixIcon: Icon(Icons.arrow_drop_down),
                        ),
                        child: SizedBox(
                          height: 40,
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Tap to choose',
                              style: theme.textTheme.bodyLarge,
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (_openedCopyToPicker) ...[
                      const SizedBox(height: 4),
                      Text(
                        _copyToDetailLine(fmt),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
      ),
      actions: [
        TextButton(
          onPressed: _applying ? null : () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
        FilledButton(
          onPressed: _applying || _loading || _categories.isEmpty
              ? null
              : _runCopy,
          child: _applying
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Copy'),
        ),
      ],
    );
  }
}
