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
