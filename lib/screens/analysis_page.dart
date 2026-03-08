import 'package:flutter/material.dart';
import '../widgets/month_header.dart';

class AnalysisPage extends StatefulWidget {
  @override
  _AnalysisPageState createState() => _AnalysisPageState();
}

class _AnalysisPageState extends State<AnalysisPage> {

  DateTime currentMonth = DateTime.now();

  List<Map<String, dynamic>> analysisData = [
    {"category": "Food", "spent": 0, "budget": 0},
  ];

  @override
  Widget build(BuildContext context) {

    return Scaffold(

      body: Column(
        children: [

          MonthHeader(
            currentMonth: currentMonth,
            onPrev: () {
              setState(() {
                currentMonth =
                    DateTime(currentMonth.year, currentMonth.month - 1);
              });
            },
            onNext: () {
              setState(() {
                currentMonth =
                    DateTime(currentMonth.year, currentMonth.month + 1);
              });
            },
          ),

          Expanded(
            child: ListView.builder(
              itemCount: analysisData.length,
              itemBuilder: (context, index) {

                final data = analysisData[index];

                double spent = data["spent"];
                double budget = data["budget"];

                double progress =
                    budget == 0 ? 0 : (spent / budget).clamp(0, 1);

                return Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),

                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,

                    children: [

                      Row(
                        mainAxisAlignment:
                            MainAxisAlignment.spaceBetween,
                        children: [

                          Text(
                            data["category"],
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),

                          Text(
                            "₹${spent.toStringAsFixed(0)} / ₹${budget.toStringAsFixed(0)}",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),

                        ],
                      ),

                      const SizedBox(height: 6),

                      LinearProgressIndicator(
                        value: progress,
                        minHeight: 8,
                      ),

                    ],
                  ),
                );
              },
            ),
          ),

        ],
      ),
    );
  }
}
