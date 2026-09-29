import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/meal_entry.dart';
import '../models/meal_item.dart';

/// Referenz-Profil für ein einzelnes Lebensmittel pro 100g.
class IngredientProfile {
  final String id;
  final String germanName;
  final double caloriesPer100g;
  final double proteinPer100g;
  final double carbsPer100g;
  final double fatPer100g;
  final double defaultServingG;

  const IngredientProfile({
    required this.id,
    required this.germanName,
    required this.caloriesPer100g,
    required this.proteinPer100g,
    required this.carbsPer100g,
    required this.fatPer100g,
    this.defaultServingG = 100.0,
  });

  /// Erzeugt ein konkretes [MealItem] mit der angegebenen Portionsgröße in Gramm.
  MealItem toMealItem([double? weightG]) {
    final actualWeight = weightG ?? defaultServingG;
    final factor = actualWeight / 100.0;
    return MealItem(
      name: germanName,
      estimatedWeightG: actualWeight,
      calories: (caloriesPer100g * factor).roundToDouble(),
      proteinG: ((proteinPer100g * factor) * 10).round() / 10.0,
      carbsG: ((carbsPer100g * factor) * 10).round() / 10.0,
      fatG: ((fatPer100g * factor) * 10).round() / 10.0,
    );
  }
}

/// Repräsentiert eine Zutat innerhalb eines Rezepts mit Standard-Gewicht.
class RecipeComponent {
  final IngredientProfile ingredient;
  final double weightG;

  const RecipeComponent(this.ingredient, this.weightG);

  MealItem toMealItem() => ingredient.toMealItem(weightG);
}

/// Definition eines typischen Alltagsgerichts zur regelbasierten Dekomposition.
class DishRecipe {
  final String id;
  final String germanName;
  final List<String> keywords;
  final List<RecipeComponent> components;
  final int healthScore;
  final String healthCategory;
  final String healthReason;

  const DishRecipe({
    required this.id,
    required this.germanName,
    required this.keywords,
    required this.components,
    this.healthScore = 7,
    this.healthCategory = 'Ausgewogen',
    this.healthReason = 'Lokale Rezeptur-Dekomposition.',
  });
}

/// Lokale Ernährungs- und Dekompositions-Engine für FoodSnap AI.
/// Zerlegt erkannte Bild-Labels in reale Einzelzutaten (MealItems)
/// und berechnet Makronährwerte 100 % offline und ohne API-Credits.
class FoodNutritionEngine {
  FoodNutritionEngine._();
  static final FoodNutritionEngine instance = FoodNutritionEngine._();

  // =========================================================================
  // 1. ZUTATEN-KATALOG (Makronährstoffe pro 100g nach USDA / Nährwerttabellen)
  // =========================================================================
  static const IngredientProfile chickenBreast = IngredientProfile(
    id: 'chicken_breast',
    germanName: 'Hähnchenbrustfilet',
    caloriesPer100g: 110,
    proteinPer100g: 23.0,
    carbsPer100g: 0.0,
    fatPer100g: 1.5,
    defaultServingG: 150,
  );

  static const IngredientProfile beefPatty = IngredientProfile(
    id: 'beef_patty',
    germanName: 'Rinder-Patty',
    caloriesPer100g: 250,
    proteinPer100g: 18.0,
    carbsPer100g: 0.0,
    fatPer100g: 20.0,
    defaultServingG: 125,
  );

  static const IngredientProfile mincedBeef = IngredientProfile(
    id: 'minced_beef',
    germanName: 'Rinderhackfleisch',
    caloriesPer100g: 220,
    proteinPer100g: 20.0,
    carbsPer100g: 0.0,
    fatPer100g: 15.0,
    defaultServingG: 120,
  );

  static const IngredientProfile donerMeat = IngredientProfile(
    id: 'doner_meat',
    germanName: 'Dönerfleisch (Kalb/Hähnchen)',
    caloriesPer100g: 235,
    proteinPer100g: 19.0,
    carbsPer100g: 3.5,
    fatPer100g: 16.0,
    defaultServingG: 150,
  );

  static const IngredientProfile salmonFillet = IngredientProfile(
    id: 'salmon_fillet',
    germanName: 'Lachsfilet gebraten',
    caloriesPer100g: 208,
    proteinPer100g: 20.0,
    carbsPer100g: 0.0,
    fatPer100g: 13.0,
    defaultServingG: 150,
  );

  static const IngredientProfile steakBeef = IngredientProfile(
    id: 'steak_beef',
    germanName: 'Rindersteak (Rumpsteak)',
    caloriesPer100g: 215,
    proteinPer100g: 26.0,
    carbsPer100g: 0.0,
    fatPer100g: 12.0,
    defaultServingG: 200,
  );

  static const IngredientProfile eggs = IngredientProfile(
    id: 'eggs',
    germanName: 'Eier (gekocht / gebraten)',
    caloriesPer100g: 143,
    proteinPer100g: 13.0,
    carbsPer100g: 0.7,
    fatPer100g: 9.5,
    defaultServingG: 120,
  );

  static const IngredientProfile basmatiRice = IngredientProfile(
    id: 'basmati_rice',
    germanName: 'Basmatireis (gekocht)',
    caloriesPer100g: 130,
    proteinPer100g: 2.7,
    carbsPer100g: 28.0,
    fatPer100g: 0.3,
    defaultServingG: 180,
  );

  static const IngredientProfile pastaCooked = IngredientProfile(
    id: 'pasta_cooked',
    germanName: 'Pasta / Spaghetti (gekocht)',
    caloriesPer100g: 158,
    proteinPer100g: 5.8,
    carbsPer100g: 30.5,
    fatPer100g: 0.9,
    defaultServingG: 200,
  );

  static const IngredientProfile potatoesCooked = IngredientProfile(
    id: 'potatoes_cooked',
    germanName: 'Salzkartoffeln',
    caloriesPer100g: 77,
    proteinPer100g: 2.0,
    carbsPer100g: 17.0,
    fatPer100g: 0.1,
    defaultServingG: 200,
  );

  static const IngredientProfile frenchFries = IngredientProfile(
    id: 'french_fries',
    germanName: 'Pommes frites',
    caloriesPer100g: 290,
    proteinPer100g: 3.4,
    carbsPer100g: 38.0,
    fatPer100g: 14.0,
    defaultServingG: 150,
  );

  static const IngredientProfile pizzaDough = IngredientProfile(
    id: 'pizza_dough',
    germanName: 'Pizzateig',
    caloriesPer100g: 260,
    proteinPer100g: 8.0,
    carbsPer100g: 50.0,
    fatPer100g: 2.5,
    defaultServingG: 200,
  );

  static const IngredientProfile burgerBun = IngredientProfile(
    id: 'burger_bun',
    germanName: 'Burgerbrötchen (Bun)',
    caloriesPer100g: 275,
    proteinPer100g: 9.0,
    carbsPer100g: 50.0,
    fatPer100g: 4.2,
    defaultServingG: 80,
  );

  static const IngredientProfile flatbread = IngredientProfile(
    id: 'flatbread',
    germanName: 'Fladenbrot',
    caloriesPer100g: 250,
    proteinPer100g: 8.5,
    carbsPer100g: 48.0,
    fatPer100g: 2.2,
    defaultServingG: 120,
  );

  static const IngredientProfile wholeGrainBread = IngredientProfile(
    id: 'wholegrain_bread',
    germanName: 'Vollkornbrot',
    caloriesPer100g: 220,
    proteinPer100g: 8.0,
    carbsPer100g: 40.0,
    fatPer100g: 1.8,
    defaultServingG: 75,
  );

  static const IngredientProfile rolledOats = IngredientProfile(
    id: 'rolled_oats',
    germanName: 'Haferflocken',
    caloriesPer100g: 370,
    proteinPer100g: 13.5,
    carbsPer100g: 58.7,
    fatPer100g: 7.0,
    defaultServingG: 60,
  );

  static const IngredientProfile mozzarella = IngredientProfile(
    id: 'mozzarella',
    germanName: 'Mozzarella',
    caloriesPer100g: 280,
    proteinPer100g: 20.0,
    carbsPer100g: 1.5,
    fatPer100g: 22.0,
    defaultServingG: 100,
  );

  static const IngredientProfile cheddarCheese = IngredientProfile(
    id: 'cheddar_cheese',
    germanName: 'Cheddar / Schmelzkäse',
    caloriesPer100g: 400,
    proteinPer100g: 25.0,
    carbsPer100g: 1.3,
    fatPer100g: 33.0,
    defaultServingG: 25,
  );

  static const IngredientProfile fetaCheese = IngredientProfile(
    id: 'feta_cheese',
    germanName: 'Feta-Käse',
    caloriesPer100g: 265,
    proteinPer100g: 14.5,
    carbsPer100g: 1.5,
    fatPer100g: 21.5,
    defaultServingG: 80,
  );

  static const IngredientProfile tomatoSauce = IngredientProfile(
    id: 'tomato_sauce',
    germanName: 'Tomatensauce',
    caloriesPer100g: 45,
    proteinPer100g: 1.5,
    carbsPer100g: 8.0,
    fatPer100g: 0.5,
    defaultServingG: 80,
  );

  static const IngredientProfile currySauce = IngredientProfile(
    id: 'curry_sauce',
    germanName: 'Kokos-Currysauce',
    caloriesPer100g: 125,
    proteinPer100g: 2.0,
    carbsPer100g: 7.0,
    fatPer100g: 10.0,
    defaultServingG: 100,
  );

  static const IngredientProfile yogurtSauce = IngredientProfile(
    id: 'yogurt_sauce',
    germanName: 'Kräuter-Joghurtsauce',
    caloriesPer100g: 110,
    proteinPer100g: 3.5,
    carbsPer100g: 5.0,
    fatPer100g: 8.0,
    defaultServingG: 40,
  );

  static const IngredientProfile broccoli = IngredientProfile(
    id: 'broccoli',
    germanName: 'Brokkoli (gedämpft)',
    caloriesPer100g: 35,
    proteinPer100g: 3.0,
    carbsPer100g: 4.5,
    fatPer100g: 0.4,
    defaultServingG: 120,
  );

  static const IngredientProfile mixedSaladGreens = IngredientProfile(
    id: 'salad_greens',
    germanName: 'Frischer Blattsalat & Rohkost',
    caloriesPer100g: 18,
    proteinPer100g: 1.2,
    carbsPer100g: 2.5,
    fatPer100g: 0.2,
    defaultServingG: 100,
  );

  static const IngredientProfile cucumberTomato = IngredientProfile(
    id: 'cucumber_tomato',
    germanName: 'Tomaten & Gurken',
    caloriesPer100g: 16,
    proteinPer100g: 0.8,
    carbsPer100g: 2.8,
    fatPer100g: 0.2,
    defaultServingG: 150,
  );

  static const IngredientProfile berries = IngredientProfile(
    id: 'berries',
    germanName: 'Frische Beeren',
    caloriesPer100g: 50,
    proteinPer100g: 0.9,
    carbsPer100g: 9.5,
    fatPer100g: 0.4,
    defaultServingG: 80,
  );

  static const IngredientProfile milk = IngredientProfile(
    id: 'milk',
    germanName: 'Kuhmilch 1.5%',
    caloriesPer100g: 47,
    proteinPer100g: 3.4,
    carbsPer100g: 4.9,
    fatPer100g: 1.5,
    defaultServingG: 150,
  );

  static const IngredientProfile oliveOil = IngredientProfile(
    id: 'olive_oil',
    germanName: 'Natives Olivenöl',
    caloriesPer100g: 884,
    proteinPer100g: 0.0,
    carbsPer100g: 0.0,
    fatPer100g: 100.0,
    defaultServingG: 10,
  );

  // =========================================================================
  // 2. REZEPTUR-DEKOMPOSITION (Typische Gerichte in Komponenten zerlegt)
  // =========================================================================
  static final List<DishRecipe> recipes = [
    // --- Hähnchen mit Reis & Brokkoli ---
    const DishRecipe(
      id: 'chicken_rice_broccoli',
      germanName: 'Hähnchenbrust mit Reis und Brokkoli',
      keywords: [
        'chicken',
        'rice',
        'broccoli',
        'reis mit hähnchen',
        'hähnchen reis',
        'hühnchen mit reis',
        'chicken bowl',
        'fitness teller',
      ],
      components: [
        RecipeComponent(chickenBreast, 150),
        RecipeComponent(basmatiRice, 180),
        RecipeComponent(broccoli, 120),
      ],
      healthScore: 10,
      healthCategory: 'Sehr gesund',
      healthReason: 'Optimales Fitness-Gericht mit magerem Eiweiß, komplexen Kohlenhydraten und Mikronährstoffen.',
    ),

    // --- Reis mit Hähnchen (Standard) ---
    const DishRecipe(
      id: 'chicken_rice',
      germanName: 'Hähnchenbrust mit Basmatireis',
      keywords: [
        'fried rice',
        'chicken rice',
        'arroz con pollo',
        'hähnchen mit reis',
      ],
      components: [
        RecipeComponent(chickenBreast, 160),
        RecipeComponent(basmatiRice, 200),
      ],
      healthScore: 9,
      healthCategory: 'Sehr gesund',
      healthReason: 'Protein- und kohlenhydratreiche Mahlzeit zur nachhaltigen Energiespeicherung.',
    ),

    // --- Pizza Margherita ---
    const DishRecipe(
      id: 'pizza_margherita',
      germanName: 'Pizza Margherita',
      keywords: [
        'pizza',
        'pizza margherita',
        'chicago-style pizza',
        'cheese pizza',
      ],
      components: [
        RecipeComponent(pizzaDough, 220),
        RecipeComponent(tomatoSauce, 80),
        RecipeComponent(mozzarella, 110),
      ],
      healthScore: 5,
      healthCategory: 'Ausgewogen',
      healthReason: 'Klassische italienische Pizza. Teig liefert Kohlenhydrate, Mozzarella moderates Protein und Fett.',
    ),

    // --- Spaghetti Bolognese ---
    const DishRecipe(
      id: 'pasta_bolognese',
      germanName: 'Spaghetti Bolognese',
      keywords: [
        'spaghetti bolognese',
        'bolognese',
        'pasta',
        'spaghetti',
        'meat sauce',
        'penne',
      ],
      components: [
        RecipeComponent(pastaCooked, 220),
        RecipeComponent(mincedBeef, 120),
        RecipeComponent(tomatoSauce, 100),
      ],
      healthScore: 6,
      healthCategory: 'Ausgewogen',
      healthReason: 'Herzhafter Pasta-Klassiker mit Rinderhackfleisch und Tomatensauce.',
    ),

    // --- Cheeseburger mit Beilage ---
    const DishRecipe(
      id: 'cheeseburger',
      germanName: 'Cheeseburger',
      keywords: [
        'cheeseburger',
        'burger',
        'hamburger',
        'afghani burger',
        'ciabatta bacon cheeseburger',
      ],
      components: [
        RecipeComponent(burgerBun, 80),
        RecipeComponent(beefPatty, 125),
        RecipeComponent(cheddarCheese, 25),
        RecipeComponent(cucumberTomato, 30),
      ],
      healthScore: 4,
      healthCategory: 'Fast Food / Cheat',
      healthReason: 'Sehr eiweißreich durch Rindfleisch, aber erhöhter Fett- und Kaloriengehalt.',
    ),

    // --- Pommes Frites ---
    const DishRecipe(
      id: 'french_fries',
      germanName: 'Portion Pommes frites',
      keywords: [
        'french fries',
        'fries',
        'pommes',
      ],
      components: [
        RecipeComponent(frenchFries, 180),
      ],
      healthScore: 3,
      healthCategory: 'Fast Food / Cheat',
      healthReason: 'Frittierte Kartoffelbeilage mit hohem Fett- und Energiegehalt.',
    ),

    // --- Döner Kebab ---
    const DishRecipe(
      id: 'doner_kebab',
      germanName: 'Döner Kebab im Fladenbrot',
      keywords: [
        'doner',
        'döner',
        'kebab',
        'shawarma',
        'gyro',
        'gyros',
      ],
      components: [
        RecipeComponent(flatbread, 120),
        RecipeComponent(donerMeat, 150),
        RecipeComponent(mixedSaladGreens, 70),
        RecipeComponent(yogurtSauce, 40),
      ],
      healthScore: 6,
      healthCategory: 'Ausgewogen',
      healthReason: 'Gute Kombination aus gegrilltem Fleisch, frischem Salat und Fladenbrot.',
    ),

    // --- Dürüm / Wrap ---
    const DishRecipe(
      id: 'durum_wrap',
      germanName: 'Dürüm Kebab / Wrap',
      keywords: [
        'durum',
        'dürüm',
        'wrap',
        'burrito',
        'fajita',
        'taco',
      ],
      components: [
        RecipeComponent(flatbread, 100),
        RecipeComponent(donerMeat, 140),
        RecipeComponent(mixedSaladGreens, 60),
        RecipeComponent(yogurtSauce, 30),
      ],
      healthScore: 6,
      healthCategory: 'Ausgewogen',
      healthReason: 'Eingerollter Weizen-Wrap mit Fleisch und Salat.',
    ),

    // --- Gemischter Salat / Griechischer Salat ---
    const DishRecipe(
      id: 'greek_salad',
      germanName: 'Griechischer Bauernsalat mit Feta',
      keywords: [
        'greek salad',
        'salad',
        'waldorf salad',
        'sabich salad',
        'caesar salad',
        'bauernsalat',
        'gemischter salat',
      ],
      components: [
        RecipeComponent(cucumberTomato, 200),
        RecipeComponent(fetaCheese, 80),
        RecipeComponent(mixedSaladGreens, 80),
        RecipeComponent(oliveOil, 10),
      ],
      healthScore: 9,
      healthCategory: 'Sehr gesund',
      healthReason: 'Reich an Vitaminen, sekundären Pflanzenstoffen und wertvollem Calcium.',
    ),

    // --- Haferflocken-Frühstück mit Beeren ---
    const DishRecipe(
      id: 'oatmeal_breakfast',
      germanName: 'Haferflocken Porridge mit Beeren',
      keywords: [
        'oatmeal',
        'porridge',
        'haferflocken',
        'müsli',
        'muesli',
        'granola',
        'cereal',
      ],
      components: [
        RecipeComponent(rolledOats, 60),
        RecipeComponent(milk, 150),
        RecipeComponent(berries, 80),
      ],
      healthScore: 10,
      healthCategory: 'Sehr gesund',
      healthReason: 'Hervorragende Quelle für lösliche Ballaststoffe (Beta-Glucan) und langanhaltende Energie.',
    ),

    // --- Rührei mit Vollkornbrot ---
    const DishRecipe(
      id: 'scrambled_eggs',
      germanName: 'Rührei mit Vollkornbrot',
      keywords: [
        'scrambled eggs',
        'eggs benedict',
        'fried egg',
        'omelette',
        'omelet',
        'rührei',
        'spiegelei',
      ],
      components: [
        RecipeComponent(eggs, 130),
        RecipeComponent(wholeGrainBread, 75),
      ],
      healthScore: 9,
      healthCategory: 'Sehr gesund',
      healthReason: 'Klassisches eiweißreiches Frühstück mit vollwertigen Aminosäuren und Ballaststoffen.',
    ),

    // --- Lachsfilet mit Beilage ---
    const DishRecipe(
      id: 'salmon_dish',
      germanName: 'Lachsfilet mit Kartoffeln',
      keywords: [
        'salmon',
        'lachs',
        'fish',
        'seafood',
      ],
      components: [
        RecipeComponent(salmonFillet, 150),
        RecipeComponent(potatoesCooked, 200),
        RecipeComponent(broccoli, 100),
      ],
      healthScore: 10,
      healthCategory: 'Sehr gesund',
      healthReason: 'Wertvolle Omega-3-Fettsäuren, hochwertiges Eiweiß und schonend gegartes Gemüse.',
    ),

    // --- Steak mit Beilage ---
    const DishRecipe(
      id: 'steak_dish',
      germanName: 'Rindersteak mit Kartoffelbeilage',
      keywords: [
        'steak',
        'beefsteak',
        'chicken fried steak',
        'cheesesteak',
        'rumpsteak',
      ],
      components: [
        RecipeComponent(steakBeef, 200),
        RecipeComponent(potatoesCooked, 180),
      ],
      healthScore: 8,
      healthCategory: 'Ausgewogen',
      healthReason: 'Reich an bioverfügbarem Eisen, Zink und hochwertigem Protein.',
    ),

    // --- Hähnchen-Curry ---
    const DishRecipe(
      id: 'chicken_curry',
      germanName: 'Hähnchen-Curry mit Reis',
      keywords: [
        'curry',
        'mutton curry',
        'hainanese curry rice',
        'chicken curry',
      ],
      components: [
        RecipeComponent(chickenBreast, 140),
        RecipeComponent(currySauce, 100),
        RecipeComponent(basmatiRice, 180),
      ],
      healthScore: 8,
      healthCategory: 'Ausgewogen',
      healthReason: 'Würziges Currygericht mit magerem Geflügel und Kurkuma-Gewürzen.',
    ),
  ];

  // =========================================================================
  // 3. MULTI-LABEL- & REZEPTUR-RESOLUTION
  // =========================================================================

  /// Findet das passendste Rezept anhand einer Liste erkannter Labels.
  DishRecipe? findMatchingRecipe(List<String> rawLabels) {
    debugPrint("DEBUG MATCHING LABELS: $rawLabels");
    if (rawLabels.isEmpty) return null;

    final normalized = rawLabels
        .map((l) => l.trim().toLowerCase().replaceAll('_', ' '))
        .toList();

    // 1. Suche nach Rezepten, bei denen mehrere spezifische Schlüsselwörter vorkommen
    for (final recipe in recipes) {
      int matchCount = 0;
      for (final keyword in recipe.keywords) {
        for (final label in normalized) {
          if (label == keyword || label.contains(keyword) || keyword.contains(label)) {
            matchCount++;
            break;
          }
        }
      }
      if (matchCount >= 2) {
        return recipe;
      }
    }

    // 2. Suche nach Rezepten mit exaktem oder bestem Einzeltreffer
    for (final label in normalized) {
      for (final recipe in recipes) {
        for (final keyword in recipe.keywords) {
          if (label == keyword || label.contains(keyword)) {
            return recipe;
          }
        }
      }
    }

    return null;
  }

  /// Erzeugt aus einem Rezept einen vollständig aggregierten [MealEntry] mit [MealItem]s.
  MealEntry createMealFromRecipe(
    DishRecipe recipe, {
    String? imagePath,
    double confidence = 1.0,
  }) {
    final items = recipe.components.map((c) => c.toMealItem()).toList();

    int totalCalories = 0;
    double totalProtein = 0.0;
    double totalCarbs = 0.0;
    double totalFat = 0.0;
    double totalWeight = 0.0;

    for (final item in items) {
      totalCalories += item.calories.round();
      totalProtein += item.proteinG;
      totalCarbs += item.carbsG;
      totalFat += item.fatG;
      totalWeight += item.estimatedWeightG;
    }

    final confPercent = (confidence * 100).toStringAsFixed(0);
    final reason = '${recipe.healthReason} (Erkannt: $confPercent % Konfidenz. Portionsgrößen geschätzt – frei anpassbar.)';

    return MealEntry(
      id: const Uuid().v4(),
      name: recipe.germanName,
      calories: totalCalories,
      protein: (totalProtein * 10).round() / 10.0,
      carbs: (totalCarbs * 10).round() / 10.0,
      fat: (totalFat * 10).round() / 10.0,
      weightGrams: totalWeight.round(),
      timestamp: DateTime.now(),
      localImagePath: imagePath,
      items: items,
      healthScore: recipe.healthScore,
      healthCategory: recipe.healthCategory,
      healthReason: reason,
    );
  }

  /// Hauptmethode: Verarbeitet eine Liste von Labels (z. B. aus dem MediaPipe MethodChannel)
  /// zu einem dekomponierten [MealEntry].
  MealEntry processDetections({
    required List<String> labels,
    required double confidence,
    String? imagePath,
  }) {
    debugPrint("DEBUG MATCHING LABELS: $labels");
    // 1. Prüfe auf Rezeptur-Treffer (z.B. "chicken", "rice", "pizza", "burger")
    final recipe = findMatchingRecipe(labels);
    if (recipe != null) {
      return createMealFromRecipe(
        recipe,
        imagePath: imagePath,
        confidence: confidence,
      );
    }

    // 2. Fallback: Keine Rezeptur gefunden -> Erzeuge ein geschätztes MealItem
    final primaryLabel = labels.isNotEmpty ? labels.first : 'Mahlzeit';
    final cleanLabel = primaryLabel.replaceAll('_', ' ').trim();
    final displayName = cleanLabel.isNotEmpty
        ? cleanLabel[0].toUpperCase() + (cleanLabel.length > 1 ? cleanLabel.substring(1) : '')
        : 'Mahlzeit';

    final singleItem = MealItem(
      name: displayName,
      estimatedWeightG: 200.0,
      calories: 250.0,
      proteinG: 14.0,
      carbsG: 28.0,
      fatG: 9.0,
    );

    return MealEntry(
      id: const Uuid().v4(),
      name: displayName,
      calories: 250,
      protein: 14.0,
      carbs: 28.0,
      fat: 9.0,
      weightGrams: 200,
      timestamp: DateTime.now(),
      localImagePath: imagePath,
      items: [singleItem],
      healthScore: 7,
      healthCategory: 'Ausgewogen',
      healthReason: 'Automatische Nährwertschätzung für "$displayName" (${(confidence * 100).toStringAsFixed(0)} % Konfidenz). Bitte passe die Zutaten und Mengen bei Bedarf an.',
    );
  }
}

