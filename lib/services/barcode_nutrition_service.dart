// ignore_for_file: avoid_print
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import '../models/meal_entry.dart';
import '../models/meal_item.dart';
import 'gemini_service.dart';

class BarcodeNetworkException implements Exception {
  final String message;
  const BarcodeNetworkException([this.message = 'Netzwerk langsam, bitte manuell eingeben']);

  @override
  String toString() => message;
}

class BarcodeNutritionService {
  static const String _baseUrl = 'https://world.openfoodfacts.org/api/v2/product';

  /// Ruft Produktinformationen und Nährwerte über die Open Food Facts API ab.
  /// Nutzt robustes Fallback-Parsing und bei leeren Nährwerten einen KI-Fallback via Gemini.
  static Future<Map<String, dynamic>?> fetchProductByBarcode(
    String barcode, {
    GeminiVisionService? geminiService,
  }) async {
    final cleanCode = barcode.trim();
    if (cleanCode.length < 8 || !RegExp(r'^\d+$').hasMatch(cleanCode)) {
      debugPrint(
          '[BarcodeService] Ungültiger Barcode (muss mind. 8 Ziffern haben): "$cleanCode"');
      return null;
    }

    final url = Uri.parse(
        '$_baseUrl/$cleanCode.json?fields=product_name,product_name_de,nutriments,quantity,serving_size');
    http.Response? response;
    bool networkOrTimeoutError = false;

    try {
      response = await http.get(
        url,
        headers: {
          'User-Agent':
              'FoodSnapAI - Android - Version 1.0.1 - emredevelop.studio@gmail.com',
        },
      ).timeout(const Duration(seconds: 8));
    } on SocketException catch (e) {
      print('>>> [OFF SOCKET ERROR] Keine Verbindung / DNS-Fehler: $e');
      networkOrTimeoutError = true;
    } on TimeoutException catch (e) {
      print('>>> [OFF TIMEOUT ERROR] Echtes Timeout nach 8s: $e');
      networkOrTimeoutError = true;
    } catch (e, stack) {
      print('>>> [OFF UNKNOWN ERROR] $e');
      print('>>> [OFF STACK] $stack');
      networkOrTimeoutError = true;
    }

    // Wenn echter Netzwerkfehler / Timeout
    if (networkOrTimeoutError || response == null) {
      debugPrint(
          '>>> [BARCODE SERVICE] OFF nicht erreichbar -> Prüfe Gemini-Fallback für Barcode $cleanCode...');
      try {
        GeminiVisionService? ai = geminiService;
        if (ai == null && GeminiVisionService.defaultApiKey.isNotEmpty) {
          ai = GeminiVisionService();
        }

        if (ai != null) {
          final aiResult = await ai
              .estimateProductByBarcode(cleanCode)
              .timeout(const Duration(seconds: 5));

          if (aiResult != null &&
              aiResult['name'] != null &&
              aiResult['name'] != 'Unbekannt') {
            final name = aiResult['name'].toString();
            final calories = (aiResult['calories'] as num?)?.toDouble() ?? 0.0;
            final protein = (aiResult['protein'] as num?)?.toDouble() ?? 0.0;
            final carbs = (aiResult['carbs'] as num?)?.toDouble() ?? 0.0;
            final fat = (aiResult['fat'] as num?)?.toDouble() ?? 0.0;

            debugPrint(
                '>>> [BARCODE AI FALLBACK] Barcode erfolgreich per Gemini aufgelöst: $name ($calories kcal)');
            return {
              'name': name,
              'calories': calories.round(),
              'protein': double.parse(protein.toStringAsFixed(1)),
              'carbs': double.parse(carbs.toStringAsFixed(1)),
              'fat': double.parse(fat.toStringAsFixed(1)),
              'fiber': 0.0,
              'unit': 'g',
              'defaultAmount': 100.0,
              'barcode': cleanCode,
              'isAiEstimated': true,
            };
          }
        }
      } catch (aiError) {
        debugPrint(
            '>>> [BARCODE AI FALLBACK] Fehler beim Gemini-Barcode-Fallback: $aiError');
      }

      throw const BarcodeNetworkException(
          'Netzwerk zu langsam, bitte manuell eingeben');
    }

    // 404: Produkt nicht in Datenbank gefunden (KEIN Netzwerkfehler!)
    if (response.statusCode == 404) {
      print(
          '>>> [OFF 404] Produkt für Barcode $cleanCode nicht in Open Food Facts gefunden (HTTP 404)');
      // Optionaler Versuch über Gemini
      try {
        GeminiVisionService? ai = geminiService;
        if (ai == null && GeminiVisionService.defaultApiKey.isNotEmpty) {
          ai = GeminiVisionService();
        }
        if (ai != null) {
          final aiResult = await ai
              .estimateProductByBarcode(cleanCode)
              .timeout(const Duration(seconds: 5));
          if (aiResult != null &&
              aiResult['name'] != null &&
              aiResult['name'] != 'Unbekannt') {
            final name = aiResult['name'].toString();
            final calories = (aiResult['calories'] as num?)?.toDouble() ?? 0.0;
            final protein = (aiResult['protein'] as num?)?.toDouble() ?? 0.0;
            final carbs = (aiResult['carbs'] as num?)?.toDouble() ?? 0.0;
            final fat = (aiResult['fat'] as num?)?.toDouble() ?? 0.0;
            return {
              'name': name,
              'calories': calories.round(),
              'protein': double.parse(protein.toStringAsFixed(1)),
              'carbs': double.parse(carbs.toStringAsFixed(1)),
              'fat': double.parse(fat.toStringAsFixed(1)),
              'fiber': 0.0,
              'unit': 'g',
              'defaultAmount': 100.0,
              'barcode': cleanCode,
              'isAiEstimated': true,
            };
          }
        }
      } catch (_) {}
      return null;
    }

    if (response.statusCode != 200) {
      print(
          '>>> [OFF ERROR] Unerwarteter HTTP-Status ${response.statusCode} für Barcode $cleanCode');
      return null;
    }

    try {
      final Map<String, dynamic> jsonBody = json.decode(response.body);
      final int status = (jsonBody['status'] as num?)?.toInt() ?? 0;
      if (status != 1 || jsonBody['product'] == null) {
        debugPrint('[BarcodeService] Product not found for barcode: $cleanCode (status: $status)');
        return null;
      }

      final dynamic rawProduct = jsonBody['product'];
      if (rawProduct is! Map) {
        debugPrint(
            '[BarcodeService] Product is not a Map for barcode: $cleanCode');
        return null;
      }
      final Map<String, dynamic> product = Map<String, dynamic>.from(rawProduct);

      final dynamic rawNutriments = product['nutriments'];
      final Map<String, dynamic> nutriments = rawNutriments is Map
          ? Map<String, dynamic>.from(rawNutriments)
          : <String, dynamic>{};

      // Debug-Prints für Rohdaten
      debugPrint('>>> [OFF RAW DATA] Barcode: $cleanCode, Name: ${product['product_name']}');
      debugPrint('>>> [OFF RAW NUTRIMENTS] ${json.encode(nutriments)}');
      debugPrint('>>> [OFF RAW QUANTITY] serving_size: ${product['serving_size']}, quantity: ${product['quantity']}');

      // 1. Name ermitteln (mit Sprach-Fallbacks)
      String name = product['product_name']?.toString().trim() ?? '';
      if (name.isEmpty) {
        name = product['product_name_de']?.toString().trim() ?? '';
      }
      if (name.isEmpty) {
        name = product['product_name_en']?.toString().trim() ?? '';
      }
      if (name.isEmpty) {
        name = product['generic_name']?.toString().trim() ?? '';
      }
      if (name.isEmpty) {
        name = 'Unbekanntes Produkt ($cleanCode)';
      }

      // 2. Kalorien (kcal) mit 4-Stufen-Fallback ermitteln
      // Stufe 1: energy-kcal_100g
      // Stufe 2: energy-kcal_value
      // Stufe 3: energy-kcal
      // Stufe 4: Umrechnung aus kJ (energy_100g / 4.184)
      double calories = _getFirstNutrimentValue(nutriments, [
        'energy-kcal_100g',
        'energy-kcal_value',
        'energy-kcal',
      ]);

      if (calories <= 0) {
        final double energyKj = _getFirstNutrimentValue(nutriments, [
          'energy_100g',
          'energy_value',
          'energy',
        ]);
        if (energyKj > 0) {
          calories = energyKj / 4.184;
        }
      }

      // 3. Proteine: proteins_100g ?? proteins_value ?? proteins ?? 0
      double protein = _getFirstNutrimentValue(nutriments, [
        'proteins_100g',
        'proteins_value',
        'proteins',
      ]);

      // 4. Kohlenhydrate: carbohydrates_100g ?? carbohydrates_value ?? carbohydrates ?? 0
      double carbs = _getFirstNutrimentValue(nutriments, [
        'carbohydrates_100g',
        'carbohydrates_value',
        'carbohydrates',
      ]);

      // 5. Fett: fat_100g ?? fat_value ?? fat ?? 0
      double fat = _getFirstNutrimentValue(nutriments, [
        'fat_100g',
        'fat_value',
        'fat',
      ]);

      // 6. Ballaststoffe: fiber_100g ?? fiber_value ?? fiber ?? 0
      double fiber = _getFirstNutrimentValue(nutriments, [
        'fiber_100g',
        'fiber_value',
        'fiber',
      ]);

      // 7. Portionsgröße & Einheit: ml falls serving_size oder quantity "ml" enthält, sonst g
      final String quantityStr =
          (product['quantity']?.toString() ?? '').toLowerCase();
      final String servingSizeStr =
          (product['serving_size']?.toString() ?? '').toLowerCase();

      final bool isMl = quantityStr.contains('ml') ||
          quantityStr.contains('liter') ||
          servingSizeStr.contains('ml') ||
          servingSizeStr.contains('liter');
      final String unit = isMl ? 'ml' : 'g';

      double defaultAmount = 100.0;
      final parsedAmount = _extractAmount(
          servingSizeStr.isNotEmpty ? servingSizeStr : quantityStr);
      if (parsedAmount != null && parsedAmount > 0) {
        defaultAmount = parsedAmount;
      }

      bool isAiEstimated = false;

      // 8. Intelligenter KI-Fallback via Gemini:
      // Wenn alle Makros 0 sind oder fehlen (und es kein Wasser ist)
      final bool allMacrosZero =
          calories <= 0 && protein <= 0 && carbs <= 0 && fat <= 0;
      final bool isWater = name.toLowerCase().contains('wasser') ||
          name.toLowerCase().contains('water');

      if (allMacrosZero && !isWater) {
        debugPrint('>>> [BARCODE AI FALLBACK] Alle Makros sind 0 für "$name" -> Starte Gemini-KI-Fallback...');
        try {
          GeminiVisionService? ai = geminiService;
          if (ai == null && GeminiVisionService.defaultApiKey.isNotEmpty) {
            ai = GeminiVisionService();
          }

          if (ai != null) {
            final aiMacros = await ai
                .estimateProductNutrition(name)
                .timeout(const Duration(seconds: 5));
            if (aiMacros != null &&
                ((aiMacros['calories'] ?? 0) > 0 ||
                    (aiMacros['protein'] ?? 0) > 0 ||
                    (aiMacros['carbs'] ?? 0) > 0 ||
                    (aiMacros['fat'] ?? 0) > 0)) {
              calories = _parseValue(aiMacros['calories']);
              protein = _parseValue(aiMacros['protein']);
              carbs = _parseValue(aiMacros['carbs']);
              fat = _parseValue(aiMacros['fat']);
              isAiEstimated = true;
              debugPrint('>>> [BARCODE AI FALLBACK] Gemini-Schätzung erfolgreich: ${calories.round()} kcal, P: $protein, C: $carbs, F: $fat');
            }
          }
        } catch (e) {
          debugPrint('>>> [BARCODE AI FALLBACK] Fehler beim Gemini-Fallback: $e');
        }
      }

      return {
        'name': name,
        'calories': calories.round(),
        'protein': double.parse(protein.toStringAsFixed(1)),
        'carbs': double.parse(carbs.toStringAsFixed(1)),
        'fat': double.parse(fat.toStringAsFixed(1)),
        'fiber': double.parse(fiber.toStringAsFixed(1)),
        'unit': unit,
        'defaultAmount': defaultAmount,
        'barcode': cleanCode,
        'isAiEstimated': isAiEstimated,
      };
    } catch (e, st) {
      debugPrint('[BarcodeService] Error parsing barcode $cleanCode: $e\n$st');
      print('>>> [OFF ERROR] $e');
      return null;
    }
  }

  /// Konvertiert die extrahierten Produktdaten in ein MealEntry für ScanReviewView.
  static MealEntry createMealEntryFromBarcodeData(Map<String, dynamic> data) {
    final String name = data['name']?.toString() ?? 'Lebensmittel';
    final double baseKcal = _parseValue(data['calories']);
    final double baseProtein = _parseValue(data['protein']);
    final double baseCarbs = _parseValue(data['carbs']);
    final double baseFat = _parseValue(data['fat']);
    final String unit = data['unit']?.toString() ?? 'g';
    final double rawAmount = _parseValue(data['defaultAmount']);
    final double amount = rawAmount > 0 ? rawAmount : 100.0;
    final bool isAiEstimated = data['isAiEstimated'] == true;

    // Auf die angegebene Portionsmenge hochrechnen
    final double ratio = amount / 100.0;
    final double itemCalories = baseKcal * ratio;
    final double itemProtein = baseProtein * ratio;
    final double itemCarbs = baseCarbs * ratio;
    final double itemFat = baseFat * ratio;

    final mealItem = MealItem(
      name: name,
      estimatedWeightG: amount,
      calories: itemCalories,
      proteinG: itemProtein,
      carbsG: itemCarbs,
      fatG: itemFat,
    );

    final bool isMl = unit == 'ml';

    return MealEntry(
      id: const Uuid().v4(),
      name: name,
      calories: itemCalories.round(),
      protein: double.parse(itemProtein.toStringAsFixed(1)),
      carbs: double.parse(itemCarbs.toStringAsFixed(1)),
      fat: double.parse(itemFat.toStringAsFixed(1)),
      amountMl: isMl ? amount.round() : null,
      weightGrams: !isMl ? amount.round() : null,
      timestamp: DateTime.now(),
      items: [mealItem],
      healthReason: isAiEstimated ? 'Nährwerte per KI geschätzt' : null,
    );
  }

  static double _getFirstNutrimentValue(
      Map<String, dynamic> nutriments, List<String> candidateKeys) {
    for (final key in candidateKeys) {
      if (nutriments.containsKey(key) && nutriments[key] != null) {
        final val = _parseValue(nutriments[key]);
        if (val > 0) return val;
      }
    }
    // Falls ein expliziter 0-Wert hinterlegt ist
    for (final key in candidateKeys) {
      if (nutriments.containsKey(key) && nutriments[key] != null) {
        return _parseValue(nutriments[key]);
      }
    }
    return 0.0;
  }

  static double _parseValue(dynamic val) {
    if (val == null) return 0.0;
    if (val is num) return val.toDouble();
    if (val is String) {
      final cleaned = val.replaceAll(',', '.').trim();
      return double.tryParse(cleaned) ?? 0.0;
    }
    return 0.0;
  }

  static double? _extractAmount(dynamic text) {
    if (text == null) return null;
    final str = text.toString().trim();
    if (str.isEmpty) return null;
    final match = RegExp(r'(\d+(?:[.,]\d+)?)').firstMatch(str);
    if (match != null) {
      final raw = match.group(1)!.replaceAll(',', '.');
      return double.tryParse(raw);
    }
    return null;
  }
}
