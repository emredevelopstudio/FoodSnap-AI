import 'nutrition_value.dart';

class MealItem {
  final String name;
  final double estimatedWeightG;
  final double calories;
  final double proteinG;
  final double carbsG;
  final double fatG;

  const MealItem({
    required this.name,
    required this.estimatedWeightG,
    required this.calories,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
  });

  MealItem copyWith({
    String? name,
    double? estimatedWeightG,
    double? calories,
    double? proteinG,
    double? carbsG,
    double? fatG,
  }) {
    return MealItem(
      name: name ?? this.name,
      estimatedWeightG: estimatedWeightG ?? this.estimatedWeightG,
      calories: calories ?? this.calories,
      proteinG: proteinG ?? this.proteinG,
      carbsG: carbsG ?? this.carbsG,
      fatG: fatG ?? this.fatG,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'amount_grams': estimatedWeightG,
      'estimatedWeightG': estimatedWeightG,
      'calories': calories,
      'protein': proteinG,
      'proteinG': proteinG,
      'carbs': carbsG,
      'carbsG': carbsG,
      'fat': fatG,
      'fatG': fatG,
    };
  }

  factory MealItem.fromMap(Map<String, dynamic> map) {
    return MealItem(
      name: map['name']?.toString() ?? 'Lebensmittel',
      estimatedWeightG: parseNutritionValue(map['amount_grams']) ??
          parseNutritionValue(map['amountGrams']) ??
          parseNutritionValue(map['estimatedWeightG']) ??
          parseNutritionValue(map['estimated_weight_g']) ??
          0.0,
      calories: parseNutritionValue(map['calories']) ?? 0.0,
      proteinG: parseNutritionValue(map['protein']) ??
          parseNutritionValue(map['proteinG']) ??
          parseNutritionValue(map['protein_g']) ??
          0.0,
      carbsG: parseNutritionValue(map['carbs']) ??
          parseNutritionValue(map['carbsG']) ??
          parseNutritionValue(map['carbs_g']) ??
          0.0,
      fatG: parseNutritionValue(map['fat']) ??
          parseNutritionValue(map['fatG']) ??
          parseNutritionValue(map['fat_g']) ??
          0.0,
    );
  }
}
