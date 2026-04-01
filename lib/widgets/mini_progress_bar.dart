import 'package:flutter/material.dart';

class MiniProgressBar extends StatelessWidget {
  final double expense;
  final double reference; // budget or income depending on mode

  const MiniProgressBar({
    super.key,
    required this.expense,
    required this.reference,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasReference = reference > 0;
    final ratio = hasReference && expense > 0 ? (expense / reference) : 0.0;
    final clamped = ratio.clamp(0.0, 2.0).toDouble();

    Color _progressColor(double r) {
      if (r <= 0.5) return const Color(0xFF22C55E);
      if (r <= 1.0) return const Color(0xFFF59E0B);
      return const Color(0xFFEF4444);
    }

    final fillColor = hasReference ? _progressColor(clamped) : theme.dividerColor;
    final percentage = hasReference && expense > 0 ? (ratio * 100).clamp(0, 999).round() : 0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 6),
      child: Row(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: Container(
                height: 3,
                color: theme.dividerColor.withOpacity(0.6),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    widthFactor: hasReference ? clamped.clamp(0.0, 1.0) : 0.0,
                    child: Container(
                      color: fillColor,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: theme.colorScheme.outline.withOpacity(0.5)),
            ),
            child: Text(
              '$percentage%',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

