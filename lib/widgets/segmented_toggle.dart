import 'dart:math' as math;

import 'package:flutter/material.dart';

enum SegmentedToggleAxis {
  horizontal,
  vertical,
}

class SegmentedToggleOption<T> {
  final T value;
  final String label;

  const SegmentedToggleOption({
    required this.value,
    required this.label,
  });
}

class SegmentedToggle<T> extends StatelessWidget {
  final List<SegmentedToggleOption<T>> options;
  final T selectedValue;
  final ValueChanged<T> onChanged;
  final SegmentedToggleAxis axis;
  /// When true, vertical toggles size to content width instead of stretching full width.
  final bool shrinkWidth;

  const SegmentedToggle({
    super.key,
    required this.options,
    required this.selectedValue,
    required this.onChanged,
    this.axis = SegmentedToggleAxis.horizontal,
    this.shrinkWidth = false,
  });

  static double _labelMaxWidth(BuildContext context, List<SegmentedToggleOption<dynamic>> options) {
    // Account for system/app text scale so the knob width matches rendered text.
    final scale = MediaQuery.textScalerOf(context).scale(12) / 12;
    final style = Theme.of(context).textTheme.labelLarge?.copyWith(
          fontSize: 12 * scale,
          fontWeight: FontWeight.w700,
        ) ??
        TextStyle(fontSize: 12 * scale, fontWeight: FontWeight.w700);
    double w = 0;
    for (final o in options) {
      final tp = TextPainter(
        text: TextSpan(text: o.label, style: style),
        textDirection: TextDirection.ltr,
      )..layout();
      w = math.max(w, tp.width);
    }
    return w + 36;
  }

  @override
  Widget build(BuildContext context) {
    final selectedIndex = options.indexWhere((option) => option.value == selectedValue);
    final safeSelectedIndex = (selectedIndex < 0 ? 0 : selectedIndex).clamp(0, options.length - 1);

    final theme = Theme.of(context);
    final selectedColor = theme.colorScheme.primary;
    final bgColor =
        theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.65);

    const double inset = 3;
    const double horizontalHeight = 36;
    const double verticalCellHeight = 40;

    return LayoutBuilder(
      builder: (context, constraints) {
        final count = options.length;
        final intrinsicW = shrinkWidth && axis == SegmentedToggleAxis.vertical
            ? _labelMaxWidth(context, options)
            : null;
        final outerWidth = intrinsicW != null
            ? math.min(constraints.maxWidth.isFinite ? constraints.maxWidth : intrinsicW, intrinsicW)
            : (constraints.maxWidth.isFinite ? constraints.maxWidth : 320.0);
        final outerHeight = axis == SegmentedToggleAxis.horizontal ? horizontalHeight : verticalCellHeight * count;

        final knobHeight = axis == SegmentedToggleAxis.horizontal ? (outerHeight - inset * 2) : (verticalCellHeight - inset * 2);
        final knobWidth = axis == SegmentedToggleAxis.horizontal ? (outerWidth / count - inset * 2) : (outerWidth - inset * 2);

        return ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: Container(
            width: outerWidth,
            height: outerHeight,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: theme.dividerColor),
            ),
            child: Stack(
              children: [
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOutCubic,
                  left: axis == SegmentedToggleAxis.horizontal ? (outerWidth / count) * safeSelectedIndex + inset : inset,
                  top: axis == SegmentedToggleAxis.horizontal ? inset : verticalCellHeight * safeSelectedIndex + inset,
                  width: knobWidth,
                  height: knobHeight,
                  child: Container(
                    decoration: BoxDecoration(
                      color: selectedColor,
                      borderRadius: BorderRadius.circular(999),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x33000000),
                          blurRadius: 8,
                          offset: Offset(0, 3),
                        ),
                      ],
                    ),
                  ),
                ),
                axis == SegmentedToggleAxis.horizontal
                    ? Row(
                        children: [
                          for (final option in options)
                            Expanded(
                              child: SizedBox(
                                height: horizontalHeight,
                                child: _ToggleOptionLabel(
                                  label: option.label,
                                  selected: option.value == selectedValue,
                                  onTap: () => onChanged(option.value),
                                ),
                              ),
                            ),
                        ],
                      )
                    : Column(
                        children: [
                          for (final option in options)
                            SizedBox(
                              height: verticalCellHeight,
                              child: _ToggleOptionLabel(
                                label: option.label,
                                selected: option.value == selectedValue,
                                onTap: () => onChanged(option.value),
                              ),
                            ),
                        ],
                      ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ToggleOptionLabel extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ToggleOptionLabel({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: selected ? Colors.white : onSurface,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
