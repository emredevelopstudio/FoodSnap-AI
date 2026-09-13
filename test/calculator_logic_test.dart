import 'package:flutter_test/flutter_test.dart';
import 'package:foodsnap_ai/models/user_profile.dart';
import 'package:foodsnap_ai/models/daily_goals.dart';

void main() {
  group('Mifflin-St. Jeor BMR Calculation', () {
    test('Calculates BMR correctly for men', () {
      // BMR = 10 * 80 + 6.25 * 180 - 5 * 25 + 5 = 800 + 1125 - 125 + 5 = 1805
      const profile = UserProfile(
        weightKg: 80.0,
        heightCm: 180.0,
        age: 25,
        gender: 'm',
        activityLevel: 'sedentary',
        goal: 'maintain',
      );
      final targets = profile.calculateTargets();
      expect(targets.bmr, 1805.0);
    });

    test('Calculates BMR correctly for women', () {
      // BMR = 10 * 60 + 6.25 * 165 - 5 * 30 - 161 = 600 + 1031.25 - 150 - 161 = 1320.25 -> round = 1320.0
      const profile = UserProfile(
        weightKg: 60.0,
        heightCm: 165.0,
        age: 30,
        gender: 'w',
        activityLevel: 'sedentary',
        goal: 'maintain',
      );
      final targets = profile.calculateTargets();
      expect(targets.bmr, 1320.0);
    });
  });

  group('PAL Activity Multipliers (TDEE)', () {
    const baseProfile = UserProfile(
      weightKg: 80.0,
      heightCm: 180.0,
      age: 25,
      gender: 'm',
      goal: 'maintain',
    );
    // BMR = 1805.0

    test('Sedentary (1.2)', () {
      final p = baseProfile.copyWith(activityLevel: 'sedentary');
      final t = p.calculateTargets();
      expect(t.tdee, (1805.0 * 1.2).roundToDouble()); // 2166.0
    });

    test('Lightly active (1.375)', () {
      final p = baseProfile.copyWith(activityLevel: 'light');
      final t = p.calculateTargets();
      expect(t.tdee, (1805.0 * 1.375).roundToDouble()); // 2482.0
    });

    test('Moderately active (1.55)', () {
      final p = baseProfile.copyWith(activityLevel: 'moderate');
      final t = p.calculateTargets();
      expect(t.tdee, (1805.0 * 1.55).roundToDouble()); // 2798.0
    });

    test('Very active (1.725)', () {
      final p = baseProfile.copyWith(activityLevel: 'very_active');
      final t = p.calculateTargets();
      expect(t.tdee, (1805.0 * 1.725).roundToDouble()); // 3114.0
    });

    test('Extremely active (1.9)', () {
      final p = baseProfile.copyWith(activityLevel: 'extremely_active');
      final t = p.calculateTargets();
      expect(t.tdee, (1805.0 * 1.9).roundToDouble()); // 3430.0
    });
  });

  group('Goal Calorie Adjustments', () {
    const baseProfile = UserProfile(
      weightKg: 80.0,
      heightCm: 180.0,
      age: 25,
      gender: 'm',
      activityLevel: 'moderate', // TDEE = 2798
    );

    test('Deficit (lose): TDEE - 400 kcal', () {
      final p = baseProfile.copyWith(goal: 'lose');
      final t = p.calculateTargets();
      expect(t.calories, (t.tdee - 400).roundToDouble());
    });

    test('Maintain: TDEE', () {
      final p = baseProfile.copyWith(goal: 'maintain');
      final t = p.calculateTargets();
      expect(t.calories, t.tdee);
    });

    test('Surplus (gain): TDEE + 350 kcal', () {
      final p = baseProfile.copyWith(goal: 'gain');
      final t = p.calculateTargets();
      expect(t.calories, (t.tdee + 350).roundToDouble());
    });
  });

  group('Macronutrient Distribution', () {
    test('Calculates protein based on goal (lose: 2.1g/kg, gain: 2.0g/kg, maintain: 1.8g/kg)', () {
      const pLose = UserProfile(weightKg: 70.0, goal: 'lose');
      expect(pLose.calculateTargets().protein, (70.0 * 2.1).roundToDouble()); // 147g

      const pGain = UserProfile(weightKg: 70.0, goal: 'gain');
      expect(pGain.calculateTargets().protein, (70.0 * 2.0).roundToDouble()); // 140g

      const pMaintain = UserProfile(weightKg: 70.0, goal: 'maintain');
      expect(pMaintain.calculateTargets().protein, (70.0 * 1.8).roundToDouble()); // 126g
    });

    test('Calculates fat with min 20-25% calories check and remaining carbs', () {
      const p = UserProfile(
        weightKg: 80.0,
        heightCm: 180.0,
        age: 25,
        gender: 'm',
        activityLevel: 'moderate',
        goal: 'maintain',
      );
      final t = p.calculateTargets();

      // Fat is at least 0.9g/kg (72g) or 22% of total calories
      expect(t.fat, greaterThanOrEqualTo(72.0));
      final fatCalories = t.fat * 9.0;
      expect(fatCalories, greaterThanOrEqualTo(t.calories * 0.20));

      // Carbs are the remaining calories
      final proteinCalories = t.protein * 4.0;
      final expectedCarbs = ((t.calories - (proteinCalories + fatCalories)) / 4.0).roundToDouble();
      expect(t.carbs, expectedCarbs);

      // Total calories from macros matches total calories closely
      final totalMacroCalories = (t.protein * 4) + (t.fat * 9) + (t.carbs * 4);
      expect((totalMacroCalories - t.calories).abs(), lessThanOrEqualTo(10.0));
    });
  });

  group('DailyGoals Model', () {
    test('Supports targetCarbsG and targetFatG with serialization', () {
      const goals = DailyGoals(
        targetCalories: 2500.0,
        targetProteinG: 175.0,
        targetCarbsG: 280.0,
        targetFatG: 75.0,
      );

      final map = goals.toMap();
      expect(map['targetCalories'], 2500.0);
      expect(map['targetProteinG'], 175.0);
      expect(map['targetCarbsG'], 280.0);
      expect(map['targetFatG'], 75.0);

      final fromMap = DailyGoals.fromMap(map);
      expect(fromMap.targetCalories, 2500.0);
      expect(fromMap.targetProteinG, 175.0);
      expect(fromMap.targetCarbsG, 280.0);
      expect(fromMap.targetFatG, 75.0);

      final backwardCompat = DailyGoals.fromMap({
        'targetCalories': 2100.0,
        'targetProteinG': 150.0,
      });
      expect(backwardCompat.targetCalories, 2100.0);
      expect(backwardCompat.targetProteinG, 150.0);
      expect(backwardCompat.targetCarbsG, 250.0);
      expect(backwardCompat.targetFatG, 70.0);
    });
  });
}
