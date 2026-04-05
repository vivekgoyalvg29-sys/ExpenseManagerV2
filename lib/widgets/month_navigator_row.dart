import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class MonthNavigatorRow extends StatelessWidget {
  final DateTime currentMonth;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final Widget? trailing;

  const MonthNavigatorRow({
    super.key,
    required this.currentMonth,
    required this.onPrev,
    required this.onNext,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final titleStyle = theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
          letterSpacing: -0.2,
          color: theme.colorScheme.onSurface,
        ) ??
        TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.2,
          color: theme.colorScheme.onSurface,
        );

    Widget navButton({required IconData icon, required VoidCallback onPressed}) {
      return IconButton(
        onPressed: onPressed,
        icon: Icon(icon, size: 22),
        style: IconButton.styleFrom(
          foregroundColor: theme.colorScheme.onSurfaceVariant,
          visualDensity: VisualDensity.compact,
          minimumSize: const Size(36, 36),
          padding: EdgeInsets.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      );
    }

    return Row(
      children: [
        navButton(icon: Icons.chevron_left_rounded, onPressed: onPrev),
        Expanded(
          child: Text(
            DateFormat('MMMM yyyy').format(currentMonth),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: titleStyle,
          ),
        ),
        navButton(icon: Icons.chevron_right_rounded, onPressed: onNext),
        if (trailing != null) ...[
          const SizedBox(width: 2),
          trailing!,
        ],
      ],
    );
  }
}
