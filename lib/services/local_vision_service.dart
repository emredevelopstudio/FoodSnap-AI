// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image/image.dart' as img;
import 'package:uuid/uuid.dart';

import '../models/meal_entry.dart';
import '../models/meal_item.dart';
import '../models/nutrition_value.dart';
import 'food_nutrition_engine.dart';
import 'local_model_manager.dart';

/// Repräsentiert das typisierte Ergebnis einer lokalen On-Device Klassifizierung.
class LocalVisionResult {
  final String label;
  final double confidence;
  final String germanName;
  final double caloriesPer100g;
  final double proteinPer100g;
  final double carbsPer100g;
  final double fatPer100g;
  final double defaultServingG;
  final int? healthScore;
  final String healthCategory;
  final String healthNote;

  const LocalVisionResult({
    required this.label,
    required this.confidence,
    required this.germanName,
    required this.caloriesPer100g,
    required this.proteinPer100g,
    required this.carbsPer100g,
    required this.fatPer100g,
    required this.defaultServingG,
    this.healthScore,
    required this.healthCategory,
    required this.healthNote,
  });

  /// Berechnete Gesamtwerte für die Standardportionsgröße
  int get calories => (caloriesPer100g * defaultServingG / 100.0).round();
  double get protein => (proteinPer100g * defaultServingG / 100.0);
  double get carbs => (carbsPer100g * defaultServingG / 100.0);
  double get fat => (fatPer100g * defaultServingG / 100.0);

  /// Konvertiert dieses Ergebnis in ein MealItem
  MealItem toMealItem({double? servingG}) {
    final grams = servingG ?? defaultServingG;
    return MealItem(
      name: germanName,
      estimatedWeightG: grams,
      calories: (caloriesPer100g * grams / 100.0),
      proteinG: (proteinPer100g * grams / 100.0),
      carbsG: (carbsPer100g * grams / 100.0),
      fatG: (fatPer100g * grams / 100.0),
    );
  }

  /// Konvertiert dieses Ergebnis in ein vollwertiges, Hive-kompatibles MealEntry
  MealEntry toMealEntry({String? imagePath, double? servingG}) {
    final grams = servingG ?? defaultServingG;
    final item = toMealItem(servingG: grams);
    final totalCalories = (caloriesPer100g * grams / 100.0).round();
    final totalProtein = (proteinPer100g * grams / 100.0);
    final totalCarbs = (carbsPer100g * grams / 100.0);
    final totalFat = (fatPer100g * grams / 100.0);

    return MealEntry(
      id: const Uuid().v4(),
      name: germanName,
      calories: totalCalories,
      protein: totalProtein,
      carbs: totalCarbs,
      fat: totalFat,
      weightGrams: grams.round(),
      timestamp: DateTime.now(),
      localImagePath: imagePath,
      items: [item],
      healthScore: healthScore,
      healthCategory: healthCategory,
      healthReason: '$healthNote (${(confidence * 100).toStringAsFixed(0)} % Konfidenz. Portionsgrößen geschätzt – frei anpassbar.)',
    );
  }
}

/// Repräsentiert die Nährwert-Referenzwerte für ein erkanntes Lebensmittel (Baseline).
class FoodBaseline {
  final String germanName;
  final int calories;
  final double proteinG;
  final double carbsG;
  final double fatG;
  final int estimatedWeightG;
  final int? amountMl;
  final int healthScore;
  final String healthCategory;
  final String healthReason;

  const FoodBaseline({
    required this.germanName,
    required this.calories,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
    this.estimatedWeightG = 150,
    this.amountMl,
    this.healthScore = 7,
    this.healthCategory = 'Ausgewogen',
    this.healthReason = 'Lokale Lebensmittel-Erkennung.',
  });
}

/// Neuer lokaler On-Device Vision-Service, der vollständige Inferenz
/// ohne externe Cloud-Abhängigkeiten via Google LiteRT (quantisiert)
/// und lokalem Nährwert-Lookup (nutrition_db.json) durchführt.
class LocalVisionService {
  static const MethodChannel _channel = MethodChannel('com.foodsnap.ai/vision');
  static MethodChannel get channel => _channel;

  final LocalModelManager modelManager;

  LocalVisionService({LocalModelManager? modelManager})
      : modelManager = modelManager ?? LocalModelManager.instance;

  static const String unrecognizedMealName = 'Unbekanntes Lebensmittel';
  static const String defaultMealName = 'Erkannte Mahlzeit';

  static Map<String, Map<String, dynamic>>? _cachedNutritionDb;

  /// Lädt die lokale Nährwert-Datenbank aus assets/models/nutrition_db.json
  static Future<Map<String, Map<String, dynamic>>> loadNutritionDb() async {
    if (_cachedNutritionDb != null) return _cachedNutritionDb!;
    try {
      final jsonStr = await rootBundle.loadString('assets/models/nutrition_db.json');
      final decoded = jsonDecode(jsonStr) as Map<String, dynamic>;
      _cachedNutritionDb = decoded.map((key, value) =>
          MapEntry(key.toLowerCase().trim(), Map<String, dynamic>.from(value as Map)));
      return _cachedNutritionDb!;
    } catch (e) {
      debugPrint('[LocalVisionService] Fehler beim Laden von nutrition_db.json: $e');
      _cachedNutritionDb = {};
      return _cachedNutritionDb!;
    }
  }

  /// Gleicht ein englisches KI-Klassifikationslabel gegen die lokale Nährwert-DB ab.
  static LocalVisionResult resolveNutrition({
    required String label,
    required double confidence,
    Map<String, Map<String, dynamic>>? db,
  }) {
    final lookupKey = label.trim().toLowerCase();
    final withSpaces = lookupKey.replaceAll('_', ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
    final withUnderscores = lookupKey.replaceAll(' ', '_').replaceAll(RegExp(r'_+'), '_').trim();

    Map<String, dynamic>? nutrition;

    // 1. Suche in nutrition_db.json (mit Alias- und Teilwortsuche)
    if (db != null && db.isNotEmpty) {
      nutrition = _findInNutritionDb(lookupKey, withSpaces, withUnderscores, db);
    }

    // 2. Suche in baselineNutrition falls noch nicht gefunden
    FoodBaseline? baseline;
    if (nutrition == null) {
      baseline = _findInBaseline(lookupKey, withSpaces, withUnderscores);
    }

    final bool isFound = (nutrition != null || baseline != null);
    debugPrint("Matching Key: $lookupKey -> Gefunden: $isFound");
    debugPrint("Matching Key: $lookupKey -> Gefunden: $isFound");

    // Falls ein DB-Treffer vorliegt:
    if (nutrition != null) {
      return _resultFromDbEntry(label, confidence, nutrition);
    }

    // Falls eine Baseline vorliegt:
    if (baseline != null) {
      final serving = baseline.estimatedWeightG.toDouble();
      return LocalVisionResult(
        label: label,
        confidence: confidence,
        germanName: baseline.germanName,
        caloriesPer100g: serving > 0 ? (baseline.calories * 100.0 / serving) : 0.0,
        proteinPer100g: serving > 0 ? (baseline.proteinG * 100.0 / serving) : 0.0,
        carbsPer100g: serving > 0 ? (baseline.carbsG * 100.0 / serving) : 0.0,
        fatPer100g: serving > 0 ? (baseline.fatG * 100.0 / serving) : 0.0,
        defaultServingG: serving,
        healthScore: baseline.healthScore,
        healthCategory: baseline.healthCategory,
        healthNote: baseline.healthReason,
      );
    }

    // 3. Fallback: Lesbar formatiertes Roh-Label (z. B. "Apple" statt "unbekanntes Lebensmittel")
    // mit Standard-Schätzwerten (100 kcal / 100g), damit der User den Namen sieht und editieren kann.
    final beautifiedName = _beautifyFoodLabel(label);
    return LocalVisionResult(
      label: label,
      confidence: confidence,
      germanName: beautifiedName,
      caloriesPer100g: 100.0,
      proteinPer100g: 4.0,
      carbsPer100g: 15.0,
      fatPer100g: 3.0,
      defaultServingG: 100.0,
      healthScore: 7,
      healthCategory: 'Ausgewogen',
      healthNote: 'Automatisch erfasst ($beautifiedName). Nährwerte auf 100 kcal / 100g geschätzt – frei anpassbar.',
    );
  }

  /// Findet einen Eintrag in der nutrition_db.json via exakter, Alias- und Teilwortsuche (Substring / Regex)
  static Map<String, dynamic>? _findInNutritionDb(
    String lookupKey,
    String withSpaces,
    String withUnderscores,
    Map<String, Map<String, dynamic>> db,
  ) {
    // A. Direkter exakter Treffer (Key mit Spaces oder Underscores oder raw)
    if (db.containsKey(lookupKey)) return db[lookupKey];
    if (db.containsKey(withSpaces)) return db[withSpaces];
    if (db.containsKey(withUnderscores)) return db[withUnderscores];

    // B. Exakter Alias-Treffer
    for (final entry in db.entries) {
      final aliases = _getAliases(entry.value);
      for (final alias in aliases) {
        final aliasSpaces = alias.replaceAll('_', ' ').trim();
        final aliasUnderscores = alias.replaceAll(' ', '_').trim();
        if (alias == lookupKey ||
            alias == withSpaces ||
            alias == withUnderscores ||
            aliasSpaces == withSpaces ||
            aliasUnderscores == withUnderscores) {
          return entry.value;
        }
      }
    }

    // C. Substring / Teilwortsuche:
    // z. B. Label "roasted_chicken" oder "grilled chicken" -> matches DB key "chicken" oder Alias "chicken"
    for (final entry in db.entries) {
      final keyClean = entry.key.replaceAll('_', ' ').trim();
      final keyUnderscores = entry.key.replaceAll(' ', '_').trim();

      // Prüfe, ob das Label den Key enthält oder der Key das Label enthält
      if (_matchesSubstring(withSpaces, keyClean) ||
          _matchesSubstring(withUnderscores, keyUnderscores) ||
          _matchesSubstring(keyClean, withSpaces)) {
        return entry.value;
      }

      // Prüfe alle Aliase gegen das Label
      final aliases = _getAliases(entry.value);
      for (final alias in aliases) {
        final aliasClean = alias.replaceAll('_', ' ').trim();
        if (aliasClean.isNotEmpty) {
          if (_matchesSubstring(withSpaces, aliasClean) ||
              _matchesSubstring(aliasClean, withSpaces)) {
            return entry.value;
          }
        }
      }
    }

    // D. Wortbasierte Regex-Suche (falls zusammengesetzte Bezeichnungen wie "crispy chicken tenders"):
    final labelWords = withSpaces
        .split(RegExp(r'\s+'))
        .where((w) => w.length >= 3 && !_stopWords.contains(w))
        .toList();

    if (labelWords.isNotEmpty) {
      for (final entry in db.entries) {
        final keyClean = entry.key.replaceAll('_', ' ').trim();
        final keyWords = keyClean.split(RegExp(r'\s+'));
        final aliases = _getAliases(entry.value);

        for (final word in labelWords) {
          if (keyClean == word || keyWords.contains(word)) {
            return entry.value;
          }
          for (final alias in aliases) {
            final aliasClean = alias.replaceAll('_', ' ').trim();
            final aliasWords = aliasClean.split(RegExp(r'\s+'));
            if (aliasClean == word || aliasWords.contains(word)) {
              return entry.value;
            }
          }
        }
      }
    }

    return null;
  }

  static List<String> _getAliases(Map<String, dynamic> data) {
    final raw = data['aliases'];
    if (raw is List) {
      return raw
          .map((e) => e.toString().toLowerCase().trim())
          .where((s) => s.isNotEmpty)
          .toList();
    }
    return const [];
  }

  static bool _matchesSubstring(String text, String pattern) {
    if (pattern.length < 3 || text.isEmpty) return false;
    final regex = RegExp(r'\b' + RegExp.escape(pattern) + r'\b', caseSensitive: false);
    if (regex.hasMatch(text)) return true;
    return text.contains(pattern);
  }

  static const Set<String> _stopWords = {
    'the', 'and', 'with', 'for', 'style', 'dish', 'plate', 'bowl', 'fresh', 'slice', 'piece'
  };

  static FoodBaseline? _findInBaseline(
    String lookupKey,
    String withSpaces,
    String withUnderscores,
  ) {
    if (baselineNutrition.containsKey(lookupKey)) return baselineNutrition[lookupKey];
    if (baselineNutrition.containsKey(withSpaces)) return baselineNutrition[withSpaces];
    if (baselineNutrition.containsKey(withUnderscores)) return baselineNutrition[withUnderscores];

    for (final entry in baselineNutrition.entries) {
      final keyClean = entry.key.replaceAll('_', ' ').trim();
      if (_matchesSubstring(withSpaces, keyClean) || _matchesSubstring(keyClean, withSpaces)) {
        return entry.value;
      }
    }
    return null;
  }

  static LocalVisionResult _resultFromDbEntry(
      String label, double confidence, Map<String, dynamic> data) {
    return LocalVisionResult(
      label: label,
      confidence: confidence,
      germanName: data['germanName']?.toString() ?? _beautifyFoodLabel(label),
      caloriesPer100g: (data['caloriesPer100g'] as num?)?.toDouble() ?? 100.0,
      proteinPer100g: (data['proteinPer100g'] as num?)?.toDouble() ?? 5.0,
      carbsPer100g: (data['carbsPer100g'] as num?)?.toDouble() ?? 10.0,
      fatPer100g: (data['fatPer100g'] as num?)?.toDouble() ?? 3.0,
      defaultServingG: (data['defaultServingG'] as num?)?.toDouble() ?? 150.0,
      healthScore: (data['healthScore'] as num?)?.toInt() ?? 7,
      healthCategory: data['healthCategory']?.toString() ?? 'Ausgewogen',
      healthNote: data['healthNote']?.toString() ?? 'Lokale Erkennung.',
    );
  }

  static String _beautifyFoodLabel(String label) {
    final clean = label.replaceAll('_', ' ').replaceAll('-', ' ').trim();
    if (clean.isEmpty) return 'Unbekanntes Gericht';
    return clean.split(RegExp(r'\s+')).map((word) {
      if (word.isEmpty) return word;
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
  }

  /// Führt On-Device-Klassifizierung durch und gibt typisierte `LocalVisionResult` zurück.
  Future<List<LocalVisionResult>> analyzeImage(
    String imagePath, {
    double threshold = 0.10,
    int maxResults = 5,
  }) async {
    final db = await loadNutritionDb();

    try {
      final rawList = await _channel.invokeMethod<List<dynamic>>(
        'classifyImage',
        {
          'imagePath': imagePath,
          'threshold': threshold,
          'maxResults': maxResults,
        },
      );

      final rawResults = rawList ?? [];
      debugPrint("Native Inferenz Raw: $rawResults");
      debugPrint("Native Inferenz Raw: $rawResults");

      if (rawResults.isNotEmpty) {
        final results = <LocalVisionResult>[];
        for (final item in rawResults) {
          if (item is Map) {
            final label = item['label']?.toString() ?? '';
            final confidence = (item['confidence'] as num?)?.toDouble() ?? 0.0;
            if (label.isNotEmpty &&
                label.toLowerCase() != '__background__' &&
                !label.startsWith('/g/')) {
              results.add(resolveNutrition(
                label: label,
                confidence: confidence,
                db: db,
              ));
            }
          }
        }
        if (results.isNotEmpty) {
          return results;
        }
      }
    } catch (e) {
      debugPrint('[LocalVisionService] MethodChannel classifyImage Fehler: $e');
    }

    return [];
  }

  /// Tabelle für lokale Nährwert-Zuordnung von ImageNet / Food-Klassen
  static final Map<String, FoodBaseline> baselineNutrition = {
    // Wasser & Getränke
    'water bottle': const FoodBaseline(
      germanName: 'Wasser / Mineralwasser',
      calories: 0,
      proteinG: 0.0,
      carbsG: 0.0,
      fatG: 0.0,
      estimatedWeightG: 500,
      amountMl: 500,
      healthScore: 10,
      healthCategory: 'Sehr gesund',
      healthReason: 'Kalorienfrei und unverzichtbar für einen gesunden Flüssigkeitshaushalt.',
    ),
    'bottle': const FoodBaseline(
      germanName: 'Wasser / Mineralwasser',
      calories: 0,
      proteinG: 0.0,
      carbsG: 0.0,
      fatG: 0.0,
      estimatedWeightG: 500,
      amountMl: 500,
      healthScore: 10,
      healthCategory: 'Sehr gesund',
      healthReason: 'Kalorienfrei und unverzichtbar für einen gesunden Flüssigkeitshaushalt.',
    ),
    'pop bottle': const FoodBaseline(
      germanName: 'Erfrischungsgetränk',
      calories: 105,
      proteinG: 0.0,
      carbsG: 26.0,
      fatG: 0.0,
      estimatedWeightG: 250,
      amountMl: 250,
      healthScore: 3,
      healthCategory: 'Fast Food / Cheat',
      healthReason: 'Zuckerhaltiges Erfrischungsgetränk.',
    ),
    'water': const FoodBaseline(
      germanName: 'Wasser / Mineralwasser',
      calories: 0,
      proteinG: 0.0,
      carbsG: 0.0,
      fatG: 0.0,
      estimatedWeightG: 500,
      amountMl: 500,
      healthScore: 10,
      healthCategory: 'Sehr gesund',
      healthReason: 'Kalorienfrei und essenziell für die Hydratation.',
    ),

    // Obst & Gemüse
    'apple': const FoodBaseline(
      germanName: 'Apfel',
      calories: 52,
      proteinG: 0.3,
      carbsG: 14.0,
      fatG: 0.2,
      estimatedWeightG: 150,
      healthScore: 10,
      healthCategory: 'Sehr gesund',
      healthReason: 'Reich an Ballaststoffen, Vitamin C und Antioxidantien.',
    ),
    'banana': const FoodBaseline(
      germanName: 'Banane',
      calories: 89,
      proteinG: 1.1,
      carbsG: 23.0,
      fatG: 0.3,
      estimatedWeightG: 120,
      healthScore: 9,
      healthCategory: 'Sehr gesund',
      healthReason: 'Schnell verfügbare Energie mit Kalium und Magnesium.',
    ),
    'orange': const FoodBaseline(
      germanName: 'Orange',
      calories: 47,
      proteinG: 0.9,
      carbsG: 12.0,
      fatG: 0.1,
      estimatedWeightG: 150,
      healthScore: 10,
      healthCategory: 'Sehr gesund',
      healthReason: 'Hervorragender Vitamin-C-Lieferant zur Unterstützung des Immunsystems.',
    ),
    'broccoli': const FoodBaseline(
      germanName: 'Brokkoli',
      calories: 34,
      proteinG: 2.8,
      carbsG: 7.0,
      fatG: 0.4,
      estimatedWeightG: 200,
      healthScore: 10,
      healthCategory: 'Sehr gesund',
      healthReason: 'Sehr nährstoffreiches Gemüse mit hohem Vitamin- und Mineralstoffgehalt.',
    ),

    // Fast Food & Mahlzeiten
    'pizza': const FoodBaseline(
      germanName: 'Pizza',
      calories: 266,
      proteinG: 11.0,
      carbsG: 33.0,
      fatG: 10.0,
      estimatedWeightG: 350,
      healthScore: 4,
      healthCategory: 'Fast Food / Cheat',
      healthReason: 'Kohlenhydrat- und fettreich mit moderatem Proteinanteil.',
    ),
    'cheeseburger': const FoodBaseline(
      germanName: 'Cheeseburger',
      calories: 303,
      proteinG: 15.0,
      carbsG: 30.0,
      fatG: 14.0,
      estimatedWeightG: 200,
      healthScore: 4,
      healthCategory: 'Fast Food / Cheat',
      healthReason: 'Guter Eiweißanteil bei gleichzeitig erhöhtem Fett- und Salzgehalt.',
    ),
    'burger': const FoodBaseline(
      germanName: 'Cheeseburger',
      calories: 303,
      proteinG: 15.0,
      carbsG: 30.0,
      fatG: 14.0,
      estimatedWeightG: 200,
      healthScore: 4,
      healthCategory: 'Fast Food / Cheat',
      healthReason: 'Klassischer Burger mit Rindfleisch-Patty.',
    ),
    'french fries': const FoodBaseline(
      germanName: 'Pommes frites',
      calories: 312,
      proteinG: 3.4,
      carbsG: 41.0,
      fatG: 15.0,
      estimatedWeightG: 150,
      healthScore: 3,
      healthCategory: 'Fast Food / Cheat',
      healthReason: 'Frittierte Kartoffelbeilage mit hohem Fettgehalt.',
    ),

    // Brot & Beilagen
    'bread': const FoodBaseline(
      germanName: 'Brot / Toast',
      calories: 265,
      proteinG: 9.0,
      carbsG: 49.0,
      fatG: 3.2,
      estimatedWeightG: 100,
      healthScore: 6,
      healthCategory: 'Ausgewogen',
      healthReason: 'Traditionelle Kohlenhydratquelle.',
    ),
    'french loaf': const FoodBaseline(
      germanName: 'Baguette',
      calories: 270,
      proteinG: 9.5,
      carbsG: 52.0,
      fatG: 2.5,
      estimatedWeightG: 150,
      healthScore: 5,
      healthCategory: 'Ausgewogen',
      healthReason: 'Helles Weizengebäck.',
    ),
    'chicken breast': const FoodBaseline(
      germanName: 'Hähnchenbrust',
      calories: 165,
      proteinG: 31.0,
      carbsG: 0.0,
      fatG: 3.6,
      estimatedWeightG: 180,
      healthScore: 10,
      healthCategory: 'Sehr gesund',
      healthReason: 'Sehr mageres Protein mit hoher biologischer Wertigkeit.',
    ),

    // Kaffee & Heißgetränke
    'espresso': const FoodBaseline(
      germanName: 'Espresso',
      calories: 9,
      proteinG: 0.1,
      carbsG: 1.7,
      fatG: 0.2,
      estimatedWeightG: 30,
      amountMl: 30,
      healthScore: 9,
      healthCategory: 'Sehr gesund',
      healthReason: 'Kalorienarmer Wachmacher mit natürlichen Antioxidantien.',
    ),
    'coffee': const FoodBaseline(
      germanName: 'Kaffee schwarz',
      calories: 4,
      proteinG: 0.3,
      carbsG: 0.2,
      fatG: 0.1,
      estimatedWeightG: 200,
      amountMl: 200,
      healthScore: 9,
      healthCategory: 'Sehr gesund',
      healthReason: 'Reines Heißgetränk ohne Kalorien oder Zucker.',
    ),
    'cup': const FoodBaseline(
      germanName: 'Kaffee / Espresso',
      calories: 2,
      proteinG: 0.1,
      carbsG: 0.0,
      fatG: 0.0,
      estimatedWeightG: 200,
      amountMl: 200,
      healthScore: 9,
      healthCategory: 'Sehr gesund',
      healthReason: 'Kalorienarmes Heißgetränk.',
    ),
    'coffee mug': const FoodBaseline(
      germanName: 'Kaffee / Espresso',
      calories: 2,
      proteinG: 0.1,
      carbsG: 0.0,
      fatG: 0.0,
      estimatedWeightG: 200,
      amountMl: 200,
      healthScore: 9,
      healthCategory: 'Sehr gesund',
      healthReason: 'Kalorienarmes Heißgetränk.',
    ),
    'hamburger': const FoodBaseline(
      germanName: 'Cheeseburger',
      calories: 303,
      proteinG: 15.0,
      carbsG: 30.0,
      fatG: 14.0,
      estimatedWeightG: 200,
      healthScore: 4,
      healthCategory: 'Fast Food / Cheat',
      healthReason: 'Klassischer Burger mit Rindfleisch-Patty.',
    ),
  };

  /// Ermittelt die Nährwert-Referenz für ein Label (exakt oder Teiltreffer).
  static FoodBaseline? getBaselineNutrition(String label) {
    final clean = label.trim().toLowerCase().replaceAll('_', ' ');
    if (baselineNutrition.containsKey(clean)) {
      return baselineNutrition[clean];
    }
    for (final entry in baselineNutrition.entries) {
      if (clean == entry.key || clean.contains(entry.key) || entry.key.contains(clean)) {
        return entry.value;
      }
    }
    return null;
  }

  /// Erstellt einen MealEntry aus einer MediaPipe / LiteRT Kategorie.
  static MealEntry createFromCategory({
    required String label,
    required double confidence,
    String? imagePath,
    List<String>? detectedLabels,
  }) {
    debugPrint('[LOCAL VISION] Erhaltenes Label: "$label", Confidence: $confidence');

    if (confidence < 0.30 || label.isEmpty || label.toLowerCase() == 'unrecognized') {
      return createUnrecognizedMeal(
        imagePath: imagePath,
        reason: 'Geringe Erkennungssicherheit (${(confidence * 100).toStringAsFixed(0)} %)',
      );
    }

    final candidateLabels = (detectedLabels != null && detectedLabels.isNotEmpty)
        ? detectedLabels
        : [label];

    // 1. Suche nach Rezeptur-Dekomposition in der lokalen Ernährungs-Engine (Teller-Zerlegung)
    final matchedRecipe = FoodNutritionEngine.instance.findMatchingRecipe(candidateLabels);
    if (matchedRecipe != null) {
      return FoodNutritionEngine.instance.createMealFromRecipe(
        matchedRecipe,
        imagePath: imagePath,
        confidence: confidence,
      );
    }

    // 2. Prüfung der bewährten Einzel-Baseline
    final baseline = getBaselineNutrition(label);
    if (baseline != null) {
      final item = MealItem(
        name: baseline.germanName,
        estimatedWeightG: baseline.estimatedWeightG.toDouble(),
        calories: baseline.calories.toDouble(),
        proteinG: baseline.proteinG,
        carbsG: baseline.carbsG,
        fatG: baseline.fatG,
      );

      return MealEntry(
        id: const Uuid().v4(),
        name: baseline.germanName,
        calories: baseline.calories,
        protein: baseline.proteinG,
        carbs: baseline.carbsG,
        fat: baseline.fatG,
        weightGrams: baseline.estimatedWeightG,
        amountMl: baseline.amountMl,
        timestamp: DateTime.now(),
        localImagePath: imagePath,
        items: [item],
        healthScore: baseline.healthScore,
        healthCategory: baseline.healthCategory,
        healthReason: '${baseline.healthReason} (${(confidence * 100).toStringAsFixed(0)} % Konfidenz. Portionsgrößen geschätzt – frei anpassbar.)',
      );
    }

    // 3. Fallback über die FoodNutritionEngine (intelligente Schätzung & Kennzeichnung)
    return FoodNutritionEngine.instance.processDetections(
      labels: candidateLabels,
      confidence: confidence,
      imagePath: imagePath,
    );
  }

  /// System-Prompt zur strukturierten Vision-Vorgabe
  static const String systemPrompt = '''
Du bist ein präziser Ernährungs- und Vision-Experte für eine Kalorientracker-App. Analysiere das Bild nach folgendem Ablauf:

SCHRITT 1: BILDTYP IDENTIFIZIEREN
Prüfe zuerst: Ist es ein fertiges Gericht (Teller/Schüssel) ODER ein verpacktes Produkt / Markenartikel (Tüte, Dose, Riegel, Flasche)?

SCHRITT 2: ANALYSE BEI VERPACKUNGEN / MARKENPRODUKTEN:
- Lies alle sichtbaren Texte exakt aus (Markenname, exakte Sorte/Geschmack, aufgedruckte Grammatur z. B. "150g" oder "75g").
- Falls die Nährwerttabelle auf dem Bild sichtbar ist: Nimm die exakten Werte aus der Tabelle!
- Falls nur die Vorderseite sichtbar ist: Nutze dein internes Wissen über dieses spezifische Produkt für die Nährwerte pro 100g und rechne sie auf die Packungsgröße um.
- Falls keine Grammatur sichtbar ist: Verwende die marktübliche Standard-Packungsgröße (z. B. Standard-Chipstüte = 150g) und markiere sie.

SCHRITT 3: ANALYSE BEI GEKOCHTEM ESSEN / TELLERN:
- Zerlege das Gericht in Einzelzutaten (MealItems) mit geschätztem Gewicht und aggregiere die Gesamtnährwerte.

GIB DAS ERGEBNIS AUSSCHLIESSLICH ALS VALIDES JSON ZURÜCK:
{
  "name": "Exakter Produkt- oder Gerichtsname",
  "weightGrams": 150,
  "calories": 795,
  "protein": 8.5,
  "carbs": 81.0,
  "fat": 48.0,
  "healthScore": 3,
  "healthCategory": "Fast Food / Cheat",
  "healthReason": "Hoher Fett- und Salzgehalt, geringe Mikronährstoffdichte",
  "items": [
    {
      "name": "Komponente 1",
      "weightGrams": 150,
      "calories": 795,
      "protein": 8.5,
      "carbs": 81.0,
      "fat": 48.0
    }
  ]
}''';

  /// Bereitet das Bild vor (Komprimierung auf max. 768px Dimension für schnelle Inferenz).
  static Uint8List preprocessImage(Uint8List rawBytes, {int maxDimension = 768}) {
    try {
      final image = img.decodeImage(rawBytes);
      if (image == null) return rawBytes;

      if (image.width <= maxDimension && image.height <= maxDimension) {
        return rawBytes;
      }

      final img.Image resized;
      if (image.width >= image.height) {
        final targetHeight = (image.height * maxDimension / image.width).round();
        resized = img.copyResize(image, width: maxDimension, height: targetHeight);
      } else {
        final targetWidth = (image.width * maxDimension / image.height).round();
        resized = img.copyResize(image, width: targetWidth, height: maxDimension);
      }

      return Uint8List.fromList(img.encodeJpg(resized, quality: 85));
    } catch (e) {
      debugPrint('[LocalVisionService] Bildvorbereitung Fehler: $e');
      return rawBytes;
    }
  }

  /// Analysiert ein Foto einer Mahlzeit vollständig offline und on-device.
  /// Gibt ein editierbares MealEntry zurück.
  Future<MealEntry> analyzeFoodImage(dynamic imageInput) async {
    final String imagePath;
    if (imageInput is File) {
      imagePath = imageInput.path;
    } else if (imageInput is String) {
      imagePath = imageInput;
    } else {
      throw ArgumentError(
          'Ungültige Eingabe für analyzeFoodImage: $imageInput (erwartet File oder String)');
    }

    final file = File(imagePath);
    if (!await file.exists()) {
      throw FileSystemException('Bilddatei existiert nicht', imagePath);
    }

    final rawBytes = await file.readAsBytes();
    if (rawBytes.isEmpty) {
      throw const FormatException('Das aufgenommene Bild ist leer.');
    }

    // 1. Primär: Native Inferenz via MethodChannel classifyImage
    List<LocalVisionResult> results = [];
    try {
      results = await analyzeImage(imagePath, threshold: 0.10, maxResults: 5);
      if (results.isNotEmpty) {
        final top = results.first;
        if (top.confidence >= 0.10) {
          final candidateLabels = results.map((r) => r.label).toList();
          final matchedRecipe = FoodNutritionEngine.instance.findMatchingRecipe(candidateLabels);
          if (matchedRecipe != null) {
            return FoodNutritionEngine.instance.createMealFromRecipe(
              matchedRecipe,
              imagePath: imagePath,
              confidence: top.confidence,
            );
          }
          return top.toMealEntry(imagePath: imagePath);
        }
      }
    } catch (e) {
      debugPrint('[LocalVisionService] classifyImage Inferenz Exception: $e');
    }

    // 2. Sekundär: analyzeFoodLocal für Rückwärtskompatibilität
    try {
      final res = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'analyzeFoodLocal',
        {'imagePath': imagePath},
      );
      if (res != null) {
        final label = res['label']?.toString() ?? '';
        final confidence = (res['confidence'] as num?)?.toDouble() ?? 0.0;
        final rawCategories = res['categories'] as List<dynamic>?;
        final List<String> detectedLabels = [];
        if (rawCategories != null) {
          for (final c in rawCategories) {
            if (c is Map && c['label'] != null) {
              detectedLabels.add(c['label'].toString());
            }
          }
        }
        if (detectedLabels.isEmpty && label.isNotEmpty) {
          detectedLabels.add(label);
        }

        if (label.isNotEmpty && label.toLowerCase() != 'unrecognized') {
          return createFromCategory(
            label: label,
            confidence: confidence,
            imagePath: imagePath,
            detectedLabels: detectedLabels,
          );
        }
      }
    } catch (e) {
      debugPrint('[LocalVisionService] analyzeFoodLocal nicht verfügbar: $e');
    }

    // 3. Fallback: On-Device OCR & Textanalyse
    await modelManager.prepareModel();
    final modelOutput = await _runOfflineOcrFallback(file);
    final ocrMeal = parseModelOutputToMealEntry(modelOutput, imagePath);

    // Falls OCR ein konkretes Markenprodukt erkannt hat:
    if (ocrMeal.name != unrecognizedMealName) {
      return ocrMeal;
    }

    // Falls LiteRT mindestens ein Ergebnis geliefert hatte, nutzen wir dessen formatiertes Roh-Label
    if (results.isNotEmpty) {
      return results.first.toMealEntry(imagePath: imagePath);
    }

    return ocrMeal;
  }

  /// Lokale OCR-gestützte Produkterkennung als integrierter On-Device-Schutz.
  Future<String> _runOfflineOcrFallback(File imageFile) async {
    final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
    String recognizedText = '';
    try {
      final inputImage = InputImage.fromFile(imageFile);
      final recognized = await textRecognizer.processImage(inputImage);
      recognizedText = recognized.text;
    } catch (e) {
      debugPrint('[LocalVisionService] OCR Erkennung: $e');
    } finally {
      await textRecognizer.close();
    }

    return matchOfflineProductJson(recognizedText);
  }

  /// Gleicht extrahierten OCR-Text mit bekannten Lebensmitteln und Marken ab.
  static String matchOfflineProductJson(String recognizedText) {
    final lower = recognizedText.toLowerCase();

    // Bekannte Lebensmittel / Marken offline abgleichen
    if (lower.contains('monster') || lower.contains('energy')) {
      final isZero = lower.contains('zero') || lower.contains('ultra');
      return jsonEncode({
        "name": isZero ? "Monster Energy Ultra (500ml)" : "Monster Energy (500ml)",
        "weightGrams": 500,
        "amountMl": 500,
        "calories": isZero ? 11 : 237,
        "protein": 0.0,
        "carbs": isZero ? 4.0 : 60.0,
        "fat": 0.0,
        "healthScore": isZero ? 5 : 2,
        "healthCategory": isZero ? "Ausgewogen" : "Fast Food / Cheat",
        "healthReason": isZero ? "Zuckerfrei, enthält Koffein und Taurin." : "Hoher Zuckergehalt und Koffein.",
        "items": [
          {
            "name": isZero ? "Monster Energy Ultra" : "Monster Energy Original",
            "weightGrams": 500,
            "calories": isZero ? 11 : 237,
            "protein": 0.0,
            "carbs": isZero ? 4.0 : 60.0,
            "fat": 0.0
          }
        ]
      });
    }

    if (lower.contains('red bull')) {
      final isSugarfree = lower.contains('sugarfree') || lower.contains('zero');
      return jsonEncode({
        "name": isSugarfree ? "Red Bull Sugarfree (250ml)" : "Red Bull Energy Drink (250ml)",
        "weightGrams": 250,
        "amountMl": 250,
        "calories": isSugarfree ? 8 : 115,
        "protein": 0.0,
        "carbs": isSugarfree ? 0.0 : 27.0,
        "fat": 0.0,
        "healthScore": isSugarfree ? 5 : 2,
        "healthCategory": isSugarfree ? "Ausgewogen" : "Fast Food / Cheat",
        "healthReason": isSugarfree ? "Kalorienfrei mit Koffein." : "Sehr hoher Zuckergehalt.",
        "items": [
          {
            "name": "Red Bull",
            "weightGrams": 250,
            "calories": isSugarfree ? 8 : 115,
            "protein": 0.0,
            "carbs": isSugarfree ? 0.0 : 27.0,
            "fat": 0.0
          }
        ]
      });
    }

    if (lower.contains('kreatin') || lower.contains('creatine')) {
      return jsonEncode({
        "name": "Kreatin Monohydrat (5g)",
        "weightGrams": 5,
        "calories": 0,
        "protein": 0.0,
        "carbs": 0.0,
        "fat": 0.0,
        "healthScore": 10,
        "healthCategory": "Sehr gesund",
        "healthReason": "Reines Kreatin-Monohydrat zur Kraftsteigerung und Regeneration.",
        "items": [
          {
            "name": "Kreatin Monohydrat",
            "weightGrams": 5,
            "calories": 0,
            "protein": 0.0,
            "carbs": 0.0,
            "fat": 0.0
          }
        ]
      });
    }

    if (lower.contains('whey') || lower.contains('protein') || lower.contains('esn')) {
      return jsonEncode({
        "name": "Whey Protein Shake (30g)",
        "weightGrams": 30,
        "calories": 115,
        "protein": 24.0,
        "carbs": 1.5,
        "fat": 1.2,
        "healthScore": 9,
        "healthCategory": "Sehr gesund",
        "healthReason": "Hochwertiges Protein mit optimalem Aminosäureprofil.",
        "items": [
          {
            "name": "Whey Proteinpulver",
            "weightGrams": 30,
            "calories": 115,
            "protein": 24.0,
            "carbs": 1.5,
            "fat": 1.2
          }
        ]
      });
    }

    if (lower.contains('cola') || lower.contains('coca-cola')) {
      final isZero = lower.contains('zero') || lower.contains('light');
      return jsonEncode({
        "name": isZero ? "Coca-Cola Zero (330ml)" : "Coca-Cola Original (330ml)",
        "weightGrams": 330,
        "amountMl": 330,
        "calories": isZero ? 1 : 139,
        "protein": 0.0,
        "carbs": isZero ? 0.0 : 35.0,
        "fat": 0.0,
        "healthScore": isZero ? 6 : 2,
        "healthCategory": isZero ? "Ausgewogen" : "Fast Food / Cheat",
        "healthReason": isZero ? "Zuckerfreies Erfrischungsgetränk." : "Hoher Gehalt an zugesetztem Zucker.",
        "items": [
          {
            "name": isZero ? "Coca-Cola Zero" : "Coca-Cola",
            "weightGrams": 330,
            "calories": isZero ? 1 : 139,
            "protein": 0.0,
            "carbs": isZero ? 0.0 : 35.0,
            "fat": 0.0
          }
        ]
      });
    }

    // Wenn kein bekanntes Markenprodukt oder OCR-Muster gefunden wurde:
    return jsonEncode({
      "name": unrecognizedMealName,
      "weightGrams": 0,
      "calories": 0,
      "protein": 0.0,
      "carbs": 0.0,
      "fat": 0.0,
      "healthScore": null,
      "healthCategory": "Unbekannt",
      "healthReason": "Offline-Scan: Es konnte kein bekanntes Lebensmittel auf dem Bild erkannt werden.",
      "items": []
    });
  }

  MealEntry parseModelOutput(String output, {String? imagePath}) =>
      parseModelOutputToMealEntry(output, imagePath);

  /// Parst einen beliebigen String mit JSON-Inhalt robust in ein `MealEntry`.
  static MealEntry parseModelOutputToMealEntry(String output, [String? localImagePath]) {
    String cleanJson = output.trim();
    if (cleanJson.contains('```json')) {
      cleanJson = cleanJson.split('```json').last.split('```').first;
    } else if (cleanJson.contains('```')) {
      final parts = cleanJson.split('```');
      if (parts.length >= 3 && parts[1].trim().isNotEmpty) {
        cleanJson = parts[1];
      } else {
        cleanJson = cleanJson.split('```').last.split('```').first;
      }
    }
    cleanJson = cleanJson.trim();

    Map<String, dynamic> decoded = {};
    try {
      decoded = jsonDecode(cleanJson) as Map<String, dynamic>;
    } on Object {
      // Kein reines JSON-Objekt → unten per {…}-Extraktion erneut versuchen.
      final startIndex = cleanJson.indexOf('{');
      final endIndex = cleanJson.lastIndexOf('}');
      if (startIndex != -1 && endIndex != -1 && endIndex > startIndex) {
        try {
          final extracted = cleanJson.substring(startIndex, endIndex + 1);
          decoded = jsonDecode(extracted) as Map<String, dynamic>;
        } catch (e) {
          debugPrint('[LocalVisionService] JSON-Extraktion fehlgeschlagen: $e');
        }
      }
    }

    final name = decoded['name']?.toString() ??
        decoded['meal_name']?.toString() ??
        decoded['title']?.toString() ??
        defaultMealName;

    final calories = (parseNutritionValue(decoded['calories']) ??
            parseNutritionValue(decoded['total_calories']) ??
            350.0)
        .round();

    final protein = parseNutritionValue(decoded['protein']) ??
        parseNutritionValue(decoded['total_protein']) ??
        20.0;

    final carbs = parseNutritionValue(decoded['carbs']) ??
        parseNutritionValue(decoded['total_carbs']) ??
        35.0;

    final fat = parseNutritionValue(decoded['fat']) ??
        parseNutritionValue(decoded['total_fat']) ??
        12.0;

    final weightGrams = (parseNutritionValue(decoded['weightGrams']) ??
            parseNutritionValue(decoded['amount_grams']) ??
            parseNutritionValue(decoded['estimatedWeightG']) ??
            250.0)
        .round();

    final amountMl = decoded['amountMl'] != null
        ? (parseNutritionValue(decoded['amountMl']) ?? 0.0).round()
        : null;

    final rawScore = decoded['healthScore'] ?? decoded['health_score'];
    final healthScore = rawScore != null
        ? (parseNutritionValue(rawScore) ?? 7.0).round().clamp(1, 10)
        : null;

    final healthCategory = decoded['healthCategory']?.toString() ??
        decoded['health_category']?.toString();

    final healthReason = decoded['healthReason']?.toString() ??
        decoded['health_reason']?.toString();

    // Items parsen
    final rawItems = (decoded['items'] as List<dynamic>?) ??
        (decoded['components'] as List<dynamic>?) ??
        [];

    final List<MealItem> items = [];
    for (final item in rawItems) {
      if (item is Map) {
        items.add(MealItem.fromMap(Map<String, dynamic>.from(item)));
      }
    }

    // Wenn keine Items vorliegen und Kalorien/Makros vorhanden sind, aggregiertes MealItem erzeugen
    if (items.isEmpty && (calories > 0 || protein > 0 || carbs > 0 || fat > 0)) {
      items.add(
        MealItem(
          name: name,
          estimatedWeightG: weightGrams.toDouble(),
          calories: calories.toDouble(),
          proteinG: protein,
          carbsG: carbs,
          fatG: fat,
        ),
      );
    }

    return MealEntry(
      id: const Uuid().v4(),
      name: name,
      calories: calories,
      protein: protein,
      carbs: carbs,
      fat: fat,
      weightGrams: weightGrams,
      amountMl: amountMl,
      timestamp: DateTime.now(),
      localImagePath: localImagePath,
      items: items,
      healthScore: healthScore,
      healthCategory: healthCategory,
      healthReason: healthReason,
    );
  }

  /// Erstellt einen nicht erkannten MealEntry
  static MealEntry createUnrecognizedMeal({String? imagePath, String? reason}) {
    return MealEntry(
      id: const Uuid().v4(),
      name: unrecognizedMealName,
      calories: 0,
      protein: 0.0,
      carbs: 0.0,
      fat: 0.0,
      weightGrams: 0,
      timestamp: DateTime.now(),
      localImagePath: imagePath,
      items: const [],
      healthCategory: 'Unbekannt',
      healthReason: reason ?? 'Essen/Getränk nicht eindeutig erkannt.',
    );
  }

  /// Erstellt einen MealEntry für Tests oder Vorab-Definitionen.
  static MealEntry createMealEntry({
    required String displayName,
    String? rawLabel,
    double confidence = 1.0,
    bool isRecognized = true,
    String? imagePath,
    int? calories,
    double? protein,
    double? carbs,
    double? fat,
    int? weightGrams,
    int? amountMl,
    int? healthScore,
    String? healthCategory,
    String? healthReason,
    List<MealItem>? items,
  }) {
    final name = isRecognized ? displayName : unrecognizedMealName;
    final finalCalories = isRecognized ? (calories ?? 0) : 0;
    final finalProtein = isRecognized ? (protein ?? 0.0) : 0.0;
    final finalCarbs = isRecognized ? (carbs ?? 0.0) : 0.0;
    final finalFat = isRecognized ? (fat ?? 0.0) : 0.0;

    final finalItems = items ??
        (isRecognized && (finalCalories > 0 || finalProtein > 0 || finalCarbs > 0 || finalFat > 0)
            ? [
                MealItem(
                  name: name,
                  estimatedWeightG: (weightGrams ?? 100).toDouble(),
                  calories: finalCalories.toDouble(),
                  proteinG: finalProtein,
                  carbsG: finalCarbs,
                  fatG: finalFat,
                )
              ]
            : <MealItem>[]);

    return MealEntry(
      id: const Uuid().v4(),
      name: name,
      calories: finalCalories,
      protein: finalProtein,
      carbs: finalCarbs,
      fat: finalFat,
      weightGrams: isRecognized ? weightGrams : 0,
      amountMl: isRecognized ? amountMl : null,
      timestamp: DateTime.now(),
      localImagePath: imagePath,
      items: finalItems,
      healthScore: isRecognized ? healthScore : null,
      healthCategory: isRecognized ? (healthCategory ?? 'Ausgewogen') : 'Unbekannt',
      healthReason: healthReason ??
          (isRecognized
              ? 'Erfolgreich von der lokalen KI erkannt.'
              : 'Konfidenz unter 40 % – Essen/Getränk nicht eindeutig erkannt.'),
    );
  }

  void close() {
    modelManager.releaseModel();
  }
}

/// Typedef für Rückwärtskompatibilität mit früheren Tests und Services
typedef FoodClassifierService = LocalVisionService;
