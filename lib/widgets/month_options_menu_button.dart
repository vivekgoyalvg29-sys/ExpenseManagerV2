import 'package:flutter/material.dart';

/// More visible overflow control for month headers (Analysis, Budget) without large padding.
class MonthOptionsMenuButton extends StatelessWidget {
  final VoidCallback onPressed;
  final String tooltip;

  const MonthOptionsMenuButton({
    super.key,
    required this.onPressed,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return IconButton(
      onPressed: onPressed,
      tooltip: tooltip,
      icon: const Icon(Icons.more_vert_rounded, size: 24),
      color: cs.onSurface.withValues(alpha: 0.92),
      style: IconButton.styleFrom(
        backgroundColor: cs.surfaceContainerHighest.withValues(alpha: 0.82),
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.all(6),
        minimumSize: const Size(40, 36),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}
