import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/fasting_provider.dart';

class FastingView extends ConsumerWidget {
  const FastingView({super.key});

  String _formatDuration(Duration d) {
    final hours = d.inHours.toString().padLeft(2, '0');
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fasting = ref.watch(fastingProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final cardBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final borderColor = isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE2E8F0);
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subtextColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Text(
          'Intervallfasten',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            letterSpacing: -0.5,
            color: textColor,
          ),
        ),
        centerTitle: false,
        backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF8F9FA),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Großer runder Fortschrittsring
            Container(
              padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: borderColor),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 220,
                    height: 220,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Hintergrund-Ring
                        SizedBox(
                          width: 200,
                          height: 200,
                          child: CircularProgressIndicator(
                            value: 1.0,
                            strokeWidth: 14,
                            strokeCap: StrokeCap.round,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF1F5F9),
                            ),
                          ),
                        ),
                        // Aktiver Fortschritts-Ring
                        SizedBox(
                          width: 200,
                          height: 200,
                          child: CircularProgressIndicator(
                            value: fasting.isFasting ? fasting.progress : 0.0,
                            strokeWidth: 14,
                            strokeCap: StrokeCap.round,
                            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF10B981)),
                          ),
                        ),
                        // Text-Inhalt im Zentrum
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: fasting.isFasting
                                    ? const Color(0xFF10B981).withValues(alpha: 0.15)
                                    : (isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                fasting.isFasting ? 'FASTENZEIT' : 'BEREIT',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.8,
                                  color: fasting.isFasting
                                      ? const Color(0xFF10B981)
                                      : subtextColor,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              fasting.isFasting
                                  ? _formatDuration(fasting.elapsed)
                                  : '00:00:00',
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -1,
                                color: textColor,
                                fontFeatures: const [FontFeature.tabularFigures()],
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Ziel: ${fasting.targetFastingHours} Std. (${fasting.selectedPlan.displayName})',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: subtextColor,
                              ),
                            ),
                            if (fasting.isFasting) ...[
                              const SizedBox(height: 4),
                              Text(
                                '${(fasting.progress * 100).toInt()}% erreicht',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF10B981),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Start / Stop Aktionsbutton
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: fasting.isFasting
                        ? OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.redAccent,
                              side: const BorderSide(color: Colors.redAccent, width: 1.2),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            onPressed: () => _confirmStopFasting(context, ref),
                            icon: const Icon(Icons.stop_rounded, size: 22),
                            label: const Text(
                              'Fasten beenden',
                              style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.bold),
                            ),
                          )
                        : ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF10B981),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            onPressed: () {
                              ref.read(fastingProvider.notifier).startFasting();
                            },
                            icon: const Icon(Icons.play_arrow_rounded, size: 24),
                            label: const Text(
                              'Fasten jetzt starten',
                              style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.bold),
                            ),
                          ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 2. Elegante Gewicht-Fortschrittskarte
            _buildWeightCard(
              context: context,
              ref: ref,
              fasting: fasting,
              isDark: isDark,
              cardBg: cardBg,
              borderColor: borderColor,
              textColor: textColor,
              subtextColor: subtextColor,
            ),
            const SizedBox(height: 16),

            // 3. Körperphasen-Karte (Yazio / Fastic inspiriert)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: borderColor),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          fasting.currentStageIcon,
                          color: const Color(0xFF10B981),
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Aktuelle Phase',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: subtextColor,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              fasting.currentStage,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: textColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    fasting.currentStageDescription,
                    style: TextStyle(
                      fontSize: 13.5,
                      height: 1.45,
                      color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 4. Plan-Auswahl
            Text(
              'Fasten-Pläne',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                letterSpacing: -0.3,
                color: textColor,
              ),
            ),
            const SizedBox(height: 10),
            _buildPlanList(
              context: context,
              ref: ref,
              fasting: fasting,
              isDark: isDark,
              cardBg: cardBg,
              borderColor: borderColor,
              textColor: textColor,
              subtextColor: subtextColor,
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  /// Baut die Gewicht-Fortschrittskarte mit Start-, aktuellem und Zielgewicht
  Widget _buildWeightCard({
    required BuildContext context,
    required WidgetRef ref,
    required FastingProvider fasting,
    required bool isDark,
    required Color cardBg,
    required Color borderColor,
    required Color textColor,
    required Color subtextColor,
  }) {
    final diff = fasting.weightDifference;
    String diffSubtitle;
    if (diff == null) {
      diffSubtitle = 'Tippe auf den Stift, um dein Gewicht zu erfassen';
    } else if (diff > 0) {
      diffSubtitle = 'Noch ${diff.toStringAsFixed(1)} kg bis zum Zielgewicht';
    } else if (diff < 0) {
      diffSubtitle = '${diff.abs().toStringAsFixed(1)} kg unter dem Ziel';
    } else {
      diffSubtitle = 'Zielgewicht erreicht! 🎉';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF0EA5E9).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.monitor_weight_outlined,
                  color: Color(0xFF0EA5E9),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Zielgewicht-Tracking',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      diffSubtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: diff != null && diff <= 0
                            ? const Color(0xFF10B981)
                            : subtextColor,
                        fontWeight: diff != null && diff <= 0
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                style: IconButton.styleFrom(
                  backgroundColor: isDark
                      ? Colors.white.withValues(alpha: 0.06)
                      : Colors.black.withValues(alpha: 0.04),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () => _showWeightEditSheet(context, ref, fasting),
                icon: const Icon(Icons.edit_outlined, size: 18),
                color: isDark ? Colors.white70 : const Color(0xFF334155),
                tooltip: 'Gewicht anpassen',
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 3 Säulen: Start, Aktuell, Ziel
          Row(
            children: [
              _buildWeightPillar(
                title: 'Start',
                weightText: fasting.startWeight != null
                    ? '${fasting.startWeight!.toStringAsFixed(1)} kg'
                    : '--',
                textColor: subtextColor,
                isDark: isDark,
              ),
              const SizedBox(width: 10),
              _buildWeightPillar(
                title: 'Aktuell',
                weightText: fasting.currentWeight != null
                    ? '${fasting.currentWeight!.toStringAsFixed(1)} kg'
                    : '--',
                textColor: textColor,
                isCurrent: true,
                isDark: isDark,
              ),
              const SizedBox(width: 10),
              _buildWeightPillar(
                title: 'Ziel',
                weightText: fasting.targetWeight != null
                    ? '${fasting.targetWeight!.toStringAsFixed(1)} kg'
                    : '--',
                textColor: const Color(0xFF10B981),
                isDark: isDark,
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Fortschrittsbalken
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: fasting.weightProgress,
              minHeight: 8,
              backgroundColor:
                  isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF1F5F9),
              valueColor:
                  const AlwaysStoppedAnimation<Color>(Color(0xFF10B981)),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Fortschritt',
                style: TextStyle(fontSize: 11.5, color: subtextColor),
              ),
              Text(
                '${(fasting.weightProgress * 100).toInt()}% erreicht',
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF10B981),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWeightPillar({
    required String title,
    required String weightText,
    required Color textColor,
    required bool isDark,
    bool isCurrent = false,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: isCurrent
              ? (isDark
                  ? const Color(0xFF10B981).withValues(alpha: 0.12)
                  : const Color(0xFFECFDF5))
              : (isDark
                  ? const Color(0xFF262626)
                  : const Color(0xFFF8FAFC)),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isCurrent
                ? const Color(0xFF10B981).withValues(alpha: 0.4)
                : (isDark
                    ? const Color(0xFF333333)
                    : const Color(0xFFE2E8F0)),
            width: isCurrent ? 1.2 : 1,
          ),
        ),
        child: Column(
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
                color: isCurrent ? const Color(0xFF10B981) : Colors.grey,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              weightText,
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: isCurrent ? FontWeight.w800 : FontWeight.bold,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Baut die Liste der Fasten-Pläne (12:12, 14:10, 16:8, 18:6, 20:4)
  Widget _buildPlanList({
    required BuildContext context,
    required WidgetRef ref,
    required FastingProvider fasting,
    required bool isDark,
    required Color cardBg,
    required Color borderColor,
    required Color textColor,
    required Color subtextColor,
  }) {
    final plans = [
      FastingPlan.plan12_12,
      FastingPlan.plan14_10,
      FastingPlan.plan16_8,
      FastingPlan.plan18_6,
      FastingPlan.plan20_4,
    ];

    return Column(
      children: plans.map((plan) {
        final isSelected = fasting.selectedPlan == plan;

        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: InkWell(
            onTap: () {
              ref.read(fastingProvider.notifier).selectPlan(plan);
            },
            borderRadius: BorderRadius.circular(16),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: isSelected
                    ? (isDark
                        ? const Color(0xFF10B981).withValues(alpha: 0.15)
                        : const Color(0xFFECFDF5))
                    : cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected
                      ? const Color(0xFF10B981)
                      : borderColor,
                  width: isSelected ? 1.5 : 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Icon oder Badge
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFF10B981).withValues(alpha: 0.2)
                          : (isDark ? Colors.white10 : const Color(0xFFF1F5F9)),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        plan.displayName,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          color: isSelected ? const Color(0xFF10B981) : textColor,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),

                  // Textblock
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              plan.tagline,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14.5,
                                color: isSelected ? const Color(0xFF10B981) : textColor,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? const Color(0xFF10B981).withValues(alpha: 0.2)
                                    : (isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.05)),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                plan.badge,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: isSelected ? const Color(0xFF10B981) : subtextColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${plan.fastHours}h Fasten · ${plan.eatHours}h Essen · ${plan.description}',
                          style: TextStyle(
                            fontSize: 12,
                            color: subtextColor,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Trailing Radio / Checkmark
                  Icon(
                    isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
                    color: isSelected
                        ? const Color(0xFF10B981)
                        : (isDark ? const Color(0xFF64748B) : const Color(0xFFCBD5E1)),
                    size: 22,
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  /// Dialog zur Eingabe des Start-, aktuellen und Zielgewichts
  void _showWeightEditSheet(
      BuildContext context, WidgetRef ref, FastingProvider fasting) {
    final currentController = TextEditingController(
      text: fasting.currentWeight != null
          ? fasting.currentWeight!.toStringAsFixed(1)
          : '',
    );
    final targetController = TextEditingController(
      text: fasting.targetWeight != null
          ? fasting.targetWeight!.toStringAsFixed(1)
          : '',
    );
    final startController = TextEditingController(
      text: fasting.startWeight != null
          ? fasting.startWeight!.toStringAsFixed(1)
          : '',
    );

    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
        ),
        child: SafeArea(
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
                    color: isDark ? Colors.white24 : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                'Gewicht anpassen',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Trage dein aktuelles Gewicht und dein persönliches Zielgewicht ein.',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 18),

              // Aktuelles Gewicht
              TextField(
                controller: currentController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Aktuelles Gewicht (kg)',
                  prefixIcon: const Icon(Icons.speed_rounded),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
              const SizedBox(height: 14),

              // Zielgewicht
              TextField(
                controller: targetController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Zielgewicht (kg)',
                  prefixIcon: const Icon(Icons.flag_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
              const SizedBox(height: 14),

              // Startgewicht
              TextField(
                controller: startController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Startgewicht (kg, optional)',
                  prefixIcon: const Icon(Icons.history_rounded),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
              const SizedBox(height: 22),

              // Speichern Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () {
                    final current = double.tryParse(
                        currentController.text.replaceAll(',', '.').trim());
                    final target = double.tryParse(
                        targetController.text.replaceAll(',', '.').trim());
                    final start = double.tryParse(
                        startController.text.replaceAll(',', '.').trim());

                    if (current != null && current > 0) {
                      ref.read(fastingProvider.notifier).updateWeight(current, target, start);
                    }
                    Navigator.pop(ctx);
                  },
                  child: const Text(
                    'Speichern',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmStopFasting(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Fasten beenden?',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'Möchtest du deine aktuelle Fastenphase wirklich beenden und in das Essensfenster wechseln?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Abbrechen'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(fastingProvider.notifier).stopFasting();
            },
            child: const Text('Ja, beenden'),
          ),
        ],
      ),
    );
  }
}
