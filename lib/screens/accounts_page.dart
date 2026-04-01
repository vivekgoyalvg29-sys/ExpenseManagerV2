import 'package:flutter/material.dart';

import '../services/data_store.dart';
import '../services/data_service.dart';
import '../services/icon_storage_service.dart';
import '../widgets/icon_utils.dart';
import '../widgets/page_content_layout.dart';
import '../widgets/section_tile.dart';

class AccountsPage extends StatefulWidget {
  const AccountsPage({super.key});

  @override
  State<AccountsPage> createState() => _AccountsPageState();
}

class _AccountsPageState extends State<AccountsPage> {
  Set<int> selectedIndexes = {};
  bool selectionMode = false;
  String? _userRole;

  @override
  void initState() {
    super.initState();
    loadAccounts();
    _loadRole();
  }

  Future<void> _loadRole() async {
    try {
      final role = await DataService.getCurrentUserRole();
      if (mounted) setState(() => _userRole = role);
    } catch (_) {}
  }

  Future<void> loadAccounts() async {
    final data = await DataService.getAccounts();
    setState(() {
      DataStore.accounts = data.map<Map<String, dynamic>>((a) => {
        'id': a['id'],
        'name': a['name'].toString(),
        'type': a['type'].toString(),
        'icon': a['icon'],
        'icon_path': a['icon_path']?.toString(),
        'is_favorite': (a['is_favorite'] as num?)?.toInt() == 1,
      }).toList();
    });
  }

  void showAddAccountDialog({Map<String, dynamic>? account}) {
    // Capture the page context so we can show a SnackBar from inside the dialog.
    final pageContext = context;
    final controller = TextEditingController(text: account?['name']);
    String selectedType = account?['type'] ?? 'expense';
    int selectedIcon = account?['icon'] ?? selectableIcons.first.codePoint;
    String? customIconPath = account?['icon_path']?.toString();

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          bool saving = false;
          return StatefulBuilder(
            builder: (dialogContext, setInnerState) => AlertDialog(
              title: Text(account == null ? 'Create Account' : 'Edit Account'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      value: selectedType,
                      items: const [
                        DropdownMenuItem(value: 'expense', child: Text('Expense')),
                        DropdownMenuItem(value: 'income', child: Text('Income')),
                      ],
                      onChanged: (value) {
                        if (value != null) selectedType = value;
                      },
                      decoration: const InputDecoration(labelText: 'Transaction Type'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: controller,
                      decoration: const InputDecoration(labelText: 'Account Name'),
                    ),
                    const SizedBox(height: 10),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Icon', style: TextStyle(fontWeight: FontWeight.w600)),
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
                    const SizedBox(height: 14),
                    InkWell(
                      onTap: () async {
                        final picked = await IconStorageService.pickAndStoreIconImage();
                        if (picked == null) return;
                        setDialogState(() => customIconPath = picked);
                      },
                      child: Row(
                        children: [
                          const Text(
                            'Choose from gallery',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                          ),
                          const Spacer(),
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
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: saving ? null : () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: saving
                      ? null
                      : () async {
                          if (controller.text.trim().isEmpty) return;
                          setInnerState(() => saving = true);
                          try {
                            if (account == null) {
                              await DataService.insertAccount(
                                controller.text.trim(), selectedType, selectedIcon,
                                iconPath: customIconPath,
                              );
                            } else {
                              await DataService.updateAccount(
                                account['id'], controller.text.trim(),
                                selectedType, selectedIcon,
                                iconPath: customIconPath,
                              );
                            }
                            if (!dialogContext.mounted) return;
                            Navigator.pop(dialogContext);
                            loadAccounts();
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
            ),
          );
        },
      ),
    );
    controller.addListener(() {});
  }

  void clearSelection() {
    setState(() {
      selectedIndexes.clear();
      selectionMode = false;
    });
  }

  Future<void> deleteSelected() async {
    for (final index in selectedIndexes) {
      final id = DataStore.accounts[index]['id'] as int;
      await DataService.deleteAccount(id);
    }
    clearSelection();
    loadAccounts();
  }

  @override
  Widget build(BuildContext context) {
    final expenseAccounts = DataStore.accounts.where((a) => a['type'] == 'expense').toList();
    final incomeAccounts = DataStore.accounts.where((a) => a['type'] == 'income').toList();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      floatingActionButton: _userRole == 'viewer'
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
                  label: Text('Delete (${selectedIndexes.length})'),
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
            SectionTile(
              margin: const EdgeInsets.fromLTRB(12, 6, 12, 6),
              child: const SizedBox(
                height: 58,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Text('Accounts', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
                  ),
                ),
              ),
            ),
            Expanded(
              child: SectionTile(
                child: ListView(
                  children: [
            _AccountSection(
              title: 'Expense Accounts',
              items: expenseAccounts,
              selectionMode: selectionMode,
              selectedIndexes: selectedIndexes,
              fullList: DataStore.accounts,
              onChanged: (index, checked) => setState(
                  () => checked ? selectedIndexes.add(index) : selectedIndexes.remove(index)),
              onLongPress: (index) => setState(() {
                selectionMode = true;
                selectedIndexes.add(index);
              }),
              onTap: (acc, index) {
                if (selectionMode) {
                  setState(() => selectedIndexes.contains(index)
                      ? selectedIndexes.remove(index)
                      : selectedIndexes.add(index));
                } else {
                  showAddAccountDialog(account: acc);
                }
              },
              onToggleFavorite: (acc) async {
                final current = acc['is_favorite'] == true;
                await DataService.setAccountFavorite(
                  id: acc['id'] as int,
                  type: (acc['type'] ?? 'expense').toString(),
                  isFavorite: !current,
                );
                await loadAccounts();
              },
            ),
            _AccountSection(
              title: 'Income Accounts',
              items: incomeAccounts,
              selectionMode: selectionMode,
              selectedIndexes: selectedIndexes,
              fullList: DataStore.accounts,
              onChanged: (index, checked) => setState(
                  () => checked ? selectedIndexes.add(index) : selectedIndexes.remove(index)),
              onLongPress: (index) => setState(() {
                selectionMode = true;
                selectedIndexes.add(index);
              }),
              onTap: (acc, index) {
                if (selectionMode) {
                  setState(() => selectedIndexes.contains(index)
                      ? selectedIndexes.remove(index)
                      : selectedIndexes.add(index));
                } else {
                  showAddAccountDialog(account: acc);
                }
              },
              onToggleFavorite: (acc) async {
                final current = acc['is_favorite'] == true;
                await DataService.setAccountFavorite(
                  id: acc['id'] as int,
                  type: (acc['type'] ?? 'expense').toString(),
                  isFavorite: !current,
                );
                await loadAccounts();
              },
            ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AccountSection extends StatelessWidget {
  final String title;
  final List<Map<String, dynamic>> items;
  final bool selectionMode;
  final Set<int> selectedIndexes;
  final List<Map<String, dynamic>> fullList;
  final void Function(int index, bool checked) onChanged;
  final void Function(int index) onLongPress;
  final void Function(Map<String, dynamic> item, int index) onTap;
  final Future<void> Function(Map<String, dynamic> item)? onToggleFavorite;

  const _AccountSection({
    required this.title,
    required this.items,
    required this.selectionMode,
    required this.selectedIndexes,
    required this.fullList,
    required this.onChanged,
    required this.onLongPress,
    required this.onTap,
    this.onToggleFavorite,
  });

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      title: Text(
        title,
        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
      ),
      initiallyExpanded: true,
      children: items.map((acc) {
        final index = fullList.indexOf(acc);
        return ListTile(
          leading: selectionMode
              ? Checkbox(
                  value: selectedIndexes.contains(index),
                  onChanged: (v) => onChanged(index, v == true),
                )
              : AppPageIcon(
                  icon: iconFromCodePoint(acc['icon'], fallback: Icons.account_balance_wallet),
                  imagePath: acc['icon_path']?.toString(),
                ),
          title: Text(
            acc['name'] ?? '',
            style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w400),
          ),
          trailing: IconButton(
            tooltip: 'Favorite',
            onPressed: onToggleFavorite == null ? null : () => onToggleFavorite!(acc),
            icon: Icon(
              (acc['is_favorite'] == true) ? Icons.star : Icons.star_border,
              color: (acc['is_favorite'] == true)
                  ? Theme.of(context).colorScheme.onSurface
                  : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          onLongPress: () => onLongPress(index),
          onTap: () => onTap(acc, index),
        );
      }).toList(),
    );
  }
}
