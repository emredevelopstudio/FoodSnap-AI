import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image/image.dart' as img;
import 'package:foodsnap_ai/core/config/api_keys.dart';
import 'package:foodsnap_ai/providers/meal_provider.dart';
import 'package:foodsnap_ai/services/gemini_vision_service.dart';
import 'package:foodsnap_ai/widgets/progress_card.dart';

void main() {
  group('ApiKeys Config', () {
    test('enthält keinen fest codierten Key (nur --dart-define)', () {
      expect(ApiKeys.geminiApiKey, const String.fromEnvironment('GEMINI_KEY'));
      expect(ApiKeys.geminiProxyUrl,
          const String.fromEnvironment('GEMINI_PROXY_URL'));
    });
  });

  group('GeminiVisionService Image Compression', () {
    test('compressImageIfNeeded downscales images larger than 1024x1024', () {
      final largeImage = img.Image(width: 2000, height: 1500);
      final rawBytes = Uint8List.fromList(img.encodeJpg(largeImage));

      final compressed = GeminiVisionService.compressImageIfNeeded(rawBytes,
          maxDimension: 1024, quality: 80);
      final decoded = img.decodeImage(compressed)!;

      expect(decoded.width, 1024);
      expect(decoded.height, 768);
    });

    test('compressImageIfNeeded preserves smaller dimensions', () {
      final smallImage = img.Image(width: 800, height: 600);
      final rawBytes = Uint8List.fromList(img.encodeJpg(smallImage));

      final compressed = GeminiVisionService.compressImageIfNeeded(rawBytes,
          maxDimension: 1024, quality: 80);
      final decoded = img.decodeImage(compressed)!;

      expect(decoded.width, 800);
      expect(decoded.height, 600);
    });
  });

  group('GeminiVisionService JSON Parsing', () {
    test('parses clean valid JSON response into MealEntry with items', () {
      const jsonStr = '''
      {
        "name": "Lachsfilet mit Reis und Brokkoli",
        "weightGrams": 400,
        "calories": 550,
        "protein": 42.0,
        "carbs": 50.0,
        "fat": 15.0,
        "healthScore": 10,
        "healthCategory": "Sehr gesund",
        "healthReason": "Omega-3 Fettsäuren und hochwertige Proteine",
        "items": [
          {
            "name": "Lachsfilet",
            "weightGrams": 180,
            "calories": 320,
            "protein": 36.0,
            "carbs": 0.0,
            "fat": 14.0
          },
          {
            "name": "Reis",
            "weightGrams": 150,
            "calories": 180,
            "protein": 4.0,
            "carbs": 40.0,
            "fat": 0.5
          },
          {
            "name": "Brokkoli",
            "weightGrams": 70,
            "calories": 50,
            "protein": 2.0,
            "carbs": 10.0,
            "fat": 0.5
          }
        ]
      }
      ''';

      final entry = GeminiVisionService.parseGeminiResponse(jsonStr,
          imagePath: 'path/to/salmon.jpg');
      expect(entry.name, 'Lachsfilet mit Reis und Brokkoli');
      expect(entry.calories, 550);
      expect(entry.protein, 42.0);
      expect(entry.carbs, 50.0);
      expect(entry.fat, 15.0);
      expect(entry.weightGrams, 400);
      expect(entry.healthScore, 10);
      expect(entry.healthCategory, 'Sehr gesund');
      expect(entry.localImagePath, 'path/to/salmon.jpg');
      expect(entry.items.length, 3);
      expect(entry.items.first.name, 'Lachsfilet');
    });

    test('parses markdown codeblock JSON (```json ... ```)', () {
      const codeBlockJson = '''
      Hier ist die Erkennung:
      ```json
      {
        "name": "Cheeseburger",
        "weightGrams": 220,
        "calories": 610,
        "protein": 32.0,
        "carbs": 44.0,
        "fat": 28.0,
        "healthScore": 4,
        "healthCategory": "Fast Food / Cheat"
      }
      ```
      ''';

      final entry = GeminiVisionService.parseGeminiResponse(codeBlockJson);
      expect(entry.name, 'Cheeseburger');
      expect(entry.calories, 610);
      expect(entry.protein, 32.0);
      expect(entry.carbs, 44.0);
      expect(entry.fat, 28.0);
      expect(entry.items, isNotEmpty);
      expect(entry.items.first.name, 'Cheeseburger');
    });
  });

  group('GeminiVisionService Modell-Fallback', () {
    Uint8List jpg() => Uint8List.fromList(img.encodeJpg(img.Image(width: 10, height: 10)));

    http.Response okMeal(String name) => http.Response(
        jsonEncode({
          "candidates": [
            {
              "content": {
                "parts": [
                  {"text": jsonEncode({"meal_name": name, "total_calories": 100})}
                ]
              }
            }
          ]
        }),
        200);

    test('Zeitüberschreitung beim 1. Modell → nächstes Modell statt Abbruch', () async {
      var calls = 0;
      final client = MockClient((req) async {
        calls++;
        if (calls == 1) {
          await Future<void>.delayed(const Duration(seconds: 2)); // hängt
        }
        return okMeal('Banane');
      });
      final service = GeminiVisionService(apiKey: 'test', proxyUrl: '', client: client);
      final meal = await service.analyzeFoodImage(
        imageBytes: jpg(),
        perModelTimeout: const Duration(milliseconds: 100),
        scanDeadline: const Duration(seconds: 5),
      );
      expect(meal.name, 'Banane');
      expect(calls, 2);
    });

    test('Gesamt-Obergrenze: hängende Modelle → klare Timeout-Meldung', () async {
      final client = MockClient((_) async {
        await Future<void>.delayed(const Duration(seconds: 5));
        return okMeal('nie');
      });
      final service = GeminiVisionService(apiKey: 'test', proxyUrl: '', client: client);
      final sw = Stopwatch()..start();
      await expectLater(
        service.analyzeFoodImage(
          imageBytes: jpg(),
          perModelTimeout: const Duration(milliseconds: 150),
          scanDeadline: const Duration(milliseconds: 400),
        ),
        throwsA(isA<ScanAnalysisException>().having(
            (e) => e.customMessage, 'message', GeminiVisionService.timeoutMessage)),
      );
      expect(sw.elapsed, lessThan(const Duration(seconds: 2)));
    });

    test('Abbrechen beendet den Scan sofort', () async {
      final client = MockClient((_) async {
        await Future<void>.delayed(const Duration(seconds: 5));
        return okMeal('nie');
      });
      final service = GeminiVisionService(apiKey: 'test', proxyUrl: '', client: client);
      final cancel = ScanCancellation();
      final sw = Stopwatch()..start();
      final future = service.analyzeFoodImage(imageBytes: jpg(), cancel: cancel);
      Future<void>.delayed(const Duration(milliseconds: 50), cancel.cancel);
      await expectLater(future, throwsA(isA<ScanCancelledException>()));
      expect(sw.elapsed, lessThan(const Duration(seconds: 1)));
    });

    test('weicht bei 503 auf das nächste Modell aus', () async {
      final calledModels = <String>[];
      final client = MockClient((req) async {
        calledModels.add(req.url.pathSegments.last.split(':').first);
        if (calledModels.length == 1) {
          return http.Response('{"error":{"code":503}}', 503);
        }
        final text = jsonEncode({"meal_name": "Apfel", "total_calories": 52});
        return http.Response(
            jsonEncode({
              "candidates": [
                {
                  "content": {
                    "parts": [
                      {"text": text}
                    ]
                  }
                }
              ]
            }),
            200);
      });

      final service = GeminiVisionService(apiKey: 'test', proxyUrl: '', client: client);
      final meal = await service.analyzeFoodImage(imageBytes: jpg());

      expect(meal.name, 'Apfel');
      expect(calledModels, [
        GeminiVisionService.fallbackModels[0],
        GeminiVisionService.fallbackModels[1],
      ]);
    });

    test('meldet „ausgelastet“ wenn alle Modelle 503 liefern', () async {
      final client = MockClient((_) async => http.Response('{}', 503));
      final service = GeminiVisionService(apiKey: 'test', proxyUrl: '', client: client);
      await expectLater(service.analyzeFoodImage(imageBytes: jpg()),
          throwsA(isA<ScanRateLimitException>()));
    }, timeout: const Timeout(Duration(seconds: 20)));
  });

  group('ProgressCard Dashboard UI', () {
    testWidgets('renders Goal and Fat without Kohlenhydrate in macro card',
        (tester) async {
      const progress = DailyProgress(
        targetCalories: 2000,
        consumedCalories: 1500,
        remainingCalories: 500,
        calorieProgress: 0.75,
        targetProteinG: 160,
        consumedProteinG: 120,
        remainingProteinG: 40,
        proteinProgress: 0.75,
        targetCarbsG: 220,
        totalCarbsG: 180,
        targetFatG: 70,
        totalFatG: 50,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ProgressCard(progress: progress),
          ),
        ),
      );

      // Fett und Ziel sollen sichtbar sein
      expect(find.textContaining('Fett'), findsOneWidget);
      expect(find.text('50.0 g'), findsOneWidget);

      // Kohlenhydrate darf im ProgressCard Dashboard NICHT gerendert werden
      expect(find.text('Kohlenhydrate'), findsNothing);
      expect(find.text('Carbs'), findsNothing);
      expect(find.text('180.0 g'), findsNothing);

      expect(tester.takeException(), isNull);
    });
  });
}
