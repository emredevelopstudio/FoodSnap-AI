import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/meal_entry.dart';
import '../models/daily_goals.dart';
import '../models/user_profile.dart';
import '../core/logging/app_log.dart';
import 'image_storage_service.dart';

class HiveService {
  static const String _tag = 'HiveService';
  static const String mealBoxName = 'meals_box';
  static const String settingsBoxName = 'nutritrack_settings';
  static const String goalsKey = 'daily_goals';
  static const String profileKey = 'user_profile';
  static const String themeKey = 'theme_mode';
  static const String isDarkModeKey = 'is_dark_mode';
  static const String localeKey = 'app_locale';
  static const String creatineWaterKey = 'creatine_water_ml';
  static const String fastingBoxName = 'fasting_box';
  static const String purchasesBoxName = 'purchases';
  static const String dailyScansBoxName = 'daily_scans';

  static Future<void> init() async {
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(MealEntryAdapter());
    }
    // 1. settings box
    if (!Hive.isBoxOpen(settingsBoxName)) {
      await Hive.openBox<Map>(settingsBoxName);
    }
    // 2. meals box
    if (!Hive.isBoxOpen(mealBoxName)) {
      await Hive.openBox<MealEntry>(mealBoxName);
    }
    // 3. purchases box
    if (!Hive.isBoxOpen(purchasesBoxName)) {
      await Hive.openBox(purchasesBoxName);
    }
    // 4. daily_scans box
    if (!Hive.isBoxOpen(dailyScansBoxName)) {
      await Hive.openBox(dailyScansBoxName);
    }
    // 5. fasting box
    if (!Hive.isBoxOpen(fastingBoxName)) {
      await Hive.openBox(fastingBoxName);
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
    if (!Hive.isBoxOpen(settingsBoxName)) return const DailyGoals();
    try {
      final raw = _settingsBox.get(goalsKey);
      if (raw != null) {
        return DailyGoals.fromMap(Map<String, dynamic>.from(raw));
      }
    } catch (e, st) {
      AppLog.e(_tag, 'Tagesziele nicht lesbar, nutze Defaults', e, st);
    }
    return const DailyGoals();
  }

  static Future<void> saveUserProfile(UserProfile profile) async {
    await _settingsBox.put(profileKey, profile.toMap());
  }

  static UserProfile getUserProfile() {
    if (!Hive.isBoxOpen(settingsBoxName)) return const UserProfile();
    try {
      final raw = _settingsBox.get(profileKey);
      if (raw != null) {
        return UserProfile.fromMap(Map<String, dynamic>.from(raw));
      }
    } catch (e, st) {
      AppLog.e(_tag, 'Profil nicht lesbar, nutze Defaults', e, st);
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
    } catch (e, st) {
      AppLog.e(_tag, 'Theme-Modus nicht lesbar', e, st);
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
  static const String privacyAcceptedKey = 'has_accepted_privacy_v1';

  static bool hasAcceptedPrivacy() {
    if (!Hive.isBoxOpen(settingsBoxName)) return false;
    try {
      final raw = _settingsBox.get(privacyAcceptedKey);
      if (raw != null && raw['accepted'] != null) {
        return raw['accepted'] == true;
      }
    } catch (e, st) {
      AppLog.e(_tag, 'Datenschutz-Status nicht lesbar', e, st);
    }
    return false;
  }

  static Future<void> setPrivacyAccepted(bool accepted) async {
    await _settingsBox.put(privacyAcceptedKey, {
      'accepted': accepted,
      'value': accepted,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  static bool getIsProUser() {
    if (!Hive.isBoxOpen(settingsBoxName)) return false;
    try {
      final raw = _settingsBox.get(isProUserKey);
      if (raw != null && raw['is_pro'] != null) {
        return raw['is_pro'] == true;
      }
    } catch (e, st) {
      AppLog.e(_tag, 'Pro-Status nicht lesbar', e, st);
    }
    return false;
  }

  static Future<void> setIsProUser(bool isPro) async {
    await _settingsBox.put(isProUserKey, {'is_pro': isPro});
  }

  static const int maxFreeDailyScans = 5;

  // Scan-Zähler: EIN Key pro Kalendertag (scans_JJJJ_MM_TT, siehe _scanDateKey).
  // Ein einziger atomarer Write pro Scan – kein Reset nötig, ein neuer Tag hat einfach
  // einen neuen Key. (Vorher: Datum + Zähler in zwei Keys → bei Abbruch dazwischen
  // stand heutiges Datum mit gestrigem Zählerstand = Sperre bis Mitternacht.)
  static DateTime _day(DateTime? date) => date ?? DateTime.now();

  static int getDailyScansCount([DateTime? date]) {
    if (!Hive.isBoxOpen(settingsBoxName)) return 0;
    try {
      return getDailyScansUsed(_day(date));
    } catch (e, st) {
      AppLog.e(_tag, 'Scan-Zähler nicht lesbar', e, st);
      return 0;
    }
  }

  /// Serialisiert über [_scanQueue], damit parallele Aufrufe keinen Zählschritt verlieren.
  static Future<void> incrementDailyScansCount([DateTime? date]) {
    final day = _day(date);
    final result = _scanQueue.then((_) => incrementDailyScansUsed(day));
    _scanQueue = result.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return result;
  }

  static bool hasFreeScansRemaining([DateTime? date]) =>
      hasDailyScanAvailable(_day(date));

  static int getRemainingDailyScans([DateTime? date]) {
    final day = _day(date);
    final remaining =
        dailyFreeScanLimit + getDailyBonusScans(day) - getDailyScansUsed(day);
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
    } catch (e, st) {
      AppLog.e(_tag, 'Backup-Import fehlgeschlagen', e, st);
      return false;
    }
  }
}
