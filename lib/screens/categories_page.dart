import 'package:flutter/material.dart';
import '../services/data_store.dart';
import '../services/database_service.dart';
import '../widgets/icon_utils.dart';
import '../widgets/section_tile.dart';

class CategoriesPage extends StatefulWidget {
  @override
  _CategoriesPageState createState() => _CategoriesPageState();
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
      DataStore.categories = data
          .map<Map<String, dynamic>>((c) => {
                "id": c["id"],
                "name": c["name"].toString(),
                "type": c["type"].toString(),
                "icon": c["icon"],
              })
          .toList();
    });
  }

  void showAddCategoryDialog({Map<String, dynamic>? category}) {
    TextEditingController controller = TextEditingController(text: category?["name"]);
    String selectedType = category?["type"] ?? "expense";
    int selectedIcon = category?["icon"] ?? selectableIcons.first.codePoint;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(category == null ? "Create Category" : "Edit Category"),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      value: selectedType,
                      items: const [
                        DropdownMenuItem(value: "expense", child: Text("Expense")),
                        DropdownMenuItem(value: "income", child: Text("Income")),
                      ],
                      onChanged: (value) {
                        selectedType = value!;
                      },
                      decoration: const InputDecoration(labelText: "Transaction Type"),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: controller,
                      decoration: const InputDecoration(labelText: "Category Name"),
                    ),
                    const SizedBox(height: 10),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text("Icon", style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: selectableIcons.map((icon) {
                        final selected = selectedIcon == icon.codePoint;
                        return InkWell(
                          onTap: () => setDialogState(() => selectedIcon = icon.codePoint),
                          child: CircleAvatar(
                            backgroundColor: selected ? Colors.green : Colors.grey.shade300,
                            child: Icon(icon, color: selected ? Colors.white : Colors.black87),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cancel"),
                ),
                TextButton(
                  onPressed: () async {
                    if (controller.text.isEmpty) return;

                    if (category == null) {
                      await DatabaseService.insertCategory(controller.text, selectedType, selectedIcon);
                    } else {
                      await DatabaseService.updateCategory(
                        category["id"],
                        controller.text,
                        selectedType,
                        selectedIcon,
                      );
                    }

                    Navigator.pop(context);
                    loadCategories();
                  },
                  child: const Text("Save"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void deleteSelected() async {
    for (var index in selectedIndexes) {
      final id = DataStore.categories[index]["id"] as int;
      await DatabaseService.deleteCategory(id);
    }

    selectedIndexes.clear();
    selectionMode = false;

    loadCategories();
  }

  @override
  Widget build(BuildContext context) {
    final expenseCategories = DataStore.categories.where((c) => c["type"] == "expense").toList();
    final incomeCategories = DataStore.categories.where((c) => c["type"] == "income").toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF3F5F9),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () => showAddCategoryDialog(),
      ),
      body: SectionTile(
        child: ListView(
          children: [
          if (selectionMode)
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                icon: const Icon(Icons.delete),
                onPressed: deleteSelected,
              ),
            ),
          ExpansionTile(
            title: const Text("Expense Categories"),
            initiallyExpanded: true,
            children: expenseCategories.map((cat) {
              int index = DataStore.categories.indexOf(cat);

              return ListTile(
                leading: selectionMode
                    ? Checkbox(
                        value: selectedIndexes.contains(index),
                        onChanged: (v) {
                          setState(() {
                            if (v == true) {
                              selectedIndexes.add(index);
                            } else {
                              selectedIndexes.remove(index);
                            }
                          });
                        },
                      )
                    : Icon(iconFromCodePoint(cat["icon"], fallback: Icons.category)),
                title: Text(cat["name"] ?? ""),
                onLongPress: () {
                  setState(() {
                    selectionMode = true;
                    selectedIndexes.add(index);
                  });
                },
                onTap: () {
                  if (selectionMode) {
                    setState(() {
                      if (selectedIndexes.contains(index)) {
                        selectedIndexes.remove(index);
                      } else {
                        selectedIndexes.add(index);
                      }
                    });
                  } else {
                    showAddCategoryDialog(category: cat);
                  }
                },
              );
            }).toList(),
          ),
          ExpansionTile(
            title: const Text("Income Categories"),
            initiallyExpanded: true,
            children: incomeCategories.map((cat) {
              int index = DataStore.categories.indexOf(cat);

              return ListTile(
                leading: selectionMode
                    ? Checkbox(
                        value: selectedIndexes.contains(index),
                        onChanged: (v) {
                          setState(() {
                            if (v == true) {
                              selectedIndexes.add(index);
                            } else {
                              selectedIndexes.remove(index);
                            }
                          });
                        },
                      )
                    : Icon(iconFromCodePoint(cat["icon"], fallback: Icons.category)),
                title: Text(cat["name"]),
                onLongPress: () {
                  setState(() {
                    selectionMode = true;
                    selectedIndexes.add(index);
                  });
                },
                onTap: () {
                  if (selectionMode) {
                    setState(() {
                      if (selectedIndexes.contains(index)) {
                        selectedIndexes.remove(index);
                      } else {
                        selectedIndexes.add(index);
                      }
                    });
                  } else {
                    showAddCategoryDialog(category: cat);
                  }
                },
              );
            }).toList(),
          ),
          ],
        ),
      ),
    );
  }
}
