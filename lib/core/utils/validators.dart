class Validators {
  Validators._();

  static String? text(
      String? value, {
        required String label,
        int min = 1,
        int max = 100,
      }) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return '$label is required';
    if (v.length < min) return '$label must be at least $min characters';
    if (v.length > max) return '$label must be at most $max characters';
    return null;
  }

  static String? joinCode(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Enter the group code';
    if (v.length != 6) return 'The code is 6 characters';
    return null;
  }
}