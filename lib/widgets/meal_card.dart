import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/meal_entry.dart';

class MealCard extends StatelessWidget {
  final MealEntry meal;
  final VoidCallback onDelete;
  final VoidCallback? onEdit;
  final VoidCallback? onDuplicate;

  const MealCard({
    super.key,
    required this.meal,
    required this.onDelete,
    this.onEdit,
    this.onDuplicate,
  });

  static String formatVolume(int ml) {
    if (ml >= 1000) {
      final liters = ml / 1000.0;
      return '${liters.toStringAsFixed(1)} L';
    }
    return '$ml ml';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final timeStr = '${DateFormat('HH:mm').format(meal.timestamp)} Uhr';

    final cardBg = isDark ? theme.colorScheme.surface : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subtextColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    String macroSubtitle;
    if (meal.amountMl != null && meal.amountMl! > 0) {
      final volStr = formatVolume(meal.amountMl!);
      if (meal.calories == 0) {
        macroSubtitle = '$timeStr • $volStr • 0 kcal';
      } else {
        macroSubtitle = '$timeStr • $volStr • ${meal.calories} kcal / ${meal.protein.toInt()}g P';
      }
    } else {
      macroSubtitle = '$timeStr • ${meal.calories} kcal / ${meal.protein.toInt()}g P';
    }

    return Dismissible(
      key: Key(meal.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 22),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.redAccent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Löschen',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            SizedBox(width: 8),
            Icon(Icons.delete_outline, color: Colors.white, size: 24),
          ],
        ),
      ),
      onDismissed: (_) => onDelete(),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.035),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Theme(
          data: theme.copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            leading: _buildThumbnail(),
            title: Text(
              meal.name,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: textColor,
                letterSpacing: -0.2,
              ),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                macroSubtitle,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: subtextColor,
                ),
              ),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (onDuplicate != null)
                  IconButton(
                    icon: const Icon(
                      Icons.copy_rounded,
                      color: Color(0xFF10B981),
                      size: 19,
                    ),
                    tooltip: 'Für Tag übernehmen',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: onDuplicate,
                  ),
                if (onDuplicate != null) const SizedBox(width: 8),
                if (onEdit != null)
                  IconButton(
                    icon: const Icon(
                      Icons.edit_outlined,
                      color: Color(0xFF64748B),
                      size: 20,
                    ),
                    tooltip: 'Eintrag bearbeiten',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: onEdit,
                  ),
                const SizedBox(width: 6),
                const Icon(
                  Icons.chevron_right,
                  color: Color(0xFF94A3B8),
                  size: 22,
                ),
              ],
            ),
            children: [
              Divider(
                height: 1,
                color: isDark ? Colors.grey.shade800 : const Color(0xFFF1F5F9),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          meal.items.isNotEmpty
                              ? 'Enthaltene Zutaten (${meal.items.length}):'
                              : 'Makronährstoffe:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (onDuplicate != null)
                              IconButton(
                                icon: const Icon(Icons.copy_rounded, color: Color(0xFF10B981), size: 19),
                                tooltip: 'Für Tag übernehmen',
                                onPressed: onDuplicate,
                              ),
                            if (onEdit != null)
                              IconButton(
                                icon: const Icon(Icons.edit_outlined, color: Color(0xFF64748B), size: 20),
                                tooltip: 'Eintrag bearbeiten',
                                onPressed: onEdit,
                              ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                              tooltip: 'Eintrag löschen',
                              onPressed: () {
                                showDialog(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: const Text('Eintrag löschen'),
                                    content: Text('Möchtest du "${meal.name}" wirklich entfernen?'),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(ctx),
                                        child: const Text('Abbrechen'),
                                      ),
                                      FilledButton(
                                        style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
                                        onPressed: () {
                                          Navigator.pop(ctx);
                                          onDelete();
                                        },
                                        child: const Text('Löschen'),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    if (meal.amountMl != null && meal.amountMl! > 0)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            const Icon(Icons.water_drop_outlined, size: 16, color: Color(0xFF0284C7)),
                            const SizedBox(width: 6),
                            Text(
                              'Flüssigkeitsmenge: ${formatVolume(meal.amountMl!)} (${meal.amountMl} ml)',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF0284C7),
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (meal.items.isNotEmpty)
                      ...meal.items.map((item) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: Text(
                                  item.name,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w500,
                                    fontSize: 13,
                                    color: textColor,
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  '${item.estimatedWeightG.toStringAsFixed(0)} g',
                                  style: TextStyle(
                                    color: subtextColor,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              Text(
                                '${item.calories.toStringAsFixed(0)} kcal',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                  color: textColor,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                '${item.proteinG.toStringAsFixed(1)} g P',
                                style: const TextStyle(
                                  color: Color(0xFF1E88E5),
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        );
                      })
                    else
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _macroBadge('Kalorien', '${meal.calories} kcal', Colors.orange.shade800),
                            _macroBadge('Protein', '${meal.protein.toStringAsFixed(1)} g', const Color(0xFF1E88E5)),
                            _macroBadge('Carbs', '${meal.carbs.toStringAsFixed(1)} g', Colors.teal.shade800),
                            _macroBadge('Fett', '${meal.fat.toStringAsFixed(1)} g', Colors.purple.shade800),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _macroBadge(String label, String val, Color color) {
    return Column(
      children: [
        Text(val, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: color)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    );
  }

  Widget _buildThumbnail() {
    final imagePath = meal.imagePath ?? meal.localImagePath;
    if (imagePath != null && imagePath.isNotEmpty && File(imagePath).existsSync()) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image(
          image: FileImage(File(imagePath)),
          width: 52,
          height: 52,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _buildFallbackIcon(),
        ),
      );
    }
    return _buildFallbackIcon();
  }

  Widget _buildFallbackIcon() {
    if (meal.amountMl != null && meal.amountMl! > 0) {
      return Container(
        width: 52,
        height: 52,
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
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: const Color(0xFFEFF3F8),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Icon(
        Icons.restaurant_rounded,
        color: Color(0xFF64748B),
        size: 24,
      ),
    );
  }
}
