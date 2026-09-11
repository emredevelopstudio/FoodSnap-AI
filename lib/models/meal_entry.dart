import 'package:hive/hive.dart';
import 'meal_item.dart';

class MealEntry extends HiveObject {
  final String id;
  final String name;
  final int calories;
  final double protein;
  final double carbs;
  final double fat;
  final int? amountMl;
  final int? weightGrams;
  final DateTime timestamp;
  final String? localImagePath;
  final List<MealItem> items;
  final int healthScore;
  final String healthCategory;
  final String? healthReason;

  MealEntry({
    required this.id,
    required this.name,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    this.amountMl,
    this.weightGrams,
    required this.timestamp,
    this.localImagePath,
    this.items = const [],
    int? healthScore,
    String? healthCategory,
    this.healthReason,
  })  : healthScore = (healthScore != null && healthScore >= 1 && healthScore <= 10)
            ? healthScore
            : _defaultHealthScore(calories, protein, fat),
        healthCategory = healthCategory ??
            _defaultCategory((healthScore != null && healthScore >= 1 && healthScore <= 10)
                ? healthScore
                : _defaultHealthScore(calories, protein, fat));

  static int _defaultHealthScore(int calories, double protein, double fat) {
    if (calories == 0) return 10;
    if (protein >= 25 && fat <= 20) return 9;
    if (protein >= 20 && fat <= 25) return 8;
    if (fat > 35 || calories > 900) return 4;
    return 7;
  }

  static String _defaultCategory(int score) {
    if (score >= 8) return 'Gesund';
    if (score <= 4) return 'Fast Food / Cheat';
    return 'Ausgewogen';
  }

  String? get imagePath => localImagePath;

  MealEntry copyWith({
    String? id,
    String? name,
    int? calories,
    double? protein,
    double? carbs,
    double? fat,
    int? amountMl,
    int? weightGrams,
    DateTime? timestamp,
    String? localImagePath,
    List<MealItem>? items,
    int? healthScore,
    String? healthCategory,
    String? healthReason,
  }) {
    return MealEntry(
      id: id ?? this.id,
      name: name ?? this.name,
      calories: calories ?? this.calories,
      protein: protein ?? this.protein,
      carbs: carbs ?? this.carbs,
      fat: fat ?? this.fat,
      amountMl: amountMl ?? this.amountMl,
      weightGrams: weightGrams ?? this.weightGrams,
      timestamp: timestamp ?? this.timestamp,
      localImagePath: localImagePath ?? this.localImagePath,
      items: items ?? this.items,
      healthScore: healthScore ?? this.healthScore,
      healthCategory: healthCategory ?? this.healthCategory,
      healthReason: healthReason ?? this.healthReason,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'calories': calories,
      'protein': protein,
      'carbs': carbs,
      'fat': fat,
      'amountMl': amountMl,
      'weightGrams': weightGrams,
      'timestamp': timestamp.toIso8601String(),
      'localImagePath': localImagePath,
      'items': items.map((item) => item.toMap()).toList(),
      'healthScore': healthScore,
      'healthCategory': healthCategory,
      'healthReason': healthReason,
    };
  }

  factory MealEntry.fromMap(Map<String, dynamic> map) {
    final rawItems = map['items'] as List<dynamic>? ?? [];
    final parsedItems = rawItems
        .map((item) => MealItem.fromMap(Map<String, dynamic>.from(item as Map)))
        .toList();

    return MealEntry(
      id: map['id'] as String? ?? '',
      name: map['name'] as String? ?? map['mealName'] as String? ?? 'Mahlzeit',
      calories: (map['calories'] as num?)?.toInt() ?? 
                (map['totalCalories'] as num?)?.toInt() ?? 0,
      protein: (map['protein'] as num?)?.toDouble() ?? 
               (map['totalProteinG'] as num?)?.toDouble() ?? 0.0,
      carbs: (map['carbs'] as num?)?.toDouble() ?? 0.0,
      fat: (map['fat'] as num?)?.toDouble() ?? 0.0,
      amountMl: (map['amountMl'] as num?)?.toInt(),
      weightGrams: (map['weightGrams'] as num?)?.toInt() ?? 
                   (map['weight_grams'] as num?)?.toInt() ??
                   (map['weight'] as num?)?.toInt(),
      timestamp: map['timestamp'] != null
          ? DateTime.parse(map['timestamp'] as String)
          : DateTime.now(),
      localImagePath: map['localImagePath'] as String? ?? map['imagePath'] as String?,
      items: parsedItems,
      healthScore: (map['healthScore'] as num?)?.toInt() ?? 
                   (map['health_score'] as num?)?.toInt(),
      healthCategory: map['healthCategory'] as String? ?? 
                      map['health_category'] as String?,
      healthReason: map['healthReason'] as String? ?? 
                    map['health_reason'] as String?,
    );
  }
}

class MealEntryAdapter extends TypeAdapter<MealEntry> {
  @override
  final int typeId = 0;

  @override
  MealEntry read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return MealEntry(
      id: fields[0] as String,
      name: fields[1] as String,
      calories: fields[2] as int,
      protein: (fields[3] as num).toDouble(),
      carbs: (fields[4] as num).toDouble(),
      fat: (fields[5] as num).toDouble(),
      amountMl: fields[6] as int?,
      timestamp: fields[7] as DateTime,
      localImagePath: fields[8] as String?,
      items: (fields[9] as List?)
              ?.map((e) => MealItem.fromMap(Map<String, dynamic>.from(e as Map)))
              .toList() ??
          const [],
      healthScore: fields[10] as int?,
      healthCategory: fields[11] as String?,
      healthReason: fields[12] as String?,
      weightGrams: fields[13] as int?,
    );
  }

  @override
  void write(BinaryWriter writer, MealEntry obj) {
    writer
      ..writeByte(14)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.calories)
      ..writeByte(3)
      ..write(obj.protein)
      ..writeByte(4)
      ..write(obj.carbs)
      ..writeByte(5)
      ..write(obj.fat)
      ..writeByte(6)
      ..write(obj.amountMl)
      ..writeByte(7)
      ..write(obj.timestamp)
      ..writeByte(8)
      ..write(obj.localImagePath)
      ..writeByte(9)
      ..write(obj.items.map((e) => e.toMap()).toList())
      ..writeByte(10)
      ..write(obj.healthScore)
      ..writeByte(11)
      ..write(obj.healthCategory)
      ..writeByte(12)
      ..write(obj.healthReason)
      ..writeByte(13)
      ..write(obj.weightGrams);
  }
}
