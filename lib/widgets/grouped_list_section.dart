import 'package:flutter/material.dart';

import 'section_tile.dart';

/// Rounded section card with header, count, and inset dividers between rows (Settings-style).
class GroupedListSection extends StatelessWidget {
  const GroupedListSection({
    super.key,
    required this.title,
    required this.itemCount,
    required this.itemBuilder,
    this.emptyHint,
    this.dividerIndent = 60,
  });

  final String title;
  final int itemCount;
  final Widget Function(BuildContext context, int index) itemBuilder;
  final String? emptyHint;
  final double dividerIndent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return SectionTile(
      margin: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.15,
                      color: cs.onSurfaceVariant.withValues(alpha: 0.95),
                    ),
                  ),
                ),
                Text(
                  '$itemCount',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: cs.onSurfaceVariant.withValues(alpha: 0.72),
                  ),
                ),
              ],
            ),
          ),
          if (itemCount == 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Text(
                emptyHint ?? 'None yet',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant.withValues(alpha: 0.82),
                  height: 1.35,
                ),
              ),
            )
          else
            ...List.generate(itemCount * 2 - 1, (i) {
              if (i.isOdd) {
                return Divider(
                  height: 1,
                  thickness: 1,
                  indent: dividerIndent,
                  endIndent: 12,
                  color: cs.outlineVariant.withValues(
                    alpha: theme.brightness == Brightness.dark ? 0.5 : 0.55,
                  ),
                );
              }
              return itemBuilder(context, i ~/ 2);
            }),
        ],
      ),
    );
  }
}

/// Soft tile behind list icons (matches month-card / finance UI rhythm).
class GroupedListIconWell extends StatelessWidget {
  const GroupedListIconWell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final a = theme.brightness == Brightness.dark ? 0.42 : 0.62;

    return Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: a),
        borderRadius: BorderRadius.circular(10),
      ),
      child: child,
    );
  }
}
