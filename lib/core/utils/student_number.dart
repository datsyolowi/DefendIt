import 'package:flutter/services.dart';

class StudentNumber {
  StudentNumber._();

  static const example = '202X-XXXXXX';
  static final _valid = RegExp(r'^20\d{2}-\d{6}$');

  /// Keeps digits only and puts the dash after the 4th digit: 2022102420 -> 2022-102420
  static String normalize(String raw) {
    final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    final capped = digits.length > 10 ? digits.substring(0, 10) : digits;
    return capped.length <= 4
        ? capped
        : '${capped.substring(0, 4)}-${capped.substring(4)}';
  }

  static bool isValid(String value) => _valid.hasMatch(value);

  static String? validator(String? value) {
    final v = (value ?? '').trim();
    if (v.isEmpty) return 'Enter your student number';
    if (!isValid(normalize(v))) {
      return 'Use the format $example, for example 2022-102420';
    }
    return null;
  }
}

/// Inserts the dash while the student types.
class StudentNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = StudentNumber.normalize(newValue.text);
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
