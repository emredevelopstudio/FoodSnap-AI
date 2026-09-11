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
      name: map['name'] as String? ?? 'Lebensmittel',
      estimatedWeightG: (map['amount_grams'] as num?)?.toDouble() ??
          (map['amountGrams'] as num?)?.toDouble() ??
          (map['estimatedWeightG'] as num?)?.toDouble() ??
          (map['estimated_weight_g'] as num?)?.toDouble() ??
          0.0,
      calories: (map['calories'] as num?)?.toDouble() ?? 0.0,
      proteinG: (map['protein'] as num?)?.toDouble() ??
          (map['proteinG'] as num?)?.toDouble() ??
          (map['protein_g'] as num?)?.toDouble() ??
          0.0,
      carbsG: (map['carbs'] as num?)?.toDouble() ??
          (map['carbsG'] as num?)?.toDouble() ??
          (map['carbs_g'] as num?)?.toDouble() ??
          0.0,
      fatG: (map['fat'] as num?)?.toDouble() ??
          (map['fatG'] as num?)?.toDouble() ??
          (map['fat_g'] as num?)?.toDouble() ??
          0.0,
    );
  }
}
