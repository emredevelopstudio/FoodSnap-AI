import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../providers/meal_provider.dart';
import '../l10n/app_localizations.dart';

class ProgressCard extends StatelessWidget {
  final DailyProgress progress;

  const ProgressCard({super.key, required this.progress});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = context.l10n;

    final outerBg = isDark ? const Color(0xFF1E1E1E) : const Color(0xFFEFF3F8);
    final innerBg = isDark ? const Color(0xFF242424) : Colors.white;
    final trackColor = isDark ? const Color(0xFF333333) : const Color(0xFFE2E8F0);
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subtextColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    final percentVal = (progress.calorieProgress * 100).round();

    return Container(
      decoration: BoxDecoration(
        color: outerBg,
        borderRadius: BorderRadius.circular(24),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Header Row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  l10n.dailyProgress,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                    letterSpacing: -0.2,
                  ),
                ),
                Icon(
                  Icons.pie_chart_outline_rounded,
                  color: subtextColor,
                  size: 20,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // 1. Inner White Card: Calories Arc Gauge (Proportionen & Innenpolster optimiert)
          Container(
            decoration: BoxDecoration(
              color: innerBg,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final maxWidth = constraints.maxWidth;
                const strokeWidth = 13.0;
                const gaugeHeight = 136.0;

                // Radius verkleinert um ca. 20-25% für harmonische Proportionen
                final radius = math.min(
                  (maxWidth - strokeWidth * 2 - 24) / 2,
                  gaugeHeight - strokeWidth - 22,
                );
                final center = Offset(maxWidth / 2, gaugeHeight - 24);

                final dLeft = center.dx - radius;
                final dRight = maxWidth - (center.dx + radius);

                return SizedBox(
                  height: gaugeHeight,
                  width: double.infinity,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Halbkreisbogen Painter
                      Positioned.fill(
                        child: CustomPaint(
                          painter: SemiCircleLinearGradientGaugePainter(
                            progress: progress.calorieProgress,
                            backgroundColor: trackColor,
                            strokeWidth: strokeWidth,
                            radius: radius,
                            center: center,
                          ),
                        ),
                      ),

                      // Zentrale Anzeige ('XXXX' und '/ YYYY kcal') harmonisch mittig im Bogen
                      Positioned(
                        top: center.dy - radius + (radius * 0.32),
                        left: 0,
                        right: 0,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${progress.consumedCalories.toInt()}',
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: textColor,
                                height: 1.0,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '/ ${progress.targetCalories.toInt()} kcal',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: subtextColor,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Linkes Label '0' sauber zentriert unter dem linken Bogenende
                      Positioned(
                        left: math.max(0.0, dLeft - 25),
                        bottom: 2,
                        child: SizedBox(
                          width: 50,
                          child: Text(
                            '0',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              color: subtextColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),

                      // Rechtes Label '${targetCalories} kcal' sauber zentriert unter dem rechten Bogenende
                      Positioned(
                        right: math.max(0.0, dRight - 36),
                        bottom: 2,
                        child: SizedBox(
                          width: 72,
                          child: Text(
                            '${progress.targetCalories.toInt()} kcal',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 11,
                              color: subtextColor,
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),

          // 2. Inner White Card: Protein Progress
          Container(
            decoration: BoxDecoration(
              color: innerBg,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      l10n.protein,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    Text(
                      '${progress.consumedProteinG.toInt()} / ${progress.targetProteinG.toInt()}g',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: progress.proteinProgress.clamp(0.0, 1.0),
                    minHeight: 8,
                    backgroundColor: trackColor,
                    valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF1E88E5)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // 3. Inner White Card: 3 Macro Mini-Bar Segments (Ziel %, Kohlenhydrate, Fett)
          Container(
            decoration: BoxDecoration(
              color: innerBg,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: _buildMacroSegment(
                    label: l10n.goal,
                    value: '$percentVal%',
                    ratio: progress.calorieProgress.clamp(0.0, 1.0),
                    trackColor: trackColor,
                    barColor: const Color(0xFF1E88E5),
                    textColor: textColor,
                    subtextColor: subtextColor,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 5,
                  child: _buildMacroSegment(
                    label: l10n.isEn ? 'Carbs' : 'Kohlenhydrate',
                    value: '${progress.totalCarbsG.toStringAsFixed(1)} g',
                    ratio: (progress.targetCarbsG > 0
                            ? progress.totalCarbsG / progress.targetCarbsG
                            : 0.0)
                        .clamp(0.0, 1.0),
                    trackColor: trackColor,
                    barColor: const Color(0xFF1E88E5),
                    textColor: textColor,
                    subtextColor: subtextColor,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 4,
                  child: _buildMacroSegment(
                    label: l10n.fat,
                    value: '${progress.totalFatG.toStringAsFixed(1)} g',
                    ratio: (progress.targetFatG > 0
                            ? progress.totalFatG / progress.targetFatG
                            : 0.0)
                        .clamp(0.0, 1.0),
                    trackColor: trackColor,
                    barColor: const Color(0xFF1E88E5),
                    textColor: textColor,
                    subtextColor: subtextColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMacroSegment({
    required String label,
    required String value,
    required double ratio,
    required Color trackColor,
    required Color barColor,
    required Color textColor,
    required Color subtextColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: subtextColor,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: ratio,
            minHeight: 6,
            backgroundColor: trackColor,
            valueColor: AlwaysStoppedAnimation<Color>(barColor),
          ),
        ),
      ],
    );
  }
}

/// Custom painter for semi-circle arc gauge with horizontal linear gradient:
/// Orange/Red (#FF5722) -> Yellow/Amber (#FFB300) -> Emerald Green (#10B981)
class SemiCircleLinearGradientGaugePainter extends CustomPainter {
  final double progress;
  final Color backgroundColor;
  final double strokeWidth;
  final double radius;
  final Offset center;

  SemiCircleLinearGradientGaugePainter({
    required this.progress,
    required this.backgroundColor,
    this.strokeWidth = 13.0,
    required this.radius,
    required this.center,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (radius <= 0) return;

    final rect = Rect.fromCircle(center: center, radius: radius);

    // 1. Hintergrund-Bogen (pi bis 2*pi)
    final bgPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(rect, math.pi, math.pi, false, bgPaint);

    // 2. Aktiver Fortschrittsbogen mit horizontalem Gradient
    if (progress > 0) {
      final clampedProgress = progress.clamp(0.0, 1.0);
      final sweepAngle = clampedProgress * math.pi;

      final gradient = ui.Gradient.linear(
        Offset(center.dx - radius, center.dy),
        Offset(center.dx + radius, center.dy),
        const [
          Color(0xFFFF5722), // Orange/Rot
          Color(0xFFFFB300), // Amber/Gelb
          Color(0xFF10B981), // Smaragdgrün
        ],
        const [0.0, 0.5, 1.0],
      );

      final fgPaint = Paint()
        ..shader = gradient
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(rect, math.pi, sweepAngle, false, fgPaint);
    }
  }

  @override
  bool shouldRepaint(covariant SemiCircleLinearGradientGaugePainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.backgroundColor != backgroundColor ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.radius != radius ||
        oldDelegate.center != center;
  }
}
