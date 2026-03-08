import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class MonthHeader extends StatelessWidget {

  final DateTime currentMonth;
  final Function onPrev;
  final Function onNext;

  MonthHeader({
    required this.currentMonth,
    required this.onPrev,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {

    return Padding(
      padding: EdgeInsets.all(12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [

          IconButton(
            icon: Icon(Icons.arrow_left),
            onPressed: () => onPrev(),
          ),

          Text(
            DateFormat('MMMM yyyy').format(currentMonth),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),

          IconButton(
            icon: Icon(Icons.arrow_right),
            onPressed: () => onNext(),
          ),

        ],
      ),
    );
  }
}
