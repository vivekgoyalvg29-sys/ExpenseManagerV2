import 'package:flutter/material.dart';
import '../services/data_store.dart';
import '../services/database_service.dart';

class CategoriesPage extends StatefulWidget {
  @override
  _CategoriesPageState createState() => _CategoriesPageState();
}

class _CategoriesPageState extends State<CategoriesPage> {

  @override
  void initState() {
    super.initState();
    loadCategories();
  }

  Future<void> loadCategories() async {

    final data = await DatabaseService.getCategories();

    setState(() {
      DataStore.categories = data.map((c) => {
        "name": c["name"],
        "type": c["type"]
      }).toList();
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
                  labelText: "Category Name",
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
              onPressed: () async {

                if (controller.text.isNotEmpty) {

                  setState(() {
                    DataStore.categories.add({
                      "name": controller.text,
                      "type": selectedType
                    });
                  });

                  await DatabaseService.insertCategory(
                    controller.text,
                    selectedType,
                  );

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

      body: DataStore.categories.isEmpty
          ? Center(child: Text("No categories yet"))
          : ListView.builder(
              itemCount: DataStore.categories.length,
              itemBuilder: (context, index) {

                final category = DataStore.categories[index];

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
