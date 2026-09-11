import 'meal_item.dart';

class Meal {
  final String id;
  final String mealName;
  final DateTime timestamp;
  final List<MealItem> items;
  final double totalCalories;
  final double totalProteinG;
  final String? imagePath;

  const Meal({
    required this.id,
    required this.mealName,
    required this.timestamp,
    required this.items,
    required this.totalCalories,
    required this.totalProteinG,
    this.imagePath,
  });

  Meal copyWith({
    String? id,
    String? mealName,
    DateTime? timestamp,
    List<MealItem>? items,
    double? totalCalories,
    double? totalProteinG,
    String? imagePath,
  }) {
    return Meal(
      id: id ?? this.id,
      mealName: mealName ?? this.mealName,
      timestamp: timestamp ?? this.timestamp,
      items: items ?? this.items,
      totalCalories: totalCalories ?? this.totalCalories,
      totalProteinG: totalProteinG ?? this.totalProteinG,
      imagePath: imagePath ?? this.imagePath,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'mealName': mealName,
      'timestamp': timestamp.toIso8601String(),
      'items': items.map((item) => item.toMap()).toList(),
      'totalCalories': totalCalories,
      'totalProteinG': totalProteinG,
      'imagePath': imagePath,
    };
  }

  factory Meal.fromMap(Map<String, dynamic> map) {
    final rawItems = map['items'] as List<dynamic>? ?? [];
    final parsedItems = rawItems
        .map((item) => MealItem.fromMap(Map<String, dynamic>.from(item as Map)))
        .toList();

    return Meal(
      id: map['id'] as String? ?? '',
      mealName: map['mealName'] as String? ?? 'Mahlzeit',
      timestamp: map['timestamp'] != null
          ? DateTime.parse(map['timestamp'] as String)
          : DateTime.now(),
      items: parsedItems,
      totalCalories: (map['totalCalories'] as num?)?.toDouble() ?? 0.0,
      totalProteinG: (map['totalProteinG'] as num?)?.toDouble() ?? 0.0,
      imagePath: map['imagePath'] as String?,
    );
  }
}

