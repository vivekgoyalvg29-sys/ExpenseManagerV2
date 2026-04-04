import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

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

const List<String> selectableAccountSampleIconPaths = [
  'assets/sample_icons/account/cash.svg',
  'assets/sample_icons/account/bank.svg',
  'assets/sample_icons/account/savings.svg',
  'assets/sample_icons/account/credit_card.svg',
  'assets/sample_icons/account/wallet.svg',
];

const List<String> selectableIncomeCategorySampleIconPaths = [
  'assets/sample_icons/income_category/salary.svg',
  'assets/sample_icons/income_category/bonus.svg',
  'assets/sample_icons/income_category/freelance.svg',
  'assets/sample_icons/income_category/interest.svg',
  'assets/sample_icons/income_category/dividends.svg',
  'assets/sample_icons/income_category/gifts.svg',
  'assets/sample_icons/income_category/reimbursements.svg',
  'assets/sample_icons/income_category/rental.svg',
  'assets/sample_icons/income_category/other.svg',
];

const List<String> selectableExpenseCategorySampleIconPaths = [
  'assets/sample_icons/expense_category/housing.svg',
  'assets/sample_icons/expense_category/utilities.svg',
  'assets/sample_icons/expense_category/groceries.svg',
  'assets/sample_icons/expense_category/dining.svg',
  'assets/sample_icons/expense_category/transport.svg',
  'assets/sample_icons/expense_category/health.svg',
  'assets/sample_icons/expense_category/insurance.svg',
  'assets/sample_icons/expense_category/education.svg',
  'assets/sample_icons/expense_category/entertainment.svg',
  'assets/sample_icons/expense_category/shopping.svg',
  'assets/sample_icons/expense_category/subscriptions.svg',
  'assets/sample_icons/expense_category/debt.svg',
  'assets/sample_icons/expense_category/savings.svg',
  'assets/sample_icons/expense_category/donations.svg',
  'assets/sample_icons/expense_category/misc.svg',
];

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

  const AppPageIcon({
    super.key,
    this.icon,
    this.imagePath,
    this.size = 18,
    this.boxSize = 36,
  });

  @override
  Widget build(BuildContext context) {
    final hasAssetImage =
        imagePath != null && imagePath!.isNotEmpty && imagePath!.startsWith('assets/');
    final hasFileImage =
        imagePath != null && imagePath!.isNotEmpty && File(imagePath!).existsSync();
    final hasImage = hasAssetImage || hasFileImage;

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
          ? (hasAssetImage
              ? SvgPicture.asset(
                  imagePath!,
                  fit: BoxFit.cover,
                  width: boxSize,
                  height: boxSize,
                )
              : Image.file(
                  File(imagePath!),
                  fit: BoxFit.cover,
                  width: boxSize,
                  height: boxSize,
                  errorBuilder: (_, __, ___) => Icon(
                    icon ?? Icons.image_outlined,
                    size: size,
                    color: const Color(0xFF1D4ED8),
                  ),
                ))
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
