import 'package:flutter/services.dart';

/// Input formatter that allows only non-negative integers (digits only)
class NonNegativeIntFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // Allow empty string
    if (newValue.text.isEmpty) return newValue;

    // Remove any non-digit characters (including minus sign)
    final filtered = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');

    if (filtered != newValue.text) {
      return TextEditingValue(
        text: filtered,
        selection: TextSelection.collapsed(offset: filtered.length),
      );
    }

    return newValue;
  }
}
