import 'package:flutter/material.dart';
import '../services/data_store.dart';

class AccountsPage extends StatefulWidget {
  @override
  _AccountsPageState createState() => _AccountsPageState();
}

class _AccountsPageState extends State<AccountsPage> {

  void showAddAccountDialog() {

    TextEditingController controller = TextEditingController();
    String selectedType = "expense";

    showDialog(
      context: context,
      builder: (context) {

        return AlertDialog(
          title: Text("Create Account"),

          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [

              DropdownButtonFormField<String>(
                value: selectedType,
                items: const [
                  DropdownMenuItem(
                      value: "expense",
                      child: Text("Expense")),
                  DropdownMenuItem(
                      value: "income",
                      child: Text("Income")),
                ],
                onChanged: (value) {
                  selectedType = value!;
                },
                decoration: InputDecoration(
                  labelText: "Transaction Type",
                ),
              ),

              const SizedBox(height: 10),

              TextField(
                controller: controller,
                decoration: InputDecoration(
                  labelText: "Account Name",
                ),
              ),

            ],
          ),

          actions: [

            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text("Cancel"),
            ),

            TextButton(
              onPressed: () {

                if (controller.text.isNotEmpty) {

                  setState(() {
                    DataStore.accounts.add({
                      "name": controller.text,
                      "type": selectedType
                    });
                  });

                }

                Navigator.pop(context);

              },
              child: Text("Add"),
            ),

          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(

      floatingActionButton: FloatingActionButton(
        child: Icon(Icons.add),
        onPressed: showAddAccountDialog,
      ),

      body: DataStore.accounts.isEmpty
          ? Center(child: Text("No accounts yet"))
          : ListView.builder(
              itemCount: DataStore.accounts.length,
              itemBuilder: (context, index) {

                final account = DataStore.accounts[index];

                return ListTile(
                  leading: Icon(Icons.account_balance_wallet),
                  title: Text(account["name"]!),
                  subtitle: Text(account["type"]!),
                );
              },
            ),
    );
  }
}
