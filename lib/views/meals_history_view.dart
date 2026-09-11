import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../models/meal_entry.dart';
import '../providers/goals_provider.dart';
import '../providers/meal_provider.dart';
import '../widgets/app_native_ad_card.dart';
import '../l10n/app_localizations.dart';

class MealsHistoryView extends ConsumerStatefulWidget {
  const MealsHistoryView({super.key});

  @override
  ConsumerState<MealsHistoryView> createState() => _MealsHistoryViewState();
}

class _MealsHistoryViewState extends ConsumerState<MealsHistoryView> {
  int _selectedFilterIndex = 0; // 0: Alle, 1: Gesündeste, 2: Fast Food, 3: High Protein
  bool _filterByDate = true;

  List<String> _getFilters(AppLocalizations l10n) => [
    l10n.filterAll,
    l10n.isEn ? 'Healthiest (★ 8+)' : 'Gesündeste (★ 8+)',
    'Fast Food / Junk',
    'High Protein',
  ];

  static String _formatVolume(int ml) {
    if (ml >= 1000) {
      final liters = ml / 1000.0;
      return '${liters.toStringAsFixed(1)} L';
    }
    return '$ml ml';
  }

  @override
  Widget build(BuildContext context) {
    final allMeals = ref.watch(allMealsProvider);
    final selectedDate = ref.watch(selectedDateProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = context.l10n;

    final dateFilteredMeals = _filterByDate
        ? allMeals.where((m) =>
            m.timestamp.year == selectedDate.year &&
            m.timestamp.month == selectedDate.month &&
            m.timestamp.day == selectedDate.day).toList()
        : allMeals;

    final filteredMeals = _applyFilter(dateFilteredMeals);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.mealHistory,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            Text(
              _filterByDate
                  ? DateFormat('EEEE, d. MMMM', l10n.isEn ? 'en_US' : 'de_DE').format(selectedDate)
                  : l10n.mealHistorySub,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        elevation: 0,
        backgroundColor: isDark ? const Color(0xFF121212) : Colors.white,
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
                setState(() => _filterByDate = true);
                ref.read(mealListProvider.notifier).setDate(picked);
              }
            },
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.auto_awesome_rounded, size: 16),
              label: Text(
                l10n.createPlan,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
              onPressed: () => _generateAndShowMealPlan(context, ref, allMeals),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildDateSelectorBar(context, ref, selectedDate, isDark, l10n),
          _buildMealPlanBanner(context, ref, allMeals, isDark, l10n),
          _buildFilterChips(isDark, dateFilteredMeals.length, filteredMeals.length, l10n),
          Expanded(
            child: allMeals.isEmpty
                ? _buildEmptyState(context, isDark, l10n)
                : filteredMeals.isEmpty
                    ? _buildNoFilterResults(isDark, l10n, selectedDate)
                    : _buildGroupedList(context, ref, filteredMeals, isDark),
          ),
        ],
      ),
    );
  }

  Widget _buildDateSelectorBar(
    BuildContext context,
    WidgetRef ref,
    DateTime selectedDate,
    bool isDark,
    AppLocalizations l10n,
  ) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final isToday = selectedDate.year == today.year &&
        selectedDate.month == today.month &&
        selectedDate.day == today.day;

    String dateText;
    if (!_filterByDate) {
      dateText = l10n.isEn ? 'All dates (History)' : 'Alle Tage (Gesamthistorie)';
    } else if (isToday) {
      dateText = '${l10n.isEn ? 'Today' : 'Heute'}, ${DateFormat('d. MMMM', l10n.isEn ? 'en_US' : 'de_DE').format(selectedDate)}';
    } else {
      dateText = DateFormat('EEEE, d. MMMM yyyy', l10n.isEn ? 'en_US' : 'de_DE').format(selectedDate);
    }

    return Container(
      color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          if (_filterByDate)
            IconButton(
              icon: const Icon(Icons.chevron_left_rounded, size: 24),
              tooltip: l10n.isEn ? 'Previous day' : 'Vorheriger Tag',
              onPressed: () {
                final prev = selectedDate.subtract(const Duration(days: 1));
                ref.read(mealListProvider.notifier).setDate(prev);
              },
            ),
          Expanded(
            child: InkWell(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: selectedDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2030),
                );
                if (picked != null) {
                  setState(() => _filterByDate = true);
                  ref.read(mealListProvider.notifier).setDate(picked);
                }
              },
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _filterByDate ? Icons.calendar_today_rounded : Icons.history_rounded,
                      size: 16,
                      color: const Color(0xFF10B981),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        dateText,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.arrow_drop_down_rounded,
                      size: 20,
                      color: isDark ? Colors.white60 : Colors.grey.shade600,
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_filterByDate)
            IconButton(
              icon: const Icon(Icons.chevron_right_rounded, size: 24),
              tooltip: l10n.isEn ? 'Next day' : 'Nächster Tag',
              onPressed: () {
                final next = selectedDate.add(const Duration(days: 1));
                ref.read(mealListProvider.notifier).setDate(next);
              },
            ),
          TextButton(
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: const Size(0, 32),
            ),
            onPressed: () {
              setState(() => _filterByDate = !_filterByDate);
            },
            child: Text(
              _filterByDate ? (l10n.isEn ? 'All' : 'Alle') : (l10n.isEn ? 'Filter' : 'Nach Datum'),
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMealPlanBanner(
    BuildContext context,
    WidgetRef ref,
    List<MealEntry> meals,
    bool isDark,
    AppLocalizations l10n,
  ) {
    return Container(
      color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
      child: InkWell(
        onTap: () => _generateAndShowMealPlan(context, ref, meals),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDark
                  ? [const Color(0xFF064E3B), const Color(0xFF065F46)]
                  : [const Color(0xFFECFDF5), const Color(0xFFD1FAE5)],
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: const Color(0xFF10B981).withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.isEn ? 'Create daily plan from my meals' : 'Tagesplan aus meinen Mahlzeiten erstellen',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13.5,
                        color: isDark ? Colors.white : const Color(0xFF065F46),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      l10n.isEn ? 'Optimal combination for your daily goal' : 'Optimale Kombination für dein Tagesziel aus deinen Einträgen',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? const Color(0xFFA7F3D0) : const Color(0xFF047857),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Color(0xFF10B981)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChips(bool isDark, int totalCount, int filteredCount, AppLocalizations l10n) {
    final filters = _getFilters(l10n);
    return Container(
      color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: List.generate(filters.length, (index) {
            final isSelected = _selectedFilterIndex == index;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                selected: isSelected,
                label: Text(filters[index]),
                avatar: index == 1
                    ? const Icon(Icons.star_rounded, size: 16, color: Color(0xFF10B981))
                    : index == 2
                        ? const Icon(Icons.fastfood_outlined, size: 16, color: Color(0xFFEF4444))
                        : index == 3
                            ? const Icon(Icons.fitness_center, size: 16, color: Color(0xFF3B82F6))
                            : null,
                labelStyle: TextStyle(
                  color: isSelected
                      ? Colors.white
                      : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569)),
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  fontSize: 13,
                ),
                selectedColor: const Color(0xFF10B981),
                backgroundColor: isDark ? const Color(0xFF262626) : const Color(0xFFF1F5F9),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                side: BorderSide.none,
                onSelected: (selected) {
                  if (selected) {
                    setState(() => _selectedFilterIndex = index);
                  }
                },
              ),
            );
          }),
        ),
      ),
    );
  }

  List<MealEntry> _applyFilter(List<MealEntry> meals) {
    switch (_selectedFilterIndex) {
      case 1: // Gesündeste (★ 8+)
        return meals.where((m) => m.healthScore >= 8).toList()
          ..sort((a, b) => b.healthScore.compareTo(a.healthScore));
      case 2: // Fast Food / Junk
        return meals.where((m) {
          final cat = m.healthCategory.toLowerCase();
          return m.healthScore <= 4 ||
              cat.contains('fast food') ||
              cat.contains('cheat') ||
              cat.contains('junk') ||
              cat.contains('burger') ||
              cat.contains('pizza') ||
              cat.contains('döner');
        }).toList();
      case 3: // High Protein (mind. 25g oder >= 25% Protein-Kalorien)
        return meals.where((m) => m.protein >= 25).toList()
          ..sort((a, b) => b.protein.compareTo(a.protein));
      default:
        return meals;
    }
  }

  Widget _buildEmptyState(BuildContext context, bool isDark, AppLocalizations l10n) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF1F5F9),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.restaurant_menu_rounded,
                size: 64,
                color: Color(0xFF94A3B8),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              l10n.noMealsSaved,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              l10n.isEn
                  ? 'Scan meals with the camera or log them manually on the dashboard.'
                  : 'Scanne Mahlzeiten mit der Kamera oder trage sie manuell auf dem Dashboard ein.',
              style: const TextStyle(color: Colors.grey, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            const AppNativeAdCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildNoFilterResults(bool isDark, AppLocalizations l10n, DateTime selectedDate) {
    if (_filterByDate && _selectedFilterIndex == 0) {
      final formatted = DateFormat('d. MMMM yyyy', l10n.isEn ? 'en_US' : 'de_DE').format(selectedDate);
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.calendar_today_outlined, size: 54, color: Colors.grey.shade400),
              const SizedBox(height: 16),
              Text(
                'Keine Mahlzeiten für $formatted',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'Du kannst Mahlzeiten von anderen Tagen mit dem Kopieren-Icon hierher übernehmen oder nach weiteren Tagen filtern.',
                style: TextStyle(color: Colors.grey, fontSize: 13),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 14),
              TextButton.icon(
                icon: const Icon(Icons.history_rounded),
                onPressed: () => setState(() => _filterByDate = false),
                label: const Text('Alle Tage anzeigen'),
              ),
            ],
          ),
        ),
      );
    }

    final filterName = _getFilters(l10n)[_selectedFilterIndex];
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.filter_alt_off_outlined, size: 54, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              l10n.isEn ? 'No meals found for "$filterName"' : 'Keine Mahlzeiten für "$filterName" gefunden',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => setState(() => _selectedFilterIndex = 0),
              child: Text(l10n.isEn ? 'Show all meals' : 'Alle Mahlzeiten anzeigen'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupedList(
    BuildContext context,
    WidgetRef ref,
    List<MealEntry> meals,
    bool isDark,
  ) {
    final Map<DateTime, List<MealEntry>> grouped = {};
    for (final meal in meals) {
      final dayKey = DateTime(meal.timestamp.year, meal.timestamp.month, meal.timestamp.day);
      grouped.putIfAbsent(dayKey, () => []).add(meal);
    }

    final sortedDays = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: sortedDays.length + 1,
      itemBuilder: (context, index) {
        if (index == 1) {
          return const AppNativeAdCard();
        }
        final dayIndex = index > 1 ? index - 1 : index;
        final day = sortedDays[dayIndex];
        final dayMeals = grouped[day]!..sort((a, b) => b.timestamp.compareTo(a.timestamp));

        int dayCalories = 0;
        double dayProtein = 0;
        double dayCarbs = 0;
        double dayFat = 0;
        for (final m in dayMeals) {
          dayCalories += m.calories;
          dayProtein += m.protein;
          dayCarbs += m.carbs;
          dayFat += m.fat;
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDateHeader(day, dayCalories, dayProtein, dayCarbs, dayFat, isDark),
            const SizedBox(height: 8),
            ...dayMeals.map((meal) => _buildMealItemCard(context, ref, meal, isDark)),
            const SizedBox(height: 16),
          ],
        );
      },
    );
  }

  Widget _buildDateHeader(
    DateTime day,
    int calories,
    double protein,
    double carbs,
    double fat,
    bool isDark,
  ) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    String title;
    if (day == today) {
      title = 'Heute (${DateFormat('d. MMMM', 'de_DE').format(day)})';
    } else if (day == yesterday) {
      title = 'Gestern (${DateFormat('d. MMMM', 'de_DE').format(day)})';
    } else {
      title = DateFormat('EEEE, d. MMMM yyyy', 'de_DE').format(day);
    }

    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4, left: 4, right: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Color(0xFF64748B),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF242424) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '$calories kcal • ${protein.round()}g P',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Color(0xFF64748B),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMealItemCard(
    BuildContext context,
    WidgetRef ref,
    MealEntry meal,
    bool isDark,
  ) {
    final timeStr = '${DateFormat('HH:mm').format(meal.timestamp)} Uhr';
    final cardBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final hasWeight = meal.weightGrams != null && meal.weightGrams! > 0;
    final hasMl = meal.amountMl != null && meal.amountMl! > 0;
    final portionStr = hasWeight
        ? '${meal.weightGrams} g'
        : (hasMl ? _formatVolume(meal.amountMl!) : null);

    return Card(
      elevation: 0,
      color: cardBg,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isDark ? Colors.grey.shade800 : const Color(0xFFE2E8F0),
          width: 0.8,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _showEditMealSheet(context, ref, meal),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildThumbnail(meal),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          meal.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          portionStr != null
                              ? '$timeStr • $portionStr • ${meal.calories} kcal'
                              : '$timeStr • ${meal.calories} kcal',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 6),
                        _buildHealthScoreBadge(meal.healthScore, meal.healthCategory),
                      ],
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.copy_rounded, size: 20, color: Color(0xFF10B981)),
                        tooltip: 'Für Tag übernehmen / Duplizieren',
                        onPressed: () => _showDuplicateMealSheet(context, ref, meal),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 20, color: Color(0xFF64748B)),
                        tooltip: 'Mahlzeit anpassen',
                        onPressed: () => _showEditMealSheet(context, ref, meal),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 20, color: Colors.redAccent),
                        tooltip: 'Löschen',
                        onPressed: () => _confirmDelete(context, ref, meal),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  _buildMacroBadge('${meal.calories} kcal', const Color(0xFF10B981)),
                  _buildMacroBadge(
                    '${meal.protein.toStringAsFixed(meal.protein % 1 == 0 ? 0 : 1)}g P',
                    const Color(0xFF3B82F6),
                  ),
                  _buildMacroBadge(
                    '${meal.carbs.toStringAsFixed(meal.carbs % 1 == 0 ? 0 : 1)}g K',
                    const Color(0xFFF59E0B),
                  ),
                  _buildMacroBadge(
                    '${meal.fat.toStringAsFixed(meal.fat % 1 == 0 ? 0 : 1)}g F',
                    const Color(0xFFEF4444),
                  ),
                  if (portionStr != null)
                    _buildMacroBadge(portionStr, const Color(0xFF06B6D4)),
                ],
              ),
              if (meal.healthReason != null && meal.healthReason!.trim().isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF262626) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isDark ? Colors.grey.shade800 : const Color(0xFFE2E8F0),
                      width: 0.6,
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.info_outline, size: 14, color: Color(0xFF64748B)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          meal.healthReason!,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF64748B),
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHealthScoreBadge(int score, String category) {
    Color badgeColor;
    Color textColor;

    if (score >= 8) {
      badgeColor = const Color(0xFF10B981); // Emerald Green
      textColor = const Color(0xFF065F46);
    } else if (score >= 5) {
      badgeColor = const Color(0xFFF59E0B); // Amber Yellow
      textColor = const Color(0xFF92400E);
    } else {
      badgeColor = const Color(0xFFEF4444); // Red
      textColor = const Color(0xFF991B1B);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: badgeColor.withValues(alpha: 0.3), width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.star_rounded, size: 14, color: badgeColor),
          const SizedBox(width: 4),
          Text(
            '★ $score/10 - $category',
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.bold,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMacroBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildThumbnail(MealEntry meal) {
    final imagePath = meal.localImagePath ?? meal.imagePath;
    if (imagePath != null && imagePath.isNotEmpty && File(imagePath).existsSync()) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image(
          image: FileImage(File(imagePath)),
          width: 58,
          height: 58,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _buildFallbackThumbnail(meal),
        ),
      );
    }
    return _buildFallbackThumbnail(meal);
  }

  Widget _buildFallbackThumbnail(MealEntry meal) {
    if (meal.amountMl != null && meal.amountMl! > 0 && (meal.weightGrams == null || meal.weightGrams == 0)) {
      return Container(
        width: 58,
        height: 58,
        decoration: BoxDecoration(
          color: const Color(0xFFE0F2FE),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(
          Icons.water_drop_outlined,
          color: Color(0xFF0284C7),
          size: 26,
        ),
      );
    }
    return Container(
      width: 58,
      height: 58,
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Icon(
        Icons.restaurant_rounded,
        color: Color(0xFF64748B),
        size: 26,
      ),
    );
  }

  void _showEditMealSheet(BuildContext context, WidgetRef ref, MealEntry meal) {
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
    final amountMlController = TextEditingController(
      text: (meal.amountMl != null && meal.amountMl! > 0) ? '${meal.amountMl}' : '',
    );
    final weightGramsController = TextEditingController(
      text: (meal.weightGrams != null && meal.weightGrams! > 0) ? '${meal.weightGrams}' : '',
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
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
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Row(
                      children: [
                        Icon(Icons.tune_rounded, color: Color(0xFF10B981)),
                        SizedBox(width: 8),
                        Text(
                          'Mahlzeit anpassen',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Korrigiere fehlerhafte Erkennungen oder passe Mengen & Nährwerte an.',
                      style: TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: nameController,
                      decoration: InputDecoration(
                        labelText: 'Name der Mahlzeit',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        prefixIcon: const Icon(Icons.fastfood_outlined),
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
                      borderRadius: BorderRadius.circular(12),
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: 'Uhrzeit',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          prefixIcon: const Icon(Icons.access_time_rounded, color: Color(0xFF10B981)),
                          suffixIcon: const Icon(Icons.edit_calendar_rounded, size: 20),
                        ),
                        child: Text(
                          '${DateFormat('HH:mm').format(selectedTimestamp)} Uhr',
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Gesamtgewicht (g)
                    TextFormField(
                      controller: weightGramsController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Gesamtgewicht (g)',
                        hintText: 'z. B. 250 g',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        prefixIcon: const Icon(Icons.scale_outlined, color: Color(0xFF10B981)),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Flüssigkeitsmenge (ml)
                    TextFormField(
                      controller: amountMlController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Menge (ml)',
                        hintText: 'z. B. 500 ml oder 1000 ml (1L)',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        prefixIcon: const Icon(Icons.water_drop_outlined, color: Color(0xFF0284C7)),
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
                              labelText: 'Kalorien (kcal)',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              prefixIcon: const Icon(Icons.local_fire_department_outlined),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: proteinController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: InputDecoration(
                              labelText: 'Protein (g)',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              prefixIcon: const Icon(Icons.fitness_center_outlined),
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
                              labelText: 'Kohlenhydrate (g)',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              prefixIcon: const Icon(Icons.grain_outlined),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: fatController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: InputDecoration(
                              labelText: 'Fett (g)',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              prefixIcon: const Icon(Icons.opacity_outlined),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
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
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('Abbrechen'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF10B981),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            icon: const Icon(Icons.check),
                            label: const Text('Änderungen speichern'),
                            onPressed: () async {
                              final newName = nameController.text.trim().isEmpty
                                  ? meal.name
                                  : nameController.text.trim();
                              final newCal = int.tryParse(calController.text.trim()) ?? meal.calories;
                              final newProtein = double.tryParse(
                                      proteinController.text.trim().replaceAll(',', '.')) ??
                                  meal.protein;
                              final newCarbs = double.tryParse(
                                      carbsController.text.trim().replaceAll(',', '.')) ??
                                  meal.carbs;
                              final newFat =
                                  double.tryParse(fatController.text.trim().replaceAll(',', '.')) ??
                                      meal.fat;
                              final newAmountMl = int.tryParse(amountMlController.text.trim());
                              final newWeightGrams = int.tryParse(weightGramsController.text.trim());

                              final updated = meal.copyWith(
                                name: newName,
                                calories: newCal,
                                protein: newProtein,
                                carbs: newCarbs,
                                fat: newFat,
                                amountMl: (newAmountMl != null && newAmountMl > 0) ? newAmountMl : null,
                                weightGrams: (newWeightGrams != null && newWeightGrams > 0) ? newWeightGrams : null,
                                timestamp: selectedTimestamp,
                              );

                              await ref.read(allMealsProvider.notifier).updateMeal(updated);

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

  void _confirmDelete(BuildContext context, WidgetRef ref, MealEntry meal) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Mahlzeit löschen?'),
        content: Text('Möchtest du "${meal.name}" wirklich unwiderruflich löschen?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(allMealsProvider.notifier).deleteMeal(meal.id);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('"${meal.name}" gelöscht'),
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
            },
            child: const Text('Löschen'),
          ),
        ],
      ),
    );
  }

  // --- Intelligenter Tagesplan-Generator (ausschließlich eigene gescannte Mahlzeiten) ---
  void _generateAndShowMealPlan(BuildContext context, WidgetRef ref, List<MealEntry> allMeals) {
    final goals = ref.read(dailyGoalsProvider);
    final targetCal = goals.targetCalories > 0 ? goals.targetCalories : 2000.0;
    final targetProt = goals.targetProteinG > 0 ? goals.targetProteinG : 140.0;

    // 1. Eindeutige verschiedene Mahlzeiten des Nutzers ermitteln
    final Map<String, MealEntry> uniqueMealsMap = {};
    for (final m in allMeals) {
      final key = m.name.trim().toLowerCase();
      if (!uniqueMealsMap.containsKey(key)) {
        uniqueMealsMap[key] = m;
      }
    }
    final distinctMeals = uniqueMealsMap.values.toList();

    // 2. Mindestanforderung prüfen: Mindestens 3 verschiedene Mahlzeiten erforderlich
    if (distinctMeals.length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Scanne noch mindestens 3–4 Mahlzeiten ein, damit die App daraus einen Tagesplan zusammenstellen kann.',
          ),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 4),
        ),
      );
      return;
    }

    // 3. Filter & Gewichtung: Bevorzuge Mahlzeiten mit Health-Score >= 6 und gutem Protein-Verhältnis
    var candidates = distinctMeals.where((m) => m.healthScore >= 6 && m.calories > 40).toList();

    // Falls weniger als 3 gesunde Mahlzeiten vorhanden sind, mit restlichen Mahlzeiten auffüllen
    if (candidates.length < 3) {
      final remaining = distinctMeals.where((m) => !candidates.contains(m)).toList()
        ..sort((a, b) => b.healthScore.compareTo(a.healthScore));
      candidates.addAll(remaining);
    }

    // Sortierung nach Qualität: Health-Score + Protein-Dichte
    candidates.sort((a, b) {
      final aProtRatio = a.calories > 0 ? (a.protein * 4.0) / a.calories : 0.0;
      final bProtRatio = b.calories > 0 ? (b.protein * 4.0) / b.calories : 0.0;
      final aScore = (a.healthScore * 10) + (aProtRatio * 50);
      final bScore = (b.healthScore * 10) + (bProtRatio * 50);
      return bScore.compareTo(aScore);
    });

    // Auf maximal 15 Kandidaten beschränken, um Kombinations-Berechnung blitzschnell zu halten
    final pool = candidates.take(15).toList();

    // 4. Optimale Kombination aus 3 bis 4 verschiedenen Mahlzeiten ermitteln
    List<MealEntry> bestPlan = [];
    double bestDifference = double.infinity;

    for (int count = 3; count <= 4; count++) {
      if (pool.length < count) continue;
      final combos = _getCombinations(pool, count);
      for (final combo in combos) {
        int sumCal = 0;
        double sumProt = 0;
        double avgScore = 0;
        for (final m in combo) {
          sumCal += m.calories;
          sumProt += m.protein;
          avgScore += m.healthScore;
        }
        avgScore /= combo.length;

        final calDiff = (sumCal - targetCal).abs();
        final protDiff = (sumProt - targetProt).abs();

        // Kalorien & Protein-Abweichung mit Qualitäts-Bonus
        final calDiffRatio = calDiff / targetCal;
        final protDiffRatio = protDiff / targetProt;
        final scoreDiff = (calDiffRatio * 100) + (protDiffRatio * 50) - (avgScore * 2);

        if (scoreDiff < bestDifference) {
          bestDifference = scoreDiff;
          bestPlan = combo;
        }
      }
    }

    if (bestPlan.isEmpty) {
      bestPlan = pool.take(3).toList();
    }

    _showMealPlanDialog(context, ref, bestPlan, targetCal, targetProt);
  }

  List<List<T>> _getCombinations<T>(List<T> list, int k) {
    if (k == 0) return [[]];
    if (list.isEmpty) return [];
    final head = list.first;
    final tail = list.sublist(1);
    final withHead = _getCombinations(tail, k - 1).map((comb) => [head, ...comb]).toList();
    final withoutHead = _getCombinations(tail, k);
    return [...withHead, ...withoutHead];
  }

  void _showMealPlanDialog(
    BuildContext context,
    WidgetRef ref,
    List<MealEntry> plan,
    double targetCal,
    double targetProt,
  ) {
    int totalPlanCal = 0;
    double totalPlanProt = 0;
    double sumScore = 0;

    for (final m in plan) {
      totalPlanCal += m.calories;
      totalPlanProt += m.protein;
      sumScore += m.healthScore;
    }
    final avgScore = (sumScore / plan.length).toStringAsFixed(1);

    // Match-Prozentwert berechnen (Abweichung von Kalorien & Protein)
    final calAcc = (1.0 - ((totalPlanCal - targetCal).abs() / targetCal)).clamp(0.0, 1.0);
    final protAcc = (1.0 - ((totalPlanProt - targetProt).abs() / targetProt)).clamp(0.0, 1.0);
    final matchPercentage = ((calAcc * 0.7 + protAcc * 0.3) * 100).round();

    final slotLabels = plan.length == 3
        ? ['🌅 Frühstück', '☀️ Mittagessen', '🌙 Abendessen']
        : ['🌅 Frühstück', '☀️ Mittagessen', '🍎 Nachmittags-Snack', '🌙 Abendessen'];

    final slotHours = plan.length == 3 ? [8, 13, 19] : [8, 12, 16, 19];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;

        return DraggableScrollableSheet(
          initialChildSize: 0.85,
          maxChildSize: 0.95,
          minChildSize: 0.5,
          expand: false,
          builder: (context, scrollController) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: ListView(
                controller: scrollController,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.auto_awesome_rounded, color: Color(0xFF10B981), size: 24),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Dein Tagesplan aus deinen Mahlzeiten',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                            ),
                            Text(
                              'Zusammengestellt aus deinen echten getrackten Speisen',
                              style: TextStyle(color: Colors.grey, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  // Übersichtskarte Nährwertvergleich & Match-Quote
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF262626) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark ? Colors.grey.shade800 : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.check_circle_outline, color: Color(0xFF10B981), size: 18),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  '$totalPlanCal / ${targetCal.toInt()} kcal • ${totalPlanProt.round()} / ${targetProt.toInt()}g Protein - $matchPercentage% Match',
                                  style: TextStyle(
                                    color: isDark ? const Color(0xFFA7F3D0) : const Color(0xFF065F46),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildPlanMetric(
                              'Kalorien',
                              '$totalPlanCal kcal',
                              'Ziel: ${targetCal.toInt()} kcal',
                              (totalPlanCal - targetCal).round(),
                              const Color(0xFF10B981),
                            ),
                            Container(width: 1, height: 40, color: Colors.grey.shade300),
                            _buildPlanMetric(
                              'Protein',
                              '${totalPlanProt.round()} g',
                              'Ziel: ${targetProt.toInt()} g',
                              (totalPlanProt - targetProt).round(),
                              const Color(0xFF3B82F6),
                            ),
                            Container(width: 1, height: 40, color: Colors.grey.shade300),
                            Column(
                              children: [
                                const Text('Health-Score', style: TextStyle(fontSize: 11, color: Colors.grey)),
                                const SizedBox(height: 4),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.star_rounded, color: Color(0xFF10B981), size: 16),
                                    Text(
                                      ' $avgScore/10',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF10B981),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                const Text('Ø Qualität', style: TextStyle(fontSize: 10, color: Colors.grey)),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Empfohlene Mahlzeiten-Aufteilung:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 12),
                  // Aufzählung der Mahlzeiten mit echtem Nutzerfoto
                  ...List.generate(plan.length, (i) {
                    final meal = plan[i];
                    final slot = slotLabels[i];
                    final hasPlanWeight = meal.weightGrams != null && meal.weightGrams! > 0;
                    final hasPlanMl = meal.amountMl != null && meal.amountMl! > 0;
                    final planPortionStr = hasPlanWeight
                        ? '${meal.weightGrams} g'
                        : (hasPlanMl ? _formatVolume(meal.amountMl!) : null);

                    return Card(
                      elevation: 0,
                      margin: const EdgeInsets.only(bottom: 12),
                      color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(
                          color: isDark ? Colors.grey.shade800 : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildThumbnail(meal),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        slot,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13,
                                          color: Color(0xFF64748B),
                                        ),
                                      ),
                                      _buildHealthScoreBadge(meal.healthScore, meal.healthCategory),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    meal.name,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 6),
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 4,
                                    children: [
                                      _buildMacroBadge('${meal.calories} kcal', const Color(0xFF10B981)),
                                      _buildMacroBadge('${meal.protein.round()}g P', const Color(0xFF3B82F6)),
                                      _buildMacroBadge('${meal.carbs.round()}g K', const Color(0xFFF59E0B)),
                                      _buildMacroBadge('${meal.fat.round()}g F', const Color(0xFFEF4444)),
                                      if (planPortionStr != null)
                                        _buildMacroBadge(planPortionStr, const Color(0xFF06B6D4)),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    icon: const Icon(Icons.playlist_add_check_rounded, size: 22),
                    label: const Text(
                      'Diesen Plan für heute übernehmen',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                    onPressed: () async {
                      final now = DateTime.now();
                      for (int i = 0; i < plan.length; i++) {
                        final sourceMeal = plan[i];
                        final hour = slotHours[i];
                        final newMeal = sourceMeal.copyWith(
                          id: const Uuid().v4(),
                          timestamp: DateTime(now.year, now.month, now.day, hour, 0),
                        );
                        await ref.read(mealListProvider.notifier).addMeal(newMeal);
                      }

                      if (context.mounted) {
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              '✨ ${plan.length} Mahlzeiten wurden erfolgreich für heute übernommen!',
                            ),
                            backgroundColor: const Color(0xFF10B981),
                            duration: const Duration(seconds: 3),
                          ),
                        );
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Schließen'),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPlanMetric(
    String label,
    String value,
    String targetLabel,
    int diff,
    Color color,
  ) {
    final diffSign = diff > 0 ? '+$diff' : '$diff';
    final diffColor = diff.abs() <= 100 ? Colors.green : Colors.grey;

    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color),
        ),
        const SizedBox(height: 2),
        Text(
          diff == 0 ? 'Exakt' : diffSign,
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: diffColor),
        ),
      ],
    );
  }
}
