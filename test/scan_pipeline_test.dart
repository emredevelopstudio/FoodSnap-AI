import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:foodsnap_ai/models/meal_item.dart';
import 'package:foodsnap_ai/services/image_mime_type.dart';
import 'package:foodsnap_ai/services/local_vision_service.dart';
import 'package:foodsnap_ai/views/scan_review_view.dart';

void main() {
  group('LocalVisionService Active On-Device Scan Pipeline', () {
    test('preprocessImage resizes large images to maxDimension of 768px', () {
      final largeImage = img.Image(width: 1000, height: 600);
      final rawBytes = Uint8List.fromList(img.encodeJpg(largeImage));

      final processedBytes = LocalVisionService.preprocessImage(rawBytes, maxDimension: 768);
      final decoded = img.decodeImage(processedBytes)!;

      expect(decoded.width, 768);
      expect(decoded.height, 461); // 600 * 768 / 1000 = 460.8 -> 461
    });

    test('preprocessImage keeps images within maxDimension unchanged in dimensions', () {
      final smallImage = img.Image(width: 400, height: 300);
      final smallBytes = Uint8List.fromList(img.encodeJpg(smallImage));

      final processedBytes = LocalVisionService.preprocessImage(smallBytes, maxDimension: 768);
      expect(processedBytes, equals(smallBytes));
    });

    test('systemPrompt contains 3-step structured guidance and JSON output contract', () {
      expect(LocalVisionService.systemPrompt, contains('SCHRITT 1: BILDTYP IDENTIFIZIEREN'));
      expect(LocalVisionService.systemPrompt, contains('SCHRITT 2: ANALYSE BEI VERPACKUNGEN / MARKENPRODUKTEN'));
      expect(LocalVisionService.systemPrompt, contains('SCHRITT 3: ANALYSE BEI GEKOCHTEM ESSEN / TELLERN'));
      expect(LocalVisionService.systemPrompt, contains('VALIDES JSON'));
    });
  });

  group('LocalVisionService Model Output Parsing & JSON Extraction', () {
    test('parses clean valid JSON response into MealEntry with items', () {
      const jsonStr = '''
      {
        "name": "Pizza Margherita",
        "weightGrams": 350,
        "calories": 780,
        "protein": 28.0,
        "carbs": 95.0,
        "fat": 32.0,
        "healthScore": 4,
        "healthCategory": "Fast Food / Cheat",
        "healthReason": "Käse und Weißmehlteig",
        "items": [
          {
            "name": "Pizzateig & Sauce",
            "weightGrams": 250,
            "calories": 500,
            "protein": 14.0,
            "carbs": 85.0,
            "fat": 10.0
          },
          {
            "name": "Mozzarella",
            "weightGrams": 100,
            "calories": 280,
            "protein": 14.0,
            "carbs": 10.0,
            "fat": 22.0
          }
        ]
      }
      ''';

      final entry = LocalVisionService.parseModelOutputToMealEntry(jsonStr, 'path/to/pizza.jpg');
      expect(entry.name, 'Pizza Margherita');
      expect(entry.calories, 780);
      expect(entry.protein, 28.0);
      expect(entry.carbs, 95.0);
      expect(entry.fat, 32.0);
      expect(entry.weightGrams, 350);
      expect(entry.healthScore, 4);
      expect(entry.healthCategory, 'Fast Food / Cheat');
      expect(entry.localImagePath, 'path/to/pizza.jpg');
      expect(entry.items.length, 2);
      expect(entry.items.first.name, 'Pizzateig & Sauce');
    });

    test('parses markdown codeblock JSON (```json ... ```)', () {
      const codeBlockJson = '''
      Hier ist deine Analyse:
      ```json
      {
        "name": "Haferflocken mit Beeren",
        "calories": 360,
        "protein": 12.0,
        "carbs": 60.0,
        "fat": 6.0,
        "healthScore": 9
      }
      ```
      ''';

      final entry = LocalVisionService.parseModelOutputToMealEntry(codeBlockJson);
      expect(entry.name, 'Haferflocken mit Beeren');
      expect(entry.calories, 360);
      expect(entry.protein, 12.0);
      expect(entry.healthScore, 9);
      expect(entry.items.length, 1);
      expect(entry.items.first.name, 'Haferflocken mit Beeren');
    });

    test('handles fallback defaults gracefully for minimal JSON', () {
      const minimalJson = '{"calories": 250}';
      final entry = LocalVisionService.parseModelOutputToMealEntry(minimalJson);
      expect(entry.name, LocalVisionService.defaultMealName);
      expect(entry.calories, 250);
      expect(entry.protein, 20.0);
      expect(entry.carbs, 35.0);
      expect(entry.fat, 12.0);
      expect(entry.items, isNotEmpty);
    });

    test('clamps healthScore between 1 and 10', () {
      final highEntry = LocalVisionService.parseModelOutputToMealEntry('{"healthScore": 15}');
      expect(highEntry.healthScore, 10);

      final lowEntry = LocalVisionService.parseModelOutputToMealEntry('{"healthScore": -2}');
      expect(lowEntry.healthScore, 1);
    });
  });

  group('LocalVisionService Offline Brand & Product OCR Mapping', () {
    test('matches Monster Energy Ultra (sugarfree, 500ml)', () {
      final jsonStr = LocalVisionService.matchOfflineProductJson('Monster Energy Zero Ultra 500ml Can');
      final entry = LocalVisionService.parseModelOutputToMealEntry(jsonStr);
      expect(entry.name, contains('Monster Energy Ultra'));
      expect(entry.calories, 11);
      expect(entry.amountMl, 500);
      expect(entry.carbs, 4.0);
    });

    test('matches Monster Energy Original (500ml)', () {
      final jsonStr = LocalVisionService.matchOfflineProductJson('Monster Energy Original Green 500ml');
      final entry = LocalVisionService.parseModelOutputToMealEntry(jsonStr);
      expect(entry.name, contains('Monster Energy (500ml)'));
      expect(entry.calories, 237);
      expect(entry.amountMl, 500);
    });

    test('matches Red Bull Sugarfree (250ml)', () {
      final jsonStr = LocalVisionService.matchOfflineProductJson('Red Bull Sugarfree Taurin');
      final entry = LocalVisionService.parseModelOutputToMealEntry(jsonStr);
      expect(entry.name, contains('Red Bull Sugarfree'));
      expect(entry.calories, 8);
      expect(entry.amountMl, 250);
    });

    test('matches Kreatin Monohydrat (5g, 0 kcal, healthScore 10)', () {
      final jsonStr = LocalVisionService.matchOfflineProductJson('Creatine Monohydrate 100% pure');
      final entry = LocalVisionService.parseModelOutputToMealEntry(jsonStr);
      expect(entry.name, contains('Kreatin Monohydrat'));
      expect(entry.calories, 0);
      expect(entry.weightGrams, 5);
      expect(entry.healthScore, 10);
      expect(entry.healthCategory, 'Sehr gesund');
    });

    test('matches Whey Protein Shake (30g, 24g protein)', () {
      final jsonStr = LocalVisionService.matchOfflineProductJson('ESN Designer Whey Protein 1000g');
      final entry = LocalVisionService.parseModelOutputToMealEntry(jsonStr);
      expect(entry.name, contains('Whey Protein Shake'));
      expect(entry.calories, 115);
      expect(entry.protein, 24.0);
      expect(entry.weightGrams, 30);
    });

    test('matches Coca-Cola Zero (330ml)', () {
      final jsonStr = LocalVisionService.matchOfflineProductJson('Coca Cola Zero Zucker 330ml Dose');
      final entry = LocalVisionService.parseModelOutputToMealEntry(jsonStr);
      expect(entry.name, contains('Coca-Cola Zero'));
      expect(entry.calories, 1);
      expect(entry.amountMl, 330);
    });

    test('falls back to unrecognized meal for unknown food text without brand match', () {
      final jsonStr = LocalVisionService.matchOfflineProductJson('Kartoffeln mit Brokkoli und Fleisch');
      final entry = LocalVisionService.parseModelOutputToMealEntry(jsonStr);
      expect(entry.name, LocalVisionService.unrecognizedMealName);
      expect(entry.calories, 0);
      expect(entry.healthCategory, 'Unbekannt');
    });
  });

  group('LocalVisionService createMealEntry Helper', () {
    test('confidence below 40% creates unrecognized meal with name "Unbekanntes Lebensmittel"', () {
      final meal = LocalVisionService.createMealEntry(
        displayName: 'desk',
        rawLabel: 'desk',
        confidence: 0.38,
        isRecognized: false,
        imagePath: 'path/to/test.jpg',
      );

      expect(meal.name, 'Unbekanntes Lebensmittel');
      expect(meal.calories, 0);
      expect(meal.protein, 0.0);
      expect(meal.carbs, 0.0);
      expect(meal.fat, 0.0);
      expect(meal.items, isEmpty);
      expect(meal.healthCategory, 'Unbekannt');
      expect(meal.healthReason, contains('40 %'));
      expect(meal.localImagePath, 'path/to/test.jpg');
    });

    test('confidence above 40% on valid food creates populated meal entry', () {
      final meal = LocalVisionService.createMealEntry(
        displayName: 'Pizza',
        rawLabel: 'pizza',
        calories: 266,
        protein: 11.0,
        carbs: 33.0,
        fat: 10.0,
        confidence: 0.82,
        isRecognized: true,
        imagePath: 'path/to/pizza.jpg',
      );

      expect(meal.name, 'Pizza');
      expect(meal.calories, 266);
      expect(meal.protein, 11.0);
      expect(meal.items, isNotEmpty);
      expect(meal.items.first.name, 'Pizza');
      expect(meal.localImagePath, 'path/to/pizza.jpg');
    });
  });

  test('image signatures override a misleading filename', () {
    expect(
        detectImageMimeType(
            Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10]),
            filePath: 'photo.jpg'),
        'image/png');
    expect(
        detectImageMimeType(Uint8List.fromList([255, 216, 255]),
            filePath: 'photo.png'),
        'image/jpeg');
    expect(() => detectImageMimeType(Uint8List(0), filePath: 'photo.jpg'),
        throwsFormatException);
  });

  test('parses numeric strings and rejects nonfinite nutrition values', () {
    final item = MealItem.fromMap({
      'calories': '250',
      'protein': '12.5',
      'carbs': 'NaN',
      'fat': 'Infinity',
      'amount_grams': '180'
    });
    expect(item.calories, 250);
    expect(item.proteinG, 12.5);
    expect(item.estimatedWeightG, 180);
    expect(item.carbsG, 0);
    expect(item.fatG, 0);
  });

  group('LocalVisionService MediaPipe Category & Baseline Lookup', () {
    test('baseline mapping for water returns 0 kcal and 500ml', () {
      final baseline = LocalVisionService.getBaselineNutrition('water bottle');
      expect(baseline, isNotNull);
      expect(baseline!.germanName, 'Wasser / Mineralwasser');
      expect(baseline.calories, 0);
      expect(baseline.proteinG, 0.0);
      expect(baseline.carbsG, 0.0);
      expect(baseline.fatG, 0.0);
      expect(baseline.amountMl, 500);
      expect(baseline.healthScore, 10);
      expect(baseline.healthCategory, 'Sehr gesund');
    });

    test('baseline mapping for apple returns 52 kcal and fruit nutrition', () {
      final baseline = LocalVisionService.getBaselineNutrition('apple');
      expect(baseline, isNotNull);
      expect(baseline!.germanName, 'Apfel');
      expect(baseline.calories, 52);
      expect(baseline.carbsG, 14.0);
      expect(baseline.healthScore, 10);
    });

    test('baseline mapping for banana returns 89 kcal', () {
      final baseline = LocalVisionService.getBaselineNutrition('banana');
      expect(baseline, isNotNull);
      expect(baseline!.germanName, 'Banane');
      expect(baseline.calories, 89);
      expect(baseline.proteinG, 1.1);
    });

    test('baseline mapping for cup and coffee mug returns coffee/espresso', () {
      final cup = LocalVisionService.getBaselineNutrition('cup');
      expect(cup, isNotNull);
      expect(cup!.germanName, 'Kaffee / Espresso');
      expect(cup.calories, 2);

      final mug = LocalVisionService.getBaselineNutrition('coffee mug');
      expect(mug, isNotNull);
      expect(mug!.germanName, 'Kaffee / Espresso');
      expect(mug.calories, 2);
    });

    test('createFromCategory rejects confidence below 0.30 with unrecognized meal', () {
      final meal = LocalVisionService.createFromCategory(
        label: 'pizza',
        confidence: 0.25,
        imagePath: 'path/to/test.jpg',
      );
      expect(meal.name, LocalVisionService.unrecognizedMealName);
      expect(meal.calories, 0);
      expect(meal.protein, 0.0);
      expect(meal.healthCategory, 'Unbekannt');
      expect(meal.healthReason, contains('25 %'));
    });

    test('createFromCategory decomposes compound dishes into separate MealItems', () {
      final meal = LocalVisionService.createFromCategory(
        label: 'chicken',
        confidence: 0.85,
        detectedLabels: ['chicken', 'rice', 'broccoli'],
        imagePath: 'path/to/plate.jpg',
      );
      expect(meal.name, contains('Hähnchenbrust mit Reis und Brokkoli'));
      expect(meal.items.length, 3);
      expect(meal.items[0].name, contains('Hähnchenbrust'));
      expect(meal.items[1].name, contains('Basmatireis'));
      expect(meal.items[2].name, contains('Brokkoli'));
      expect(meal.calories, greaterThan(400));
      expect(meal.protein, greaterThan(35.0));
      expect(meal.healthCategory, 'Sehr gesund');
    });

    test('createFromCategory decomposes pizza into dough, sauce and mozzarella', () {
      final meal = LocalVisionService.createFromCategory(
        label: 'pizza',
        confidence: 0.80,
        imagePath: 'path/to/pizza.jpg',
      );
      expect(meal.name, contains('Pizza Margherita'));
      expect(meal.items.length, 3);
      expect(meal.items.any((i) => i.name.contains('Pizzateig')), isTrue);
      expect(meal.items.any((i) => i.name.contains('Mozzarella')), isTrue);
      expect(meal.items.any((i) => i.name.contains('Tomatensauce')), isTrue);
    });

    test('createFromCategory decomposes cheeseburger into bun, patty and cheese', () {
      final meal = LocalVisionService.createFromCategory(
        label: 'cheeseburger',
        confidence: 0.88,
        imagePath: 'path/to/burger.jpg',
      );
      expect(meal.name, 'Cheeseburger');
      expect(meal.items.length, 4);
      expect(meal.items.any((i) => i.name.contains('Burgerbrötchen')), isTrue);
      expect(meal.items.any((i) => i.name.contains('Rinder-Patty')), isTrue);
      expect(meal.items.any((i) => i.name.contains('Cheddar')), isTrue);
      expect(meal.protein, greaterThan(25.0));
      expect(meal.localImagePath, 'path/to/burger.jpg');
    });

    test('createFromCategory generates estimated fallback for unknown label with confidence >= 0.30', () {
      final meal = LocalVisionService.createFromCategory(
        label: 'croissant',
        confidence: 0.32,
      );
      expect(meal.name, 'Croissant');
      expect(meal.calories, 250);
      expect(meal.protein, 14.0);
      expect(meal.carbs, 28.0);
      expect(meal.fat, 9.0);
      expect(meal.items, isNotEmpty);
      expect(meal.healthReason, contains('Croissant'));
    });
  });

  group('LocalVisionResult & Nutrition DB Mapping', () {
    test('resolveNutrition with nutrition db data calculates correct macros and serving sizes', () {
      final db = {
        'cheeseburger': {
          'germanName': 'Cheeseburger',
          'caloriesPer100g': 303.0,
          'proteinPer100g': 15.0,
          'carbsPer100g': 30.0,
          'fatPer100g': 14.0,
          'defaultServingG': 200.0,
          'healthScore': 4,
          'healthCategory': 'Fast Food / Cheat',
          'healthNote': 'Burger mit Rindfleisch-Patty',
        }
      };

      final result = LocalVisionService.resolveNutrition(
        label: 'cheeseburger',
        confidence: 0.92,
        db: db,
      );

      expect(result.label, 'cheeseburger');
      expect(result.confidence, 0.92);
      expect(result.germanName, 'Cheeseburger');
      expect(result.caloriesPer100g, 303.0);
      expect(result.defaultServingG, 200.0);
      expect(result.calories, 606); // 303 * 2
      expect(result.protein, 30.0); // 15 * 2
      expect(result.carbs, 60.0);
      expect(result.fat, 28.0);

      final mealItem = result.toMealItem();
      expect(mealItem.name, 'Cheeseburger');
      expect(mealItem.estimatedWeightG, 200.0);
      expect(mealItem.calories, 606.0);

      final mealEntry = result.toMealEntry(imagePath: 'path/to/burger.jpg');
      expect(mealEntry.name, 'Cheeseburger');
      expect(mealEntry.calories, 606);
      expect(mealEntry.weightGrams, 200);
      expect(mealEntry.localImagePath, 'path/to/burger.jpg');
      expect(mealEntry.items.length, 1);
    });

    test('resolveNutrition fallback uses baseline nutrition when db lacks key', () {
      final result = LocalVisionService.resolveNutrition(
        label: 'apple',
        confidence: 0.88,
        db: {},
      );

      expect(result.germanName, 'Apfel');
      expect(result.healthScore, 10);
      expect(result.healthCategory, 'Sehr gesund');
    });

    test('resolveNutrition fallback uses beautified label when neither db nor baseline matches with 100 kcal/100g', () {
      final result = LocalVisionService.resolveNutrition(
        label: 'exotic_spiced_tofu',
        confidence: 0.75,
        db: {},
      );

      expect(result.germanName, 'Exotic Spiced Tofu');
      expect(result.caloriesPer100g, 100.0);
      expect(result.defaultServingG, 100.0);
      expect(result.calories, 100);
      expect(result.proteinPer100g, 4.0);
      expect(result.healthNote, contains('Exotic Spiced Tofu'));
    });

    test('resolveNutrition tolerant matching matches roasted_chicken and grilled chicken to chicken DB entry', () {
      final db = {
        'chicken': {
          'germanName': 'Hähnchen / Hühnerfleisch',
          'caloriesPer100g': 165.0,
          'proteinPer100g': 31.0,
          'carbsPer100g': 0.0,
          'fatPer100g': 3.6,
          'defaultServingG': 180.0,
          'healthScore': 10,
          'healthCategory': 'Sehr gesund',
          'healthNote': 'Mageres Hähnchen',
          'aliases': ['roasted chicken', 'grilled chicken', 'hähnchen']
        }
      };

      // Test mit Underscore
      final res1 = LocalVisionService.resolveNutrition(
        label: 'roasted_chicken',
        confidence: 0.85,
        db: db,
      );
      expect(res1.germanName, 'Hähnchen / Hühnerfleisch');
      expect(res1.caloriesPer100g, 165.0);

      // Test mit Leerzeichen
      final res2 = LocalVisionService.resolveNutrition(
        label: 'grilled chicken',
        confidence: 0.90,
        db: db,
      );
      expect(res2.germanName, 'Hähnchen / Hühnerfleisch');
      expect(res2.caloriesPer100g, 165.0);

      // Test mit Substring, wenn nur "chicken" in DB als Key ist und Label "crispy chicken tenders"
      final res3 = LocalVisionService.resolveNutrition(
        label: 'crispy_chicken_tenders',
        confidence: 0.78,
        db: db,
      );
      expect(res3.germanName, 'Hähnchen / Hühnerfleisch');
    });
  });

  testWidgets('ScanReviewView renders detected meal and editable cards', (tester) async {
    final meal = LocalVisionService.createMealEntry(
      displayName: 'Pizza',
      calories: 266,
      protein: 11.0,
      confidence: 0.91,
      isRecognized: true,
    );

    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(
        home: ScanReviewView(initialMeal: meal),
      ),
    ));

    expect(find.text('266 kcal'), findsWidgets);
    expect(find.text('Pizza'), findsWidgets);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('ScanReviewView renders unrecognized meal with notice', (tester) async {
    final meal = LocalVisionService.createMealEntry(
      displayName: LocalVisionService.unrecognizedMealName,
      confidence: 0.20,
      isRecognized: false,
    );

    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(
        home: ScanReviewView(initialMeal: meal),
      ),
    ));

    expect(find.text(LocalVisionService.unrecognizedMealName), findsWidgets);
    expect(find.text('Essen/Getränk nicht eindeutig erkannt'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('Erkannte Komponenten section row fits within narrow width without overflow', (tester) async {
    tester.view.physicalSize = const Size(360, 600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Erkannte Komponenten (3)',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Tippe auf die Grammzahl zur schnellen Anpassung',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Zutat +', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  onPressed: () {},
                ),
              ],
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Zutat +'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
