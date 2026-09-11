import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/meal_entry.dart';
import '../models/meal_item.dart';
import 'scan_review_view.dart';

class ManualEntryView extends StatelessWidget {
  const ManualEntryView({super.key});

  @override
  Widget build(BuildContext context) {
    final emptyMeal = MealEntry(
      id: const Uuid().v4(),
      name: 'Manuelle Mahlzeit',
      timestamp: DateTime.now(),
      calories: 150,
      protein: 10,
      carbs: 15,
      fat: 5,
      items: const [
        MealItem(
          name: 'Zutat 1',
          estimatedWeightG: 100,
          calories: 150,
          proteinG: 10,
          carbsG: 15,
          fatG: 5,
        ),
      ],
      localImagePath: null,
    );

    return ScanReviewView(
      initialMeal: emptyMeal,
      imagePath: null,
    );
  }
}
