class DailyGoals {
  final double targetCalories;
  final double targetProteinG;

  const DailyGoals({
    this.targetCalories = 2200.0,
    this.targetProteinG = 160.0,
  });

  DailyGoals copyWith({
    double? targetCalories,
    double? targetProteinG,
  }) {
    return DailyGoals(
      targetCalories: targetCalories ?? this.targetCalories,
      targetProteinG: targetProteinG ?? this.targetProteinG,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'targetCalories': targetCalories,
      'targetProteinG': targetProteinG,
    };
  }

  factory DailyGoals.fromMap(Map<String, dynamic> map) {
    return DailyGoals(
      targetCalories: (map['targetCalories'] as num?)?.toDouble() ?? 2200.0,
      targetProteinG: (map['targetProteinG'] as num?)?.toDouble() ?? 160.0,
    );
  }
}

