import 'package:flutter_test/flutter_test.dart';
import 'package:foodsnap_ai/services/barcode_nutrition_service.dart';

void main() {
  group('BarcodeNutritionService', () {
    test('empty or invalid barcode returns null immediately', () async {
      final result = await BarcodeNutritionService.fetchProductByBarcode('');
      expect(result, isNull);

      final whitespaceResult =
          await BarcodeNutritionService.fetchProductByBarcode('   ');
      expect(whitespaceResult, isNull);

      final shortResult =
          await BarcodeNutritionService.fetchProductByBarcode('1234567');
      expect(shortResult, isNull);

      final nonNumericResult =
          await BarcodeNutritionService.fetchProductByBarcode('1234567a');
      expect(nonNumericResult, isNull);
    });

    test('createMealEntryFromBarcodeData creates valid MealEntry with grams', () {
      final data = {
        'name': 'Haferflocken',
        'calories': 370,
        'protein': 13.5,
        'carbs': 58.7,
        'fat': 7.0,
        'fiber': 10.0,
        'unit': 'g',
        'defaultAmount': 100.0,
        'barcode': '4008400404127',
      };

      final meal = BarcodeNutritionService.createMealEntryFromBarcodeData(data);

      expect(meal.name, 'Haferflocken');
      expect(meal.calories, 370);
      expect(meal.protein, 13.5);
      expect(meal.carbs, 58.7);
      expect(meal.fat, 7.0);
      expect(meal.weightGrams, 100);
      expect(meal.amountMl, isNull);
      expect(meal.items.length, 1);
      expect(meal.items.first.name, 'Haferflocken');
      expect(meal.healthReason, isNull);
    });

    test('createMealEntryFromBarcodeData scales for ml serving sizes', () {
      final data = {
        'name': 'Mandelmilch',
        'calories': 24,
        'protein': 0.5,
        'carbs': 3.0,
        'fat': 1.1,
        'fiber': 0.2,
        'unit': 'ml',
        'defaultAmount': 250.0,
        'barcode': '5449000000996',
      };

      final meal = BarcodeNutritionService.createMealEntryFromBarcodeData(data);

      expect(meal.name, 'Mandelmilch');
      expect(meal.calories, 60); // 24 * 2.5 = 60
      expect(meal.protein, 1.3); // 0.5 * 2.5 = 1.25 -> 1.3
      expect(meal.carbs, 7.5); // 3.0 * 2.5 = 7.5
      expect(meal.fat, 2.8); // 1.1 * 2.5 = 2.75 -> 2.8
      expect(meal.amountMl, 250);
      expect(meal.weightGrams, isNull);
    });

    test('createMealEntryFromBarcodeData sets healthReason when isAiEstimated is true', () {
      final data = {
        'name': 'Barilla Spaghetti No. 5',
        'calories': 359,
        'protein': 12.0,
        'carbs': 71.2,
        'fat': 2.0,
        'unit': 'g',
        'defaultAmount': 100.0,
        'barcode': '8076809513753',
        'isAiEstimated': true,
      };

      final meal = BarcodeNutritionService.createMealEntryFromBarcodeData(data);

      expect(meal.name, 'Barilla Spaghetti No. 5');
      expect(meal.calories, 359);
      expect(meal.healthReason, 'Nährwerte per KI geschätzt');
    });
  });
}
