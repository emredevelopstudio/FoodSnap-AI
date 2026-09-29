import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/hive_service.dart';

class PrivacyConsentDialog extends StatelessWidget {
  static const String privacyPolicyUrl =
      'https://emredevelopstudio.github.io/FoodSnap-AI/privacy.html';

  const PrivacyConsentDialog({super.key});

  /// Öffnet die offizielle Datenschutzerklärung im externen Browser
  static Future<void> openPrivacyPolicy(BuildContext context) async {
    final uri = Uri.parse(privacyPolicyUrl);
    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Konnte Datenschutzerklärung nicht öffnen.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fehler beim Öffnen des Links: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  /// Zeigt den Dialog an. Gibt `true` zurück, wenn zugestimmt wurde, sonst `false`.
  static Future<bool> show(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const PrivacyConsentDialog(),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Farben abgestimmt auf Light & Dark Mode
    const royalBlue = Color(0xFF2563EB);
    final dialogBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final titleColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final textColor = isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569);
    final cardBorder = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final infoBoxBg = isDark ? const Color(0xFF182234) : const Color(0xFFEFF6FF);

    return Dialog(
      backgroundColor: dialogBg,
      elevation: 12,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: cardBorder, width: 1),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Schild-Icon in Accent-Blue Container
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: royalBlue.withValues(alpha: isDark ? 0.22 : 0.12),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: royalBlue.withValues(alpha: isDark ? 0.4 : 0.2),
                    width: 1.5,
                  ),
                ),
                child: const Icon(
                  Icons.security_rounded,
                  color: royalBlue,
                  size: 30,
                ),
              ),
              const SizedBox(height: 14),

              // Titel
              Text(
                'Datenschutz & KI-Nutzung',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.4,
                  color: titleColor,
                ),
              ),
              const SizedBox(height: 10),

              // Beschreibung
              Text(
                'Um deine Mahlzeiten automatisch zu erkennen und Nährwerte präzise zu ermitteln, nutzt FoodSnap AI die Kamera und Galerie deines Geräts.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13.5,
                  height: 1.4,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 10),

              // Info-Kasten: Foto-Übertragung an Google Gemini (muss mit privacy.html übereinstimmen)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: infoBoxBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: royalBlue.withValues(alpha: isDark ? 0.3 : 0.2),
                    width: 1,
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.verified_user_outlined,
                      color: royalBlue,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Zur Erkennung wird dein Foto verschlüsselt an Google (Gemini API) übertragen und dort analysiert. Deine Mahlzeiten und Fotos werden nur auf deinem Gerät gespeichert und nicht verkauft.',
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.35,
                          color: isDark
                              ? const Color(0xFF93C5FD)
                              : const Color(0xFF1E40AF),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),

              // Link-Button zur Datenschutzerklärung
              TextButton.icon(
                onPressed: () =>
                    PrivacyConsentDialog.openPrivacyPolicy(context),
                icon: const Icon(
                  Icons.open_in_new_rounded,
                  size: 15,
                  color: royalBlue,
                ),
                label: const Text(
                  'Datenschutzerklärung lesen',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: royalBlue,
                    decoration: TextDecoration.underline,
                    decorationColor: royalBlue,
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Zwei Buttons: Ablehnen & Zustimmen
              Row(
                children: [
                  // Button 1: Ablehnen (Outlined / Slate-100)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () async {
                        final messenger = ScaffoldMessenger.of(context);
                        await HiveService.setPrivacyAccepted(false);
                        if (!context.mounted) return;
                        Navigator.of(context).pop(false);

                        messenger.showSnackBar(
                          const SnackBar(
                            content: Text(
                              'KI-Scan bleibt deaktiviert. Du kannst der Nutzung jederzeit in den Einstellungen zustimmen.',
                            ),
                            behavior: SnackBarBehavior.floating,
                            duration: Duration(seconds: 4),
                          ),
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        backgroundColor: isDark
                            ? const Color(0xFF262626)
                            : const Color(0xFFF1F5F9),
                        side: BorderSide(
                          color: isDark
                              ? const Color(0xFF3F3F46)
                              : const Color(0xFFCBD5E1),
                          width: 1.2,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        'Ablehnen',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? const Color(0xFF94A3B8)
                              : const Color(0xFF475569),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),

                  // Button 2: Zustimmen (Primary Royal Blue)
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        await HiveService.setPrivacyAccepted(true);
                        if (!context.mounted) return;
                        Navigator.of(context).pop(true);
                      },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        backgroundColor: royalBlue,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        'Zustimmen',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

