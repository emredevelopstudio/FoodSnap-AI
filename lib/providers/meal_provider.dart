import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/meal_entry.dart';
import '../services/hive_service.dart';
import '../services/gemini_vision_service.dart';
import 'goals_provider.dart';

final selectedDateProvider = StateProvider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
});

class MealListNotifier extends StateNotifier<List<MealEntry>> {
  final Ref ref;

  MealListNotifier(this.ref) : super([]) {
    loadMeals();
  }

  void loadMeals() {
    final date = ref.read(selectedDateProvider);
    state = HiveService.getMealsForDate(date);
  }

  void setDate(DateTime date) {
    ref.read(selectedDateProvider.notifier).state = DateTime(date.year, date.month, date.day);
  }

  Future<void> addMeal(MealEntry meal) async {
    await HiveService.saveMeal(meal);
    loadMeals();
    ref.read(allMealsProvider.notifier).loadAllMeals();
  }

  Future<void> updateMeal(MealEntry meal) async {
    await HiveService.saveMeal(meal);
    loadMeals();
    ref.read(allMealsProvider.notifier).loadAllMeals();
  }

  Future<void> deleteMeal(String id) async {
    await HiveService.deleteMeal(id);
    loadMeals();
    ref.read(allMealsProvider.notifier).loadAllMeals();
  }
}

final StateNotifierProvider<MealListNotifier, List<MealEntry>> mealListProvider =
    StateNotifierProvider<MealListNotifier, List<MealEntry>>((ref) {
  ref.watch(selectedDateProvider);
  return MealListNotifier(ref);
});

class AllMealsNotifier extends StateNotifier<List<MealEntry>> {
  final Ref ref;

  AllMealsNotifier(this.ref) : super([]) {
    loadAllMeals();
  }

  void loadAllMeals() {
    final meals = HiveService.getAllMeals();
    meals.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    state = meals;
  }

  Future<void> updateMeal(MealEntry meal) async {
    await HiveService.saveMeal(meal);
    loadAllMeals();
    ref.read(mealListProvider.notifier).loadMeals();
  }

  Future<void> deleteMeal(String id) async {
    await HiveService.deleteMeal(id);
    loadAllMeals();
    ref.read(mealListProvider.notifier).loadMeals();
  }
}

final StateNotifierProvider<AllMealsNotifier, List<MealEntry>> allMealsProvider =
    StateNotifierProvider<AllMealsNotifier, List<MealEntry>>((ref) {
  return AllMealsNotifier(ref);
});

class DailyProgress {
  final double targetCalories;
  final double consumedCalories;
  final double remainingCalories;
  final double calorieProgress;

  final double targetProteinG;
  final double consumedProteinG;
  final double remainingProteinG;
  final double proteinProgress;

  final double totalCarbsG;
  final double totalFatG;
  final int totalWaterMl;

  const DailyProgress({
    required this.targetCalories,
    required this.consumedCalories,
    required this.remainingCalories,
    required this.calorieProgress,
    required this.targetProteinG,
    required this.consumedProteinG,
    required this.remainingProteinG,
    required this.proteinProgress,
    this.totalCarbsG = 0.0,
    this.totalFatG = 0.0,
    this.totalWaterMl = 0,
  });
}

final dailyProgressProvider = Provider<DailyProgress>((ref) {
  final meals = ref.watch(mealListProvider);
  final goals = ref.watch(dailyGoalsProvider);

  double totalCalories = 0;
  double totalProtein = 0;
  double totalCarbs = 0;
  double totalFat = 0;
  int totalWater = 0;

  for (final meal in meals) {
    totalCalories += meal.calories;
    totalProtein += meal.protein;
    totalCarbs += meal.carbs;
    totalFat += meal.fat;
    if (meal.amountMl != null) {
      totalWater += meal.amountMl!;
    }
  }

  final remainingCalories = (goals.targetCalories - totalCalories).clamp(0.0, double.infinity);
  final remainingProtein = (goals.targetProteinG - totalProtein).clamp(0.0, double.infinity);

  final calorieRatio = goals.targetCalories > 0
      ? (totalCalories / goals.targetCalories)
      : 0.0;

  final proteinRatio = goals.targetProteinG > 0
      ? (totalProtein / goals.targetProteinG)
      : 0.0;

  return DailyProgress(
    targetCalories: goals.targetCalories,
    consumedCalories: totalCalories,
    remainingCalories: remainingCalories,
    calorieProgress: calorieRatio,
    targetProteinG: goals.targetProteinG,
    consumedProteinG: totalProtein,
    remainingProteinG: remainingProtein,
    proteinProgress: proteinRatio,
    totalCarbsG: totalCarbs,
    totalFatG: totalFat,
    totalWaterMl: totalWater,
  );
});

final geminiVisionServiceProvider = Provider<GeminiVisionService>((ref) {
  final key = ref.watch(geminiApiKeyProvider);
  return GeminiVisionService(apiKey: key);
});

class CreatineWaterNotifier extends StateNotifier<int> {
  CreatineWaterNotifier() : super(HiveService.getCreatineWaterMl());

  Future<void> setWaterMl(int ml) async {
    await HiveService.saveCreatineWaterMl(ml);
    state = ml;
  }
}

final creatineWaterProvider =
    StateNotifierProvider<CreatineWaterNotifier, int>((ref) {
  return CreatineWaterNotifier();
});

