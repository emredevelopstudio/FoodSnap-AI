// ignore_for_file: avoid_print
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../models/meal_entry.dart';
import '../providers/meal_provider.dart';
import '../services/hive_service.dart';
import '../services/image_storage_service.dart';
import '../services/image_mime_type.dart';
import '../services/purchase_service.dart';
import '../services/gemini_service.dart';
import '../widgets/pro_upgrade_sheet.dart';
import '../widgets/meal_card.dart';
import '../widgets/progress_card.dart';
import '../l10n/app_localizations.dart';
import 'manual_entry_view.dart';
import 'scan_review_view.dart';
import 'settings_view.dart';
import 'responsive_scaffold.dart';
import '../providers/fasting_provider.dart';

final _scanInProgressProvider = StateProvider<bool>((ref) => false);

class DashboardView extends ConsumerWidget {
  const DashboardView({super.key});

  Future<void> _pickAndAnalyzeImage(
      BuildContext context, WidgetRef ref, ImageSource source) async {
    final scanInProgress = ref.read(_scanInProgressProvider.notifier);
    if (scanInProgress.state) return;
    scanInProgress.state = true;
    final statusNotifier =
        ValueNotifier<String>('Lebensmittel & Nährwerte werden berechnet');
    DialogRoute<void>? loadingRoute;
    NavigatorState? loadingNavigator;
    void closeLoadingDialog() {
      final route = loadingRoute;
      if (route != null && route.isActive) {
        loadingNavigator?.removeRoute(route);
      }
      loadingRoute = null;
    }

    try {
      if (!PurchaseService.isProUser && !HiveService.hasFreeScansRemaining()) {
        await ProUpgradeSheet.show(
          context,
          customMessage:
              'Du hast dein tägliches Limit von 5 kostenlosen Scans erreicht! Hol dir FoodSnap AI Pro für unbegrenzte Scans und eine 100 % werbefreie Nutzung – oder warte bis morgen.',
        );
        return;
      }
      final picker = ImagePicker();
      final image = await picker.pickImage(
        source: source,
        maxWidth: 720,
        maxHeight: 720,
        imageQuality: 70,
      );
      if (image == null) return;

      print("DEBUG: Bild ausgewählt: ${image.path}");

      final imageBytes = await image.readAsBytes();
      final mimeType = detectImageMimeType(imageBytes, filePath: image.path);

      if (!context.mounted) return;

      final visionService = ref.read(geminiVisionServiceProvider);
      if (!PurchaseService.isProUser && !HiveService.hasFreeScansRemaining()) {
        if (!context.mounted) return;
        await ProUpgradeSheet.show(
          context,
          customMessage:
              'Du hast dein tägliches Limit von 5 kostenlosen Scans erreicht! Hol dir FoodSnap AI Pro für unbegrenzte Scans und eine 100 % werbefreie Nutzung – oder warte bis morgen.',
        );
        return;
      }
      if (!context.mounted) return;
      loadingNavigator = Navigator.of(context, rootNavigator: true);
      loadingRoute = DialogRoute<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => PopScope(
          canPop: false,
          child: Center(
            child: Card(
              margin: const EdgeInsets.all(24),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 20),
                    const Text(
                      'Analysiere Bild...',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 6),
                    ValueListenableBuilder<String>(
                      valueListenable: statusNotifier,
                      builder: (ctx, status, _) => Text(
                        status,
                        style:
                            const TextStyle(fontSize: 12, color: Colors.grey),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      loadingNavigator.push(loadingRoute!);

      final analysisFuture = visionService.analyzeFoodImage(
        imageBytes: imageBytes,
        mimeType: mimeType,
        onStatusUpdate: (newStatus) {
          statusNotifier.value = newStatus;
        },
      );

      final results = await Future.wait([
        analysisFuture,
        ImageStorageService.saveImagePermanently(image.path),
      ]);

      final meal = results[0] as MealEntry;
      final localImagePath = results[1] as String;

      // Jeder erfolgreiche Scan erhöht den Zähler um 1 (nur bei Nicht-Pro-Nutzern)
      if (!PurchaseService.isProUser) {
        await HiveService.incrementDailyScansCount();
      }

      if (!context.mounted) return;
      closeLoadingDialog();

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (ctx) => ScanReviewView(
            initialMeal: meal,
            imagePath: localImagePath,
          ),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      closeLoadingDialog();

      debugPrint('SCAN_ERROR UI: $e');
      final String errorText;
      if (e is ScanRateLimitException) {
        errorText = e.toString();
      } else if (GeminiVisionService.isRateLimitError(e)) {
        errorText = ScanRateLimitException.message;
      } else if (e is ScanAnalysisException) {
        errorText = e.toString();
      } else if (e is FormatException) {
        errorText = e.message;
      } else {
        final raw = e.toString().replaceFirst('Exception: ', '').trim();
        final lower = raw.toLowerCase();
        if (lower.contains('api') ||
            lower.contains('generative') ||
            lower.contains('socket') ||
            lower.contains('http') ||
            lower.contains('client') ||
            lower.contains('server') ||
            lower.contains('longer available') ||
            lower.contains('status code') ||
            lower.contains('failed')) {
          errorText = 'Fehler bei der Analyse. Bitte versuche es erneut.';
        } else {
          errorText = raw.isNotEmpty
              ? raw
              : 'Fehler bei der Analyse. Bitte versuche es erneut.';
        }
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorText),
          backgroundColor: Colors.redAccent,
          duration: const Duration(seconds: 6),
        ),
      );
    } finally {
      closeLoadingDialog();
      statusNotifier.dispose();
      scanInProgress.state = false;
    }
  }

  void _showImageSourceDialog(BuildContext context, WidgetRef ref) {
    if (!PurchaseService.isProUser && !HiveService.hasFreeScansRemaining()) {
      ProUpgradeSheet.show(
        context,
        customMessage:
            'Du hast dein tägliches Limit von 5 kostenlosen Scans erreicht! Hol dir FoodSnap AI Pro für unbegrenzte Scans und eine 100 % werbefreie Nutzung – oder warte bis morgen.',
      );
      return;
    }

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF334155)
                        : const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                child: Text(
                  'Mahlzeit erfassen',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF1E293B),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Option 1: Foto aufnehmen
              ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: isDark
                        ? const Color(0xFF2A2A2A)
                        : const Color(0xFFE2E8F0),
                  ),
                ),
                leading: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.photo_camera_rounded,
                      color: Color(0xFF10B981),
                      size: 22,
                    ),
                  ),
                ),
                title: Text(
                  'Foto aufnehmen',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: isDark ? Colors.white : const Color(0xFF1E293B),
                  ),
                ),
                subtitle: Text(
                  'Mahlzeit live fotografieren',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: isDark
                        ? const Color(0xFF94A3B8)
                        : const Color(0xFF64748B),
                  ),
                ),
                trailing: Icon(
                  Icons.chevron_right_rounded,
                  color: isDark
                      ? const Color(0xFF64748B)
                      : const Color(0xFF94A3B8),
                  size: 22,
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickAndAnalyzeImage(context, ref, ImageSource.camera);
                },
              ),
              const SizedBox(height: 10),
              // Option 2: Aus Album wählen
              ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: isDark
                        ? const Color(0xFF2A2A2A)
                        : const Color(0xFFE2E8F0),
                  ),
                ),
                leading: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: const Color(0xFF3B82F6).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.photo_library_rounded,
                      color: Color(0xFF3B82F6),
                      size: 22,
                    ),
                  ),
                ),
                title: Text(
                  'Aus Album wählen',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: isDark ? Colors.white : const Color(0xFF1E293B),
                  ),
                ),
                subtitle: Text(
                  'Bild aus der Galerie importieren',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: isDark
                        ? const Color(0xFF94A3B8)
                        : const Color(0xFF64748B),
                  ),
                ),
                trailing: Icon(
                  Icons.chevron_right_rounded,
                  color: isDark
                      ? const Color(0xFF64748B)
                      : const Color(0xFF94A3B8),
                  size: 22,
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickAndAnalyzeImage(context, ref, ImageSource.gallery);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPro = ref.watch(premiumProvider);
    debugPrint('[DashboardView] Build aufgerufen - isPro: $isPro');
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final progress = ref.watch(dailyProgressProvider);
    final meals = ref.watch(mealListProvider);
    final selectedDate = ref.watch(selectedDateProvider);

    final scaffoldBg = isDark ? const Color(0xFF121212) : const Color(0xFFFBFBF9);

    return Scaffold(
      backgroundColor: scaffoldBg,
      body: CustomScrollView(
        slivers: [
          // AppBar
          SliverAppBar(
            floating: true,
            pinned: true,
            backgroundColor: scaffoldBg,
            elevation: 0,
            title: Row(
              children: [
                RichText(
                  text: TextSpan(
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.5,
                      color: isDark ? Colors.white : const Color(0xFF64748B),
                    ),
                    children: [
                      const TextSpan(text: 'FoodSnap '),
                      const TextSpan(
                        text: 'AI',
                        style: TextStyle(
                          color: Color(0xFF1E88E5),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (isPro)
                        const WidgetSpan(
                          alignment: PlaceholderAlignment.middle,
                          child: Padding(
                            padding: EdgeInsets.only(left: 6),
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: Color(0xFF10B981),
                                borderRadius: BorderRadius.all(Radius.circular(6)),
                              ),
                              child: Padding(
                                padding: EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                child: Text(
                                  'PRO',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              IconButton(
                icon: const Icon(
                  Icons.calendar_month_outlined,
                  color: Color(0xFF64748B),
                  size: 22,
                ),
                tooltip: 'Datum wählen',
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: selectedDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2030),
                  );
                  if (picked != null) {
                    ref.read(mealListProvider.notifier).setDate(picked);
                  }
                },
              ),
              IconButton(
                icon: const Icon(
                  Icons.settings_outlined,
                  color: Color(0xFF64748B),
                  size: 22,
                ),
                tooltip: context.l10n.settings,
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (ctx) => const SettingsView()),
                  );
                },
              ),
              const SizedBox(width: 4),
            ],
          ),

          // Dashboard Content
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Tagesfortschritt Card
                  ProgressCard(progress: progress),
                  const SizedBox(height: 16),

                  // 2. Action Buttons matching Mockup
                  _buildMockupActionButtons(context, ref, isDark),
                  const SizedBox(height: 12),

                  // 2b. Schneller 1-Klick Creatin-Tracker
                  _CreatineTrackerCard(
                    selectedDate: selectedDate,
                    meals: meals,
                    isDark: isDark,
                  ),
                  const SizedBox(height: 10),

                  // 2c. Intervallfasten-Karte
                  _FastingDashboardCard(isDark: isDark),
                  const SizedBox(height: 22),

                  // 3. Section Title
                  Text(
                    context.l10n.todaysMeals,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.3,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),

          // 4. Meals List
          if (meals.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF3F8).withValues(alpha: isDark ? 0.2 : 0.8),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.no_meals_outlined,
                          size: 42,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        context.l10n.noMealsTracked,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white70 : const Color(0xFF334155),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        context.l10n.noMealsTrackedSub,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final meal = meals[index];
                    return MealCard(
                      meal: meal,
                      onDelete: () {
                        ref.read(mealListProvider.notifier).deleteMeal(meal.id);
                      },
                      onEdit: () => _showEditMealSheet(context, ref, meal),
                      onDuplicate: () => _showDuplicateMealSheet(context, ref, meal),
                    );
                  },
                  childCount: meals.length,
                ),
              ),
            ),
          const SliverToBoxAdapter(
            child: SizedBox(height: 30),
          ),
        ],
      ),
    );
  }

  Widget _buildMockupActionButtons(BuildContext context, WidgetRef ref, bool isDark) {
    final btnBg = isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF1F4F9);
    final borderColor = isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE2E8F0);
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final iconColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569);

    return Row(
      children: [
        // "Mahlzeit scannen" Button
        Expanded(
          flex: 3,
          child: InkWell(
            onTap: () => _showImageSourceDialog(context, ref),
            borderRadius: BorderRadius.circular(14),
            child: Container(
              height: 54,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: btnBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: borderColor),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.camera_alt_outlined,
                    size: 20,
                    color: iconColor,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    context.l10n.scanMeal,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),

        // "Manuell eintragen" Button
        Expanded(
          flex: 2,
          child: InkWell(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (ctx) => const ManualEntryView()),
              );
            },
            borderRadius: BorderRadius.circular(14),
            child: Container(
              height: 54,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: btnBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: borderColor),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.edit_note_outlined,
                    size: 22,
                    color: iconColor,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      context.l10n.manualEntry,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: textColor,
                        height: 1.15,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _showEditMealSheet(BuildContext context, WidgetRef ref, MealEntry meal) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    DateTime selectedTimestamp = meal.timestamp;
    final nameController = TextEditingController(text: meal.name);
    final calController = TextEditingController(text: '${meal.calories}');
    final proteinController = TextEditingController(
      text: meal.protein % 1 == 0 ? '${meal.protein.toInt()}' : '${meal.protein}',
    );
    final carbsController = TextEditingController(
      text: meal.carbs % 1 == 0 ? '${meal.carbs.toInt()}' : '${meal.carbs}',
    );
    final fatController = TextEditingController(
      text: meal.fat % 1 == 0 ? '${meal.fat.toInt()}' : '${meal.fat}',
    );
    final weightGramsController = TextEditingController(
      text: (meal.weightGrams != null && meal.weightGrams! > 0) ? '${meal.weightGrams}' : '',
    );
    final amountMlController = TextEditingController(
      text: (meal.amountMl != null && meal.amountMl! > 0) ? '${meal.amountMl}' : '',
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
            top: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Icon(Icons.edit_note_rounded, color: Color(0xFF10B981), size: 24),
                    const SizedBox(width: 8),
                    Text(
                      'Mahlzeit bearbeiten',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Passe Name, Kalorien, Nährwerte oder Menge nachträglich an.',
                  style: TextStyle(
                    color: isDark ? Colors.white60 : Colors.grey.shade600,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 18),
                TextFormField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: 'Mahlzeit-Name',
                    prefixIcon: const Icon(Icons.restaurant, size: 20),
                    filled: true,
                    fillColor: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Uhrzeit-Auswahl
                InkWell(
                  onTap: () async {
                    final picked = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay(
                        hour: selectedTimestamp.hour,
                        minute: selectedTimestamp.minute,
                      ),
                    );
                    if (picked != null) {
                      setSheetState(() {
                        selectedTimestamp = DateTime(
                          selectedTimestamp.year,
                          selectedTimestamp.month,
                          selectedTimestamp.day,
                          picked.hour,
                          picked.minute,
                        );
                      });
                    }
                  },
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.access_time_rounded, size: 20, color: Color(0xFF10B981)),
                        const SizedBox(width: 12),
                        Text(
                          'Uhrzeit: ',
                          style: TextStyle(
                            fontSize: 15,
                            color: isDark ? Colors.white60 : Colors.grey.shade600,
                          ),
                        ),
                        Text(
                          '${DateFormat('HH:mm').format(selectedTimestamp)} Uhr',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        const Spacer(),
                        Icon(
                          Icons.edit_calendar_rounded,
                          size: 18,
                          color: isDark ? Colors.white54 : Colors.grey.shade500,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: calController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Kalorien',
                          suffixText: 'kcal',
                          prefixIcon: const Icon(Icons.local_fire_department, size: 20, color: Color(0xFF10B981)),
                          filled: true,
                          fillColor: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF8FAFC),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: proteinController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          labelText: 'Protein',
                          suffixText: 'g',
                          prefixIcon: const Icon(Icons.fitness_center, size: 20, color: Color(0xFF3B82F6)),
                          filled: true,
                          fillColor: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF8FAFC),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: carbsController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          labelText: 'Kohlenhydrate',
                          suffixText: 'g',
                          prefixIcon: const Icon(Icons.grain, size: 20, color: Color(0xFFF59E0B)),
                          filled: true,
                          fillColor: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF8FAFC),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: fatController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          labelText: 'Fett',
                          suffixText: 'g',
                          prefixIcon: const Icon(Icons.opacity, size: 20, color: Color(0xFFEF4444)),
                          filled: true,
                          fillColor: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF8FAFC),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: weightGramsController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Gesamtgewicht',
                          suffixText: 'g',
                          prefixIcon: const Icon(Icons.scale, size: 20, color: Color(0xFF8B5CF6)),
                          filled: true,
                          fillColor: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF8FAFC),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: amountMlController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Flüssigkeit',
                          suffixText: 'ml',
                          prefixIcon: const Icon(Icons.water_drop_outlined, size: 20, color: Color(0xFF0284C7)),
                          filled: true,
                          fillColor: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF8FAFC),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF10B981),
                      side: const BorderSide(color: Color(0xFF10B981)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.copy_rounded, size: 18),
                    label: const Text('Kopie für heute / anderen Tag erstellen'),
                    onPressed: () {
                      Navigator.pop(ctx);
                      _showDuplicateMealSheet(context, ref, meal);
                    },
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: Text(
                          'Abbrechen',
                          style: TextStyle(color: isDark ? Colors.white60 : Colors.grey.shade700),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        icon: const Icon(Icons.check),
                        label: const Text('Änderungen speichern'),
                        onPressed: () async {
                          final newName = nameController.text.trim().isEmpty ? meal.name : nameController.text.trim();
                          final newCal = int.tryParse(calController.text.trim()) ?? meal.calories;
                          final newProtein = double.tryParse(proteinController.text.trim().replaceAll(',', '.')) ?? meal.protein;
                          final newCarbs = double.tryParse(carbsController.text.trim().replaceAll(',', '.')) ?? meal.carbs;
                          final newFat = double.tryParse(fatController.text.trim().replaceAll(',', '.')) ?? meal.fat;
                          final newWeight = int.tryParse(weightGramsController.text.trim());
                          final newAmountMl = int.tryParse(amountMlController.text.trim());

                          final updated = meal.copyWith(
                            name: newName,
                            calories: newCal,
                            protein: newProtein,
                            carbs: newCarbs,
                            fat: newFat,
                            weightGrams: (newWeight != null && newWeight > 0) ? newWeight : null,
                            amountMl: (newAmountMl != null && newAmountMl > 0) ? newAmountMl : null,
                            timestamp: selectedTimestamp,
                          );

                          await ref.read(mealListProvider.notifier).updateMeal(updated);

                          if (context.mounted) {
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Mahlzeit erfolgreich aktualisiert'),
                                duration: Duration(seconds: 2),
                              ),
                            );
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
          },
        );
      },
    );
  }

  void _showDuplicateMealSheet(BuildContext context, WidgetRef ref, MealEntry meal) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final selectedDate = ref.read(selectedDateProvider);
    final now = DateTime.now();
    final isSelectedToday = selectedDate.year == now.year &&
        selectedDate.month == now.month &&
        selectedDate.day == now.day;

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.copy_rounded, color: Color(0xFF10B981), size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Mahlzeit übernehmen',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        Text(
                          '${meal.name} • ${meal.calories} kcal',
                          style: const TextStyle(fontSize: 13, color: Colors.grey),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFF10B981),
                  foregroundColor: Colors.white,
                  child: Icon(Icons.today_rounded, size: 20),
                ),
                title: const Text('Für heute übernehmen', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text('Heute, ${DateFormat('dd.MM.yyyy').format(now)} (${DateFormat('HH:mm').format(now)} Uhr)'),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                tileColor: isDark ? const Color(0xFF262626) : const Color(0xFFF8FAFC),
                onTap: () async {
                  Navigator.pop(ctx);
                  await _copyMealToTargetDate(context, ref, meal, now);
                },
              ),
              if (!isSelectedToday) ...[
                const SizedBox(height: 10),
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: const Color(0xFF0284C7).withValues(alpha: 0.15),
                    foregroundColor: const Color(0xFF0284C7),
                    child: const Icon(Icons.event_available_rounded, size: 20),
                  ),
                  title: const Text('Für ausgewähltes Datum übernehmen', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(DateFormat('EEEE, dd.MM.yyyy', 'de_DE').format(selectedDate)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  tileColor: isDark ? const Color(0xFF262626) : const Color(0xFFF8FAFC),
                  onTap: () async {
                    Navigator.pop(ctx);
                    await _copyMealToTargetDate(context, ref, meal, selectedDate);
                  },
                ),
              ],
              const SizedBox(height: 10),
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.grey.withValues(alpha: 0.15),
                  foregroundColor: isDark ? Colors.white70 : Colors.black87,
                  child: const Icon(Icons.calendar_month_outlined, size: 20),
                ),
                title: const Text('Anderes Datum wählen...', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Freie Auswahl im Kalender'),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                tileColor: isDark ? const Color(0xFF262626) : const Color(0xFFF8FAFC),
                onTap: () async {
                  Navigator.pop(ctx);
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: selectedDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2030),
                  );
                  if (picked != null) {
                    if (!context.mounted) return;
                    await _copyMealToTargetDate(context, ref, meal, picked);
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _copyMealToTargetDate(
    BuildContext context,
    WidgetRef ref,
    MealEntry meal,
    DateTime targetDate,
  ) async {
    final now = DateTime.now();
    final newTimestamp = DateTime(
      targetDate.year,
      targetDate.month,
      targetDate.day,
      now.hour,
      now.minute,
      now.second,
    );

    final newEntry = MealEntry(
      id: const Uuid().v4(),
      name: meal.name,
      calories: meal.calories,
      protein: meal.protein,
      carbs: meal.carbs,
      fat: meal.fat,
      amountMl: meal.amountMl,
      weightGrams: meal.weightGrams,
      timestamp: newTimestamp,
      items: List.from(meal.items),
      healthScore: meal.healthScore,
      healthCategory: meal.healthCategory,
      healthReason: meal.healthReason,
      localImagePath: meal.localImagePath,
    );

    await ref.read(mealListProvider.notifier).addMeal(newEntry);
    ref.read(mealListProvider.notifier).setDate(targetDate);
    ref.read(mealListProvider.notifier).loadMeals();
    ref.read(allMealsProvider.notifier).loadAllMeals();

    if (context.mounted) {
      final dateStr = DateFormat('dd.MM.').format(targetDate);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✓ "${meal.name}" für $dateStr hinzugefügt!'),
          backgroundColor: const Color(0xFF10B981),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }
}

class _CreatineTrackerCard extends ConsumerWidget {
  final DateTime selectedDate;
  final List<MealEntry> meals;
  final bool isDark;

  const _CreatineTrackerCard({
    required this.selectedDate,
    required this.meals,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final waterMl = ref.watch(creatineWaterProvider);
    final hasCreatineMeal = meals.any((m) => m.name.toLowerCase().contains('creatin'));
    final isTaken = HiveService.isCreatineTaken(selectedDate) || hasCreatineMeal;

    final cardBg = isTaken
        ? (isDark ? const Color(0xFF064E3B).withValues(alpha: 0.25) : const Color(0xFFECFDF5))
        : (isDark ? const Color(0xFF1E1E1E) : Colors.white);

    final borderColor = isTaken
        ? const Color(0xFF10B981).withValues(alpha: 0.5)
        : (isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE2E8F0));

    return InkWell(
      onTap: () => _toggleCreatine(context, ref, isTaken, hasCreatineMeal),
      onLongPress: () => _showWaterDialog(context, ref, waterMl),
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor, width: isTaken ? 1.2 : 1),
        ),
        child: Row(
          children: [
            // Icon in dezentem Cyan/Blau (oder Emerald wenn eingenommen)
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isTaken
                    ? const Color(0xFF10B981).withValues(alpha: 0.15)
                    : const Color(0xFF0284C7).withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isTaken ? Icons.check_circle_rounded : Icons.fitness_center_rounded,
                size: 20,
                color: isTaken ? const Color(0xFF10B981) : const Color(0xFF0284C7),
              ),
            ),
            const SizedBox(width: 12),

            // Text Label
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    l10n.isEn ? 'Daily Creatine (5g)' : 'Tägliches Creatin (5g)',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isTaken
                        ? (l10n.isEn ? '✓ Taken today • $waterMl ml' : '✓ Heute eingenommen • $waterMl ml')
                        : (l10n.isEn ? '5g powder in $waterMl ml water' : '5g Pulver in $waterMl ml Wasser'),
                    style: TextStyle(
                      fontSize: 11,
                      color: isTaken ? const Color(0xFF059669) : Colors.grey,
                      fontWeight: isTaken ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),

            // Dedicated Edit-Icon for Water ml
            IconButton(
              icon: const Icon(
                Icons.water_drop_outlined,
                size: 20,
                color: Color(0xFF0284C7),
              ),
              tooltip: 'Flüssigkeit anpassen',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: () => _showWaterDialog(context, ref, waterMl),
            ),
            const SizedBox(width: 10),

            // Status-Toggle / Checkbox
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l10n.isEn ? 'Taken today' : 'Heute eingenommen',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: isTaken ? FontWeight.bold : FontWeight.w500,
                    color: isTaken ? const Color(0xFF10B981) : const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(width: 8),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: isTaken ? const Color(0xFF10B981) : Colors.transparent,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isTaken ? const Color(0xFF10B981) : Colors.grey.shade400,
                      width: 1.8,
                    ),
                  ),
                  child: isTaken
                      ? const Icon(Icons.check, size: 14, color: Colors.white)
                      : null,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showWaterDialog(BuildContext context, WidgetRef ref, int currentMl) {
    final controller = TextEditingController(text: '$currentMl');
    final isDarkCard = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: isDarkCard ? const Color(0xFF1E1E1E) : Colors.white,
        title: const Row(
          children: [
            Icon(Icons.water_drop_rounded, color: Color(0xFF0284C7), size: 22),
            SizedBox(width: 8),
            Text(
              'Flüssigkeit anpassen',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Wähle oder tippe die gewünschte Wassermenge (ml) für dein tägliches Creatin ein:',
              style: TextStyle(
                fontSize: 13,
                color: isDarkCard ? Colors.white70 : Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Menge in ml',
                suffixText: 'ml',
                prefixIcon: const Icon(Icons.local_drink_outlined, size: 20, color: Color(0xFF0284C7)),
                filled: true,
                fillColor: isDarkCard ? const Color(0xFF2A2A2A) : const Color(0xFFF1F5F9),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [100, 150, 200, 250, 300].map((ml) {
                return ActionChip(
                  label: Text('$ml ml'),
                  backgroundColor: isDarkCard ? const Color(0xFF2A2A2A) : const Color(0xFFF1F5F9),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide.none,
                  ),
                  onPressed: () {
                    controller.text = '$ml';
                  },
                );
              }).toList(),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Abbrechen',
              style: TextStyle(color: isDarkCard ? Colors.white60 : Colors.grey.shade700),
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              final newMl = int.tryParse(controller.text.trim());
              if (newMl != null && newMl > 0) {
                await ref.read(creatineWaterProvider.notifier).setWaterMl(newMl);
                final creatineEntry =
                    meals.where((m) => m.name.toLowerCase().contains('creatin')).firstOrNull;
                if (creatineEntry != null) {
                  await ref.read(mealListProvider.notifier).updateMeal(creatineEntry.copyWith(amountMl: newMl));
                }
                if (context.mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Creatin-Wassermenge auf $newMl ml angepasst.'),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                }
              }
            },
            child: const Text('Speichern'),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleCreatine(BuildContext context, WidgetRef ref, bool isTaken, bool hasCreatineMeal) async {
    final nextState = !isTaken;
    await HiveService.setCreatineTaken(selectedDate, nextState);

    if (nextState) {
      if (!hasCreatineMeal) {
        final currentWaterMl = ref.read(creatineWaterProvider);
        final creatineMeal = MealEntry(
          id: const Uuid().v4(),
          name: 'Creatin Monohydrat (5g)',
          calories: 0,
          protein: 0,
          carbs: 0,
          fat: 0,
          amountMl: currentWaterMl,
          timestamp: DateTime(selectedDate.year, selectedDate.month, selectedDate.day, 8, 0),
          healthScore: 10,
          healthCategory: 'Gesund',
          healthReason: 'Unterstützt die zelluläre ATP-Regeneration und Kraftleistung.',
        );
        await ref.read(mealListProvider.notifier).addMeal(creatineMeal);
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✓ Creatin (5g) für heute als eingenommen markiert!'),
            backgroundColor: Color(0xFF10B981),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } else {
      final creatineEntry =
          meals.where((m) => m.name.toLowerCase().contains('creatin')).firstOrNull;
      if (creatineEntry != null) {
        await ref.read(mealListProvider.notifier).deleteMeal(creatineEntry.id);
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Creatin-Einnahme für heute zurückgenommen.'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }
}

class _FastingDashboardCard extends ConsumerWidget {
  final bool isDark;

  const _FastingDashboardCard({required this.isDark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fasting = ref.watch(fastingProvider);
    final isActive = fasting.isFasting;

    final cardBg = isActive
        ? (isDark
            ? const Color(0xFF78350F).withValues(alpha: 0.25)
            : const Color(0xFFFFFBEB))
        : (isDark ? const Color(0xFF1E1E1E) : Colors.white);

    final borderColor = isActive
        ? const Color(0xFFF59E0B).withValues(alpha: 0.5)
        : (isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE2E8F0));

    final title =
        'Intervallfasten (${fasting.targetFastingHours}:${fasting.targetEatingHours})';
    final subtitle = isActive
        ? 'Läuft · ${fasting.elapsed.inHours}h ${fasting.elapsed.inMinutes.remainder(60)}m / ${fasting.targetFastingHours}h'
        : 'Nicht aktiv · Tippe zum Starten';

    return InkWell(
      onTap: () {
        ref.read(bottomNavIndexProvider.notifier).state = 2;
      },
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor, width: isActive ? 1.2 : 1),
        ),
        child: Row(
          children: [
            // Icon in Bernstein/Orange
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.hourglass_bottom_rounded,
                color: Color(0xFFF59E0B),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),

            // Textblock
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14.5,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: isActive
                          ? (isDark
                              ? const Color(0xFFFBBF24)
                              : const Color(0xFFD97706))
                          : (isDark
                              ? const Color(0xFF94A3B8)
                              : const Color(0xFF64748B)),
                      fontWeight:
                          isActive ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),

            // Trailing Chevron
            Icon(
              Icons.chevron_right_rounded,
              size: 22,
              color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
            ),
          ],
        ),
      ),
    );
  }
}

