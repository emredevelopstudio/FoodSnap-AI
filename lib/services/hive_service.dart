import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import '../models/meal_entry.dart';
import '../models/daily_goals.dart';
import '../models/user_profile.dart';
import 'image_storage_service.dart';

class HiveService {
  static const String mealBoxName = 'meals_box';
  static const String settingsBoxName = 'nutritrack_settings';
  static const String goalsKey = 'daily_goals';
  static const String profileKey = 'user_profile';
  static const String themeKey = 'theme_mode';
  static const String localeKey = 'app_locale';
  static const String creatineWaterKey = 'creatine_water_ml';

  static Future<void> init() async {
    final appDir = await getApplicationDocumentsDirectory();
    await Hive.initFlutter(appDir.path);
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(MealEntryAdapter());
    }
    if (!Hive.isBoxOpen(mealBoxName)) {
      await Hive.openBox<MealEntry>(mealBoxName);
    }
    if (!Hive.isBoxOpen(settingsBoxName)) {
      await Hive.openBox<Map>(settingsBoxName);
    }
  }

  static Box<MealEntry> get _mealBox => Hive.box<MealEntry>(mealBoxName);
  static Box<Map> get _settingsBox => Hive.box<Map>(settingsBoxName);

  static Future<void> saveMeal(MealEntry entry) async {
    await _mealBox.put(entry.id, entry);
  }

  static Future<void> deleteMeal(String id) async {
    final meal = _mealBox.get(id);
    final path = meal?.localImagePath ?? meal?.imagePath;
    if (path != null && path.isNotEmpty) {
      await ImageStorageService.deleteImage(path);
    }
    await _mealBox.delete(id);
  }

  static List<MealEntry> getAllMeals() {
    return _mealBox.values.toList();
  }

  static List<MealEntry> getMealsForDate(DateTime date) {
    final all = getAllMeals();
    return all.where((m) =>
        m.timestamp.year == date.year &&
        m.timestamp.month == date.month &&
        m.timestamp.day == date.day).toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }

  static Future<void> saveDailyGoals(DailyGoals goals) async {
    await _settingsBox.put(goalsKey, goals.toMap());
  }

  static DailyGoals getDailyGoals() {
    final raw = _settingsBox.get(goalsKey);
    if (raw != null) {
      return DailyGoals.fromMap(Map<String, dynamic>.from(raw));
    }
    return const DailyGoals();
  }

  static Future<void> saveUserProfile(UserProfile profile) async {
    await _settingsBox.put(profileKey, profile.toMap());
  }

  static UserProfile getUserProfile() {
    final raw = _settingsBox.get(profileKey);
    if (raw != null) {
      return UserProfile.fromMap(Map<String, dynamic>.from(raw));
    }
    return const UserProfile();
  }

  static Future<void> saveThemeMode(ThemeMode mode) async {
    await _settingsBox.put(themeKey, {'mode': mode.name});
  }

  static ThemeMode getThemeMode() {
    final raw = _settingsBox.get(themeKey);
    if (raw != null && raw['mode'] != null) {
      final name = raw['mode'] as String;
      return ThemeMode.values.firstWhere(
        (e) => e.name == name,
        orElse: () => ThemeMode.system,
      );
    }
    return ThemeMode.system;
  }

  static Future<void> saveLocale(Locale locale) async {
    await _settingsBox.put(localeKey, {'languageCode': locale.languageCode});
  }

  static Locale getLocale() {
    final raw = _settingsBox.get(localeKey);
    if (raw != null && raw['languageCode'] != null) {
      final code = raw['languageCode'] as String;
      return Locale(code);
    }
    return const Locale('de');
  }

  static String _creatineDateKey(DateTime date) =>
      'creatine_taken_${date.year}_${date.month.toString().padLeft(2, '0')}_${date.day.toString().padLeft(2, '0')}';

  static bool isCreatineTaken(DateTime date) {
    final key = _creatineDateKey(date);
    final raw = _settingsBox.get(key);
    if (raw != null && raw['taken'] == true) {
      return true;
    }
    return false;
  }

  static Future<void> setCreatineTaken(DateTime date, bool taken) async {
    final key = _creatineDateKey(date);
    await _settingsBox.put(key, {
      'taken': taken,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  static Future<void> saveCreatineWaterMl(int ml) async {
    await _settingsBox.put(creatineWaterKey, {'ml': ml});
  }

  static int getCreatineWaterMl() {
    final raw = _settingsBox.get(creatineWaterKey);
    if (raw != null && raw['ml'] != null) {
      return (raw['ml'] as num).toInt();
    }
    return 150;
  }

  static String _scanDateKey(DateTime date) =>
      'scans_${date.year}_${date.month.toString().padLeft(2, '0')}_${date.day.toString().padLeft(2, '0')}';

  static int getDailyScansUsed(DateTime date) {
    final key = _scanDateKey(date);
    final raw = _settingsBox.get(key);
    if (raw != null && raw['used'] != null) {
      return (raw['used'] as num).toInt();
    }
    return 0;
  }

  static int getDailyBonusScans(DateTime date) {
    final key = _scanDateKey(date);
    final raw = _settingsBox.get(key);
    if (raw != null && raw['bonus'] != null) {
      return (raw['bonus'] as num).toInt();
    }
    return 0;
  }

  static Future<void> incrementDailyScansUsed(DateTime date) async {
    final key = _scanDateKey(date);
    final currentUsed = getDailyScansUsed(date);
    final currentBonus = getDailyBonusScans(date);
    await _settingsBox.put(key, {
      'used': currentUsed + 1,
      'bonus': currentBonus,
    });
  }

  static Future<void> addDailyBonusScan(DateTime date) async {
    final key = _scanDateKey(date);
    final currentUsed = getDailyScansUsed(date);
    final currentBonus = getDailyBonusScans(date);
    await _settingsBox.put(key, {
      'used': currentUsed,
      'bonus': currentBonus + 1,
    });
  }

  static String exportBackupJson() {
    final meals = getAllMeals().map((m) => m.toMap()).toList();
    final goals = getDailyGoals().toMap();
    final profile = getUserProfile().toMap();
    final data = {
      'version': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'meals': meals,
      'goals': goals,
      'profile': profile,
    };
    return const JsonEncoder.withIndent('  ').convert(data);
  }

  static Future<bool> importBackupJson(String jsonString) async {
    try {
      final decoded = jsonDecode(jsonString) as Map<String, dynamic>;
      if (decoded.containsKey('goals')) {
        final goalsMap = Map<String, dynamic>.from(decoded['goals'] as Map);
        await saveDailyGoals(DailyGoals.fromMap(goalsMap));
      }
      if (decoded.containsKey('profile')) {
        final profileMap = Map<String, dynamic>.from(decoded['profile'] as Map);
        await saveUserProfile(UserProfile.fromMap(profileMap));
      }
      if (decoded.containsKey('meals')) {
        final rawMeals = decoded['meals'] as List<dynamic>;
        for (final m in rawMeals) {
          final mealMap = Map<String, dynamic>.from(m as Map);
          final entry = MealEntry.fromMap(mealMap);
          await saveMeal(entry);
        }
      }
      return true;
    } catch (_) {
      return false;
    }
  }
}
