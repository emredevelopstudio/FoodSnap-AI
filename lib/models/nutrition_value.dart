/// Accepts JSON numbers and numeric strings, excluding NaN and infinity.
double? parseNutritionValue(Object? value) {
  final parsed = num.tryParse(value?.toString().trim() ?? '');
  return parsed != null && parsed.isFinite ? parsed.toDouble() : null;
}
