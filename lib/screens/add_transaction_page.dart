import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AddTransactionPage extends StatefulWidget {
  @override
  _AddTransactionPageState createState() => _AddTransactionPageState();
}

class _AddTransactionPageState extends State<AddTransactionPage> {

  DateTime selectedDate = DateTime.now();

  Future<void> pickDate() async {

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (picked != null && picked != selectedDate) {
      setState(() {
        selectedDate = picked;
      });
    }
  }

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

            ListTile(
              title: Text("Date"),
              subtitle: Text(
                DateFormat('dd MMM yyyy').format(selectedDate),
              ),
              trailing: Icon(Icons.calendar_today),
              onTap: pickDate,
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
