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

  /// Row height for each option when [axis] is vertical. Defaults to 40 if null.
  final double? verticalCellHeight;

  const SegmentedToggle({
    super.key,
    required this.options,
    required this.selectedValue,
    required this.onChanged,
    this.axis = SegmentedToggleAxis.horizontal,
    this.shrinkWidth = false,
    this.verticalCellHeight,
  });

  static double _labelMaxWidth(
    BuildContext context,
    List<SegmentedToggleOption<dynamic>> options, {
    double baseFontSize = 12,
  }) {
    // Account for system/app text scale so the knob width matches rendered text.
    final scale = MediaQuery.textScalerOf(context).scale(baseFontSize) / baseFontSize;
    final style = Theme.of(context).textTheme.labelLarge?.copyWith(
          fontSize: baseFontSize * scale,
          fontWeight: FontWeight.w700,
        ) ??
        TextStyle(fontSize: baseFontSize * scale, fontWeight: FontWeight.w700);
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
    const double horizontalHeight = 42;
    const double defaultVerticalCellHeight = 40;

    return LayoutBuilder(
      builder: (context, constraints) {
        final count = options.length;
        final vCell = verticalCellHeight ?? defaultVerticalCellHeight;
        final compactVertical = axis == SegmentedToggleAxis.vertical && vCell < defaultVerticalCellHeight;
        final labelBaseSize = compactVertical ? 11.0 : 12.0;
        final intrinsicW = shrinkWidth && axis == SegmentedToggleAxis.vertical
            ? _labelMaxWidth(context, options, baseFontSize: labelBaseSize)
            : null;
        final outerWidth = intrinsicW != null
            ? math.min(constraints.maxWidth.isFinite ? constraints.maxWidth : intrinsicW, intrinsicW)
            : (constraints.maxWidth.isFinite ? constraints.maxWidth : 320.0);
        final outerHeight = axis == SegmentedToggleAxis.horizontal ? horizontalHeight : vCell * count;

        final knobHeight = axis == SegmentedToggleAxis.horizontal ? (outerHeight - inset * 2) : (vCell - inset * 2);
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
                  top: axis == SegmentedToggleAxis.horizontal ? inset : vCell * safeSelectedIndex + inset,
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
                                  axis: axis,
                                  compactHeight: false,
                                ),
                              ),
                            ),
                        ],
                      )
                    : Column(
                        children: [
                          for (final option in options)
                            SizedBox(
                              height: vCell,
                              child: _ToggleOptionLabel(
                                label: option.label,
                                selected: option.value == selectedValue,
                                onTap: () => onChanged(option.value),
                                axis: axis,
                                compactHeight: compactVertical,
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
  final SegmentedToggleAxis axis;
  final bool compactHeight;

  const _ToggleOptionLabel({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.axis,
    this.compactHeight = false,
  });

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final fontSize = compactHeight ? 11.0 : 12.0;
    final hPad = compactHeight ? 8.0 : 10.0;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Center(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: hPad),
            child: Text(
              label,
              maxLines: axis == SegmentedToggleAxis.horizontal ? 2 : 1,
              softWrap: axis == SegmentedToggleAxis.horizontal,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: fontSize,
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
