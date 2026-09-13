import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodsnap_ai/models/meal_item.dart';
import 'package:foodsnap_ai/providers/goals_provider.dart';
import 'package:foodsnap_ai/services/gemini_service.dart';
import 'package:foodsnap_ai/services/image_mime_type.dart';
import 'package:foodsnap_ai/views/scan_review_view.dart';

void main() {
  final service = GeminiVisionService(apiKey: 'test-only-no-network');

  test('uses dotenv for provider and handles an empty key gracefully', () {
    dotenv.testLoad(fileInput: 'GEMINI_API_KEY=test-env-key');
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(container.read(geminiApiKeyProvider), 'test-env-key');
    expect(GeminiVisionService().apiKey, 'test-env-key');
    expect(GeminiVisionService(apiKey: '  ').apiKey, '');
    dotenv.testLoad(fileInput: 'GEMINI_API_KEY=');
    expect(GeminiVisionService().apiKey, '');
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

  test('accepts fenced JSON and legacy component names', () {
    final meal = service.parseResponse(
        '```json\n{"meal_name":"Salat",'
        '"components":[{"calories":"250","protein_g":"12.5"}],'
        '"health_score":"8"}\n```',
        null);
    expect(meal.calories, 250);
    expect(meal.protein, 12.5);
    expect(meal.healthScore, 8);
  });

  test('malformed JSON and wrong list types produce controlled errors', () {
    expect(() => service.parseResponse('{"items":[{}]', null),
        throwsFormatException);
    expect(() => service.parseResponse('{"items":"invalid"}', null),
        throwsFormatException);
    expect(() => service.parseResponse('{"items":[null]}', null),
        throwsFormatException);
  });

  testWidgets('review retains and allows editing totals without components',
      (tester) async {
    final meal = service.parseResponse(
        '{"meal_name":"Suppe",'
        '"total_calories":"250","total_protein":"12.5",'
        '"total_carbs":"30","total_fat":"8","items":[]}',
        null);
    await tester.pumpWidget(ProviderScope(
        child: MaterialApp(
      home: ScanReviewView(initialMeal: meal),
    )));
    expect(find.text('250 kcal'), findsWidgets);
    expect(find.text('Suppe'), findsWidgets);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
