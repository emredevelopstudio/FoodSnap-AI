import '../services/gemini_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/daily_goals.dart';
import '../models/user_profile.dart';
import '../services/hive_service.dart';

class DailyGoalsNotifier extends StateNotifier<DailyGoals> {
  DailyGoalsNotifier() : super(HiveService.getDailyGoals());

  Future<void> updateGoals({
    double? targetCalories,
    double? targetProteinG,
    double? targetCarbsG,
    double? targetFatG,
  }) async {
    final updated = state.copyWith(
      targetCalories: targetCalories,
      targetProteinG: targetProteinG,
      targetCarbsG: targetCarbsG,
      targetFatG: targetFatG,
    );
    state = updated;
    await HiveService.saveDailyGoals(updated);
  }
}

final dailyGoalsProvider =
    StateNotifierProvider<DailyGoalsNotifier, DailyGoals>((ref) {
  return DailyGoalsNotifier();
});

class UserProfileNotifier extends StateNotifier<UserProfile> {
  final Ref ref;

  UserProfileNotifier(this.ref) : super(HiveService.getUserProfile());

  Future<void> updateProfile(UserProfile profile,
      {bool applyToGoals = true}) async {
    state = profile;
    await HiveService.saveUserProfile(profile);

    if (applyToGoals) {
      final calculated = profile.calculateTargets();
      await ref.read(dailyGoalsProvider.notifier).updateGoals(
            targetCalories: calculated.calories,
            targetProteinG: calculated.protein,
            targetCarbsG: calculated.carbs,
            targetFatG: calculated.fat,
          );
    }
  }
}

final userProfileProvider =
    StateNotifierProvider<UserProfileNotifier, UserProfile>((ref) {
  return UserProfileNotifier(ref);
});

final geminiApiKeyProvider = StateProvider<String>((ref) {
  return GeminiVisionService.defaultApiKey;
});
