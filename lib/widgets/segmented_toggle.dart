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

  const SegmentedToggle({
    super.key,
    required this.options,
    required this.selectedValue,
    required this.onChanged,
    this.axis = SegmentedToggleAxis.horizontal,
  });

  @override
  Widget build(BuildContext context) {
    final selectedIndex = options.indexWhere((option) => option.value == selectedValue);
    final theme = Theme.of(context);
    final selectedColor = theme.colorScheme.primary;
    final bgColor = theme.colorScheme.surfaceVariant.withOpacity(0.55);
    final knobInsets = axis == SegmentedToggleAxis.horizontal
        ? const EdgeInsets.symmetric(vertical: 3, horizontal: 3)
        : const EdgeInsets.symmetric(vertical: 3, horizontal: 3);

    return LayoutBuilder(
      builder: (context, constraints) {
        final count = options.length;
        final size = axis == SegmentedToggleAxis.horizontal
            ? (constraints.maxWidth.isFinite ? constraints.maxWidth : 300) / count
            : 38.0;
        final knobWidth = axis == SegmentedToggleAxis.horizontal ? size - 6 : (constraints.maxWidth.isFinite ? constraints.maxWidth - 6 : 180);
        final knobHeight = axis == SegmentedToggleAxis.vertical ? size - 6 : 36.0;
        final knobOffset = selectedIndex < 0 ? 0.0 : selectedIndex * size;

        return Container(
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: theme.dividerColor),
          ),
          padding: knobInsets,
          child: Stack(
            children: [
              AnimatedPositioned(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                left: axis == SegmentedToggleAxis.horizontal ? knobOffset : 0,
                top: axis == SegmentedToggleAxis.vertical ? knobOffset : 0,
                child: Container(
                  width: knobWidth,
                  height: knobHeight,
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
                            child: _ToggleOptionLabel(
                              label: option.label,
                              selected: option.value == selectedValue,
                              onTap: () => onChanged(option.value),
                            ),
                          ),
                      ],
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final option in options)
                          SizedBox(
                            height: 38,
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
