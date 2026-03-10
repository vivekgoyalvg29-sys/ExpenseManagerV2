import 'package:flutter/material.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(FinTrackApp());
}

class FinTrackApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "FinTrack",
      theme: ThemeData(primarySwatch: Colors.green),
      home: HomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
