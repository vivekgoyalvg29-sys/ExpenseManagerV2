import 'package:flutter/material.dart';

/// Same inner fill as [AggregationSmoothLineChart] plot panel — for monthly summary
/// and first content blocks to align with chart cards.
Color contentPanelInnerTint(BuildContext context) {
  final theme = Theme.of(context);
  final cs = theme.colorScheme;
  return cs.surfaceContainerHighest.withValues(
    alpha: theme.brightness == Brightness.dark ? 0.35 : 0.5,
  );
}
