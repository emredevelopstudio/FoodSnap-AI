import 'package:foodsnap_ai/models/meal_entry.dart';
import 'package:foodsnap_ai/models/meal_item.dart';

/// Beispiel-Mahlzeit für Widget-Tests (z. B. ScanReviewView).
MealEntry testMeal({
  String name = 'Pizza',
  int calories = 266,
  double protein = 11.0,
  double fat = 10.0,
  String? healthReason,
}) {
  return MealEntry(
    id: 'test-$name',
    name: name,
    calories: calories,
    protein: protein,
    carbs: 0,
    fat: fat,
    timestamp: DateTime(2026, 9, 30, 12),
    items: [
      MealItem(
        name: name,
        estimatedWeightG: 100,
        calories: calories.toDouble(),
        proteinG: protein,
        carbsG: 0,
        fatG: fat,
      ),
    ],
    healthReason: healthReason,
  );
}

/// Mahlzeit, die die Prüfansicht als „nicht eindeutig erkannt“ markiert.
MealEntry unrecognizedTestMeal() => MealEntry(
      id: 'test-unrecognized',
      name: 'Unbekanntes Lebensmittel',
      calories: 0,
      protein: 0,
      carbs: 0,
      fat: 0,
      timestamp: DateTime(2026, 9, 30, 12),
      items: const [],
      healthCategory: 'Unbekannt',
      healthReason: 'Essen/Getränk nicht eindeutig erkannt.',
    );
