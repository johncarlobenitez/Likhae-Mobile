import 'package:flutter/services.dart';

/// Groups whole digits from the right while leaving a typed decimal fraction
/// in place. Commas are display-only and are removed by [parseMoneyInput].
String formatGroupedMoneyInput(String value, {int decimalDigits = 2}) {
  final String raw = value
      .replaceAll(',', '')
      .replaceAll(RegExp(r'[^0-9.]'), '');
  final int decimalIndex = raw.indexOf('.');
  final String whole = decimalIndex < 0 ? raw : raw.substring(0, decimalIndex);
  final String rawFraction = decimalIndex < 0
      ? ''
      : raw.substring(decimalIndex + 1).replaceAll('.', '');
  final String fraction = rawFraction.length > decimalDigits
      ? rawFraction.substring(0, decimalDigits)
      : rawFraction;
  final StringBuffer grouped = StringBuffer();
  for (int index = 0; index < whole.length; index++) {
    if (index > 0 && (whole.length - index) % 3 == 0) grouped.write(',');
    grouped.write(whole[index]);
  }
  final String formattedWhole = whole.isEmpty && decimalIndex >= 0
      ? '0'
      : grouped.toString();
  return decimalIndex < 0 ? formattedWhole : '$formattedWhole.$fraction';
}

String parseMoneyInput(String value) =>
    value.replaceAll(RegExp(r'PHP|₱|,|\s', caseSensitive: false), '').trim();

double? parseMoneyAmount(String value) {
  final double? amount = double.tryParse(parseMoneyInput(value));
  return amount != null && amount.isFinite ? amount : null;
}

String formatGroupedMoney(
  num value, {
  int decimalDigits = 2,
  bool trimTrailingZeros = false,
}) {
  final String fixed = value.abs().toStringAsFixed(decimalDigits);
  final List<String> parts = fixed.split('.');
  final String groupedWhole = formatGroupedMoneyInput(parts.first);
  String fraction = parts.length > 1 ? parts.last : '';
  if (trimTrailingZeros) fraction = fraction.replaceFirst(RegExp(r'0+$'), '');
  final String sign = value < 0 ? '-' : '';
  return '$sign$groupedWhole${fraction.isEmpty ? '' : '.$fraction'}';
}

String formatPesoCurrency(num value) => '₱${formatGroupedMoney(value)}';

String formatPesoValue(Object? value, {String fallback = '—'}) {
  final String raw = (value ?? '').toString().trim();
  if (raw.isEmpty || raw == '—') return fallback;
  final num? amount = num.tryParse(parseMoneyInput(raw));
  return amount == null || !amount.isFinite
      ? fallback
      : formatPesoCurrency(amount);
}

/// Adds live thousands separators and keeps the caret next to the same digit.
class MonetaryAmountInputFormatter extends TextInputFormatter {
  const MonetaryAmountInputFormatter({this.decimalDigits = 2})
    : assert(decimalDigits >= 0);

  final int decimalDigits;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (!newValue.composing.isCollapsed) return newValue;

    String filtered = '';
    int decimalCount = 0;
    int fractionCount = 0;
    final int rawCursor = newValue.selection.extentOffset;
    int acceptedBeforeCursor = 0;
    for (int index = 0; index < newValue.text.length; index++) {
      final String character = newValue.text[index];
      final bool beforeCursor = index < rawCursor;
      if (character == '.' && decimalCount == 0) {
        filtered += character;
        decimalCount++;
        if (beforeCursor) acceptedBeforeCursor++;
      } else if (RegExp(r'\d').hasMatch(character)) {
        if (decimalCount == 0) {
          filtered += character;
          if (beforeCursor) acceptedBeforeCursor++;
        } else if (fractionCount < decimalDigits) {
          filtered += character;
          fractionCount++;
          if (beforeCursor) acceptedBeforeCursor++;
        }
      }
    }

    final String formatted = formatGroupedMoneyInput(
      filtered,
      decimalDigits: decimalDigits,
    );
    int cursor = 0;
    int counted = 0;
    while (cursor < formatted.length && counted < acceptedBeforeCursor) {
      if (formatted[cursor] != ',') counted++;
      cursor++;
    }
    final int selectionEnd = newValue.selection.isValid
        ? cursor
        : formatted.length;
    final int selectionStart = newValue.selection.isValid
        ? _formattedOffsetFor(
            newValue.text,
            newValue.selection.baseOffset,
            formatted,
          )
        : selectionEnd;

    return TextEditingValue(
      text: formatted,
      selection: TextSelection(
        baseOffset: selectionStart,
        extentOffset: selectionEnd,
      ),
    );
  }

  int _formattedOffsetFor(String input, int offset, String formatted) {
    int accepted = 0;
    for (int index = 0; index < offset && index < input.length; index++) {
      final String character = input[index];
      if (RegExp(r'\d').hasMatch(character) || character == '.') accepted++;
    }
    int result = 0;
    int counted = 0;
    while (result < formatted.length && counted < accepted) {
      if (formatted[result] != ',') counted++;
      result++;
    }
    return result;
  }
}
