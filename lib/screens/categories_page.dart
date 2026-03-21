import 'package:flutter/material.dart';

import '../services/data_store.dart';
import '../services/database_service.dart';
import '../services/icon_storage_service.dart';
import '../widgets/icon_utils.dart';
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
    final data = await DatabaseService.getCategories();
    setState(() {
      DataStore.categories = data.map<Map<String, dynamic>>((c) => {
        'id': c['id'],
        'name': c['name'].toString(),
        'type': c['type'].toString(),
        'icon': c['icon'],
        'icon_path': c['icon_path']?.toString(),
      }).toList();
    });
  }

  void showAddCategoryDialog({Map<String, dynamic>? category}) {
    final controller = TextEditingController(text: category?['name']);
    String selectedType = category?['type'] ?? 'expense';
    int selectedIcon = category?['icon'] ?? selectableIcons.first.codePoint;
    String? customIconPath = category?['icon_path']?.toString();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(category == null ? 'Create Category' : 'Edit Category'),
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
                TextField(controller: controller, decoration: const InputDecoration(labelText: 'Category Name')),
                const SizedBox(height: 10),
                const Align(alignment: Alignment.centerLeft, child: Text('Icon', style: TextStyle(fontWeight: FontWeight.w600))),
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
                        child: Icon(icon, color: selected ? Colors.white : Colors.black87),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: AppPageIcon(icon: iconFromCodePoint(selectedIcon), imagePath: customIconPath),
                  title: const Text('Pick custom icon from gallery'),
                  subtitle: Text(customIconPath == null ? 'Use your own image for this category icon.' : customIconPath!.split('/').last),
                  trailing: customIconPath == null ? const Icon(Icons.photo_library_outlined) : IconButton(icon: const Icon(Icons.close), onPressed: () => setDialogState(() => customIconPath = null)),
                  onTap: () async {
                    final picked = await IconStorageService.pickAndStoreIconImage();
                    if (picked == null) return;
                    setDialogState(() => customIconPath = picked);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            TextButton(
              onPressed: () async {
                if (controller.text.isEmpty) return;
                if (category == null) {
                  await DatabaseService.insertCategory(controller.text, selectedType, selectedIcon, iconPath: customIconPath);
                } else {
                  await DatabaseService.updateCategory(category['id'], controller.text, selectedType, selectedIcon, iconPath: customIconPath);
                }
                if (!context.mounted) return;
                Navigator.pop(context);
                loadCategories();
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
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
      await DatabaseService.deleteCategory(id);
    }
    clearSelection();
    loadCategories();
  }

  @override
  Widget build(BuildContext context) {
    final expenseCategories = DataStore.categories.where((c) => c['type'] == 'expense').toList();
    final incomeCategories = DataStore.categories.where((c) => c['type'] == 'income').toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF3F5F9),
      floatingActionButton: selectionMode
          ? Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                FloatingActionButton.small(heroTag: 'cancelCategorySelection', onPressed: clearSelection, tooltip: 'Cancel selection', child: const Icon(Icons.close)),
                const SizedBox(height: 10),
                FloatingActionButton.extended(heroTag: 'deleteSelectedCategories', onPressed: deleteSelected, icon: const Icon(Icons.delete), label: Text('Delete (${selectedIndexes.length})')),
              ],
            )
          : FloatingActionButton(child: const Icon(Icons.add), onPressed: () => showAddCategoryDialog()),
      body: SectionTile(
        child: ListView(
          children: [
            _CategorySection(title: 'Expense Categories', items: expenseCategories, selectionMode: selectionMode, selectedIndexes: selectedIndexes, fullList: DataStore.categories, onChanged: (index, checked) => setState(() => checked ? selectedIndexes.add(index) : selectedIndexes.remove(index)), onLongPress: (index) => setState(() { selectionMode = true; selectedIndexes.add(index); }), onTap: (cat, index) {
              if (selectionMode) {
                setState(() => selectedIndexes.contains(index) ? selectedIndexes.remove(index) : selectedIndexes.add(index));
              } else {
                showAddCategoryDialog(category: cat);
              }
            }),
            _CategorySection(title: 'Income Categories', items: incomeCategories, selectionMode: selectionMode, selectedIndexes: selectedIndexes, fullList: DataStore.categories, onChanged: (index, checked) => setState(() => checked ? selectedIndexes.add(index) : selectedIndexes.remove(index)), onLongPress: (index) => setState(() { selectionMode = true; selectedIndexes.add(index); }), onTap: (cat, index) {
              if (selectionMode) {
                setState(() => selectedIndexes.contains(index) ? selectedIndexes.remove(index) : selectedIndexes.add(index));
              } else {
                showAddCategoryDialog(category: cat);
              }
            }),
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

  const _CategorySection({required this.title, required this.items, required this.selectionMode, required this.selectedIndexes, required this.fullList, required this.onChanged, required this.onLongPress, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      title: Text(title),
      initiallyExpanded: true,
      children: items.map((cat) {
        final index = fullList.indexOf(cat);
        return ListTile(
          leading: selectionMode
              ? Checkbox(value: selectedIndexes.contains(index), onChanged: (v) => onChanged(index, v == true))
              : AppPageIcon(icon: iconFromCodePoint(cat['icon'], fallback: Icons.category), imagePath: cat['icon_path']?.toString()),
          title: Text(cat['name'] ?? ''),
          onLongPress: () => onLongPress(index),
          onTap: () => onTap(cat, index),
        );
      }).toList(),
    );
  }
}
