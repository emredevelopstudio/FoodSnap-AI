import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/daily_goals.dart';
import '../models/user_profile.dart';
import '../services/hive_service.dart';

class DailyGoalsNotifier extends StateNotifier<DailyGoals> {
  DailyGoalsNotifier() : super(HiveService.getDailyGoals());

  Future<void> updateGoals({double? targetCalories, double? targetProteinG}) async {
    final updated = state.copyWith(
      targetCalories: targetCalories,
      targetProteinG: targetProteinG,
    );
    state = updated;
    await HiveService.saveDailyGoals(updated);
  }
}

final dailyGoalsProvider = StateNotifierProvider<DailyGoalsNotifier, DailyGoals>((ref) {
  return DailyGoalsNotifier();
});

class UserProfileNotifier extends StateNotifier<UserProfile> {
  final Ref ref;

  UserProfileNotifier(this.ref) : super(HiveService.getUserProfile());

  Future<void> updateProfile(UserProfile profile, {bool applyToGoals = true}) async {
    state = profile;
    await HiveService.saveUserProfile(profile);

    if (applyToGoals) {
      final calculated = profile.calculateTargets();
      await ref.read(dailyGoalsProvider.notifier).updateGoals(
            targetCalories: calculated.calories,
            targetProteinG: calculated.protein,
          );
    }
  }
}

final userProfileProvider = StateNotifierProvider<UserProfileNotifier, UserProfile>((ref) {
  return UserProfileNotifier(ref);
});

final geminiApiKeyProvider = StateProvider<String>((ref) {
  return const String.fromEnvironment(
    'GEMINI_API_KEY',
    defaultValue: 'AQ.Ab8RN6IayeGgVKKiGMXoRH2xiVhFt-2ByVx5YSDIZbPqgh0g0A',
  );
});
