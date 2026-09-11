// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:uuid/uuid.dart';
import '../models/meal_entry.dart';
import '../models/meal_item.dart';

typedef GeminiService = GeminiVisionService;

class GeminiVisionService {
  static const String defaultApiKey = 'AQ.Ab8RN6IayeGgVKKiGMXoRH2xiVhFt-2ByVx5YSDIZbPqgh0g0A';
  static const String modelName = 'gemini-3.6-flash';

  final String apiKey;
  late final GenerativeModel _model;

  GeminiVisionService({String? apiKey})
      : apiKey = (apiKey != null && apiKey.trim().isNotEmpty) ? apiKey.trim() : defaultApiKey {
    final config = GenerationConfig(
      responseMimeType: 'application/json',
      temperature: 0.2,
      maxOutputTokens: 500,
    );
    _model = GenerativeModel(
      model: modelName,
      apiKey: this.apiKey,
      generationConfig: config,
    );
  }

  /// Analyzes an image provided either as file path or raw bytes.
  Future<MealEntry> analyzeFoodImage({
    String? filePath,
    Uint8List? imageBytes,
    String mimeType = 'image/jpeg',
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
      final lower = filePath.toLowerCase();
      if (lower.endsWith('.png')) {
        mimeType = 'image/png';
      } else if (lower.endsWith('.webp')) {
        mimeType = 'image/webp';
      } else if (lower.endsWith('.heic')) {
        mimeType = 'image/heic';
      }
    } else {
      throw ArgumentError('Entweder filePath oder imageBytes muss angegeben werden.');
    }

    const String systemPrompt = '''
Analysiere dieses Foto einer Mahlzeit als Ernährungs- und Computer-Vision-Experte.
Schätze die Einzelkomponenten mit Stückzahl/Menge und Gramm sowie Gesamtkalorien und Makros.

Bewertung:
- health_score: 1-10
- health_category: "Gesund", "Ausgewogen" oder "Fast Food / Cheat"
- health_reason: 1 kurzer Satz

Antworte ausschließlich mit einem validen JSON-Objekt (kein Markdown/Fließtext):
Antworte ausschließlich im JSON-Format mit den Nährwerten (calories, protein, carbs, fat):
{
  "meal_name": "string",
  "total_calories": number,
  "total_protein_g": number,
  "total_carbs_g": number,
  "total_fat_g": number,
  "health_score": number,
  "health_category": "Gesund" | "Ausgewogen" | "Fast Food / Cheat",
  "health_reason": "string",
  "components": [
    {
      "name": "string",
      "amount_grams": number,
      "calories": number,
      "protein": number,
      "carbs": number,
      "fat": number
    }
  ]
}''';

    final content = [
      Content.multi([
        TextPart(systemPrompt),
        DataPart(mimeType, bytes),
      ])
    ];

    debugPrint("DEBUG: Sende Request an Gemini ($modelName)...");
    String? responseText;

    const maxRetries = 2;
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        final res = await _model.generateContent(content).timeout(
          const Duration(seconds: 45),
          onTimeout: () => throw Exception('Timeout: Anfrage an $modelName hat länger als 45 Sekunden gedauert.'),
        );
        if (res.text != null && res.text!.trim().isNotEmpty) {
          responseText = res.text;
          debugPrint("DEBUG: Antwort erhalten von $modelName: $responseText");
          break;
        }
      } catch (e) {
        debugPrint('SCAN_ERROR [$modelName, Versuch $attempt]: $e');
        final err = e.toString().toLowerCase();
        final isRateLimitOrOverload = err.contains('429') ||
            err.contains('503') ||
            err.contains('resource_exhausted') ||
            err.contains('unavailable') ||
            err.contains('overloaded') ||
            err.contains('timeout');

        if (isRateLimitOrOverload && attempt < maxRetries) {
          onStatusUpdate?.call("KI ausgelastet, neuer Versuch ($attempt/$maxRetries)...");
          await Future.delayed(const Duration(milliseconds: 1000));
          continue;
        }
        throw Exception('API-Fehler bei $modelName: $e');
      }
    }

    if (responseText == null || responseText.trim().isEmpty) {
      debugPrint('SCAN_ERROR: Leere Antwort von der Gemini-API erhalten.');
      throw Exception('API lieferte eine leere Antwort zurück.');
    }

    return _parseResponse(responseText, filePath);
  }

  MealEntry _parseResponse(String rawText, String? imagePath) {
    String cleanJson = rawText.trim();
    if (cleanJson.startsWith('```json')) {
      cleanJson = cleanJson.substring(7);
    } else if (cleanJson.startsWith('```')) {
      cleanJson = cleanJson.substring(3);
    }
    if (cleanJson.endsWith('```')) {
      cleanJson = cleanJson.substring(0, cleanJson.length - 3);
    }
    cleanJson = cleanJson.trim();

    Map<String, dynamic> decoded;
    try {
      decoded = jsonDecode(cleanJson) as Map<String, dynamic>;
    } catch (e) {
      final startIndex = cleanJson.indexOf('{');
      final endIndex = cleanJson.lastIndexOf('}');
      if (startIndex != -1 && endIndex != -1 && endIndex > startIndex) {
        final extracted = cleanJson.substring(startIndex, endIndex + 1);
        decoded = jsonDecode(extracted) as Map<String, dynamic>;
      } else {
        throw Exception(
          'Die Mahlzeit konnte nicht eindeutig erkannt werden. Bitte versuche ein anderes Foto.',
        );
      }
    }

    final mealName = decoded['meal_name'] as String? ?? 'Erkannte Mahlzeit';
    final rawComponents = (decoded['components'] as List<dynamic>?) ??
        (decoded['items'] as List<dynamic>?) ??
        [];

    final items = rawComponents.map((item) {
      final map = Map<String, dynamic>.from(item as Map);
      return MealItem.fromMap(map);
    }).toList();

    double totalCalories = (decoded['total_calories'] as num?)?.toDouble() ?? 0.0;
    double totalProtein = (decoded['total_protein_g'] as num?)?.toDouble() ??
        (decoded['total_protein'] as num?)?.toDouble() ??
        0.0;
    double totalCarbs = (decoded['total_carbs_g'] as num?)?.toDouble() ??
        (decoded['total_carbs'] as num?)?.toDouble() ??
        0.0;
    double totalFat = (decoded['total_fat_g'] as num?)?.toDouble() ??
        (decoded['total_fat'] as num?)?.toDouble() ??
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

    final rawScore = (decoded['health_score'] as num?)?.toInt() ??
        (decoded['healthScore'] as num?)?.toInt();
    final healthCategory = decoded['health_category'] as String? ??
        decoded['healthCategory'] as String?;
    final healthReason = decoded['health_reason'] as String? ??
        decoded['healthReason'] as String?;

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
      weightGrams: (totalWeightG != null && totalWeightG > 0) ? totalWeightG : null,
      localImagePath: imagePath,
      healthScore: rawScore,
      healthCategory: healthCategory,
      healthReason: healthReason,
    );
  }
}
