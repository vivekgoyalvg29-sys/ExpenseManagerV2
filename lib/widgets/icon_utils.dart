import 'package:flutter/material.dart';

const List<IconData> selectableIcons = [
  Icons.wallet,
  Icons.savings,
  Icons.credit_card,
  Icons.account_balance,
  Icons.shopping_bag,
  Icons.shopping_cart,
  Icons.home,
  Icons.restaurant,
  Icons.directions_car,
  Icons.local_hospital,
  Icons.school,
  Icons.movie,
  Icons.flight,
  Icons.cake,
  Icons.pets,
  Icons.attach_money,
  Icons.work,
  Icons.card_giftcard,
  Icons.phone_android,
  Icons.bolt,
];

IconData iconFromCodePoint(dynamic codePoint, {IconData fallback = Icons.category}) {
  if (codePoint is int) {
    for (final icon in selectableIcons) {
      if (icon.codePoint == codePoint) {
        return icon;
      }
    }
  }

  return fallback;
}

class AppPageIcon extends StatelessWidget {
  final IconData icon;
  final double size;

  const AppPageIcon({super.key, required this.icon, this.size = 18});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: const Color(0xFFE8F1FF),
        borderRadius: BorderRadius.circular(12),
      ),
      alignment: Alignment.center,
      child: Icon(
        icon,
        size: size,
        color: const Color(0xFF1D4ED8),
      ),
    );
  }
}

class ModernProgressBar extends StatelessWidget {
  final double value;
  final Color color;

  const ModernProgressBar({super.key, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    final clampedValue = value.clamp(0.0, 1.0);

    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: SizedBox(
        height: 10,
        child: Stack(
          children: [
            Container(color: const Color(0xFFE7ECF4)),
            FractionallySizedBox(
              widthFactor: clampedValue,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [color.withOpacity(0.72), color],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: color.withOpacity(0.18),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
