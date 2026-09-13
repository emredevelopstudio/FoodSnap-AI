// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:uuid/uuid.dart';
import '../models/meal_entry.dart';
import '../models/meal_item.dart';
import '../models/nutrition_value.dart';
import 'image_mime_type.dart';

typedef GeminiService = GeminiVisionService;

class ScanRateLimitException implements Exception {
  static const message =
      'Die Bilderkennung ist gerade kurz ausgelastet. Bitte versuche es in wenigen Sekunden erneut.';

  final String customMessage;

  ScanRateLimitException([this.customMessage = message]);

  @override
  String toString() => customMessage;
}

class ScanAnalysisException implements Exception {
  static const message = 'Fehler bei der Analyse. Bitte versuche es erneut.';

  final String customMessage;

  const ScanAnalysisException([this.customMessage = message]);

  @override
  String toString() => customMessage;
}

class GeminiVisionService {
  static bool isRateLimitError(Object error) {
    final message = error.toString().toLowerCase();
    return RegExp(r'\b429\b').hasMatch(message) ||
        message.contains('resource_exhausted') ||
        message.contains('resourceexhausted') ||
        message.contains('quota exceeded') ||
        message.contains('quota_exceeded') ||
        message.contains('quotas') ||
        message.contains('exceeded your current quota') ||
        message.contains('rate limit') ||
        message.contains('ratelimit') ||
        message.contains('too many requests');
  }

  static String get defaultApiKey {
    final envKey = dotenv.isInitialized ? dotenv.env['GEMINI_API_KEY'] : null;
    final apiKey = envKey ?? const String.fromEnvironment('GEMINI_API_KEY');
    return apiKey.trim();
  }

  static const String modelName = 'gemini-3.7-flash';

  final String apiKey;
  final http.Client _client;

  GeminiVisionService({String? apiKey, http.Client? client})
      : apiKey = (apiKey ?? defaultApiKey).trim(),
        _client = client ?? http.Client() {
    print('>>> CHECK KEY: ${this.apiKey.isNotEmpty ? "KEY VORHANDEN" : "KEY IST NULL/LEER"}');
    if (this.apiKey.isEmpty) {
      debugPrint(
          '>>> [GEMINI WARNING]: GEMINI_API_KEY fehlt! Bitte in .env oder via --dart-define=GEMINI_API_KEY=... hinterlegen.');
    }
  }

  void dispose() {
    _client.close();
  }

  /// Skaliert und komprimiert das Bild auf max. 1024x1024 px und 80-85% Qualität,
  /// um Übertragungsfehler und API-Payload-Limits zu vermeiden.
  static Uint8List compressImageIfNeeded(Uint8List bytes,
      {int maxDimension = 1024, int quality = 85}) {
    try {
      final image = img.decodeImage(bytes);
      if (image == null) return bytes;

      img.Image processed = image;
      if (image.width > maxDimension || image.height > maxDimension) {
        if (image.width >= image.height) {
          final targetWidth = maxDimension;
          final targetHeight =
              (image.height * maxDimension / image.width).round();
          processed =
              img.copyResize(image, width: targetWidth, height: targetHeight);
        } else {
          final targetHeight = maxDimension;
          final targetWidth =
              (image.width * maxDimension / image.height).round();
          processed =
              img.copyResize(image, width: targetWidth, height: targetHeight);
        }
      }
      return Uint8List.fromList(img.encodeJpg(processed, quality: quality));
    } catch (e, stackTrace) {
      print('>>> [GEMINI COMPRESSION ERROR]: $e');
      print('>>> [GEMINI STACK]: $stackTrace');
      return bytes;
    }
  }

  /// Schätzt Nährwerte pro 100g/ml für ein Produkt anhand des Namens via Gemini Text-Prompt.
  Future<Map<String, double>?> estimateProductNutrition(
      String productName) async {
    final cleanName = productName.trim();
    if (cleanName.isEmpty || apiKey.isEmpty) return null;

    final url = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/$modelName:generateContent?key=$apiKey');

    final requestBody = jsonEncode({
      'contents': [
        {
          'parts': [
            {
              'text':
                  'Ermittle durchschnittliche Nährwerte pro 100g/ml für folgendes Lebensmittel: "$cleanName". '
                  'Gib ausschließlich ein valides JSON zurück mit: {"calories": number, "protein": number, "carbs": number, "fat": number}.',
            }
          ]
        }
      ],
      'generationConfig': {
        'response_mime_type': 'application/json',
      }
    });

    http.Response? response;
    try {
      response = await _client.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: requestBody,
      ).timeout(const Duration(seconds: 5));

      print('>>> GEMINI STATUS CODE: ${response.statusCode}');
      print('>>> GEMINI RAW RESPONSE: ${response.body}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonResponse = jsonDecode(response.body);
        final candidates = jsonResponse['candidates'] as List<dynamic>?;
        String? responseText;
        if (candidates != null && candidates.isNotEmpty) {
          final content = candidates[0]['content'] as Map<String, dynamic>?;
          final parts = content?['parts'] as List<dynamic>?;
          if (parts != null && parts.isNotEmpty) {
            responseText = parts[0]['text'] as String?;
          }
        }
        if (responseText == null || responseText.trim().isEmpty) return null;

        String raw = responseText;
        if (raw.contains('```json')) {
          raw = raw.split('```json').last.split('```').first;
        } else if (raw.contains('```')) {
          final parts = raw.split('```');
          if (parts.length >= 3 && parts[1].trim().isNotEmpty) {
            raw = parts[1];
          } else {
            raw = raw.split('```').last.split('```').first;
          }
        }
        raw = raw.trim();

        final dynamic decoded = json.decode(raw);
        if (decoded is Map) {
          final calories = (decoded['calories'] as num?)?.toDouble() ?? 0.0;
          final protein = (decoded['protein'] as num?)?.toDouble() ?? 0.0;
          final carbs = (decoded['carbs'] as num?)?.toDouble() ?? 0.0;
          final fat = (decoded['fat'] as num?)?.toDouble() ?? 0.0;

          return {
            'calories': calories,
            'protein': protein,
            'carbs': carbs,
            'fat': fat,
          };
        }
      }
    } catch (e, stackTrace) {
      if (response != null) {
        print('>>> GEMINI STATUS CODE: ${response.statusCode}');
        print('>>> GEMINI RAW RESPONSE: ${response.body}');
      }
      print('>>> [GEMINI ERROR]: $e');
      print('>>> [GEMINI STACK]: $stackTrace');
      debugPrint(
          '[GeminiService] Fehler bei KI-Schätzung für "$cleanName": $e');
    }
    return null;
  }

  /// Schätzt Produktname und Nährwerte direkt anhand des Barcodes (EAN/GTIN).
  Future<Map<String, dynamic>?> estimateProductByBarcode(String barcode) async {
    final cleanCode = barcode.trim();
    if (cleanCode.isEmpty || apiKey.isEmpty) return null;

    final url = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/$modelName:generateContent?key=$apiKey');

    final requestBody = jsonEncode({
      'contents': [
        {
          'parts': [
            {
              'text':
                  'Ermittle das Produkt und durchschnittliche Nährwerte pro 100g/ml für folgenden Barcode (EAN/GTIN): "$cleanCode". '
                  'Gib ausschließlich ein valides JSON zurück mit: {"name": string, "calories": number, "protein": number, "carbs": number, "fat": number}. '
                  'Falls der Barcode unbekannt ist, gib {"name": "Unbekannt", "calories": 0, "protein": 0, "carbs": 0, "fat": 0} zurück.',
            }
          ]
        }
      ],
      'generationConfig': {
        'response_mime_type': 'application/json',
      }
    });

    http.Response? response;
    try {
      response = await _client.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: requestBody,
      ).timeout(const Duration(seconds: 5));

      print('>>> GEMINI STATUS CODE: ${response.statusCode}');
      print('>>> GEMINI RAW RESPONSE: ${response.body}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonResponse = jsonDecode(response.body);
        final candidates = jsonResponse['candidates'] as List<dynamic>?;
        String? responseText;
        if (candidates != null && candidates.isNotEmpty) {
          final content = candidates[0]['content'] as Map<String, dynamic>?;
          final parts = content?['parts'] as List<dynamic>?;
          if (parts != null && parts.isNotEmpty) {
            responseText = parts[0]['text'] as String?;
          }
        }
        if (responseText == null || responseText.trim().isEmpty) return null;

        String raw = responseText;
        if (raw.contains('```json')) {
          raw = raw.split('```json').last.split('```').first;
        } else if (raw.contains('```')) {
          final parts = raw.split('```');
          if (parts.length >= 3 && parts[1].trim().isNotEmpty) {
            raw = parts[1];
          } else {
            raw = raw.split('```').last.split('```').first;
          }
        }
        raw = raw.trim();

        final dynamic decoded = json.decode(raw);
        if (decoded is Map &&
            decoded['name'] != null &&
            decoded['name'] != 'Unbekannt') {
          final name = decoded['name'].toString();
          final calories = (decoded['calories'] as num?)?.toDouble() ?? 0.0;
          final protein = (decoded['protein'] as num?)?.toDouble() ?? 0.0;
          final carbs = (decoded['carbs'] as num?)?.toDouble() ?? 0.0;
          final fat = (decoded['fat'] as num?)?.toDouble() ?? 0.0;

          if (calories > 0 || protein > 0 || carbs > 0 || fat > 0) {
            return {
              'name': name,
              'calories': calories,
              'protein': protein,
              'carbs': carbs,
              'fat': fat,
            };
          }
        }
      }
    } catch (e, stackTrace) {
      if (response != null) {
        print('>>> GEMINI STATUS CODE: ${response.statusCode}');
        print('>>> GEMINI RAW RESPONSE: ${response.body}');
      }
      print('>>> [GEMINI ERROR]: $e');
      print('>>> [GEMINI STACK]: $stackTrace');
      debugPrint(
          '[GeminiService] Fehler bei Barcode-KI-Schätzung für "$cleanCode": $e');
    }
    return null;
  }

  /// Analyzes an image provided either as file path or raw bytes.
  Future<MealEntry> analyzeFoodImage({
    String? filePath,
    Uint8List? imageBytes,
    String? mimeType,
    void Function(String status)? onStatusUpdate,
  }) async {
    Uint8List bytes;
    if (imageBytes != null) {
      bytes = imageBytes;
    } else if (filePath != null) {
      final file = File(filePath);
      if (!await file.exists()) {
        throw Exception('Bilddatei wurde nicht gefunden: $filePath');
      }
      bytes = await file.readAsBytes();
    } else {
      throw ArgumentError(
          'Entweder filePath oder imageBytes muss angegeben werden.');
    }

    if (bytes.isEmpty) {
      throw const FormatException('Die ausgewählte Bilddatei ist leer.');
    }
    if (apiKey.isEmpty) {
      debugPrint(
          '>>> [GEMINI ERROR]: Scan abgebrochen, da kein GEMINI_API_KEY hinterlegt ist.');
      throw const ScanAnalysisException(
          'GEMINI_API_KEY fehlt. Bitte trage deinen API-Schlüssel in die .env-Datei ein.');
    }
    mimeType ??= detectImageMimeType(bytes, filePath: filePath);

    // Bild-Kompression vor dem Senden:
    // Skaliert auf max. 1024x1024 px und 80-85% Qualität, damit der Request nicht wegen Übergröße abbricht.
    final compressedBytes =
        compressImageIfNeeded(bytes, maxDimension: 1024, quality: 85);
    final finalBytes = compressedBytes;
    final finalMimeType =
        (finalBytes.length != bytes.length) ? 'image/jpeg' : mimeType;

    const String systemPrompt = '''
Du bist ein präziser Ernährungs-, Lebensmittel- und Computer-Vision-Experte.
Analysiere dieses Foto (Mahlzeit, Lebensmittelverpackung, Dose, Flasche oder Tellergericht) und ermittle die exakten Nährwerte und Komponenten.

WICHTIGE ANWEISUNGEN:
1. OCR-PRIORITÄT (Verpackte Lebensmittel & Produkte):
   - Wenn auf dem Bild Text, ein Marken- oder Produktname, Füllmengen (z. B. 250g, 500ml) oder eine Nährwerttabelle (z. B. "pro 100g/ml" oder "pro Portion") sichtbar sind, lies diese exakt ab!
   - Erfinde oder schätze KEINE abweichenden Werte, wenn gedruckte Daten vorliegen. Nutze die sichtbaren Angaben als verbindliche Quelle.

2. PORTIONS-LOGIK & NÄHRWERTBERECHNUNG:
   a) Wenn eine spezifische Portionsgröße (z. B. 1 Riegel = 40g, 1 Dose/Flasche = 500ml) oder die Gesamtfüllmenge der Packung erkennbar ist, berechne die Nährwerte (Kalorien, Protein, Kohlenhydrate, Fett) exakt bezogen auf die sichtbare Gesamtmenge bzw. Standardportion.
      (Beispiel: Wenn auf einer 500ml-Flasche Nährwerte pro 100ml angegeben sind, multipliziere alle Werte exakt mit 5).
   b) Gib im Feld "meal_name" eindeutig an, worauf sich die Werte beziehen (z. B. "Cola Zero (500ml Flasche)" oder "Haferflocken (100g Basis)").

3. TELLERGERICHTE / LOSE MAHLZEITEN:
   - Nur wenn KEINE Verpackung oder Nährwerttabelle sichtbar ist (z. B. frisch gekochtes Essen auf einem Teller), nutze eine realistische Schätzung basierend auf Portionsgröße und Standard-Nährwerten. Schätze die sichtbaren Einzelkomponenten mit Stückzahl/Menge und Gramm.

Bewertung:
- health_score: 1-10
- health_category: "Gesund", "Ausgewogen" oder "Fast Food / Cheat"
- health_reason: 1 kurzer Satz (z. B. Begründung zu Nährstoffdichte, Zuckergehalt, Protein)

Antworte ausschließlich mit einem validen JSON-Objekt (kein Markdown/Fließtext außerhalb von JSON):
Verwende genau diese Feldnamen. Nährwerte sind Zahlen (keine Strings);
Protein, Kohlenhydrate und Fett sind in Gramm, Energie in kcal.
items enthält die Einzelkomponenten; Gesamtnährwerte müssen immer vorhanden sein.

Formatbeispiel:
{
  "meal_name": "Cola Zero (500ml Flasche)",
  "total_calories": 2,
  "total_protein": 0,
  "total_carbs": 0,
  "total_fat": 0,
  "health_score": 5,
  "health_category": "Ausgewogen",
  "health_reason": "Zuckerfrei und kalorienarm, enthält Süßungsmittel.",
  "items": [
    {
      "name": "Cola Zero",
      "amount_grams": 500,
      "calories": 2,
      "protein": 0,
      "carbs": 0,
      "fat": 0
    }
  ]
}''';

    final url = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/$modelName:generateContent?key=$apiKey');

    final requestBody = jsonEncode({
      'contents': [
        {
          'parts': [
            {'text': systemPrompt},
            {
              'inline_data': {
                'mime_type': finalMimeType,
                'data': base64Encode(finalBytes),
              }
            }
          ]
        }
      ],
      'generationConfig': {
        'response_mime_type': 'application/json',
      }
    });

    debugPrint("DEBUG: Sende Request an Gemini ($modelName)...");
    String? responseText;

    const maxRetries = 2; // 1 Initialversuch + max. 1 Wiederholungsversuch
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      http.Response? response;
      try {
        response = await _client.post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: requestBody,
        ).timeout(
          const Duration(seconds: 45),
          onTimeout: () => throw Exception(
              'Timeout: Anfrage an $modelName hat länger als 45 Sekunden gedauert.'),
        );

        print('>>> GEMINI STATUS CODE: ${response.statusCode}');
        print('>>> GEMINI RAW RESPONSE: ${response.body}');

        if (response.statusCode == 200) {
          final Map<String, dynamic> jsonResponse = jsonDecode(response.body);
          final candidates = jsonResponse['candidates'] as List<dynamic>?;
          if (candidates != null && candidates.isNotEmpty) {
            final content = candidates[0]['content'] as Map<String, dynamic>?;
            final parts = content?['parts'] as List<dynamic>?;
            if (parts != null && parts.isNotEmpty) {
              responseText = parts[0]['text'] as String?;
            }
          }
          if (responseText != null && responseText.trim().isNotEmpty) {
            debugPrint("DEBUG: Antwort erhalten von $modelName: $responseText");
            break;
          }
        } else {
          final errorBody = response.body.toLowerCase();
          if (response.statusCode == 429 ||
              errorBody.contains('quota') ||
              errorBody.contains('resource_exhausted')) {
            throw ScanRateLimitException();
          }
          throw Exception('HTTP ${response.statusCode}: ${response.body}');
        }
      } catch (e, stackTrace) {
        if (response != null) {
          print('>>> GEMINI STATUS CODE: ${response.statusCode}');
          print('>>> GEMINI RAW RESPONSE: ${response.body}');
        }
        print('>>> [GEMINI ERROR]: $e');
        print('>>> [GEMINI STACK]: $stackTrace');
        debugPrint('SCAN_ERROR [$modelName, Versuch $attempt]: $e');

        final isRateLimit = isRateLimitError(e);
        final err = e.toString().toLowerCase();
        final isOverload = err.contains('503') ||
            err.contains('unavailable') ||
            err.contains('overloaded') ||
            err.contains('timeout');

        // Automatischer Retry: Bei Rate-Limit oder Serverüberlastung 2s warten und 1x wiederholen
        if ((isRateLimit || isOverload) && attempt < maxRetries) {
          onStatusUpdate?.call(
              "Die Bilderkennung ist kurz ausgelastet. Wiederholung in 2 Sekunden...");
          await Future.delayed(const Duration(seconds: 2));
          continue;
        }

        if (isRateLimit) {
          throw ScanRateLimitException();
        }

        throw const ScanAnalysisException();
      }
    }

    if (responseText == null || responseText.trim().isEmpty) {
      debugPrint('SCAN_ERROR: Leere Antwort von der Gemini-API erhalten.');
      throw const ScanAnalysisException();
    }

    return parseResponse(responseText, filePath);
  }

  @visibleForTesting
  MealEntry parseResponse(String rawText, String? imagePath) {
    print('>>> [GEMINI RAW RESPONSE]: $rawText');
    String raw = rawText;
    if (raw.contains('```json')) {
      raw = raw.split('```json').last.split('```').first;
    } else if (raw.contains('```')) {
      final parts = raw.split('```');
      if (parts.length >= 3 && parts[1].trim().isNotEmpty) {
        raw = parts[1];
      } else {
        raw = raw.split('```').last.split('```').first;
      }
    }
    raw = raw.trim();

    Map<String, dynamic> decodeObject(String text) {
      final value = jsonDecode(text);
      if (value is! Map<String, dynamic>) {
        throw const FormatException('Die KI-Antwort enthält kein JSON-Objekt.');
      }
      return value;
    }

    Map<String, dynamic> decoded;
    try {
      decoded = decodeObject(raw);
    } on FormatException {
      final startIndex = raw.indexOf('{');
      final endIndex = raw.lastIndexOf('}');
      if (startIndex != -1 && endIndex != -1 && endIndex > startIndex) {
        final extracted = raw.substring(startIndex, endIndex + 1);
        try {
          decoded = decodeObject(extracted);
        } on FormatException {
          throw const FormatException(
              'Die KI-Antwort ist unvollständig oder ungültig. Bitte erneut scannen.');
        }
      } else {
        throw Exception(
          'Die Mahlzeit konnte nicht eindeutig erkannt werden. Bitte versuche ein anderes Foto.',
        );
      }
    }

    final mealName = decoded['meal_name']?.toString() ?? 'Erkannte Mahlzeit';
    final rawComponents = decoded['items'] ?? decoded['components'] ?? [];
    if (rawComponents is! List) {
      throw const FormatException(
          'Die KI-Antwort enthält eine ungültige Komponentenliste.');
    }

    final items = rawComponents.map((item) {
      if (item is! Map<String, dynamic>) {
        throw const FormatException(
            'Die KI-Antwort enthält eine ungültige Komponente.');
      }
      return MealItem.fromMap(item);
    }).toList();

    double totalCalories =
        parseNutritionValue(decoded['total_calories']) ?? 0.0;
    double totalProtein = parseNutritionValue(decoded['total_protein_g']) ??
        parseNutritionValue(decoded['total_protein']) ??
        0.0;
    double totalCarbs = parseNutritionValue(decoded['total_carbs_g']) ??
        parseNutritionValue(decoded['total_carbs']) ??
        0.0;
    double totalFat = parseNutritionValue(decoded['total_fat_g']) ??
        parseNutritionValue(decoded['total_fat']) ??
        0.0;

    if (totalCalories == 0 && items.isNotEmpty) {
      totalCalories = items.fold(0.0, (sum, i) => sum + i.calories);
    }
    if (totalProtein == 0 && items.isNotEmpty) {
      totalProtein = items.fold(0.0, (sum, i) => sum + i.proteinG);
    }
    if (totalCarbs == 0 && items.isNotEmpty) {
      totalCarbs = items.fold(0.0, (sum, i) => sum + i.carbsG);
    }
    if (totalFat == 0 && items.isNotEmpty) {
      totalFat = items.fold(0.0, (sum, i) => sum + i.fatG);
    }

    final rawScore = (parseNutritionValue(decoded['health_score']) ??
            parseNutritionValue(decoded['healthScore']))
        ?.toInt();
    final healthCategory =
        (decoded['health_category'] ?? decoded['healthCategory'])?.toString();
    final healthReason =
        (decoded['health_reason'] ?? decoded['healthReason'])?.toString();

    final totalWeightG = items.isNotEmpty
        ? items.fold(0.0, (sum, i) => sum + i.estimatedWeightG).round()
        : null;

    return MealEntry(
      id: const Uuid().v4(),
      name: mealName,
      timestamp: DateTime.now(),
      items: items,
      calories: totalCalories.round(),
      protein: totalProtein,
      carbs: totalCarbs,
      fat: totalFat,
      weightGrams:
          (totalWeightG != null && totalWeightG > 0) ? totalWeightG : null,
      localImagePath: imagePath,
      healthScore: rawScore,
      healthCategory: healthCategory,
      healthReason: healthReason,
    );
  }
}
