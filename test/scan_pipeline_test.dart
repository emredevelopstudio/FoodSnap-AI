import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodsnap_ai/models/meal_item.dart';
import 'package:foodsnap_ai/services/image_mime_type.dart';
import 'package:foodsnap_ai/views/scan_review_view.dart';
import 'helpers/test_meal.dart';

void main() {
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

  testWidgets('ScanReviewView renders detected meal and editable cards', (tester) async {
    final meal = testMeal();

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
    final meal = unrecognizedTestMeal();

    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(
        home: ScanReviewView(initialMeal: meal),
      ),
    ));

    expect(find.text('Unbekanntes Lebensmittel'), findsWidgets);
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
