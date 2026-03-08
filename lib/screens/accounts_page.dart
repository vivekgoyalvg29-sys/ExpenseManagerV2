import 'package:flutter/material.dart';
import '../services/data_store.dart';

class AccountsPage extends StatefulWidget {
  @override
  _AccountsPageState createState() => _AccountsPageState();
}

class _AccountsPageState extends State<AccountsPage> {


  void addAccount(String name) {
    setState(() {
      DataStore.accounts.add(name);
    });
  }

  void showAddAccountDialog() {

    TextEditingController controller = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {

        return AlertDialog(
          title: Text("Create Account"),

          content: TextField(
            controller: controller,
            decoration: InputDecoration(
              labelText: "Account Name",
            ),
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
                  addAccount(controller.text);
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

      body: accounts.isEmpty
          ? Center(child: Text("No accounts yet"))
          : ListView.builder(
              itemCount: accounts.length,
              itemBuilder: (context, index) {

                return ListTile(
                  leading: Icon(Icons.account_balance_wallet),
                  title: Text(accounts[index]),
                );
              },
            ),
    );
  }
}
