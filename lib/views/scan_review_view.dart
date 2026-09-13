import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/meal_entry.dart';
import '../models/meal_item.dart';
import '../providers/meal_provider.dart';
import '../services/ad_service.dart';
import '../services/purchase_service.dart';

class ScanReviewView extends ConsumerStatefulWidget {
  final MealEntry initialMeal;
  final String? imagePath;

  const ScanReviewView({
    super.key,
    required this.initialMeal,
    this.imagePath,
  });

  @override
  ConsumerState<ScanReviewView> createState() => _ScanReviewViewState();
}

class _ScanReviewViewState extends ConsumerState<ScanReviewView> {
  late TextEditingController _mealNameController;
  late TextEditingController _amountMlController;
  late TextEditingController _weightGramsController;
  late List<_EditableItem> _editableItems;

  @override
  void initState() {
    super.initState();
    _mealNameController = TextEditingController(text: widget.initialMeal.name);
    _amountMlController = TextEditingController(
      text: (widget.initialMeal.amountMl != null &&
              widget.initialMeal.amountMl! > 0)
          ? widget.initialMeal.amountMl.toString()
          : '',
    );
    final initialWeight = widget.initialMeal.weightGrams ??
        (widget.initialMeal.items.isNotEmpty
            ? widget.initialMeal.items
                .fold(0.0, (sum, i) => sum + i.estimatedWeightG)
                .round()
            : null);
    _weightGramsController = TextEditingController(
      text:
          (initialWeight != null && initialWeight > 0) ? '$initialWeight' : '',
    );
    final meal = widget.initialMeal;
    // Keep totals editable when the model could not split the meal into items.
    final initialItems = meal.items.isEmpty
        ? [
            MealItem(
              name: meal.name,
              estimatedWeightG: meal.weightGrams?.toDouble() ?? 0,
              calories: meal.calories.toDouble(),
              proteinG: meal.protein,
              carbsG: meal.carbs,
              fatG: meal.fat,
            )
          ]
        : meal.items;
    _editableItems =
        initialItems.map((item) => _EditableItem.fromMealItem(item)).toList();
  }

  @override
  void dispose() {
    _mealNameController.dispose();
    _amountMlController.dispose();
    _weightGramsController.dispose();
    for (final item in _editableItems) {
      item.dispose();
    }
    super.dispose();
  }

  double get _totalCalories => _editableItems.fold(
      0.0, (sum, item) => sum + (double.tryParse(item.caloriesCtrl.text) ?? 0.0));

  double get _totalProtein => _editableItems.fold(
      0.0, (sum, item) => sum + (double.tryParse(item.proteinCtrl.text) ?? 0.0));

  double get _totalCarbs => _editableItems.fold(
      0.0, (sum, item) => sum + (double.tryParse(item.carbsCtrl.text) ?? 0.0));

  double get _totalFat => _editableItems.fold(
      0.0, (sum, item) => sum + (double.tryParse(item.fatCtrl.text) ?? 0.0));

  void _addItem() {
    setState(() {
      _editableItems.add(_EditableItem(
        nameCtrl: TextEditingController(text: 'Zusätzliche Zutat'),
        weightCtrl: TextEditingController(text: '100'),
        caloriesCtrl: TextEditingController(text: '120'),
        proteinCtrl: TextEditingController(text: '8'),
        carbsCtrl: TextEditingController(text: '10'),
        fatCtrl: TextEditingController(text: '4'),
        baseCaloriesPerG: 1.2,
        baseProteinPerG: 0.08,
        baseCarbsPerG: 0.10,
        baseFatPerG: 0.04,
      ));
    });
  }

  void _removeItem(int index) {
    setState(() {
      final removed = _editableItems.removeAt(index);
      removed.dispose();
    });
  }

  void _saveMeal() {
    final finalItems = _editableItems.map((item) {
      return MealItem(
        name: item.nameCtrl.text.trim().isEmpty ? 'Lebensmittel' : item.nameCtrl.text.trim(),
        estimatedWeightG: double.tryParse(item.weightCtrl.text) ?? 0.0,
        calories: double.tryParse(item.caloriesCtrl.text) ?? 0.0,
        proteinG: double.tryParse(item.proteinCtrl.text) ?? 0.0,
        carbsG: double.tryParse(item.carbsCtrl.text) ?? 0.0,
        fatG: double.tryParse(item.fatCtrl.text) ?? 0.0,
      );
    }).toList();

    final enteredName = _mealNameController.text.trim();
    final rawMl = int.tryParse(_amountMlController.text.trim());
    final mlVal = (rawMl != null && rawMl > 0) ? rawMl : null;
    final rawWeight = int.tryParse(_weightGramsController.text.trim());
    final weightVal = (rawWeight != null && rawWeight > 0) ? rawWeight : null;

    final savedMeal = MealEntry(
      id: widget.initialMeal.id.isNotEmpty ? widget.initialMeal.id : const Uuid().v4(),
      name: enteredName.isNotEmpty
          ? enteredName
          : (mlVal != null && _totalCalories == 0 ? 'Wasser' : 'Mahlzeit'),
      calories: _totalCalories.round(),
      protein: _totalProtein,
      carbs: _totalCarbs,
      fat: _totalFat,
      amountMl: mlVal,
      weightGrams: weightVal,
      localImagePath: widget.imagePath ?? widget.initialMeal.localImagePath,
      timestamp: DateTime.now(),
      items: finalItems,
      healthScore: widget.initialMeal.healthScore,
      healthCategory: widget.initialMeal.healthCategory,
      healthReason: widget.initialMeal.healthReason,
    );

    ref.read(mealListProvider.notifier).addMeal(savedMeal);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('"${savedMeal.name}" im Tagebuch gespeichert!'),
        backgroundColor: const Color(0xFF10B981),
      ),
    );

    final isPremium = ref.read(premiumProvider);
    AdService.showInterstitialAd(
      isPremium: isPremium,
      onDismissed: () {
        if (mounted) {
          Navigator.of(context).pop();
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('Eintrag prüfen & anpassen'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Komponente hinzufügen',
            onPressed: _addItem,
          ),
          IconButton(
            icon: const Icon(Icons.check),
            tooltip: 'Speichern',
            onPressed: _saveMeal,
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth >= 768;
          if (isDesktop) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.imagePath != null)
                  Expanded(
                    flex: 2,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: _buildImageSection(),
                    ),
                  ),
                Expanded(
                  flex: 3,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: _buildFormSection(theme, isDark),
                  ),
                ),
              ],
            );
          } else {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  if (widget.imagePath != null) ...[
                    _buildImageSection(),
                    const SizedBox(height: 16),
                  ],
                  _buildFormSection(theme, isDark),
                ],
              ),
            );
          }
        },
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton.icon(
            icon: const Icon(Icons.save_rounded),
            label: const Text('Mahlzeit in Tagebuch speichern', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: _saveMeal,
          ),
        ),
      ),
    );
  }

  Widget _buildImageSection() {
    final path = widget.imagePath;
    final fileExists = path != null && path.isNotEmpty && File(path).existsSync();

    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 1,
      child: Stack(
        alignment: Alignment.bottomLeft,
        children: [
          if (fileExists)
            Image(
              image: FileImage(File(path)),
              width: double.infinity,
              height: 220,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => _buildImageFallback(),
            )
          else
            _buildImageFallback(),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.black87, Colors.transparent],
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Gescannte Mahlzeit',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                if (widget.initialMeal.healthScore > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '★ ${widget.initialMeal.healthScore}/10',
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageFallback() {
    return Container(
      width: double.infinity,
      height: 220,
      color: const Color(0xFFF1F5F9),
      child: const Center(
        child: Icon(Icons.fastfood_rounded, size: 64, color: Color(0xFF94A3B8)),
      ),
    );
  }

  Widget _buildFormSection(ThemeData theme, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Name & Flüssigkeitsmenge
        Card(
          elevation: 0,
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: isDark ? Colors.grey.shade800 : const Color(0xFFE2E8F0)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.initialMeal.healthReason != null &&
                    widget.initialMeal.healthReason!.isNotEmpty) ...[
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF3B82F6).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: const Color(0xFF3B82F6).withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.auto_awesome,
                            size: 16, color: Color(0xFF3B82F6)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            widget.initialMeal.healthReason!,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF3B82F6),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                Text(
                  'Name des Eintrags',
                  style: TextStyle(
                    color: isDark ? Colors.grey.shade300 : const Color(0xFF475569),
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _mealNameController,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    prefixIcon: const Icon(Icons.restaurant_menu, color: Color(0xFF10B981)),
                    hintText: 'z.B. Rührei mit Gemüse oder Wasser',
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 14),

                // Gesamtgewicht (g)
                Text(
                  'Gesamtgewicht (optional)',
                  style: TextStyle(
                    color: isDark ? Colors.grey.shade400 : const Color(0xFF10B981),
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _weightGramsController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    prefixIcon: const Icon(Icons.scale_outlined, color: Color(0xFF10B981)),
                    labelText: 'Gesamtgewicht (g)',
                    hintText: 'z. B. 250 g',
                    isDense: true,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 14),

                // Flüssigkeitsmenge
                Text(
                  'Flüssigkeitsmenge (optional für Getränke / Shakes / Wasser)',
                  style: TextStyle(
                    color: isDark ? Colors.grey.shade400 : const Color(0xFF0284C7),
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _amountMlController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    prefixIcon: const Icon(Icons.water_drop_outlined, color: Color(0xFF0284C7)),
                    labelText: 'Menge (ml)',
                    hintText: 'z. B. 500 ml oder 1000 ml (1L)',
                    isDense: true,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 8),

                // Schnellwahltasten / Preset-Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildMlPresetChip(250, '250 ml'),
                      const SizedBox(width: 6),
                      _buildMlPresetChip(500, '500 ml'),
                      const SizedBox(width: 6),
                      _buildMlPresetChip(750, '750 ml'),
                      const SizedBox(width: 6),
                      _buildMlPresetChip(1000, '1.0 L (1000 ml)'),
                      const SizedBox(width: 6),
                      _buildMlPresetChip(1500, '1.5 L (1500 ml)'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),

        // Nährwert-Gesamtübersicht
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFECFDF5),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFF10B981).withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            children: [
              Expanded(child: _buildSummaryStat('Kalorien', '${_totalCalories.toStringAsFixed(0)} kcal', const Color(0xFF10B981))),
              Container(width: 1, height: 32, color: Colors.grey.withValues(alpha: 0.3)),
              Expanded(child: _buildSummaryStat('Protein', '${_totalProtein.toStringAsFixed(1)} g', const Color(0xFF3B82F6))),
              Container(width: 1, height: 32, color: Colors.grey.withValues(alpha: 0.3)),
              Expanded(child: _buildSummaryStat('Kohlenhydrate', '${_totalCarbs.toStringAsFixed(1)} g', const Color(0xFFF59E0B))),
              Container(width: 1, height: 32, color: Colors.grey.withValues(alpha: 0.3)),
              Expanded(child: _buildSummaryStat('Fett', '${_totalFat.toStringAsFixed(1)} g', const Color(0xFFEF4444))),
            ],
          ),
        ),
        const SizedBox(height: 18),

        // Sektion: Erkannte Komponenten
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Erkannte Komponenten (${_editableItems.length})',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Tippe auf die Grammzahl zur schnellen Anpassung',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
            TextButton.icon(
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Zutat +', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              onPressed: _addItem,
            ),
          ],
        ),
        const SizedBox(height: 10),

        ..._editableItems.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          return _buildComponentCard(index, item, theme, isDark);
        }),
      ],
    );
  }

  Widget _buildMlPresetChip(int ml, String label) {
    final isSelected = _amountMlController.text.trim() == ml.toString();
    return InkWell(
      onTap: () {
        setState(() {
          _amountMlController.text = ml.toString();
        });
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF0284C7)
              : const Color(0xFF0284C7).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF0284C7)
                : const Color(0xFF0284C7).withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.white : const Color(0xFF0284C7),
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryStat(String label, String value, Color color) {
    return Column(
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: color),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Colors.grey),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildComponentCard(int index, _EditableItem item, ThemeData theme, bool isDark) {
    final cardBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final borderColor = isDark ? Colors.grey.shade800 : const Color(0xFFE2E8F0);

    final currentCalories = double.tryParse(item.caloriesCtrl.text) ?? 0.0;
    final currentProtein = double.tryParse(item.proteinCtrl.text) ?? 0.0;
    final currentCarbs = double.tryParse(item.carbsCtrl.text) ?? 0.0;
    final currentFat = double.tryParse(item.fatCtrl.text) ?? 0.0;

    return Card(
      elevation: 0,
      color: cardBg,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: borderColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Zeile 1: Name der Komponente & Löschen-Button
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: item.nameCtrl,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5),
                    decoration: const InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                      hintText: 'Bezeichnung der Zutat',
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.grey, size: 18),
                  tooltip: 'Komponente entfernen',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => _removeItem(index),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Zeile 2: 1-Klick Mengenanpassung (Grammzahl mit Quick-Buttons)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF262626) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.scale_rounded, size: 16, color: Color(0xFF10B981)),
                  const SizedBox(width: 6),
                  const Text(
                    'Menge:',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey),
                  ),
                  const SizedBox(width: 8),

                  // Minus 10g Stepper
                  _buildQuickStepButton(
                    label: '-10',
                    onTap: () {
                      setState(() {
                        item.adjustWeight(-10);
                      });
                    },
                  ),
                  const SizedBox(width: 4),

                  // Gramm Input Field
                  Container(
                    width: 68,
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: const Color(0xFF10B981).withValues(alpha: 0.4),
                      ),
                    ),
                    child: TextField(
                      controller: item.weightCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      decoration: const InputDecoration(
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(vertical: 4),
                        border: InputBorder.none,
                        suffixText: 'g',
                        suffixStyle: TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                      onChanged: (val) {
                        setState(() {
                          final parsed = double.tryParse(val) ?? 0.0;
                          item.setWeight(parsed);
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 4),

                  // Plus 10g Stepper
                  _buildQuickStepButton(
                    label: '+10',
                    onTap: () {
                      setState(() {
                        item.adjustWeight(10);
                      });
                    },
                  ),
                  const SizedBox(width: 6),

                  // Zusätzliche Schnellwahl-Chips (+25g, +50g)
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildQuickDeltaChip(item, -25),
                          const SizedBox(width: 4),
                          _buildQuickDeltaChip(item, 25),
                          const SizedBox(width: 4),
                          _buildQuickDeltaChip(item, 50),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // Zeile 3: Makros der Komponente (aktualisieren sich automatisch bei Gramm-Änderung)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildMacroPill('${currentCalories.round()} kcal', const Color(0xFF10B981)),
                _buildMacroPill('${currentProtein.toStringAsFixed(1)}g P', const Color(0xFF3B82F6)),
                _buildMacroPill('${currentCarbs.toStringAsFixed(1)}g K', const Color(0xFFF59E0B)),
                _buildMacroPill('${currentFat.toStringAsFixed(1)}g F', const Color(0xFFEF4444)),
                InkWell(
                  onTap: () => _showManualMacroEditSheet(item),
                  borderRadius: BorderRadius.circular(6),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    child: Icon(Icons.tune_rounded, size: 16, color: Colors.grey),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickStepButton({required String label, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.grey.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildQuickDeltaChip(_EditableItem item, double delta) {
    final text = delta > 0 ? '+$delta g' : '$delta g';
    return InkWell(
      onTap: () {
        setState(() {
          item.adjustWeight(delta);
        });
      },
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFF10B981).withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.bold,
            color: Color(0xFF10B981),
          ),
        ),
      ),
    );
  }

  Widget _buildMacroPill(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 11.5,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  void _showManualMacroEditSheet(_EditableItem item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Makros für "${item.nameCtrl.text}" feinjustieren',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: item.caloriesCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Kalorien (kcal)',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      onChanged: (_) {
                        item.recalcBaseRatios();
                        setState(() {});
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: item.proteinCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Protein (g)',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      onChanged: (_) {
                        item.recalcBaseRatios();
                        setState(() {});
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: item.carbsCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Kohlenhydrate (g)',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      onChanged: (_) {
                        item.recalcBaseRatios();
                        setState(() {});
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: item.fatCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Fett (g)',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      onChanged: (_) {
                        item.recalcBaseRatios();
                        setState(() {});
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  minimumSize: const Size.fromHeight(46),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  Navigator.pop(ctx);
                  setState(() {});
                },
                child: const Text('Übernehmen'),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _EditableItem {
  final TextEditingController nameCtrl;
  final TextEditingController weightCtrl;
  final TextEditingController caloriesCtrl;
  final TextEditingController proteinCtrl;
  final TextEditingController carbsCtrl;
  final TextEditingController fatCtrl;

  double baseCaloriesPerG;
  double baseProteinPerG;
  double baseCarbsPerG;
  double baseFatPerG;

  _EditableItem({
    required this.nameCtrl,
    required this.weightCtrl,
    required this.caloriesCtrl,
    required this.proteinCtrl,
    required this.carbsCtrl,
    required this.fatCtrl,
    required this.baseCaloriesPerG,
    required this.baseProteinPerG,
    required this.baseCarbsPerG,
    required this.baseFatPerG,
  });

  factory _EditableItem.fromMealItem(MealItem item) {
    final weight = item.estimatedWeightG > 0 ? item.estimatedWeightG : 100.0;
    final calPerG = item.calories / weight;
    final protPerG = item.proteinG / weight;
    final carbsPerG = item.carbsG / weight;
    final fatPerG = item.fatG / weight;

    return _EditableItem(
      nameCtrl: TextEditingController(text: item.name),
      weightCtrl: TextEditingController(text: weight.toStringAsFixed(0)),
      caloriesCtrl: TextEditingController(text: item.calories.toStringAsFixed(0)),
      proteinCtrl: TextEditingController(text: item.proteinG.toStringAsFixed(1)),
      carbsCtrl: TextEditingController(text: item.carbsG.toStringAsFixed(1)),
      fatCtrl: TextEditingController(text: item.fatG.toStringAsFixed(1)),
      baseCaloriesPerG: calPerG,
      baseProteinPerG: protPerG,
      baseCarbsPerG: carbsPerG,
      baseFatPerG: fatPerG,
    );
  }

  void setWeight(double newWeight) {
    final clampedWeight = newWeight < 0 ? 0.0 : newWeight;
    weightCtrl.text = clampedWeight.toStringAsFixed(0);
    caloriesCtrl.text = (clampedWeight * baseCaloriesPerG).round().toString();
    proteinCtrl.text = (clampedWeight * baseProteinPerG).toStringAsFixed(1);
    carbsCtrl.text = (clampedWeight * baseCarbsPerG).toStringAsFixed(1);
    fatCtrl.text = (clampedWeight * baseFatPerG).toStringAsFixed(1);
  }

  void adjustWeight(double delta) {
    final current = double.tryParse(weightCtrl.text) ?? 0.0;
    setWeight(current + delta);
  }

  void recalcBaseRatios() {
    final weight = double.tryParse(weightCtrl.text) ?? 0.0;
    if (weight > 0) {
      final cal = double.tryParse(caloriesCtrl.text) ?? 0.0;
      final prot = double.tryParse(proteinCtrl.text) ?? 0.0;
      final carbs = double.tryParse(carbsCtrl.text) ?? 0.0;
      final fat = double.tryParse(fatCtrl.text) ?? 0.0;

      baseCaloriesPerG = cal / weight;
      baseProteinPerG = prot / weight;
      baseCarbsPerG = carbs / weight;
      baseFatPerG = fat / weight;
    }
  }

  void dispose() {
    nameCtrl.dispose();
    weightCtrl.dispose();
    caloriesCtrl.dispose();
    proteinCtrl.dispose();
    carbsCtrl.dispose();
    fatCtrl.dispose();
  }
}
