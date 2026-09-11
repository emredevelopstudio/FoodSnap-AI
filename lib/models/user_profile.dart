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

  /// Calculates Daily Calorie and Protein requirements based on Mifflin-St Jeor formula
  ({double bmr, double tdee, double calories, double protein}) calculateTargets() {
    // 1. Grundumsatz (BMR) via Mifflin-St Jeor
    double bmr;
    if (gender == 'w') {
      bmr = (10 * weightKg) + (6.25 * heightCm) - (5 * age) - 161;
    } else {
      // default 'm' (Mann)
      bmr = (10 * weightKg) + (6.25 * heightCm) - (5 * age) + 5;
    }

    // 2. Gesamtumsatz (TDEE) Multiplikator
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
      case 'moderate':
      default:
        activityMultiplier = 1.55;
        break;
    }

    double tdee = bmr * activityMultiplier;

    // 3. Ziel-Korrektur (Kalorien)
    double targetCalories;
    switch (goal) {
      case 'lose':
        targetCalories = (tdee - 400).clamp(1200.0, 5000.0);
        break;
      case 'gain':
        targetCalories = (tdee + 400).clamp(1500.0, 6000.0);
        break;
      case 'maintain':
      default:
        targetCalories = tdee.clamp(1400.0, 5500.0);
        break;
    }

    // 4. Proteinbedarf: ca. 2.0g pro kg Körpergewicht
    double targetProtein = (weightKg * 2.0).clamp(40.0, 350.0);

    return (
      bmr: bmr.roundToDouble(),
      tdee: tdee.roundToDouble(),
      calories: targetCalories.roundToDouble(),
      protein: targetProtein.roundToDouble(),
    );
  }
}
