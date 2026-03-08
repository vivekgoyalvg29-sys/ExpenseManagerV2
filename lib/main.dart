import 'package:flutter/material.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(MyMoneyApp());
}

class MyMoneyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "MyMoney",
      theme: ThemeData(primarySwatch: Colors.green),
      home: HomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
