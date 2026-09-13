class DailyGoals {
  final double targetCalories;
  final double targetProteinG;
  final double targetCarbsG;
  final double targetFatG;

  const DailyGoals({
    this.targetCalories = 2200.0,
    this.targetProteinG = 160.0,
    this.targetCarbsG = 250.0,
    this.targetFatG = 70.0,
  });

  DailyGoals copyWith({
    double? targetCalories,
    double? targetProteinG,
    double? targetCarbsG,
    double? targetFatG,
  }) {
    return DailyGoals(
      targetCalories: targetCalories ?? this.targetCalories,
      targetProteinG: targetProteinG ?? this.targetProteinG,
      targetCarbsG: targetCarbsG ?? this.targetCarbsG,
      targetFatG: targetFatG ?? this.targetFatG,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'targetCalories': targetCalories,
      'targetProteinG': targetProteinG,
      'targetCarbsG': targetCarbsG,
      'targetFatG': targetFatG,
    };
  }

  factory DailyGoals.fromMap(Map<String, dynamic> map) {
    return DailyGoals(
      targetCalories: (map['targetCalories'] as num?)?.toDouble() ?? 2200.0,
      targetProteinG: (map['targetProteinG'] as num?)?.toDouble() ?? 160.0,
      targetCarbsG: (map['targetCarbsG'] as num?)?.toDouble() ?? 250.0,
      targetFatG: (map['targetFatG'] as num?)?.toDouble() ?? 70.0,
    );
  }
}

