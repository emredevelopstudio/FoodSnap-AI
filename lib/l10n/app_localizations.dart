import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class AppLocalizations {
  final Locale locale;

  AppLocalizations(this.locale);

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations) ??
        AppLocalizations(const Locale('de'));
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  bool get isEn => locale.languageCode == 'en';

  static final Map<String, Map<String, String>> _localizedValues = {
    'de': {
      // Navigation
      'dashboard': 'Dashboard',
      'meals': 'Mahlzeiten',
      'calculator': 'Rechner',
      'settings': 'Einstellungen',

      // Dashboard
      'daily_progress': 'Tagesfortschritt',
      'scan_meal': 'Mahlzeit scannen',
      'manual_entry': 'Manuell\neintragen',
      'manual_entry_single_line': 'Manuell eintragen',
      'todays_meals': 'Heutige Mahlzeiten',
      'no_meals_tracked': 'Noch keine Mahlzeiten erfasst',
      'no_meals_tracked_sub': 'Scanne dein Essen mit der Kamera oder trage es manuell ein.',
      'creatine_taken': 'Kreatin eingenommen',
      'creatine_track': 'Kreatin tracken',
      'creatine_logged_sub': 'Tägliche Dosis für heute abgehakt',
      'creatine_not_logged_sub': 'Tippe zum schnellen Eintragen (5g)',
      'goal': 'Ziel',
      'fat': 'Fett',
      'carbs': 'Carbs',
      'protein': 'Protein',
      'calories': 'Kalorien',
      'kcal': 'kcal',

      // Mahlzeiten-Historie
      'meal_history': 'Mahlzeiten-Historie',
      'meal_history_sub': 'Alle getrackten Speisen & Getränke',
      'create_plan': 'Plan erstellen',
      'filter_all': 'Alle',
      'filter_healthy': 'Gesündeste',
      'filter_fastfood': 'Fast Food',
      'filter_high_protein': 'High Protein',
      'no_meals_saved': 'Noch keine Mahlzeiten gespeichert',
      'no_meals_saved_sub': 'Tippe auf das Plus oder scann ein Foto, um deine erste Mahlzeit einzutragen.',
      'delete_meal': 'Mahlzeit löschen?',
      'delete_meal_confirm': 'Möchtest du diese Mahlzeit wirklich entfernen?',
      'delete': 'Löschen',
      'cancel': 'Abbrechen',
      'save': 'Speichern',
      'edit_meal': 'Mahlzeit bearbeiten',
      'add_meal': 'Mahlzeit hinzufügen',
      'meal_name': 'Name der Mahlzeit',
      'weight_grams': 'Gesamtgewicht (g)',
      'weight_grams_hint': 'z. B. 250 g',

      // Rechner
      'calc_title': 'Kalorienbedarfs-Rechner',
      'daily_requirement': 'Dein Tagesbedarf',
      'apply_as_goal': 'Als Tagesziel übernehmen',
      'goal_applied': 'Als Tagesziel übernommen: ',
      'personal_data': 'Persönliche Daten',
      'age': 'Alter',
      'height': 'Größe (cm)',
      'weight': 'Gewicht',
      'gender': 'Geschlecht',
      'male': 'Männlich',
      'female': 'Weiblich',
      'activity_level': 'Aktivitätslevel',
      'activity_sedentary': 'Kaum Bewegung (Bürojob)',
      'activity_light': 'Leichte Aktivität (1-3x Sport/Woche)',
      'activity_moderate': 'Moderate Aktivität (3-5x Sport/Woche)',
      'activity_very': 'Sehr aktiv (6-7x Sport/Woche)',
      'activity_extremely': 'Extrem aktiv (Schwerstarbeit / tägl. hartes Training)',
      'bmr': 'Grundumsatz',
      'tdee': 'Gesamtumsatz',
      'calc_goal': 'Dein Ziel',
      'goal_maintain': 'Gewicht halten',
      'goal_deficit': 'Abnehmen (Defizit)',
      'goal_surplus': 'Muskelaufbau (Überschuss)',

      // Einstellungen
      'appearance': 'Erscheinungsbild',
      'dark_mode': 'Dunkelmodus',
      'dark_theme_active': 'Dark Theme aktiv',
      'light_theme_active': 'Light Theme aktiv',
      'data_management': 'Datenverwaltung',
      'export_backup': 'Daten-Backup exportieren',
      'export_backup_sub': 'Tagebuch & Einstellungen sichern',
      'import_backup': 'Daten-Backup importieren',
      'import_backup_sub': 'Tagebuch aus Backup wiederherstellen',
      'general': 'Allgemein',
      'language_selection': 'Sprachauswahl',
      'app_language': 'App-Sprache',
      'german': 'Deutsch',
      'english': 'English',
      'app_version': 'App-Version',
      'backup_exported': 'Backup exportiert',
      'backup_exported_msg': 'Dein Tagebuch- und Einstellungs-Backup wurde erfolgreich erstellt und in die Zwischenablage kopiert.',
      'backup_imported': 'Backup erfolgreich importiert!',
      'backup_import_error': 'Fehler beim Importieren des Backups. Ungültiges Format.',
      'import_title': 'Backup importieren',
      'import_info': 'Füge die JSON-Backup-Daten hier ein, um deine Mahlzeiten und Ziele wiederherzustellen:',
      'import_btn': 'Importieren',
    },
    'en': {
      // Navigation
      'dashboard': 'Dashboard',
      'meals': 'Meals',
      'calculator': 'Calculator',
      'settings': 'Settings',

      // Dashboard
      'daily_progress': 'Daily Progress',
      'scan_meal': 'Scan Meal',
      'manual_entry': 'Log\nManually',
      'manual_entry_single_line': 'Log Manually',
      'todays_meals': "Today's Meals",
      'no_meals_tracked': 'No meals tracked yet',
      'no_meals_tracked_sub': 'Scan your food with the camera or enter it manually.',
      'creatine_taken': 'Creatine taken',
      'creatine_track': 'Track creatine',
      'creatine_logged_sub': 'Daily dose checked off for today',
      'creatine_not_logged_sub': 'Tap for quick entry (5g)',
      'goal': 'Goal',
      'fat': 'Fat',
      'carbs': 'Carbs',
      'protein': 'Protein',
      'calories': 'Calories',
      'kcal': 'kcal',

      // Mahlzeiten-Historie
      'meal_history': 'Meal History',
      'meal_history_sub': 'All tracked food & drinks',
      'create_plan': 'Generate Plan',
      'filter_all': 'All',
      'filter_healthy': 'Healthiest',
      'filter_fastfood': 'Fast Food',
      'filter_high_protein': 'High Protein',
      'no_meals_saved': 'No meals saved yet',
      'no_meals_saved_sub': 'Tap the plus button or scan a photo to track your first meal.',
      'delete_meal': 'Delete meal?',
      'delete_meal_confirm': 'Are you sure you want to remove this meal?',
      'delete': 'Delete',
      'cancel': 'Cancel',
      'save': 'Save',
      'edit_meal': 'Edit Meal',
      'add_meal': 'Add Meal',
      'meal_name': 'Meal Name',
      'weight_grams': 'Total Weight (g)',
      'weight_grams_hint': 'e.g. 250 g',

      // Rechner
      'calc_title': 'Calorie Calculator',
      'daily_requirement': 'Your Daily Requirement',
      'apply_as_goal': 'Apply as Daily Goal',
      'goal_applied': 'Applied as daily goal: ',
      'personal_data': 'Personal Data',
      'age': 'Age',
      'height': 'Height (cm)',
      'weight': 'Weight',
      'gender': 'Gender',
      'male': 'Male',
      'female': 'Female',
      'activity_level': 'Activity Level',
      'activity_sedentary': 'Sedentary (desk job)',
      'activity_light': 'Light activity (1-3x workout/week)',
      'activity_moderate': 'Moderate activity (3-5x workout/week)',
      'activity_very': 'Very active (6-7x workout/week)',
      'activity_extremely': 'Extremely active (hard manual labor / intense training)',
      'bmr': 'BMR',
      'tdee': 'TDEE',
      'calc_goal': 'Your Goal',
      'goal_maintain': 'Maintain weight',
      'goal_deficit': 'Lose weight (Deficit)',
      'goal_surplus': 'Build muscle (Surplus)',

      // Einstellungen
      'appearance': 'Appearance',
      'dark_mode': 'Dark Mode',
      'dark_theme_active': 'Dark Theme active',
      'light_theme_active': 'Light Theme active',
      'data_management': 'Data Management',
      'export_backup': 'Export Data Backup',
      'export_backup_sub': 'Backup diary & settings',
      'import_backup': 'Import Data Backup',
      'import_backup_sub': 'Restore diary from backup',
      'general': 'General',
      'language_selection': 'Language Selection',
      'app_language': 'App Language',
      'german': 'Deutsch',
      'english': 'English',
      'app_version': 'App Version',
      'backup_exported': 'Backup exported',
      'backup_exported_msg': 'Your diary and settings backup was successfully created and copied to the clipboard.',
      'backup_imported': 'Backup successfully imported!',
      'backup_import_error': 'Failed to import backup. Invalid format.',
      'import_title': 'Import Backup',
      'import_info': 'Paste your JSON backup data here to restore your meals and goals:',
      'import_btn': 'Import',
    },
  };

  String t(String key) {
    final lang = locale.languageCode;
    return _localizedValues[lang]?[key] ?? _localizedValues['de']?[key] ?? key;
  }

  // Getters for frequently used keys
  String get dashboard => t('dashboard');
  String get meals => t('meals');
  String get calculator => t('calculator');
  String get settings => t('settings');

  String get dailyProgress => t('daily_progress');
  String get scanMeal => t('scan_meal');
  String get manualEntry => t('manual_entry');
  String get manualEntrySingleLine => t('manual_entry_single_line');
  String get todaysMeals => t('todays_meals');
  String get noMealsTracked => t('no_meals_tracked');
  String get noMealsTrackedSub => t('no_meals_tracked_sub');
  String get creatineTaken => t('creatine_taken');
  String get creatineTrack => t('creatine_track');
  String get creatineLoggedSub => t('creatine_logged_sub');
  String get creatineNotLoggedSub => t('creatine_not_logged_sub');
  String get goal => t('goal');
  String get fat => t('fat');
  String get carbs => t('carbs');
  String get protein => t('protein');
  String get calories => t('calories');
  String get kcal => t('kcal');

  String get mealHistory => t('meal_history');
  String get mealHistorySub => t('meal_history_sub');
  String get createPlan => t('create_plan');
  String get filterAll => t('filter_all');
  String get filterHealthy => t('filter_healthy');
  String get filterFastfood => t('filter_fastfood');
  String get filterHighProtein => t('filter_high_protein');
  String get noMealsSaved => t('no_meals_saved');
  String get noMealsSavedSub => t('no_meals_saved_sub');
  String get deleteMeal => t('delete_meal');
  String get deleteMealConfirm => t('delete_meal_confirm');
  String get delete => t('delete');
  String get cancel => t('cancel');
  String get save => t('save');
  String get editMeal => t('edit_meal');
  String get addMeal => t('add_meal');
  String get mealName => t('meal_name');
  String get weightGrams => t('weight_grams');
  String get weightGramsHint => t('weight_grams_hint');

  String get calcTitle => t('calc_title');
  String get dailyRequirement => t('daily_requirement');
  String get applyAsGoal => t('apply_as_goal');
  String get goalApplied => t('goal_applied');
  String get personalData => t('personal_data');
  String get age => t('age');
  String get height => t('height');
  String get weight => t('weight');
  String get gender => t('gender');
  String get male => t('male');
  String get female => t('female');
  String get activityLevel => t('activity_level');
  String get activitySedentary => t('activity_sedentary');
  String get activityLight => t('activity_light');
  String get activityModerate => t('activity_moderate');
  String get activityVery => t('activity_very');
  String get activityExtremely => t('activity_extremely');
  String get bmr => t('bmr');
  String get tdee => t('tdee');
  String get calcGoal => t('calc_goal');
  String get goalMaintain => t('goal_maintain');
  String get goalDeficit => t('goal_deficit');
  String get goalSurplus => t('goal_surplus');

  String get appearance => t('appearance');
  String get darkMode => t('dark_mode');
  String get darkThemeActive => t('dark_theme_active');
  String get lightThemeActive => t('light_theme_active');
  String get dataManagement => t('data_management');
  String get exportBackup => t('export_backup');
  String get exportBackupSub => t('export_backup_sub');
  String get importBackup => t('import_backup');
  String get importBackupSub => t('import_backup_sub');
  String get general => t('general');
  String get languageSelection => t('language_selection');
  String get appLanguage => t('app_language');
  String get german => t('german');
  String get english => t('english');
  String get appVersion => t('app_version');
  String get backupExported => t('backup_exported');
  String get backupExportedMsg => t('backup_exported_msg');
  String get backupImported => t('backup_imported');
  String get backupImportError => t('backup_import_error');
  String get importTitle => t('import_title');
  String get importInfo => t('import_info');
  String get importBtn => t('import_btn');
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => ['de', 'en'].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(AppLocalizations(locale));
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

extension AppLocalizationsX on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}

