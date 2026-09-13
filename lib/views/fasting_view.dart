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
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Column(
          children: [
            // 1. Großer runder Fortschrittsring
            Container(
              padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
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
                    width: 230,
                    height: 230,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Hintergrund-Ring
                        SizedBox(
                          width: 210,
                          height: 210,
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
                          width: 210,
                          height: 210,
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
                              'Ziel: ${fasting.targetFastingHours} Std.',
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
                  const SizedBox(height: 28),

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
            const SizedBox(height: 18),

            // 2. Körperphasen-Karte (Yazio / Fastic inspiriert)
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
            const SizedBox(height: 18),

            // 3. Plan-Auswahl
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
                  Text(
                    'Fasten-Plan wählen',
                    style: TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      _buildPlanChip(
                        context: context,
                        ref: ref,
                        fastHours: 14,
                        eatHours: 10,
                        title: '14:10',
                        subtitle: 'Sanft',
                        isSelected: fasting.targetFastingHours == 14,
                        isDark: isDark,
                      ),
                      const SizedBox(width: 10),
                      _buildPlanChip(
                        context: context,
                        ref: ref,
                        fastHours: 16,
                        eatHours: 8,
                        title: '16:8',
                        subtitle: 'Standard',
                        isSelected: fasting.targetFastingHours == 16,
                        isDark: isDark,
                      ),
                      const SizedBox(width: 10),
                      _buildPlanChip(
                        context: context,
                        ref: ref,
                        fastHours: 18,
                        eatHours: 6,
                        title: '18:6',
                        subtitle: 'Intensiv',
                        isSelected: fasting.targetFastingHours == 18,
                        isDark: isDark,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildPlanChip({
    required BuildContext context,
    required WidgetRef ref,
    required int fastHours,
    required int eatHours,
    required String title,
    required String subtitle,
    required bool isSelected,
    required bool isDark,
  }) {
    return Expanded(
      child: InkWell(
        onTap: () {
          ref.read(fastingProvider.notifier).changePlan(fastHours, eatHours);
        },
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFF10B981).withValues(alpha: 0.15)
                : (isDark ? const Color(0xFF262626) : const Color(0xFFF8FAFC)),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFF10B981)
                  : (isDark ? const Color(0xFF333333) : const Color(0xFFE2E8F0)),
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Column(
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: isSelected
                      ? const Color(0xFF10B981)
                      : (isDark ? Colors.white : const Color(0xFF0F172A)),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: isSelected
                      ? const Color(0xFF10B981)
                      : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
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

