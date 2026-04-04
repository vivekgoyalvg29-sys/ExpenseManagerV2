import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/app_localizations.dart';
import '../services/data_store.dart';
import '../services/data_service.dart';

class AddTransactionPage extends StatefulWidget {
  final Map<String, dynamic>? existingTransaction;
  final Future<void> Function(Map<String, dynamic> result)? onSaveResult;
  final bool modalStyle;

  const AddTransactionPage({
    super.key,
    this.existingTransaction,
    this.onSaveResult,
    this.modalStyle = true,
  });

  @override
  State<AddTransactionPage> createState() => _AddTransactionPageState();
}

class _AddTransactionPageState extends State<AddTransactionPage> {
  DateTime selectedDate = DateTime.now();

  final commentController = TextEditingController();
  final amountController = TextEditingController();
  final _commentFocusNode = FocusNode();

  String transactionType = 'expense';
  String? selectedAccount;
  String? selectedCategory;
  List<String> _existingComments = [];
  List<String> _matchingComments = [];
  bool _showCommentSuggestions = false;

  @override
  void initState() {
    super.initState();
    _commentFocusNode.addListener(() {
      if (!_commentFocusNode.hasFocus && _showCommentSuggestions) {
        setState(() {
          _showCommentSuggestions = false;
          _matchingComments = [];
        });
      }
    });
    _loadData();

    if (widget.existingTransaction != null) {
      commentController.text = (widget.existingTransaction!['comment'] ?? '').toString();
      amountController.text = widget.existingTransaction!['amount'].toString();
      selectedDate = DateTime.parse(widget.existingTransaction!['date']);
      transactionType = (widget.existingTransaction!['type'] ?? 'expense').toString();
      selectedAccount = widget.existingTransaction!['account']?.toString();
      selectedCategory = widget.existingTransaction!['title']?.toString();
    }
  }

  @override
  void dispose() {
    commentController.dispose();
    amountController.dispose();
    _commentFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final accounts = await DataService.getAccounts();
    final categories = await DataService.getCategories();
    final favoriteAccount = await DataService.getFavoriteAccountName(transactionType);
    final favoriteCategory = await DataService.getFavoriteCategoryName(transactionType);
    final existingComments = await DataService.getExistingComments();

    if (!mounted) return;

    setState(() {
      DataStore.accounts = accounts;
      DataStore.categories = categories;
      _existingComments = existingComments;
      if (widget.existingTransaction == null) {
        selectedAccount = favoriteAccount;
        selectedCategory = favoriteCategory;
      }
    });
  }

  void _onCommentChanged(String value) {
    final query = value.trim().toLowerCase();

    if (query.length < 2) {
      setState(() {
        _matchingComments = [];
        _showCommentSuggestions = false;
      });
      return;
    }

    final matches = _existingComments
        .where((comment) => comment.toLowerCase().contains(query))
        .toList();

    setState(() {
      _matchingComments = matches;
      _showCommentSuggestions = matches.isNotEmpty;
    });
  }

  void _selectCommentSuggestion(String comment) {
    commentController.text = comment;
    commentController.selection = TextSelection.fromPosition(
      TextPosition(offset: comment.length),
    );
    setState(() {
      _showCommentSuggestions = false;
      _matchingComments = [];
    });
  }

  Future<void> pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      setState(() {
        selectedDate = picked;
      });
    }
  }

  Future<void> _save() async {
    if (selectedAccount == null || selectedCategory == null || amountController.text.isEmpty) {
      return;
    }

    final amount = double.tryParse(amountController.text) ?? 0;
    final result = {
      'title': selectedCategory,
      'amount': amount,
      'date': selectedDate,
      'type': transactionType,
      'account': selectedAccount,
      'comment': commentController.text.trim(),
    };

    if (widget.onSaveResult != null) {
      await widget.onSaveResult!(result);
      return;
    }

    if (!mounted) return;

    Navigator.pop(context, result);
  }

  Future<void> _openSelector({required bool isAccount}) async {
    final entries = (isAccount ? DataStore.accounts : DataStore.categories)
        .where((item) => item['type'] == transactionType)
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
                  padding: const EdgeInsets.fromLTRB(12, 8, 4, 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          isAccount ? 'Select Account' : 'Select Category',
                          style: Theme.of(dialogContext).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ),
                      IconButton(
                        onPressed: () async {
                          final created = await _showQuickCreateDialog(isAccount: isAccount);
                          if (!mounted) return;
                          if (created == null) return;
                          Navigator.pop(dialogContext, created);
                        },
                        icon: const Icon(Icons.add),
                        tooltip: isAccount ? 'Add account' : 'Add category',
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                SizedBox(
                  height: 220,
                  child: entries.isEmpty
                      ? Center(
                          child: Text(
                            'No items yet. Tap + to add.',
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                        )
                      : ListView.builder(
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
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Close'),
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
        selectedAccount = selected;
      } else {
        selectedCategory = selected;
      }
    });
  }

  Future<String?> _showQuickCreateDialog({required bool isAccount}) async {
    final nameController = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          isAccount ? 'Create Account' : 'Create Category',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        content: TextField(
          controller: nameController,
          autofocus: true,
          style: Theme.of(context).textTheme.bodyLarge,
          decoration: InputDecoration(
            labelText: isAccount ? 'Account Name' : 'Category Name',
            labelStyle: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              final trimmed = nameController.text.trim();
              if (trimmed.isEmpty) return;
              if (isAccount) {
                await DataService.insertAccount(trimmed, transactionType, Icons.account_balance_wallet.codePoint);
              } else {
                await DataService.insertCategory(trimmed, transactionType, Icons.category.codePoint);
              }
              if (!context.mounted) return;
              Navigator.pop(context, trimmed);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    nameController.dispose();
    await _loadData();
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final tr = AppLocalizationsScope.of(context);
    final theme = Theme.of(context);
    final largerFieldLabelStyle = theme.textTheme.bodyMedium;
    final helperTextStyle = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
    );

    final content = SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<String>(
            key: ValueKey(transactionType),
            initialValue: transactionType,
            items: [
              DropdownMenuItem(child: Text(context.tr('Expense')), value: 'expense'),
              DropdownMenuItem(child: Text(context.tr('Income')), value: 'income'),
            ],
            onChanged: (v) async {
              setState(() {
                transactionType = v!;
                selectedCategory = null;
                selectedAccount = null;
              });
              await _loadData();
            },
            decoration: InputDecoration(
              labelText: context.tr('Type'),
              labelStyle: largerFieldLabelStyle,
            ),
          ),
          const SizedBox(height: 10),
          InkWell(
            onTap: () => _openSelector(isAccount: true),
            child: InputDecorator(
              decoration: InputDecoration(
                labelText: context.tr('Account'),
                labelStyle: largerFieldLabelStyle,
              ),
              child: Text(
                selectedAccount ?? 'Tap to choose',
                style: selectedAccount == null ? helperTextStyle : theme.textTheme.bodyMedium,
              ),
            ),
          ),
          const SizedBox(height: 10),
          InkWell(
            onTap: () => _openSelector(isAccount: false),
            child: InputDecorator(
              decoration: InputDecoration(
                labelText: context.tr('Category'),
                labelStyle: largerFieldLabelStyle,
              ),
              child: Text(
                selectedCategory ?? 'Tap to choose',
                style: selectedCategory == null ? helperTextStyle : theme.textTheme.bodyMedium,
              ),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: commentController,
            focusNode: _commentFocusNode,
            textInputAction: TextInputAction.done,
            minLines: 1,
            maxLines: 3,
            onChanged: _onCommentChanged,
            decoration: InputDecoration(
              labelText: context.tr('Comments'),
              labelStyle: largerFieldLabelStyle,
              alignLabelWithHint: true,
            ),
          ),
          if (_showCommentSuggestions) ...[
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              constraints: const BoxConstraints(maxHeight: 180),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: theme.colorScheme.outline.withValues(alpha: 0.4)),
              ),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _matchingComments.length,
                itemBuilder: (context, index) {
                  final comment = _matchingComments[index];
                  return ListTile(
                    dense: true,
                    title: Text(
                      comment,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: () => _selectCommentSuggestion(comment),
                  );
                },
              ),
            ),
          ],
          const SizedBox(height: 10),
          TextField(
            controller: amountController,
            decoration: InputDecoration(
              labelText: context.tr('Amount'),
              labelStyle: largerFieldLabelStyle,
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: 14),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(context.tr('Date')),
            subtitle: Text(DateFormat('dd MMM yyyy').format(selectedDate)),
            trailing: const Icon(Icons.calendar_today),
            onTap: pickDate,
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _save,
              child: Text(context.tr('Save')),
            ),
          ),
        ],
      ),
    );

    if (!widget.modalStyle) {
      return Scaffold(
        appBar: AppBar(
          title: Text(
            widget.existingTransaction == null
                ? tr.t('Add Transaction')
                : tr.t('Edit Transaction'),
          ),
        ),
        body: Padding(padding: const EdgeInsets.all(16), child: content),
      );
    }

    return Dialog(
      backgroundColor: theme.colorScheme.surface,
      surfaceTintColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.existingTransaction == null
                          ? tr.t('Add Transaction')
                          : tr.t('Edit Transaction'),
                      style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, size: 18),
                    tooltip: 'Close',
                  ),
                ],
              ),
              content,
            ],
          ),
        ),
      ),
    );
  }
}
