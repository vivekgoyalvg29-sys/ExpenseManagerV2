import 'package:flutter/material.dart';
import '../services/data_store.dart';
import '../services/database_service.dart';
import '../widgets/icon_utils.dart';
import '../widgets/section_tile.dart';

class AccountsPage extends StatefulWidget {
  const AccountsPage({super.key});

  @override
  _AccountsPageState createState() => _AccountsPageState();
}

class _AccountsPageState extends State<AccountsPage> {
  Set<int> selectedIndexes = {};
  bool selectionMode = false;

  @override
  void initState() {
    super.initState();
    loadAccounts();
  }

  Future<void> loadAccounts() async {
    final data = await DatabaseService.getAccounts();

    setState(() {
      DataStore.accounts = data
          .map<Map<String, dynamic>>((a) => {
                "id": a["id"],
                "name": a["name"].toString(),
                "type": a["type"].toString(),
                "icon": a["icon"],
              })
          .toList();
    });
  }

  void showAddAccountDialog({Map<String, dynamic>? account}) {
    TextEditingController controller = TextEditingController(text: account?["name"]);
    String selectedType = account?["type"] ?? "expense";
    int selectedIcon = account?["icon"] ?? selectableIcons.first.codePoint;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(account == null ? "Create Account" : "Edit Account"),
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
                      decoration: const InputDecoration(labelText: "Account Name"),
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

                    if (account == null) {
                      await DatabaseService.insertAccount(controller.text, selectedType, selectedIcon);
                    } else {
                      await DatabaseService.updateAccount(
                        account["id"],
                        controller.text,
                        selectedType,
                        selectedIcon,
                      );
                    }

                    Navigator.pop(context);
                    loadAccounts();
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

  void clearSelection() {
    setState(() {
      selectedIndexes.clear();
      selectionMode = false;
    });
  }

  void deleteSelected() async {
    for (var index in selectedIndexes) {
      final id = DataStore.accounts[index]["id"] as int;
      await DatabaseService.deleteAccount(id);
    }

    clearSelection();

    loadAccounts();
  }

  @override
  Widget build(BuildContext context) {
    final expenseAccounts = DataStore.accounts.where((a) => a["type"] == "expense").toList();
    final incomeAccounts = DataStore.accounts.where((a) => a["type"] == "income").toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF3F5F9),
      floatingActionButton: selectionMode
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
      body: SectionTile(
        child: ListView(
          children: [
          ExpansionTile(
            title: const Text("Expense Accounts"),
            initiallyExpanded: true,
            children: expenseAccounts.map((acc) {
              int index = DataStore.accounts.indexOf(acc);

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
                    : Icon(iconFromCodePoint(acc["icon"], fallback: Icons.account_balance_wallet)),
                title: Text(acc["name"] ?? ""),
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
                    showAddAccountDialog(account: acc);
                  }
                },
              );
            }).toList(),
          ),
          ExpansionTile(
            title: const Text("Income Accounts"),
            initiallyExpanded: true,
            children: incomeAccounts.map((acc) {
              int index = DataStore.accounts.indexOf(acc);

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
                    : Icon(iconFromCodePoint(acc["icon"], fallback: Icons.account_balance_wallet)),
                title: Text(acc["name"]),
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
                    showAddAccountDialog(account: acc);
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
