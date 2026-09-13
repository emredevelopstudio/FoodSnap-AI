import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import '../services/hive_service.dart';
import '../services/purchase_service.dart';

class ProUpgradeSheet extends ConsumerStatefulWidget {
  final String? customMessage;

  const ProUpgradeSheet({super.key, this.customMessage});

  static Future<void> show(BuildContext context, {String? customMessage}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ProUpgradeSheet(customMessage: customMessage),
    );
  }

  @override
  ConsumerState<ProUpgradeSheet> createState() => _ProUpgradeSheetState();
}

class _ProUpgradeSheetState extends ConsumerState<ProUpgradeSheet> {
  bool _isLoading = false;
  bool _hasHandledSuccess = false;

  void _onPurchaseSuccess({String? message}) {
    if (_hasHandledSuccess) return;
    _hasHandledSuccess = true;
    if (mounted) {
      final messenger = ScaffoldMessenger.of(context);
      final navigator = Navigator.of(context);
      navigator.pop();
      messenger.showSnackBar(
        SnackBar(
          content: Text(message ?? 'FoodSnap AI Pro erfolgreich aktiviert!'),
          backgroundColor: const Color(0xFF10B981),
        ),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    PurchaseService.proStatusNotifier.addListener(_onProNotifierChanged);
  }

  void _onProNotifierChanged() {
    if (PurchaseService.proStatusNotifier.value || HiveService.getIsProUser()) {
      _onPurchaseSuccess();
    }
  }

  @override
  void dispose() {
    PurchaseService.proStatusNotifier.removeListener(_onProNotifierChanged);
    super.dispose();
  }

  Future<void> _handlePurchase() async {
    debugPrint('>>> [DEBUG-KAUF] Upgrade-Button gedrückt!');
    setState(() => _isLoading = true);
    try {
      bool success = false;
      debugPrint('>>> [DEBUG-KAUF] Rufe Purchases.getOfferings() ab...');
      final offerings = await Purchases.getOfferings();
      debugPrint('>>> [DEBUG-KAUF] Gefundene Offerings: ${offerings.all.keys}');

      final current = offerings.current;
      debugPrint('>>> [DEBUG-KAUF] Current Offering: ${current?.identifier}, Packages: ${current?.availablePackages.map((p) => '${p.identifier} (${p.storeProduct.identifier})').toList()}');

      if (current != null && current.availablePackages.isNotEmpty) {
        final package = current.availablePackages.first;
        debugPrint('>>> [DEBUG-KAUF] Übergebe Package an RevenueCat: ${package.identifier} (Product: ${package.storeProduct.identifier})');
        success = await PurchaseService.purchasePackage(package, ref);
      } else {
        debugPrint('>>> [DEBUG-KAUF] Kein Offering-Package verfügbar. Fallback auf getProducts() für ID: ${PurchaseService.productId}');
        List<StoreProduct> products = await Purchases.getProducts(
          [PurchaseService.productId],
          productCategory: ProductCategory.nonSubscription,
        );
        if (products.isEmpty) {
          debugPrint('>>> [DEBUG-KAUF] Nicht als nonSubscription gefunden. Probiere subscription...');
          products = await Purchases.getProducts(
            [PurchaseService.productId],
            productCategory: ProductCategory.subscription,
          );
        }
        debugPrint('>>> [DEBUG-KAUF] Gefundene StoreProducts: ${products.map((p) => '${p.identifier} (${p.priceString})').toList()}');

        if (products.isNotEmpty) {
          final product = products.first;
          debugPrint('>>> [DEBUG-KAUF] Übergebe StoreProduct an RevenueCat: ${product.identifier}');
          success = await PurchaseService.purchaseStoreProduct(product, ref);
        } else {
          debugPrint('>>> [DEBUG-KAUF-FEHLER] Weder Offering noch StoreProduct in Google Play gefunden!');
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Keine Upgrade-Angebote verfügbar.'),
              backgroundColor: Colors.orange,
            ),
          );
          setState(() => _isLoading = false);
          return;
        }
      }

      if (!mounted) return;
      setState(() => _isLoading = false);

      debugPrint('>>> [DEBUG-KAUF] Ergebnis: success=$success, isProUser=${PurchaseService.isProUser}, Hive=${HiveService.getIsProUser()}');
      if (success || PurchaseService.isProUser || HiveService.getIsProUser()) {
        _onPurchaseSuccess();
      }
    } catch (e, stack) {
      debugPrint('>>> [DEBUG-KAUF-FEHLER] Fehler beim Kauf: $e');
      debugPrint('>>> [DEBUG-KAUF-FEHLER] Stacktrace: $stack');
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Kauf fehlgeschlagen: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  Future<void> _handleRestore() async {
    setState(() => _isLoading = true);
    try {
      debugPrint('[Purchase] Starte Wiederherstellung aus Paywall-Sheet...');
      final isPremium = await PurchaseService.restorePurchases(ref);
      if (!mounted) return;
      setState(() => _isLoading = false);
      if (isPremium || PurchaseService.isProUser || HiveService.getIsProUser()) {
        _onPurchaseSuccess(message: 'Deine Pro-Version wurde erfolgreich wiederhergestellt!');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Keine aktiven Käufe gefunden.'),
          ),
        );
      }
    } catch (e, stack) {
      debugPrint('[Purchase-FEHLER] Wiederherstellung fehlgeschlagen: $e\n$stack');
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Wiederherstellung fehlgeschlagen: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<bool>(premiumProvider, (previous, next) {
      if (next) {
        _onPurchaseSuccess();
      }
    });

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade400,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.workspace_premium_rounded,
                color: Color(0xFF10B981),
                size: 40,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'FoodSnap AI Pro',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.customMessage ??
                  'Schalte alle Premium-Features frei und genieße eine werbefreie Erfahrung.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13.5,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                fontWeight: widget.customMessage != null ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
            const SizedBox(height: 20),
            _buildFeatureRow(Icons.all_inclusive_rounded, 'Unbegrenzte KI-Mahlzeiten-Scans'),
            _buildFeatureRow(Icons.block_rounded, '100 % Werbefreiheit (keine Banner, keine Einblendungen)'),
            _buildFeatureRow(Icons.bolt_rounded, 'Schnellere KI-Scan-Latenz & priorisierte Analysen'),
            _buildFeatureRow(Icons.auto_graph_rounded, 'Detaillierte Nährwert- & Gesundheitsanalyse'),
            _buildFeatureRow(Icons.cloud_done_outlined, 'Prioritäts-Serverzugang'),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                onPressed: _isLoading ? null : _handlePurchase,
                child: _isLoading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      )
                    : const Text(
                        'Jetzt für 2,99 € freischalten',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: _isLoading ? null : _handleRestore,
              child: Text(
                'Käufe wiederherstellen',
                style: TextStyle(
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF10B981), size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}

