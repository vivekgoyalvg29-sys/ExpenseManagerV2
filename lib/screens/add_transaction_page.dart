import 'package:flutter/material.dart';

class AddTransactionPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Add Transaction"),
      ),

      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [

            DropdownButtonFormField(
              items: const [
                DropdownMenuItem(child: Text("Expense"), value: "expense"),
                DropdownMenuItem(child: Text("Income"), value: "income"),
              ],
              onChanged: (v) {},
              decoration: InputDecoration(labelText: "Type"),
            ),

            TextField(
              decoration: InputDecoration(labelText: "Account"),
            ),

            TextField(
              decoration: InputDecoration(labelText: "Category"),
            ),

            TextField(
              decoration: InputDecoration(labelText: "Comments"),
            ),

            TextField(
              decoration: InputDecoration(labelText: "Amount"),
              keyboardType: TextInputType.number,
            ),

            const SizedBox(height: 20),

            ElevatedButton(
              onPressed: () {},
              child: Text("Save"),
            )
          ],
        ),
      ),
    );
  }
}
