import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/app_localizations.dart';
import '../services/data_store.dart';
import '../services/data_service.dart';
import 'accounts_page.dart';
import 'categories_page.dart';

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
  final GlobalKey _commentSuggestionsPanelKey = GlobalKey();
  int _dismissSuggestionsGeneration = 0;

  String transactionType = 'expense';
  String? selectedAccount;
  String? selectedCategory;
  List<String> _existingComments = [];
  List<String> _matchingComments = [];
  bool _showCommentSuggestions = false;

  String? _accountError;
  String? _categoryError;
  String? _amountError;

  @override
  void initState() {
    super.initState();
    _commentFocusNode.addListener(_onCommentFocusChanged);
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
    _dismissSuggestionsGeneration++;
    _commentFocusNode.removeListener(_onCommentFocusChanged);
    commentController.dispose();
    amountController.dispose();
    _commentFocusNode.dispose();
    super.dispose();
  }

  /// True when [descendant]'s render subtree is under [ancestor]'s render object.
  static bool _contextIsDescendantOf(BuildContext ancestor, BuildContext descendant) {
    final ancRO = ancestor.findRenderObject();
    final descRO = descendant.findRenderObject();
    if (ancRO == null || descRO == null) return false;
    RenderObject? p = descRO;
    while (p != null) {
      if (p == ancRO) return true;
      p = p.parent;
    }
    return false;
  }

  void _onCommentFocusChanged() {
    if (_commentFocusNode.hasFocus || !_showCommentSuggestions) return;
    final gen = ++_dismissSuggestionsGeneration;
    // Delay dismiss so a tap on the list can run: focus often leaves the field
    // before primaryFocus lands on the suggestion row, and it may be null for a frame.
    Future<void>.delayed(const Duration(milliseconds: 200), () {
      if (!mounted || gen != _dismissSuggestionsGeneration) return;
      if (_commentFocusNode.hasFocus) return;
      if (!_showCommentSuggestions) return;
      final primaryCtx = FocusManager.instance.primaryFocus?.context;
      final panelCtx = _commentSuggestionsPanelKey.currentContext;
      if (primaryCtx != null &&
          panelCtx != null &&
          _contextIsDescendantOf(panelCtx, primaryCtx)) {
        return;
      }
      setState(() {
        _showCommentSuggestions = false;
        _matchingComments = [];
      });
    });
  }

  /// Call only inside [setState] — updates [_matchingComments] / [_showCommentSuggestions]
  /// from [commentController] and [_existingComments].
  void _syncCommentSuggestions() {
    final query = commentController.text.trim().toLowerCase();
    if (query.length < 2) {
      _matchingComments = [];
      _showCommentSuggestions = false;
      return;
    }
    final matches =
        _existingComments.where((comment) => comment.toLowerCase().contains(query)).toList();
    _matchingComments = matches;
    _showCommentSuggestions = matches.isNotEmpty;
  }

  Future<void> _loadData() async {
    final accounts = await DataService.getAccounts();
    final categories = await DataService.getCategories();
    final favoriteAccount = await DataService.getFavoriteAccountName(transactionType);
    final favoriteCategory = await DataService.getFavoriteCategoryName(transactionType);
    final existingComments = await DataService.getExistingComments();

    if (!mounted) return;

    setState(() {
      DataStore.replaceAccounts(accounts);
      DataStore.replaceCategories(categories);
      _existingComments = existingComments;
      if (widget.existingTransaction == null) {
        selectedAccount = favoriteAccount;
        selectedCategory = favoriteCategory;
      }
      _syncCommentSuggestions();
    });
  }

  void _onCommentChanged(String value) {
    setState(_syncCommentSuggestions);
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
    final amountText = amountController.text.trim();
    final accountErr = (selectedAccount == null || selectedAccount!.trim().isEmpty)
        ? context.tr('Please select an account')
        : null;
    final categoryErr = (selectedCategory == null || selectedCategory!.trim().isEmpty)
        ? context.tr('Please select a category')
        : null;
    final String? amountErr;
    if (amountText.isEmpty) {
      amountErr = context.tr('Please enter an amount');
    } else if (double.tryParse(amountText) == null) {
      amountErr = context.tr('Enter a valid amount');
    } else {
      amountErr = null;
    }

    if (accountErr != null || categoryErr != null || amountErr != null) {
      setState(() {
        _accountError = accountErr;
        _categoryError = categoryErr;
        _amountError = amountErr;
      });
      return;
    }

    setState(() {
      _accountError = null;
      _categoryError = null;
      _amountError = null;
    });

    final amount = double.parse(amountText);
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

  bool _rowIsFavorite(Map<String, dynamic> item) =>
      DataStore.coerceFavoriteFlag(item['is_favorite']);

  Future<void> _refreshAccountsAndCategoriesOnly() async {
    final accounts = await DataService.getAccounts();
    final categories = await DataService.getCategories();
    if (!mounted) return;
    setState(() {
      DataStore.replaceAccounts(accounts);
      DataStore.replaceCategories(categories);
    });
  }

  Future<void> _openSelector({required bool isAccount}) async {
    await _refreshAccountsAndCategoriesOnly();
    if (!mounted) return;
    final entries = (isAccount ? DataStore.accounts : DataStore.categories)
        .where((item) => isAccount || item['type'] == transactionType)
        .toList();
    entries.sort((a, b) {
      final af = _rowIsFavorite(a);
      final bf = _rowIsFavorite(b);
      if (af != bf) return af ? -1 : 1;
      return a['name'].toString().compareTo(b['name'].toString());
    });

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
                      FilledButton.tonalIcon(
                        onPressed: () async {
                          final created = isAccount
                              ? await showAccountEditorDialog(
                                  context,
                                  account: null,
                                  afterSave: () async {
                                    await _refreshAccountsAndCategoriesOnly();
                                    DataStore.bumpTransactionMutationGeneration();
                                  },
                                )
                              : await showCategoryEditorDialog(
                                  context,
                                  category: null,
                                  initialTypeWhenCreating: transactionType,
                                  afterSave: () async {
                                    await _refreshAccountsAndCategoriesOnly();
                                    DataStore.bumpTransactionMutationGeneration();
                                  },
                                );
                          if (!mounted) return;
                          if (created == null || created.isEmpty) return;
                          Navigator.pop(dialogContext, created);
                        },
                        icon: const Icon(Icons.add_rounded, size: 22),
                        label: Text(isAccount ? 'New account' : 'New category'),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          visualDensity: VisualDensity.compact,
                        ),
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
                            'No items yet. Use the button above.',
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
        _accountError = null;
      } else {
        selectedCategory = selected;
        _categoryError = null;
      }
    });
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
                _accountError = null;
                _categoryError = null;
                _amountError = null;
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
                errorText: _accountError,
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
                errorText: _categoryError,
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
              key: _commentSuggestionsPanelKey,
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
            onChanged: (_) {
              if (_amountError != null) setState(() => _amountError = null);
            },
            decoration: InputDecoration(
              labelText: context.tr('Amount'),
              labelStyle: largerFieldLabelStyle,
              errorText: _amountError,
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
