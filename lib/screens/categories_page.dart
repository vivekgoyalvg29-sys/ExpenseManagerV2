import 'package:flutter/material.dart';

import '../services/data_store.dart';
import '../services/data_service.dart';
import '../services/icon_storage_service.dart';
import '../widgets/icon_utils.dart';
import '../widgets/page_content_layout.dart';
import '../widgets/section_tile.dart';

class CategoriesPage extends StatefulWidget {
  const CategoriesPage({super.key});

  @override
  State<CategoriesPage> createState() => _CategoriesPageState();
}

class _CategoriesPageState extends State<CategoriesPage> {
  Set<int> selectedIndexes = {};
  bool selectionMode = false;
  @override
  void initState() {
    super.initState();
    loadCategories();
  }

  Future<void> loadCategories() async {
    final data = await DataService.getCategories();
    setState(() {
      DataStore.categories = data.map<Map<String, dynamic>>((c) => {
        'id': c['id'],
        'name': c['name'].toString(),
        'type': c['type'].toString(),
        'icon': c['icon'],
        'icon_path': c['icon_path']?.toString(),
        'is_favorite': (c['is_favorite'] as num?)?.toInt() == 1,
      }).toList();
    });
  }

  void showAddCategoryDialog({Map<String, dynamic>? category}) {
    // Capture the page context so we can show a SnackBar from inside the dialog.
    final pageContext = context;
    final controller = TextEditingController(text: category?['name']);
    String selectedType = category?['type'] ?? 'expense';
    int selectedIcon = category?['icon'] ?? selectableIcons.first.codePoint;
    String? customIconPath = category?['icon_path']?.toString();

    showDialog(
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
                        if (value != null) selectedType = value;
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
                      children: (selectedType == 'income'
                              ? selectableIncomeCategorySampleIconPaths
                              : selectableExpenseCategorySampleIconPaths)
                          .map((path) {
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
                            if (category == null) {
                              await DataService.insertCategory(
                                controller.text.trim(), selectedType, selectedIcon,
                                iconPath: customIconPath,
                              );
                            } else {
                              await DataService.updateCategory(
                                category['id'], controller.text.trim(),
                                selectedType, selectedIcon,
                                iconPath: customIconPath,
                              );
                            }
                            if (!dialogContext.mounted) return;
                            Navigator.pop(dialogContext);
                            loadCategories();
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
      final id = DataStore.categories[index]['id'] as int;
      await DataService.deleteCategory(id);
    }
    clearSelection();
    loadCategories();
  }

  @override
  Widget build(BuildContext context) {
    final expenseCategories = DataStore.categories.where((c) => c['type'] == 'expense').toList();
    final incomeCategories = DataStore.categories.where((c) => c['type'] == 'income').toList();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      floatingActionButton: selectionMode
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
                  label: Text('Delete (${selectedIndexes.length})'),
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
              child: const SizedBox(
                height: 58,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Text('Categories', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
                  ),
                ),
              ),
            ),
            Expanded(
              child: SectionTile(
                child: ListView(
                  children: [
            _CategorySection(
              title: 'Expense Categories',
              items: expenseCategories,
              selectionMode: selectionMode,
              selectedIndexes: selectedIndexes,
              fullList: DataStore.categories,
              onChanged: (index, checked) => setState(
                  () => checked ? selectedIndexes.add(index) : selectedIndexes.remove(index)),
              onLongPress: (index) => setState(() {
                selectionMode = true;
                selectedIndexes.add(index);
              }),
              onTap: (cat, index) {
                if (selectionMode) {
                  setState(() => selectedIndexes.contains(index)
                      ? selectedIndexes.remove(index)
                      : selectedIndexes.add(index));
                } else {
                  showAddCategoryDialog(category: cat);
                }
              },
              onToggleFavorite: (cat) async {
                final current = cat['is_favorite'] == true;
                await DataService.setCategoryFavorite(
                  id: cat['id'] as int,
                  type: (cat['type'] ?? 'expense').toString(),
                  isFavorite: !current,
                );
                await loadCategories();
              },
            ),
            _CategorySection(
              title: 'Income Categories',
              items: incomeCategories,
              selectionMode: selectionMode,
              selectedIndexes: selectedIndexes,
              fullList: DataStore.categories,
              onChanged: (index, checked) => setState(
                  () => checked ? selectedIndexes.add(index) : selectedIndexes.remove(index)),
              onLongPress: (index) => setState(() {
                selectionMode = true;
                selectedIndexes.add(index);
              }),
              onTap: (cat, index) {
                if (selectionMode) {
                  setState(() => selectedIndexes.contains(index)
                      ? selectedIndexes.remove(index)
                      : selectedIndexes.add(index));
                } else {
                  showAddCategoryDialog(category: cat);
                }
              },
              onToggleFavorite: (cat) async {
                final current = cat['is_favorite'] == true;
                await DataService.setCategoryFavorite(
                  id: cat['id'] as int,
                  type: (cat['type'] ?? 'expense').toString(),
                  isFavorite: !current,
                );
                await loadCategories();
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

class _CategorySection extends StatelessWidget {
  final String title;
  final List<Map<String, dynamic>> items;
  final bool selectionMode;
  final Set<int> selectedIndexes;
  final List<Map<String, dynamic>> fullList;
  final void Function(int index, bool checked) onChanged;
  final void Function(int index) onLongPress;
  final void Function(Map<String, dynamic> item, int index) onTap;
  final Future<void> Function(Map<String, dynamic> item)? onToggleFavorite;

  const _CategorySection({
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
      children: items.map((cat) {
        final index = fullList.indexOf(cat);
        return ListTile(
          leading: selectionMode
              ? Checkbox(
                  value: selectedIndexes.contains(index),
                  onChanged: (v) => onChanged(index, v == true),
                )
              : AppPageIcon(
                  icon: iconFromCodePoint(cat['icon'], fallback: Icons.category),
                  imagePath: cat['icon_path']?.toString(),
                ),
          title: Text(
            cat['name'] ?? '',
            style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w400),
          ),
          trailing: IconButton(
            tooltip: 'Favorite',
            onPressed: onToggleFavorite == null ? null : () => onToggleFavorite!(cat),
            icon: Icon(
              (cat['is_favorite'] == true) ? Icons.star : Icons.star_border,
              color: (cat['is_favorite'] == true)
                  ? Theme.of(context).colorScheme.onSurface
                  : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          onLongPress: () => onLongPress(index),
          onTap: () => onTap(cat, index),
        );
      }).toList(),
    );
  }
}
