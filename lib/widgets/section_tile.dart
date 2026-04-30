import 'package:flutter/material.dart';

import 'content_panel_colors.dart';

class SectionTile extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? margin;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  /// Matches chart inner panel tint ([contentPanelInnerTint]) for separation from the app bar.
  final bool useInnerPanelTint;

  const SectionTile({
    super.key,
    required this.child,
    this.margin,
    this.padding = const EdgeInsets.all(8),
    this.borderRadius = 16,
    this.useInnerPanelTint = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fill = useInnerPanelTint
        ? contentPanelInnerTint(context)
        : theme.colorScheme.surface.withValues(
            alpha: theme.brightness == Brightness.dark ? 0.92 : 0.98,
          );
    return Container(
      margin: margin ?? const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: padding,
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(
            alpha: theme.brightness == Brightness.dark ? 0.28 : 0.22,
          ),
          width: 0.8,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: theme.brightness == Brightness.dark ? 0.18 : 0.04,
            ),
            blurRadius: 12,
            spreadRadius: -3,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}
