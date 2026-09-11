import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import '../l10n/app_localizations.dart';
import '../providers/locale_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/meal_provider.dart';
import '../services/hive_service.dart';
import '../services/purchase_service.dart';

class SettingsView extends ConsumerStatefulWidget {
  const SettingsView({super.key});

  @override
  ConsumerState<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends ConsumerState<SettingsView> {
  Future<void> _handleUpgrade() async {
    try {
      final offerings = await Purchases.getOfferings();
      final currentOffering = offerings.current;
      if (currentOffering == null || currentOffering.availablePackages.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Keine Upgrade-Angebote verfügbar.'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
      final package = currentOffering.availablePackages.first;
      final success = await PurchaseService.purchasePackage(package, ref);
      if (!mounted) return;
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Willkommen bei FoodSnap AI Pro!'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Upgrade fehlgeschlagen: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  void _exportBackup(AppLocalizations l10n) {
    final backupJson = HiveService.exportBackupJson();
    Clipboard.setData(ClipboardData(text: backupJson));

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.check_circle, color: Color(0xFF10B981)),
            const SizedBox(width: 8),
            Text(l10n.backupExported),
          ],
        ),
        content: Text(l10n.backupExportedMsg),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showImportDialog(AppLocalizations l10n) {
    final textController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.importTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.importInfo,
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: textController,
              maxLines: 5,
              decoration: const InputDecoration(
                hintText: '{\n  "meals": [...],\n  "goals": {...}\n}',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () async {
              final text = textController.text.trim();
              if (text.isEmpty) return;

              final success = await HiveService.importBackupJson(text);
              if (!ctx.mounted) return;
              Navigator.pop(ctx);

              if (success) {
                ref.read(mealListProvider.notifier).loadMeals();
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(l10n.backupImported),
                    backgroundColor: const Color(0xFF10B981),
                  ),
                );
              } else {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(l10n.backupImportError),
                    backgroundColor: Colors.redAccent,
                  ),
                );
              }
            },
            child: Text(l10n.importBtn),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final currentThemeMode = ref.watch(themeModeProvider);
    final currentLocale = ref.watch(localeProvider);
    final isPremium = ref.watch(premiumProvider);
    final l10n = context.l10n;

    final scaffoldBg = isDark ? const Color(0xFF121212) : const Color(0xFFFBFBF9);
    final cardBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final titleColor = isDark ? Colors.white : const Color(0xFF0F172A);

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        title: Text(l10n.settings),
        backgroundColor: scaffoldBg,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          // FoodSnap AI Pro Card
          Container(
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isPremium
                    ? const Color(0xFF10B981)
                    : (isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE2E8F0)),
                width: isPremium ? 1.5 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    isPremium ? Icons.verified : Icons.workspace_premium_outlined,
                    color: const Color(0xFF10B981),
                    size: 26,
                  ),
                ),
                title: Text(
                  isPremium ? 'FoodSnap AI Pro aktiv' : 'FoodSnap AI Pro freischalten',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15.5),
                ),
                subtitle: Text(
                  isPremium ? 'Werbung dauerhaft deaktiviert' : 'Keine Werbung & unbegrenzte Features',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                ),
                trailing: isPremium
                    ? const Icon(Icons.check_circle, color: Color(0xFF10B981), size: 28)
                    : ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        ),
                        onPressed: _handleUpgrade,
                        child: const Text(
                          'Upgrade',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Sektion 1: Erscheinungsbild
          _buildSectionHeader(l10n.appearance, titleColor),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: SwitchListTile.adaptive(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                secondary: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: (isDark ? Colors.amber : Colors.indigo).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    isDark ? Icons.dark_mode : Icons.light_mode,
                    color: isDark ? Colors.amber : Colors.indigo,
                  ),
                ),
                title: Text(
                  l10n.darkMode,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                subtitle: Text(
                  isDark ? l10n.darkThemeActive : l10n.lightThemeActive,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                value: currentThemeMode == ThemeMode.dark,
                onChanged: (val) {
                  ref.read(themeModeProvider.notifier).toggleTheme(val);
                },
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Sektion 2: Datenverwaltung
          _buildSectionHeader(l10n.dataManagement, titleColor),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: Column(
                children: [
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.upload_file_outlined, color: Color(0xFF10B981)),
                    ),
                    title: Text(
                      l10n.exportBackup,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    subtitle: Text(
                      l10n.exportBackupSub,
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                    trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                    onTap: () => _exportBackup(l10n),
                  ),
                  Divider(height: 1, color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF1F5F9)),
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2563EB).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.download_for_offline_outlined, color: Color(0xFF2563EB)),
                    ),
                    title: Text(
                      l10n.importBackup,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    subtitle: Text(
                      l10n.importBackupSub,
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                    trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                    onTap: () => _showImportDialog(l10n),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Sektion 3: Allgemein
          _buildSectionHeader(l10n.general, titleColor),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: Column(
                children: [
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.language, color: Colors.orange),
                    ),
                    title: Text(
                      l10n.languageSelection,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    subtitle: Text(
                      l10n.appLanguage,
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                    trailing: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: currentLocale.languageCode,
                        items: [
                          DropdownMenuItem(
                            value: 'de',
                            child: Text(l10n.german),
                          ),
                          DropdownMenuItem(
                            value: 'en',
                            child: Text(l10n.english),
                          ),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            ref.read(localeProvider.notifier).setLanguageCode(val);
                          }
                        },
                      ),
                    ),
                  ),
                  Divider(height: 1, color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF1F5F9)),
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.purple.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.info_outline, color: Colors.purple),
                    ),
                    title: Text(
                      l10n.appVersion,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    subtitle: const Text(
                      'FoodSnap AI v1.0.0',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (kDebugMode) ...[
            const SizedBox(height: 24),
            _buildSectionHeader('Entwickler-Optionen', isDark ? Colors.amber.shade400 : Colors.amber.shade800),
            const SizedBox(height: 8),
            Card(
              color: cardBg,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
                side: BorderSide(
                  color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE2E8F0),
                ),
              ),
              child: SwitchListTile.adaptive(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                secondary: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.developer_mode,
                    color: Colors.amber,
                  ),
                ),
                title: const Text(
                  'Pro-Status simulieren (Dev)',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                subtitle: const Text(
                  'Zwischen Free- und Pro-Modus wechseln',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                value: PurchaseService.isPremium,
                onChanged: (val) {
                  setState(() {
                    PurchaseService.setDevPremiumOverride(val);
                  });
                  ref.invalidate(premiumProvider);
                },
              ),
            ),
          ],
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, Color color) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          letterSpacing: -0.3,
          color: color,
        ),
      ),
    );
  }
}
