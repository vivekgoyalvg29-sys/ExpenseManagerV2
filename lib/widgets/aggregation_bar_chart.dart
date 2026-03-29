import 'package:flutter/material.dart';

import '../utils/indian_number_formatter.dart';

class AggregationBarData {
  final String label;
  final double value;

  const AggregationBarData({
    required this.label,
    required this.value,
  });
}

class AggregationBarChart extends StatelessWidget {
  final List<AggregationBarData> data;
  final String emptyMessage;

  const AggregationBarChart({
    super.key,
    required this.data,
    required this.emptyMessage,
  });

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE3E7EE)),
        ),
        child: Text(
          emptyMessage,
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey[700], fontWeight: FontWeight.w500),
        ),
      );
    }

    final maxValue = data.fold<double>(0, (max, item) => item.value > max ? item.value : max);
    final normalizedMax = maxValue <= 0 ? 1.0 : maxValue;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE3E7EE)),
      ),
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: BoxConstraints(minWidth: MediaQuery.of(context).size.width - 52),
          child: SizedBox(
            width: (data.length * 54).toDouble(),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final item in data)
                  SizedBox(
                    width: 54,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: _ChartBar(
                        value: item.value,
                        maxValue: normalizedMax,
                        label: item.label,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ChartBar extends StatelessWidget {
  final double value;
  final double maxValue;
  final String label;

  const _ChartBar({
    required this.value,
    required this.maxValue,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final ratio = maxValue == 0 ? 0.0 : (value / maxValue).clamp(0.0, 1.0).toDouble();
    final height = 28 + (ratio * 116);

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        SizedBox(
          height: 150,
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              height: height,
              constraints: const BoxConstraints(minWidth: 18, maxWidth: 26),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                gradient: const LinearGradient(
                  colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              alignment: Alignment.center,
              child: RotatedBox(
                quarterTurns: 3,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    formatIndianCurrency(value),
                    maxLines: 1,
                    overflow: TextOverflow.fade,
                    softWrap: false,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Colors.grey[800],
          ),
        ),
      ],
    );
  }
}
