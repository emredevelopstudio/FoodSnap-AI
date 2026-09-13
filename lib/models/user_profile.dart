class UserProfile {
  final double heightCm;
  final double weightKg;
  final int age;
  final String gender; // 'm', 'w'
  final String activityLevel; // 'sedentary', 'light', 'moderate', 'very_active'
  final String goal; // 'maintain', 'lose', 'gain'

  const UserProfile({
    this.heightCm = 175.0,
    this.weightKg = 75.0,
    this.age = 28,
    this.gender = 'm',
    this.activityLevel = 'moderate',
    this.goal = 'maintain',
  });

  UserProfile copyWith({
    double? heightCm,
    double? weightKg,
    int? age,
    String? gender,
    String? activityLevel,
    String? goal,
  }) {
    return UserProfile(
      heightCm: heightCm ?? this.heightCm,
      weightKg: weightKg ?? this.weightKg,
      age: age ?? this.age,
      gender: gender ?? this.gender,
      activityLevel: activityLevel ?? this.activityLevel,
      goal: goal ?? this.goal,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'heightCm': heightCm,
      'weightKg': weightKg,
      'age': age,
      'gender': gender,
      'activityLevel': activityLevel,
      'goal': goal,
    };
  }

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      heightCm: (map['heightCm'] as num?)?.toDouble() ?? 175.0,
      weightKg: (map['weightKg'] as num?)?.toDouble() ?? 75.0,
      age: (map['age'] as num?)?.toInt() ?? 28,
      gender: map['gender'] as String? ?? 'm',
      activityLevel: map['activityLevel'] as String? ?? 'moderate',
      goal: map['goal'] as String? ?? 'maintain',
    );
  }

  /// Calculates Daily Calorie and Macro requirements based on Mifflin-St Jeor formula
  ({double bmr, double tdee, double calories, double protein, double carbs, double fat}) calculateTargets() {
    // 1. Grundumsatz (BMR) via moderner Mifflin-St Jeor Formel
    double bmr;
    if (gender == 'w') {
      bmr = (10 * weightKg) + (6.25 * heightCm) - (5 * age) - 161;
    } else {
      // default 'm' (Mann)
      bmr = (10 * weightKg) + (6.25 * heightCm) - (5 * age) + 5;
    }

    // 2. Gesamtumsatz (TDEE) PAL-Multiplikator
    double activityMultiplier;
    switch (activityLevel) {
      case 'sedentary':
        activityMultiplier = 1.2;
        break;
      case 'light':
        activityMultiplier = 1.375;
        break;
      case 'very_active':
        activityMultiplier = 1.725;
        break;
      case 'extremely_active':
        activityMultiplier = 1.9;
        break;
      case 'moderate':
      default:
        activityMultiplier = 1.55;
        break;
    }

    final double tdee = bmr * activityMultiplier;

    // 3. Ziel-Korrektur (Kaloriendefizit / Überschuss)
    double targetCalories;
    switch (goal) {
      case 'lose':
        // Nachhaltiges Defizit: -400 kcal (300 bis 500 kcal Bereich)
        targetCalories = (tdee - 400).clamp(1200.0, 5000.0);
        break;
      case 'gain':
        // Moderater Clean-Bulk Überschuss: +350 kcal (250 bis 400 kcal Bereich)
        targetCalories = (tdee + 350).clamp(1500.0, 6000.0);
        break;
      case 'maintain':
      default:
        targetCalories = tdee.clamp(1400.0, 5500.0);
        break;
    }

    // 4. Makronährstoff-Verteilung nach Ziel
    // 4a. Proteinbedarf nach wissenschaftlichem Standard:
    // - Fettabbau / Muskelerhalt: 2.0 bis 2.2 g/kg (2.1 g/kg)
    // - Muskelaufbau: 1.8 bis 2.0 g/kg (2.0 g/kg)
    // - Halten: 1.6 bis 1.8 g/kg (1.8 g/kg)
    double proteinMultiplier;
    switch (goal) {
      case 'lose':
        proteinMultiplier = 2.1;
        break;
      case 'gain':
        proteinMultiplier = 2.0;
        break;
      case 'maintain':
      default:
        proteinMultiplier = 1.8;
        break;
    }
    final double targetProtein = (weightKg * proteinMultiplier).clamp(40.0, 350.0);

    // 4b. Fettbedarf: 0.8 bis 1.0 g pro kg Körpergewicht (mind. 20-25% der Gesamtkalorien)
    double targetFat = (weightKg * 0.9).clamp(30.0, 200.0);
    final double minFatCalories = targetCalories * 0.22; // mind. 22% der Gesamtkalorien
    if (targetFat * 9.0 < minFatCalories) {
      targetFat = minFatCalories / 9.0;
    }

    final double roundedCalories = targetCalories.roundToDouble();
    final double roundedProtein = targetProtein.roundToDouble();
    final double roundedFat = targetFat.roundToDouble();

    // 4c. Kohlenhydrate: Restliche verbleibende Kalorien (Gesamtkalorien - Protein-Kcal - Fett-Kcal) / 4
    final double proteinCalories = roundedProtein * 4.0;
    final double fatCalories = roundedFat * 9.0;
    final double remainingCalories = roundedCalories - (proteinCalories + fatCalories);
    final double targetCarbs = (remainingCalories / 4.0).clamp(0.0, 1000.0).roundToDouble();

    return (
      bmr: bmr.roundToDouble(),
      tdee: tdee.roundToDouble(),
      calories: roundedCalories,
      protein: roundedProtein,
      carbs: targetCarbs,
      fat: roundedFat,
    );
  }
}
