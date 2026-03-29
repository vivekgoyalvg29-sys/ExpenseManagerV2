import 'dart:io';

import 'package:flutter/material.dart';

const IconData defaultAppIcon = Icons.category;

const List<IconData> selectableIcons = [
  defaultAppIcon,
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

IconData iconFromCodePoint(dynamic codePoint, {IconData fallback = defaultAppIcon}) {
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
  final IconData? icon;
  final String? imagePath;
  final double size;
  final double boxSize;

  const AppPageIcon({
    super.key,
    this.icon,
    this.imagePath,
    this.size = 18,
    this.boxSize = 36,
  });

  @override
  Widget build(BuildContext context) {
    final hasImage = imagePath != null && imagePath!.isNotEmpty && File(imagePath!).existsSync();

    return Container(
      width: boxSize,
      height: boxSize,
      decoration: BoxDecoration(
        color: const Color(0xFFE8F1FF),
        borderRadius: BorderRadius.circular(boxSize / 3),
      ),
      alignment: Alignment.center,
      clipBehavior: Clip.antiAlias,
      child: hasImage
          ? Image.file(
              File(imagePath!),
              fit: BoxFit.cover,
              width: boxSize,
              height: boxSize,
              errorBuilder: (_, __, ___) => Icon(
                icon ?? Icons.image_outlined,
                size: size,
                color: const Color(0xFF1D4ED8),
              ),
            )
          : Icon(
              icon ?? Icons.category,
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
    final clampedValue = value.clamp(0.0, 1.0).toDouble();

    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: SizedBox(
        height: 12,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Container(color: const Color(0xFFE7ECF4)),
            if (clampedValue > 0)
              Align(
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
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
              ),
          ],
        ),
      ),
    );
  }
}
