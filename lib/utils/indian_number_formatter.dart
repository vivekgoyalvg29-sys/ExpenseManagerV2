import 'package:intl/intl.dart';

final NumberFormat _indianCurrencyNoDecimals = NumberFormat.currency(
  locale: 'en_IN',
  symbol: '₹',
  decimalDigits: 0,
);

final NumberFormat _indianCurrencyTwoDecimals = NumberFormat.currency(
  locale: 'en_IN',
  symbol: '₹',
  decimalDigits: 2,
);

String formatIndianCurrency(
  num value, {
  int decimalDigits = 0,
  bool includeSymbol = true,
}) {
  final formatter = decimalDigits == 2
      ? _indianCurrencyTwoDecimals
      : _indianCurrencyNoDecimals;
  final formatted = formatter.format(value);

  if (includeSymbol) {
    return formatted;
  }

  return formatted.replaceFirst('₹', '').trimLeft();
}
