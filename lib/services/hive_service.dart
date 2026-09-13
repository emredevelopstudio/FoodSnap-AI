import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
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
  static const String isDarkModeKey = 'is_dark_mode';
  static const String localeKey = 'app_locale';
  static const String creatineWaterKey = 'creatine_water_ml';

  static Future<void> init() async {
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

  /// Prüft, ob der Nachtmodus aktiv ist.
  /// Falls der Key 'is_dark_mode' noch nie gesetzt wurde, wird der Systemstatus abgefragt
  /// und initial persistent gespeichert, sodass UI-Switch und ThemeMode von Beginn an synchron sind.
  static bool isDarkMode() {
    try {
      final rawDark = _settingsBox.get(isDarkModeKey);
      if (rawDark != null && rawDark['enabled'] != null) {
        return rawDark['enabled'] == true;
      }

      final rawTheme = _settingsBox.get(themeKey);
      if (rawTheme != null && rawTheme['mode'] != null) {
        final modeName = rawTheme['mode'] as String;
        if (modeName == 'dark') return true;
        if (modeName == 'light') return false;
      }

      // Default: Systemstatus des Geräts abfragen
      final systemIsDark =
          WidgetsBinding.instance.platformDispatcher.platformBrightness == Brightness.dark;
      setDarkMode(systemIsDark);
      return systemIsDark;
    } catch (_) {
      return true; // Sicherer Fallback (Dark Theme)
    }
  }

  /// Speichert den Dark-Mode Status persistent in Hive
  static Future<void> setDarkMode(bool isDark) async {
    await _settingsBox.put(isDarkModeKey, {'enabled': isDark});
    await _settingsBox.put(themeKey, {'mode': isDark ? 'dark' : 'light'});
  }

  static Future<void> saveThemeMode(ThemeMode mode) async {
    await setDarkMode(mode == ThemeMode.dark);
  }

  static ThemeMode getThemeMode() {
    return isDarkMode() ? ThemeMode.dark : ThemeMode.light;
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

  static const String isProUserKey = 'is_pro_user';

  static bool getIsProUser() {
    final raw = _settingsBox.get(isProUserKey);
    if (raw != null && raw['is_pro'] != null) {
      return raw['is_pro'] == true;
    }
    return false;
  }

  static Future<void> setIsProUser(bool isPro) async {
    await _settingsBox.put(isProUserKey, {'is_pro': isPro});
  }

  static const int maxFreeDailyScans = 5;
  static const String dailyScansCountKey = 'daily_scans_count';
  static const String dailyScanDateKey = 'daily_scan_date';

  static String _formatIsoDate(DateTime date) =>
      date.toIso8601String().substring(0, 10);

  /// Synchronisiert das Datum und setzt bei Datumswechsel den Zähler auf 0 zurück
  static void _checkAndResetDailyCounter([DateTime? date]) {
    final todayStr = _formatIsoDate(date ?? DateTime.now());
    final savedDate = _settingsBox.get(dailyScanDateKey)?['date'] as String?;
    if (savedDate != todayStr) {
      _settingsBox.put(dailyScanDateKey, {'date': todayStr});
      _settingsBox.put(dailyScansCountKey, {'count': 0});
    }
  }

  static int getDailyScansCount([DateTime? date]) {
    _checkAndResetDailyCounter(date);
    final raw = _settingsBox.get(dailyScansCountKey);
    if (raw != null && raw['count'] != null) {
      return (raw['count'] as num).toInt();
    }
    return 0;
  }

  static Future<void> incrementDailyScansCount([DateTime? date]) async {
    _checkAndResetDailyCounter(date);
    final current = getDailyScansCount(date);
    await _settingsBox.put(dailyScansCountKey, {'count': current + 1});
  }

  static bool hasFreeScansRemaining([DateTime? date]) {
    return getDailyScansCount(date) < maxFreeDailyScans;
  }

  static int getRemainingDailyScans([DateTime? date]) {
    final remaining = maxFreeDailyScans - getDailyScansCount(date);
    return remaining < 0 ? 0 : remaining;
  }

  // Abwärtskompatible Aliase
  static int getTotalScansCount([DateTime? date]) => getDailyScansCount(date);
  static Future<void> incrementTotalScansCount([DateTime? date]) => incrementDailyScansCount(date);
  static int getRemainingFreeScans([DateTime? date]) => getRemainingDailyScans(date);

  static const int dailyFreeScanLimit = 5;
  static Future<void> _scanQueue = Future<void>.value();

  static bool hasDailyScanAvailable(DateTime date) =>
      getDailyScansUsed(date) < dailyFreeScanLimit + getDailyBonusScans(date);

  /// Reserve a scan before the API call; serialize check and write so rapid
  /// requests cannot exceed the daily allowance. Each local date has its own key.
  static Future<bool> tryConsumeDailyScan(DateTime date) {
    final result = _scanQueue.then((_) async {
      if (!hasDailyScanAvailable(date)) return false;
      await incrementDailyScansUsed(date);
      return true;
    });
    _scanQueue = result.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return result;
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
