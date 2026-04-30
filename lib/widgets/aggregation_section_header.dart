import 'package:flutter/material.dart';

/// Section title for Analysis/Budget options: **Aggregation** with optional **Pro** badge.
class AggregationSectionHeader extends StatelessWidget {
  const AggregationSectionHeader({super.key, required this.showProBadge});

  final bool showProBadge;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 2),
      child: Row(
        children: [
          Text(
            'Aggregation',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: cs.onSurfaceVariant,
                ),
          ),
          if (showProBadge) ...[
            const SizedBox(width: 8),
            Text(
              'Pro',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: cs.primary,
                    fontSize: 11,
                  ),
            ),
          ],
        ],
      ),
    );
  }
}
