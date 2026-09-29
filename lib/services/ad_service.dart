import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'ad_consent_service.dart';
import 'purchase_service.dart';

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

  static const String _realInterstitialUnitIdAndroid = 'ca-app-pub-8940664066373911/1110024346';
  static const String _testInterstitialUnitIdAndroid = 'ca-app-pub-3940256099942544/1033173712';

  static const String _realRewardedUnitIdAndroid = 'ca-app-pub-8940664066373911/9745499163';
  static const String _testRewardedUnitIdAndroid = 'ca-app-pub-3940256099942544/5224354917';

  static InterstitialAd? _interstitialAd;
  static bool _isInterstitialLoading = false;

  static RewardedAd? _rewardedAd;
  static bool _isRewardedLoading = false;

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

  /// Gibt die Interstitial Ad Unit ID basierend auf Modus und Plattform zurück
  static String get interstitialAdUnitId {
    if (kDebugMode || forceTestAds) {
      return _testInterstitialUnitIdAndroid;
    }

    if (Platform.isAndroid) {
      return _realInterstitialUnitIdAndroid;
    } else if (Platform.isIOS) {
      // Test-Interstitial für iOS als Fallback
      return 'ca-app-pub-3940256099942544/4411468910';
    }

    return _testInterstitialUnitIdAndroid;
  }

  /// Gibt die Rewarded Ad Unit ID basierend auf Modus und Plattform zurück
  static String get rewardedAdUnitId {
    if (kDebugMode || forceTestAds) {
      return _testRewardedUnitIdAndroid;
    }

    if (Platform.isAndroid) {
      return _realRewardedUnitIdAndroid;
    } else if (Platform.isIOS) {
      // Test-Rewarded für iOS als Fallback
      return 'ca-app-pub-3940256099942544/1712485313';
    }

    return _testRewardedUnitIdAndroid;
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
      if (!PurchaseService.isProUser) {
        loadInterstitialAd();
        loadRewardedAd();
      }
    } catch (e) {
      debugPrint('Fehler bei der Initialisierung von MobileAds: $e');
    }
  }

  /// Lädt eine Interstitial-Ad vor, falls noch keine geladen ist (und der Nutzer kein Pro hat)
  static void loadInterstitialAd() {
    if (PurchaseService.isProUser || !adsReady.value) return;
    if (_interstitialAd != null || _isInterstitialLoading) return;

    _isInterstitialLoading = true;
    InterstitialAd.load(
      adUnitId: interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          _isInterstitialLoading = false;
          debugPrint('InterstitialAd erfolgreich vorgeladen.');
        },
        onAdFailedToLoad: (error) {
          _interstitialAd = null;
          _isInterstitialLoading = false;
          debugPrint('Fehler beim Vorladen der InterstitialAd: $error');
        },
      ),
    );
  }

  /// Zeigt die Interstitial-Ad an (mit Pro-Bypass: Werbefreiheit für Pro-Käufer)
  static void showInterstitialAd({
    required bool isPremium,
    VoidCallback? onDismissed,
  }) {
    // 1. Wenn Pro aktiv ist: Sofort fortfahren, 100% werbefrei
    if (isPremium || PurchaseService.isProUser) {
      onDismissed?.call();
      return;
    }

    // 2. Wenn Interstitial verfügbar ist
    if (_interstitialAd != null) {
      _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (ad) {
          ad.dispose();
          _interstitialAd = null;
          loadInterstitialAd();
          onDismissed?.call();
        },
        onAdFailedToShowFullScreenContent: (ad, error) {
          debugPrint('Fehler beim Anzeigen der InterstitialAd: $error');
          ad.dispose();
          _interstitialAd = null;
          loadInterstitialAd();
          onDismissed?.call();
        },
      );

      _interstitialAd!.show();
    } else {
      // 3. Wenn keine Ad bereitsteht: Sofort weiterleiten & nachladen
      onDismissed?.call();
      loadInterstitialAd();
    }
  }

  /// Lädt eine Rewarded-Ad vor, falls noch keine geladen ist (und der Nutzer kein Pro hat)
  static void loadRewardedAd() {
    if (PurchaseService.isProUser || !adsReady.value) return;
    if (_rewardedAd != null || _isRewardedLoading) return;

    _isRewardedLoading = true;
    RewardedAd.load(
      adUnitId: rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
          _isRewardedLoading = false;
          debugPrint('RewardedAd erfolgreich vorgeladen.');
        },
        onAdFailedToLoad: (error) {
          _rewardedAd = null;
          _isRewardedLoading = false;
          debugPrint('Fehler beim Vorladen der RewardedAd: $error');
        },
      ),
    );
  }

  /// Zeigt die Rewarded-Ad an und belohnt den Nutzer (oder belohnt Pro-Nutzer direkt ohne Ad)
  static void showRewardedAd({
    required VoidCallback onUserEarnedReward,
    VoidCallback? onDismissed,
    VoidCallback? onFailedToLoad,
  }) {
    if (PurchaseService.isProUser) {
      onUserEarnedReward();
      onDismissed?.call();
      return;
    }

    if (_rewardedAd == null) {
      onFailedToLoad?.call();
      loadRewardedAd();
      return;
    }

    final adToShow = _rewardedAd!;
    _rewardedAd = null;

    adToShow.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        loadRewardedAd();
        onDismissed?.call();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        debugPrint('Fehler beim Anzeigen der RewardedAd: $error');
        ad.dispose();
        loadRewardedAd();
        onDismissed?.call();
      },
    );

    adToShow.show(
      onUserEarnedReward: (ad, reward) {
        onUserEarnedReward();
      },
    );
  }
}
