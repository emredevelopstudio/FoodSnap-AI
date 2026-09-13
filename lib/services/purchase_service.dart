import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'hive_service.dart';

/// StateNotifier für reaktive UI-Aktualisierung bei Kauf oder Wiederherstellung
class ProStatusNotifier extends StateNotifier<bool> {
  ProStatusNotifier() : super(PurchaseService.isPremium) {
    PurchaseService.proStatusNotifier.addListener(_onProStatusChanged);
  }

  void _onProStatusChanged() {
    state = PurchaseService.isPremium;
  }

  void setProStatus(bool value) {
    state = value;
  }

  @override
  void dispose() {
    PurchaseService.proStatusNotifier.removeListener(_onProStatusChanged);
    super.dispose();
  }
}

// Riverpod Provider für den Pro-Status
final premiumProvider = StateNotifierProvider<ProStatusNotifier, bool>((ref) {
  return ProStatusNotifier();
});
final isProUserProvider = premiumProvider;

class PurchaseService {
  static const String _googleApiKey = String.fromEnvironment(
    'REVENUECAT_GOOGLE_API_KEY',
    defaultValue: 'goog_ReDtwghXMNACnVeKLjyJZvsDLgK',
  );
  static const String _appleApiKey = String.fromEnvironment(
    'REVENUECAT_APPLE_API_KEY',
    defaultValue: 'HIER_APPLE_API_KEY_FALLS_VORHANDEN',
  );
  static const String entitlementId = 'pro';
  static const String productId = 'foodsnap_lifetime';

  // Entwickler-Bypass: Bei true werden alle Pro-Features im Debug-Modus forciert
  static const bool _isDevAdmin = false;
  static bool? devOverrideIsPremium;
  static bool _cachedIsPremium = false;

  /// ValueNotifier für globale Listener (Widgets, Services)
  static final ValueNotifier<bool> proStatusNotifier =
      ValueNotifier<bool>(isPremium);

  /// Gibt an, ob Pro aktiv ist (unter Berücksichtigung von Hive-Status und Dev-Simulation)
  /// Ein echter Kauf (HiveService.getIsProUser() == true) schaltet Pro IMMER frei,
  /// völlig egal ob der Entwickler-Schalter an oder aus ist!
  /// Wenn kein echter Kauf vorliegt, kann im Debug-Modus Pro simuliert werden.
  static bool get isPremium {
    // 1. Echter Kauf / Wiederherstellungs-Status aus Hive oder Memory-Cache
    if (HiveService.getIsProUser() || _cachedIsPremium) {
      return true;
    }

    // 2. Entwickler-Simulation im Debug-Modus (greift, wenn noch kein echter Kauf vorliegt)
    if (kDebugMode) {
      if (devOverrideIsPremium == true) {
        return true;
      }
      if (_isDevAdmin) {
        return true;
      }
    }

    return false;
  }

  /// Alias für Pro-Status (Werbefreiheit & unbegrenzte Scans)
  static bool get isProUser => isPremium;

  /// Schaltet den simulierten Pro-Status im Entwicklermodus um und benachrichtigt alle Listener
  static void setDevOverrideIsPremium(bool? value, [dynamic ref]) {
    devOverrideIsPremium = value;
    final active = isPremium;
    proStatusNotifier.value = active;
    if (ref is WidgetRef) {
      ref.read(premiumProvider.notifier).setProStatus(active);
    }
  }

  /// Alias für Entwickler-Bypass
  static void setDevPremiumOverride(bool? value, [dynamic ref]) =>
      setDevOverrideIsPremium(value, ref);

  /// Initialisiert das SDK und registriert den Purchase / CustomerInfo Stream-Listener
  static Future<void> init([dynamic ref]) async {
    // 1. Initialer Stand aus Hive laden
    if (HiveService.getIsProUser()) {
      _cachedIsPremium = true;
      proStatusNotifier.value = true;
      debugPrint('[PurchaseService] Pro-Status aus lokalem Speicher (Hive) geladen: aktiv');
    }

    await Purchases.setLogLevel(kDebugMode ? LogLevel.debug : LogLevel.info);

    PurchasesConfiguration configuration;
    if (Platform.isAndroid) {
      configuration = PurchasesConfiguration(_googleApiKey);
    } else if (Platform.isIOS) {
      configuration = PurchasesConfiguration(_appleApiKey);
    } else {
      return;
    }

    await Purchases.configure(configuration);
    debugPrint('[PurchaseService] Purchases SDK erfolgreich konfiguriert.');

    // 2. Purchase Stream / CustomerInfo Update Listener (fängt z. B. 'Tippen & Kaufen' sauber ab)
    Purchases.addCustomerInfoUpdateListener((customerInfo) async {
      debugPrint('[PurchaseService] CustomerInfo Update empfangen: '
          'allPurchased=${customerInfo.allPurchasedProductIdentifiers}, '
          'activeEntitlements=${customerInfo.entitlements.active.keys}, '
          'nonSubTransactions=${customerInfo.nonSubscriptionTransactions.map((t) => t.productIdentifier).toList()}');

      final isSubbed = checkCustomerInfoIsPro(customerInfo) ||
          customerInfo.allPurchasedProductIdentifiers.contains(productId) ||
          customerInfo.allPurchasedProductIdentifiers.isNotEmpty;

      if (isSubbed) {
        debugPrint('[PurchaseService] Pro-Kauf über Listener bestätigt! Speichere persistent...');
        await HiveService.setIsProUser(true);
        _updateProStatus(true, ref);
      }
    });

    // 3. Status beim Start abfragen
    final isSubbed = await isUserSubscribed();
    if (isSubbed) {
      await HiveService.setIsProUser(true);
      _updateProStatus(true, ref);
    }
  }

  /// Prüft CustomerInfo auf Pro-Berechtigung oder Kauf von 'foodsnap_lifetime'
  static bool checkCustomerInfoIsPro(CustomerInfo customerInfo) {
    final hasProEntitlement =
        customerInfo.entitlements.all[entitlementId]?.isActive ?? false;
    final hasAnyActiveEntitlement =
        customerInfo.entitlements.active.isNotEmpty;
    final hasLifetimeProduct =
        customerInfo.allPurchasedProductIdentifiers.contains(productId) ||
        customerInfo.nonSubscriptionTransactions
            .any((t) => t.productIdentifier == productId);
    final hasActiveSub = customerInfo.activeSubscriptions.isNotEmpty;

    final isPro = hasProEntitlement ||
        hasAnyActiveEntitlement ||
        hasLifetimeProduct ||
        hasActiveSub;

    debugPrint('[PurchaseService] Statusprüfung: '
        'hasProEntitlement=$hasProEntitlement, '
        'hasAnyActiveEntitlement=$hasAnyActiveEntitlement, '
        'hasLifetimeProduct=$hasLifetimeProduct, '
        'hasActiveSub=$hasActiveSub -> isPro=$isPro');

    return isPro;
  }

  /// Prüft, ob der Nutzer Pro-Status besitzt
  static Future<bool> isUserSubscribed([String id = entitlementId]) async {
    // 1. Lokaler Hive-Speicher hat höchste Priorität
    if (HiveService.getIsProUser() || _cachedIsPremium) {
      return true;
    }

    // 2. Entwickler-Bypass im Debug-Modus
    if (kDebugMode) {
      if (devOverrideIsPremium == true) {
        return true;
      }
      if (_isDevAdmin) return true;
    }

    try {
      final customerInfo = await Purchases.getCustomerInfo();
      final isSubbed = checkCustomerInfoIsPro(customerInfo) ||
          customerInfo.allPurchasedProductIdentifiers.contains(productId) ||
          customerInfo.allPurchasedProductIdentifiers.isNotEmpty;

      if (isSubbed) {
        await HiveService.setIsProUser(true);
        _updateProStatus(true);
      }
      return isSubbed;
    } catch (e) {
      debugPrint('[PurchaseService] Fehler beim Prüfen des Abos: $e');
      return HiveService.getIsProUser();
    }
  }

  /// Ruft die aktuellen Paywalls/Offerings ab
  static Future<Offerings?> getOfferings() async {
    try {
      return await Purchases.getOfferings();
    } catch (e) {
      debugPrint('[PurchaseService] Fehler beim Laden der Offerings: $e');
      return null;
    }
  }

  /// Führt einen Kauf für ein Package aus
  static Future<bool> purchasePackage(Package package, [dynamic ref]) async {
    try {
      debugPrint('>>> [DEBUG-KAUF] Starte Purchase-Call mit Package: ${package.identifier}, Product-ID: ${package.storeProduct.identifier}');
      final purchaseResult = await Purchases.purchase(PurchaseParams.package(package));
      debugPrint('>>> [DEBUG-KAUF] Kauf-API erfolgreich zurückgekehrt!');

      // SOFORT VOR JEDER WEITEREN PRÜFUNG:
      devOverrideIsPremium = null;
      await HiveService.setIsProUser(true);
      _cachedIsPremium = true;
      proStatusNotifier.value = true;
      if (ref != null && ref is WidgetRef) {
        ref.read(premiumProvider.notifier).setProStatus(true);
      }
      debugPrint('>>> [DEBUG-KAUF] Hive erfolgreich auf isPro = true gesetzt!');

      try {
        final customerInfo = purchaseResult.customerInfo;
        debugPrint('>>> [DEBUG-KAUF] allPurchasedProductIdentifiers: ${customerInfo.allPurchasedProductIdentifiers}');
        debugPrint('>>> [DEBUG-KAUF] activeSubscriptions: ${customerInfo.activeSubscriptions}');
        debugPrint('>>> [DEBUG-KAUF] entitlements: ${customerInfo.entitlements.all}');
      } catch (e) {
        debugPrint('>>> [DEBUG-KAUF] Hinweis beim Auslesen der customerInfo: $e');
      }

      return true;
    } catch (e, stack) {
      debugPrint('>>> [DEBUG-KAUF-FEHLER] Fehler beim Kauf: $e');
      debugPrint('>>> [DEBUG-KAUF-FEHLER] Stacktrace: $stack');
      return false;
    }
  }

  /// Führt einen Kauf direkt für ein StoreProduct aus (Fallback für 'foodsnap_lifetime')
  static Future<bool> purchaseStoreProduct(StoreProduct product, [dynamic ref]) async {
    try {
      debugPrint('>>> [DEBUG-KAUF] Starte Purchase-Call mit ID: ${product.identifier}');
      final purchaseResult = await Purchases.purchase(PurchaseParams.storeProduct(product));
      debugPrint('>>> [DEBUG-KAUF] Kauf-API erfolgreich zurückgekehrt!');

      // SOFORT VOR JEDER WEITEREN PRÜFUNG:
      devOverrideIsPremium = null;
      await HiveService.setIsProUser(true);
      _cachedIsPremium = true;
      proStatusNotifier.value = true;
      if (ref != null && ref is WidgetRef) {
        ref.read(premiumProvider.notifier).setProStatus(true);
      }
      debugPrint('>>> [DEBUG-KAUF] Hive erfolgreich auf isPro = true gesetzt!');

      try {
        final customerInfo = purchaseResult.customerInfo;
        debugPrint('>>> [DEBUG-KAUF] allPurchasedProductIdentifiers: ${customerInfo.allPurchasedProductIdentifiers}');
        debugPrint('>>> [DEBUG-KAUF] activeSubscriptions: ${customerInfo.activeSubscriptions}');
        debugPrint('>>> [DEBUG-KAUF] entitlements: ${customerInfo.entitlements.all}');
      } catch (e) {
        debugPrint('>>> [DEBUG-KAUF] Hinweis beim Auslesen der customerInfo: $e');
      }

      return true;
    } catch (e, stack) {
      debugPrint('>>> [DEBUG-KAUF-FEHLER] Fehler beim Kauf: $e');
      debugPrint('>>> [DEBUG-KAUF-FEHLER] Stacktrace: $stack');
      return false;
    }
  }

  /// Käufe wiederherstellen
  static Future<bool> restorePurchases([dynamic ref]) async {
    try {
      debugPrint('>>> [DEBUG-RESTORE] Starte Käufe-Wiederherstellung...');
      final customerInfo = await Purchases.restorePurchases();
      debugPrint('>>> [DEBUG-RESTORE] allPurchasedProductIdentifiers: ${customerInfo.allPurchasedProductIdentifiers}');
      debugPrint('>>> [DEBUG-RESTORE] activeSubscriptions: ${customerInfo.activeSubscriptions}');
      debugPrint('>>> [DEBUG-RESTORE] entitlements: ${customerInfo.entitlements.all}');

      final isSubbed = checkCustomerInfoIsPro(customerInfo) ||
          customerInfo.allPurchasedProductIdentifiers.contains(productId) ||
          customerInfo.allPurchasedProductIdentifiers.isNotEmpty;

      if (isSubbed) {
        debugPrint('>>> [DEBUG-RESTORE] Kauf bestätigt! Speichere in Hive...');
        devOverrideIsPremium = null;
        await HiveService.setIsProUser(true);
        _cachedIsPremium = true;
        proStatusNotifier.value = true;
        debugPrint('>>> [DEBUG-RESTORE] Hive erfolgreich auf isPro = true gesetzt!');

        if (ref != null && ref is WidgetRef) {
          ref.read(premiumProvider.notifier).setProStatus(true);
        }
        return true;
      }
      return false;
    } catch (e, stack) {
      debugPrint('>>> [DEBUG-RESTORE-FEHLER] Fehler beim Wiederherstellen: $e\n$stack');
      return false;
    }
  }

  static void _updateProStatus(bool value, [dynamic ref]) {
    try {
      _cachedIsPremium = value;
      proStatusNotifier.value = value;
      if (ref is WidgetRef) {
        ref.read(premiumProvider.notifier).setProStatus(value);
      }
    } catch (e) {
      debugPrint('[PurchaseService] Hinweis beim Aktualisieren des Riverpod-Status: $e');
    }
  }
}