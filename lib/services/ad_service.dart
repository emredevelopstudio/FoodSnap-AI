import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'ad_consent_service.dart';

/// Für Widgets mit Anzeigen: ruft [load] erst auf, wenn [AdService.adsReady] true ist
/// (sofort, falls schon bereit – sonst sobald die Einwilligung vorliegt).
mixin AdsReadyGate<T extends StatefulWidget> on State<T> {
  VoidCallback? _pendingLoad;

  void loadWhenAdsReady(VoidCallback load) {
    if (AdService.adsReady.value) {
      load();
      return;
    }
    _pendingLoad = load;
    AdService.adsReady.addListener(_onAdsReady);
  }

  void _onAdsReady() {
    if (!AdService.adsReady.value) return;
    AdService.adsReady.removeListener(_onAdsReady);
    final load = _pendingLoad;
    _pendingLoad = null;
    if (mounted && load != null) load();
  }

  @override
  void dispose() {
    AdService.adsReady.removeListener(_onAdsReady);
    super.dispose();
  }
}

class AdService {
  /// Diagnoseschalter: Bei `true` werden auch im Release-Build die offiziellen
  /// Google-Test-IDs verwendet, um No-Fill-Probleme (Error 3) von Codefehlern zu unterscheiden.
  static const bool forceTestAds = false;

  static const String _realBannerUnitIdAndroid = 'ca-app-pub-9627194765500923/1163571642';
  static const String _testBannerUnitIdAndroid = 'ca-app-pub-3940256099942544/6300978111';

  static const String _realNativeUnitIdAndroid = 'ca-app-pub-9627194765500923/3789734985';
  static const String _testNativeUnitIdAndroid = 'ca-app-pub-3940256099942544/2247696110';

  static const String _realCalculatorNativeUnitIdAndroid = 'ca-app-pub-9627194765500923/6144435584';
  static const String _testCalculatorNativeUnitIdAndroid = 'ca-app-pub-3940256099942544/2247696110';

  /// Gibt die Banner Ad Unit ID basierend auf Modus und Plattform zurück
  static String get bannerAdUnitId {
    if (kDebugMode || forceTestAds) {
      return _testBannerUnitIdAndroid;
    }

    if (Platform.isAndroid) {
      return _realBannerUnitIdAndroid;
    } else if (Platform.isIOS) {
      // Test-Banner für iOS als Fallback
      return 'ca-app-pub-3940256099942544/2934735716';
    }

    return _testBannerUnitIdAndroid;
  }

  /// Gibt die Native Ad Unit ID basierend auf Modus und Plattform zurück
  static String get nativeAdUnitId {
    if (kDebugMode || forceTestAds) {
      return _testNativeUnitIdAndroid;
    }

    if (Platform.isAndroid) {
      return _realNativeUnitIdAndroid;
    } else if (Platform.isIOS) {
      return 'ca-app-pub-3940256099942544/3986624511';
    }

    return _testNativeUnitIdAndroid;
  }

  /// Gibt die Native Ad Unit ID für den Rechner basierend auf Modus und Plattform zurück
  static String get calculatorNativeAdUnitId {
    if (kDebugMode || forceTestAds) {
      return _testCalculatorNativeUnitIdAndroid;
    }

    if (Platform.isAndroid) {
      return _realCalculatorNativeUnitIdAndroid;
    } else if (Platform.isIOS) {
      return 'ca-app-pub-3940256099942544/3986624511';
    }

    return _testCalculatorNativeUnitIdAndroid;
  }

  /// Wird `true`, sobald eine gültige Werbe-Einwilligung vorliegt und das SDK läuft.
  /// Vorher darf KEINE Anzeige angefragt werden (DSGVO/TCF).
  static final ValueNotifier<bool> adsReady = ValueNotifier<bool>(false);

  /// Holt zuerst die Werbe-Einwilligung (UMP) und startet erst danach das SDK.
  /// Nach dem ersten Frame aufrufen, da der Einwilligungsdialog eine sichtbare Activity braucht.
  static Future<void> init() async {
    try {
      final canRequestAds = await AdConsentService.gatherConsent();
      if (!canRequestAds) {
        debugPrint('[AdMob] Keine Werbe-Einwilligung – es werden keine Anzeigen geladen.');
        return;
      }
      await MobileAds.instance.initialize();
      adsReady.value = true;
    } catch (e) {
      debugPrint('Fehler bei der Initialisierung von MobileAds: $e');
    }
  }
}
