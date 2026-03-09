import 'package:flutter/material.dart';
import '../services/data_store.dart';
import '../services/database_service.dart';

class AccountsPage extends StatefulWidget {
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

      DataStore.accounts = data.map<Map<String, dynamic>>((a) {
        return {
          "id": a["id"],
          "name": a["name"].toString(),
          "type": a["type"].toString(),
        };
      }).toList();

    });
  }

  void showAddAccountDialog({Map<String, dynamic>? account}) {

    TextEditingController controller =
        TextEditingController(text: account?["name"]);

    String selectedType = account?["type"] ?? "expense";

    showDialog(
      context: context,
      builder: (context) {

        return AlertDialog(
          title: Text(account == null ? "Create Account" : "Edit Account"),

          content: Column(
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
                decoration: const InputDecoration(
                  labelText: "Transaction Type",
                ),
              ),

              const SizedBox(height: 10),

              TextField(
                controller: controller,
                decoration: const InputDecoration(
                  labelText: "Account Name",
                ),
              ),

            ],
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

                  await DatabaseService.insertAccount(
                      controller.text, selectedType);

                } else {

                  await DatabaseService.updateAccount(
                      account["id"], controller.text, selectedType);

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
  }

  void deleteSelected() async {

    for (var index in selectedIndexes) {

      final id = DataStore.accounts[index]["id"] as int;

      await DatabaseService.deleteAccount(id);
    }

    selectedIndexes.clear();
    selectionMode = false;

    loadAccounts();
  }

  @override
  Widget build(BuildContext context) {

    final expenseAccounts =
        DataStore.accounts.where((a) => a["type"] == "expense").toList();

    final incomeAccounts =
        DataStore.accounts.where((a) => a["type"] == "income").toList();

    return Scaffold(

      appBar: AppBar(

        title: Text(
            selectionMode
                ? "${selectedIndexes.length} selected"
                : "Accounts"
        ),

        actions: [

          if (selectionMode)
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: deleteSelected,
            )

        ],
      ),

      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () => showAddAccountDialog(),
      ),

      body: ListView(
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

                            if (v == true)
                              selectedIndexes.add(index);
                            else
                              selectedIndexes.remove(index);

                          });

                        },
                      )
                    : const Icon(Icons.account_balance_wallet),

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

                      if (selectedIndexes.contains(index))
                        selectedIndexes.remove(index);
                      else
                        selectedIndexes.add(index);

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

                            if (v == true)
                              selectedIndexes.add(index);
                            else
                              selectedIndexes.remove(index);

                          });

                        },
                      )
                    : const Icon(Icons.account_balance_wallet),

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

                      if (selectedIndexes.contains(index))
                        selectedIndexes.remove(index);
                      else
                        selectedIndexes.add(index);

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
    );
  }
}
