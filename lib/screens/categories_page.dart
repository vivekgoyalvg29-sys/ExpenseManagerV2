import 'package:flutter/material.dart';

import '../services/data_store.dart';
import '../services/data_service.dart';
import '../services/default_seed_icons.dart';
import '../services/account_subscription_service.dart';
import '../services/entitlement_service.dart';
import 'pro_purchase_flow.dart';
import '../services/icon_storage_service.dart';
import '../widgets/grouped_list_section.dart';
import '../widgets/icon_utils.dart';
import '../widgets/page_content_layout.dart';
import '../widgets/section_tile.dart';

/// Create/edit category dialog; [afterSave] runs after a successful save (e.g. reload list).
/// Returns the saved category name on success, or null if cancelled.
Future<String?> showCategoryEditorDialog(
  BuildContext context, {
  Map<String, dynamic>? category,
  /// When [category] is null, pre-selects expense vs income (e.g. from add-transaction).
  String? initialTypeWhenCreating,
  required Future<void> Function() afterSave,
}) async {
  final pageContext = context;
  final controller = TextEditingController(text: category?['name']);
  String selectedType = category?['type'] ?? initialTypeWhenCreating ?? 'expense';
  int selectedIcon = category?['icon'] ?? selectableIcons.first.codePoint;
  String? customIconPath = category?['icon_path']?.toString();
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
                category == null ? 'Create Category' : 'Edit Category',
                style: Theme.of(dialogContext).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      key: ValueKey(selectedType),
                      initialValue: selectedType,
                      items: const [
                        DropdownMenuItem(value: 'expense', child: Text('Expense')),
                        DropdownMenuItem(value: 'income', child: Text('Income')),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() => selectedType = value);
                        }
                      },
                      style: fieldTextStyle,
                      decoration: InputDecoration(
                        labelText: 'Transaction Type',
                        labelStyle: fieldLabelStyle,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: controller,
                      onChanged: (_) => setDialogState(() {}),
                      style: fieldTextStyle,
                      decoration: InputDecoration(
                        labelText: 'Category Name',
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
                      children: DefaultSeedIcons.categorySamplePathsForEditor(
                        type: selectedType,
                        typedName: controller.text,
                        originalName: category?['name']?.toString(),
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
                            final name = controller.text.trim();
                            if (category == null) {
                              await DataService.insertCategory(
                                name, selectedType, selectedIcon,
                                iconPath: customIconPath,
                              );
                            } else {
                              await DataService.updateCategory(
                                category['id'], name,
                                selectedType, selectedIcon,
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
                                SnackBar(content: Text('Could not save category: $e')),
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

class CategoriesPage extends StatefulWidget {
  const CategoriesPage({super.key});

  @override
  State<CategoriesPage> createState() => _CategoriesPageState();
}

Future<void> openCreateCategoryFromMainMenu(BuildContext context) {
  return showCategoryEditorDialog(
    context,
    category: null,
    afterSave: () async {
      final data = await DataService.getCategories();
      DataStore.replaceCategories(data);
      DataStore.bumpTransactionMutationGeneration();
    },
  );
}

class _CategoriesPageState extends State<CategoriesPage> {
  Set<int> selectedCategoryIds = {};
  bool selectionMode = false;
  bool _incomeSectionExpanded = true;
  bool _expenseSectionExpanded = true;

  @override
  void initState() {
    super.initState();
    DataStore.transactionMutationGeneration.addListener(_onBookDataMutation);
    DataStore.profileSwitchGeneration.addListener(_onProfileSwitch);
    loadCategories();
  }

  void _onBookDataMutation() {
    if (mounted) loadCategories();
  }

  void _onProfileSwitch() {
    if (mounted) loadCategories();
  }

  @override
  void dispose() {
    DataStore.transactionMutationGeneration.removeListener(_onBookDataMutation);
    DataStore.profileSwitchGeneration.removeListener(_onProfileSwitch);
    super.dispose();
  }

  Future<void> loadCategories() async {
    final data = await DataService.getCategories();
    setState(() {
      DataStore.replaceCategories(data);
    });
  }

  void showAddCategoryDialog({Map<String, dynamic>? category}) {
    showCategoryEditorDialog(
      context,
      category: category,
      afterSave: () async {
        await loadCategories();
      },
    );
  }

  void clearSelection() {
    setState(() {
      selectedCategoryIds.clear();
      selectionMode = false;
    });
  }

  Future<void> deleteSelected() async {
    for (final id in selectedCategoryIds) {
      await DataService.deleteCategory(id);
    }
    clearSelection();
    loadCategories();
  }

  static int _compareCategoryFavoriteThenName(
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
    final incomeCategories = DataStore.categories.where((c) => c['type'] == 'income').toList()
      ..sort(_compareCategoryFavoriteThenName);
    final expenseCategories = DataStore.categories.where((c) => c['type'] == 'expense').toList()
      ..sort(_compareCategoryFavoriteThenName);
    final total = DataStore.categories.length;

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
                  heroTag: 'cancelCategorySelection',
                  onPressed: clearSelection,
                  tooltip: 'Cancel selection',
                  child: const Icon(Icons.close),
                ),
                const SizedBox(height: 10),
                FloatingActionButton.extended(
                  heroTag: 'deleteSelectedCategories',
                  onPressed: deleteSelected,
                  icon: const Icon(Icons.delete),
                  label: Text('Delete (${selectedCategoryIds.length})'),
                ),
              ],
            )
          : FloatingActionButton(
              child: const Icon(Icons.add),
              onPressed: () => showAddCategoryDialog(),
            ),
      body: PageContentLayout(
        child: Column(
          children: [
            SectionTile(
              margin: const EdgeInsets.fromLTRB(12, 6, 12, 6),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              useInnerPanelTint: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Categories',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.2,
                      color: cs.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    total == 0 ? 'Organize expense and income types' : '$total ${total == 1 ? 'category' : 'categories'}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant.withValues(alpha: 0.88),
                      height: 1.25,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(bottom: 88),
                children: [
                  if (total == 0)
                    SectionTile(
                      margin: const EdgeInsets.fromLTRB(12, 6, 12, 6),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
                      child: Column(
                        children: [
                          Icon(
                            Icons.category_outlined,
                            size: 44,
                            color: cs.onSurfaceVariant.withValues(alpha: 0.55),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            'No categories yet',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: cs.onSurface,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Tap + to add expense or income categories.',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: cs.onSurfaceVariant.withValues(alpha: 0.85),
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    )
                  else ...[
                    _ExpandableCategoryGroup(
                      headerTitle: 'Income categories',
                      count: incomeCategories.length,
                      expanded: _incomeSectionExpanded,
                      onExpandedChanged: (v) => setState(() => _incomeSectionExpanded = v),
                      child: _CategorySection(
                        title: 'Income categories',
                        showGroupedTitle: false,
                        items: incomeCategories,
                        selectionMode: selectionMode,
                        selectedIds: selectedCategoryIds,
                        onChanged: (id, checked) => setState(
                            () => checked ? selectedCategoryIds.add(id) : selectedCategoryIds.remove(id)),
                        onLongPress: DataStore.viewerReadOnly
                            ? (_) {}
                            : (id) => setState(() {
                                selectionMode = true;
                                selectedCategoryIds.add(id);
                              }),
                        onTap: (cat, id) {
                          if (DataStore.viewerReadOnly && !selectionMode) {
                            DataStore.showViewerReadOnlyNotice(context);
                            return;
                          }
                          if (selectionMode) {
                            setState(() => selectedCategoryIds.contains(id)
                                ? selectedCategoryIds.remove(id)
                                : selectedCategoryIds.add(id));
                          } else {
                            showAddCategoryDialog(category: cat);
                          }
                        },
                        onToggleFavorite: (cat) async {
                          if (DataStore.viewerReadOnly) {
                            DataStore.showViewerReadOnlyNotice(context);
                            return;
                          }
                          final current = cat['is_favorite'] == true;
                          await DataService.setCategoryFavorite(
                            id: cat['id'] as int,
                            type: (cat['type'] ?? 'income').toString(),
                            isFavorite: !current,
                          );
                          await loadCategories();
                        },
                      ),
                    ),
                    _ExpandableCategoryGroup(
                      headerTitle: 'Expense categories',
                      count: expenseCategories.length,
                      expanded: _expenseSectionExpanded,
                      onExpandedChanged: (v) => setState(() => _expenseSectionExpanded = v),
                      child: _CategorySection(
                        title: 'Expense categories',
                        showGroupedTitle: false,
                        items: expenseCategories,
                        selectionMode: selectionMode,
                        selectedIds: selectedCategoryIds,
                        onChanged: (id, checked) => setState(
                            () => checked ? selectedCategoryIds.add(id) : selectedCategoryIds.remove(id)),
                        onLongPress: DataStore.viewerReadOnly
                            ? (_) {}
                            : (id) => setState(() {
                                selectionMode = true;
                                selectedCategoryIds.add(id);
                              }),
                        onTap: (cat, id) {
                          if (DataStore.viewerReadOnly && !selectionMode) {
                            DataStore.showViewerReadOnlyNotice(context);
                            return;
                          }
                          if (selectionMode) {
                            setState(() => selectedCategoryIds.contains(id)
                                ? selectedCategoryIds.remove(id)
                                : selectedCategoryIds.add(id));
                          } else {
                            showAddCategoryDialog(category: cat);
                          }
                        },
                        onToggleFavorite: (cat) async {
                          if (DataStore.viewerReadOnly) {
                            DataStore.showViewerReadOnlyNotice(context);
                            return;
                          }
                          final current = cat['is_favorite'] == true;
                          await DataService.setCategoryFavorite(
                            id: cat['id'] as int,
                            type: (cat['type'] ?? 'expense').toString(),
                            isFavorite: !current,
                          );
                          await loadCategories();
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExpandableCategoryGroup extends StatelessWidget {
  final String headerTitle;
  final int count;
  final bool expanded;
  final ValueChanged<bool> onExpandedChanged;
  final Widget child;

  const _ExpandableCategoryGroup({
    required this.headerTitle,
    required this.count,
    required this.expanded,
    required this.onExpandedChanged,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: () => onExpandedChanged(!expanded),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    headerTitle,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ),
                Text(
                  '$count',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: cs.onSurfaceVariant.withValues(alpha: 0.72),
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                  size: 22,
                  color: cs.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
        if (expanded) child,
      ],
    );
  }
}

class _CategorySection extends StatelessWidget {
  final String title;
  final bool showGroupedTitle;
  final List<Map<String, dynamic>> items;
  final bool selectionMode;
  final Set<int> selectedIds;
  final void Function(int id, bool checked) onChanged;
  final void Function(int id) onLongPress;
  final void Function(Map<String, dynamic> item, int id) onTap;
  final Future<void> Function(Map<String, dynamic> item)? onToggleFavorite;

  const _CategorySection({
    required this.title,
    this.showGroupedTitle = true,
    required this.items,
    required this.selectionMode,
    required this.selectedIds,
    required this.onChanged,
    required this.onLongPress,
    required this.onTap,
    this.onToggleFavorite,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final dividerIndent = selectionMode ? 52.0 : 60.0;

    return GroupedListSection(
      title: title,
      showTitleRow: showGroupedTitle,
      itemCount: items.length,
      dividerIndent: dividerIndent,
      emptyHint: 'No categories in this group. Tap + to add.',
      itemBuilder: (context, i) {
        final cat = items[i];
        final id = cat['id'] as int;
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          visualDensity: VisualDensity.compact,
          leading: selectionMode
              ? Checkbox(
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  value: selectedIds.contains(id),
                  onChanged: (v) => onChanged(id, v == true),
                )
              : GroupedListIconWell(
                  child: AppPageIcon(
                    embedded: true,
                    icon: iconFromCodePoint(cat['icon'], fallback: Icons.category),
                    imagePath: cat['icon_path']?.toString(),
                    size: 22,
                    boxSize: 28,
                  ),
                ),
          title: Text(
            cat['name'] ?? '',
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w500,
              fontSize: 15.5,
              color: cs.onSurface,
            ),
          ),
          trailing: IconButton(
            tooltip: 'Favorite',
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
            onPressed: onToggleFavorite == null ? null : () => onToggleFavorite!(cat),
            icon: Icon(
              (cat['is_favorite'] == true) ? Icons.star_rounded : Icons.star_outline_rounded,
              color: (cat['is_favorite'] == true)
                  ? cs.primary
                  : cs.onSurfaceVariant.withValues(alpha: 0.65),
            ),
          ),
          onLongPress: () => onLongPress(id),
          onTap: () => onTap(cat, id),
        );
      },
    );
  }
}
