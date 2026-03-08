import 'package:flutter/material.dart';
import '../services/data_store.dart';

class CategoriesPage extends StatefulWidget {
  @override
  _CategoriesPageState createState() => _CategoriesPageState();
}

class _CategoriesPageState extends State<CategoriesPage> {


  void addCategory(String name, String type) {
  setState(() {
    DataStore.categories.add({
      "name": name,
      "type": type,
    });
  });
}

  void showAddCategoryDialog() {

    TextEditingController controller = TextEditingController();
    String selectedType = "expense";

    showDialog(
      context: context,
      builder: (context) {

        return AlertDialog(
          title: Text("Create Category"),

          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [

              TextField(
                controller: controller,
                decoration: InputDecoration(
                  labelText: "Category Name",
                ),
              ),

              const SizedBox(height: 10),

              DropdownButtonFormField(
                value: selectedType,
                items: const [
                  DropdownMenuItem(value: "expense", child: Text("Expense")),
                  DropdownMenuItem(value: "income", child: Text("Income")),
                ],
                onChanged: (value) {
                  selectedType = value!;
                },
                decoration: InputDecoration(labelText: "Transaction Type"),
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
                  addCategory(controller.text, selectedType);
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
        onPressed: showAddCategoryDialog,
      ),

      body: categories.isEmpty
          ? Center(child: Text("No categories yet"))
          : ListView.builder(
              itemCount: categories.length,
              itemBuilder: (context, index) {

                final category = categories[index];

                return ListTile(
                  leading: Icon(Icons.category),
                  title: Text(category["name"]!),
                  subtitle: Text(category["type"]!),
                );
              },
            ),
    );
  }
}
