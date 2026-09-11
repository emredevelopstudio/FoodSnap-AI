import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

// Riverpod Provider für den Pro-Status
final premiumProvider = Provider<bool>((ref) {
  return PurchaseService.isPremium;
});

class PurchaseService {
  static const String _googleApiKey = 'goog_ReDtwghXMNACnVeKLjyJZvsDLgK';
  static const String _appleApiKey = 'HIER_APPLE_API_KEY_FALLS_VORHANDEN';
  static const String entitlementId = 'pro';

  static const bool _isDevAdmin = false;
  static bool? devOverrideIsPremium = false;
  static bool _cachedIsPremium = false;

  /// Gibt an, ob Pro aktiv ist (unter Berücksichtigung des Dev-Overrides)
  static bool get isPremium {
    if (_isDevAdmin) return true;
    if (kDebugMode && devOverrideIsPremium != null) {
      return devOverrideIsPremium!;
    }
    return _cachedIsPremium;
  }

  /// Ermöglicht Entwicklern im Debug-Modus das Überschreiben des Pro-Status
  static void setDevPremiumOverride(bool? value) {
    devOverrideIsPremium = value;
  }

  /// Initialisiert das SDK
  static Future<void> init([dynamic ref]) async {
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

    if (ref != null) {
      final isSubbed = await isUserSubscribed();
      _updateRef(ref, isSubbed);
    }
  }

  /// Prüft, ob der Nutzer Pro-Status besitzt
  static Future<bool> isUserSubscribed([String id = entitlementId]) async {
    if (kDebugMode && devOverrideIsPremium != null) {
      return devOverrideIsPremium!;
    }

    try {
      final customerInfo = await Purchases.getCustomerInfo();
      return customerInfo.entitlements.all[id]?.isActive ?? false;
    } catch (e) {
      debugPrint('Fehler beim Prüfen des Abos: $e');
      return false;
    }
  }

  /// Ruft die aktuellen Paywalls/Offerings ab
  static Future<Offerings?> getOfferings() async {
    try {
      return await Purchases.getOfferings();
    } catch (e) {
      debugPrint('Fehler beim Laden der Offerings: $e');
      return null;
    }
  }

  /// Führt einen Kauf aus
  static Future<bool> purchasePackage(Package package, [dynamic ref]) async {
    try {
      // ignore: deprecated_member_use
      final purchaseResult = await Purchases.purchasePackage(package);
      final isSubbed =
          purchaseResult.customerInfo.entitlements.all[entitlementId]?.isActive ??
              false;
      if (ref != null) _updateRef(ref, isSubbed);
      return isSubbed;
    } catch (e) {
      debugPrint('Kauf abgebrochen oder fehlgeschlagen: $e');
      return false;
    }
  }

  /// Käufe wiederherstellen
  static Future<bool> restorePurchases([dynamic ref]) async {
    try {
      final customerInfo = await Purchases.restorePurchases();
      final isSubbed =
          customerInfo.entitlements.all[entitlementId]?.isActive ?? false;
      if (ref != null) _updateRef(ref, isSubbed);
      return isSubbed;
    } catch (e) {
      debugPrint('Fehler beim Wiederherstellen: $e');
      return false;
    }
  }

  static void _updateRef(dynamic ref, bool value) {
    try {
      _cachedIsPremium = value;
      if (ref is WidgetRef) {
        ref.invalidate(premiumProvider);
      }
    } catch (e) {
      debugPrint('Fehler beim Setzen des Riverpod-Status: $e');
    }
  }
}