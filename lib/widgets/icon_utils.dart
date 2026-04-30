import 'dart:io';

import 'package:flutter/material.dart';

import '../services/default_seed_icons.dart';

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

/// All bundled PNG variants (`1`–`3`) for default account names.
List<String> get selectableAccountSampleIconPaths =>
    DefaultSeedIcons.allAccountSampleIconPaths;

/// All bundled PNG variants for default income category names.
List<String> get selectableIncomeCategorySampleIconPaths =>
    DefaultSeedIcons.allIncomeCategorySampleIconPaths;

/// All bundled PNG variants for default expense category names.
List<String> get selectableExpenseCategorySampleIconPaths =>
    DefaultSeedIcons.allExpenseCategorySampleIconPaths;

const List<IconData> _persistedCodePointIcons = [
  ...selectableIcons,
  Icons.trending_up,
  Icons.shopping_bag_outlined,
  Icons.account_balance_wallet,
  Icons.account_balance_wallet_outlined,
];

final Map<int, IconData> _persistedCodePointIconMap = {
  for (final icon in _persistedCodePointIcons) icon.codePoint: icon,
};

int? _parseStoredCodePoint(dynamic codePoint) {
  if (codePoint is int) return codePoint;
  if (codePoint is num) return codePoint.toInt();
  if (codePoint is String) return int.tryParse(codePoint.trim());
  return null;
}

IconData iconFromCodePoint(dynamic codePoint, {IconData fallback = defaultAppIcon}) {
  final parsedCodePoint = _parseStoredCodePoint(codePoint);
  if (parsedCodePoint == null) return fallback;

  return _persistedCodePointIconMap[parsedCodePoint] ?? fallback;
}

class AppPageIcon extends StatelessWidget {
  final IconData? icon;
  final String? imagePath;
  final double size;
  final double boxSize;

  /// No outer colored tile — use inside a parent well (e.g. [GroupedListIconWell]).
  final bool embedded;

  const AppPageIcon({
    super.key,
    this.icon,
    this.imagePath,
    this.size = 18,
    this.boxSize = 36,
    this.embedded = false,
  });

  @override
  Widget build(BuildContext context) {
    final hasAssetImage =
        imagePath != null && imagePath!.isNotEmpty && imagePath!.startsWith('assets/');
    final hasFileImage =
        imagePath != null && imagePath!.isNotEmpty && File(imagePath!).existsSync();
    final hasImage = hasAssetImage || hasFileImage;

    final cs = Theme.of(context).colorScheme;
    final iconTint = embedded ? cs.primary : const Color(0xFF1D4ED8);
    final fallbackTint = embedded ? cs.onSurfaceVariant : const Color(0xFF1D4ED8);

    final Widget child;
    if (hasImage) {
      if (hasAssetImage) {
        final lower = imagePath!.toLowerCase();
        if (lower.endsWith('.svg')) {
          child = Icon(
            icon ?? Icons.image_not_supported_outlined,
            size: size,
            color: fallbackTint,
          );
        } else {
          final assetKey = DefaultSeedIcons.normalizeBundledSeedIconPath(imagePath!) ?? imagePath!;
          child = Image.asset(
            assetKey,
            fit: BoxFit.contain,
            width: boxSize,
            height: boxSize,
            filterQuality: FilterQuality.medium,
            errorBuilder: (_, __, ___) => Icon(
              icon ?? Icons.image_outlined,
              size: size,
              color: fallbackTint,
            ),
          );
        }
      } else {
        child = Image.file(
          File(imagePath!),
          fit: BoxFit.contain,
          width: boxSize,
          height: boxSize,
          filterQuality: FilterQuality.medium,
          errorBuilder: (_, __, ___) => Icon(
            icon ?? Icons.image_outlined,
            size: size,
            color: fallbackTint,
          ),
        );
      }
    } else {
      child = Icon(
        icon ?? Icons.category,
        size: size,
        color: iconTint,
      );
    }

    if (embedded) {
      return SizedBox(
        width: boxSize,
        height: boxSize,
        child: Center(child: child),
      );
    }

    return Container(
      width: boxSize,
      height: boxSize,
      decoration: BoxDecoration(
        color: const Color(0xFFE8F1FF),
        borderRadius: BorderRadius.circular(boxSize / 3),
      ),
      alignment: Alignment.center,
      clipBehavior: Clip.antiAlias,
      child: child,
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
                        colors: [color.withValues(alpha: 0.72), color],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: color.withValues(alpha: 0.18),
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
