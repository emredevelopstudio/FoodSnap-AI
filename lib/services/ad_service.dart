import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdService {
  static const String _realBannerUnitIdAndroid = 'ca-app-pub-8940664066373911/1463880581';
  static const String _testBannerUnitIdAndroid = 'ca-app-pub-3940256099942544/6300978111';

  static const String _realNativeUnitIdAndroid = 'ca-app-pub-8940664066373911/6692156538';
  static const String _testNativeUnitIdAndroid = 'ca-app-pub-3940256099942544/2247696110';

  static const String _realCalculatorNativeUnitIdAndroid = 'ca-app-pub-8940664066373911/5786268976';
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
    if (kDebugMode) {
      return _testBannerUnitIdAndroid;
    }

    if (Platform.isAndroid) {
      return _realBannerUnitIdAndroid;
    } else if (Platform.isIOS) {
      return 'ca-app-pub-3940256099942544/2934735716';
    }

    return _testBannerUnitIdAndroid;
  }

  /// Gibt die Native Ad Unit ID basierend auf Modus und Plattform zurück
  static String get nativeAdUnitId {
    if (kDebugMode) {
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
    if (kDebugMode) {
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
    if (kDebugMode) {
      return _testInterstitialUnitIdAndroid;
    }

    if (Platform.isAndroid) {
      return _realInterstitialUnitIdAndroid;
    } else if (Platform.isIOS) {
      return 'ca-app-pub-3940256099942544/4411468910';
    }

    return _testInterstitialUnitIdAndroid;
  }

  /// Gibt die Rewarded Ad Unit ID basierend auf Modus und Plattform zurück
  static String get rewardedAdUnitId {
    if (kDebugMode) {
      return _testRewardedUnitIdAndroid;
    }

    if (Platform.isAndroid) {
      return _realRewardedUnitIdAndroid;
    } else if (Platform.isIOS) {
      return 'ca-app-pub-3940256099942544/1712485313';
    }

    return _testRewardedUnitIdAndroid;
  }

  /// Initialisiert das Google Mobile Ads SDK und lädt Interstitial & Rewarded Ads vor
  static Future<void> init() async {
    try {
      await MobileAds.instance.initialize();
      loadInterstitialAd();
      loadRewardedAd();
    } catch (e) {
      debugPrint('[AdService] Fehler bei der Initialisierung von MobileAds: $e');
    }
  }

  /// Lädt eine Interstitial-Ad vor, falls noch keine geladen ist
  static void loadInterstitialAd() {
    if (_interstitialAd != null || _isInterstitialLoading) return;

    _isInterstitialLoading = true;
    debugPrint('[AdService] Lade InterstitialAd...');
    InterstitialAd.load(
      adUnitId: interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          _isInterstitialLoading = false;
          debugPrint('[AdService] InterstitialAd erfolgreich geladen.');
        },
        onAdFailedToLoad: (error) {
          _interstitialAd = null;
          _isInterstitialLoading = false;
          debugPrint('[AdService] Fehler beim Laden der InterstitialAd: $error');
        },
      ),
    );
  }

  /// Zeigt die Interstitial-Ad an (mit Premium-Bypass)
  static void showInterstitialAd({
    required bool isPremium,
    VoidCallback? onDismissed,
  }) {
    // 1. Wenn Premium aktiv ist: Direkt fortfahren
    if (isPremium) {
      onDismissed?.call();
      return;
    }

    // 2. Wenn Interstitial verfügbar ist
    if (_interstitialAd != null) {
      final adToShow = _interstitialAd!;
      _interstitialAd = null;

      adToShow.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (ad) {
          ad.dispose();
          loadInterstitialAd();
          onDismissed?.call();
        },
        onAdFailedToShowFullScreenContent: (ad, error) {
          debugPrint('[AdService] Fehler beim Anzeigen der InterstitialAd: $error');
          ad.dispose();
          loadInterstitialAd();
          onDismissed?.call();
        },
      );

      adToShow.show();
    } else {
      // 3. Wenn keine Ad bereitsteht: Sofort nachladen und weiterleiten
      debugPrint('[AdService] Interstitial not ready, loading now...');
      loadInterstitialAd();
      onDismissed?.call();
    }
  }

  /// Lädt eine Rewarded-Ad vor, falls noch keine geladen ist
  static void loadRewardedAd() {
    if (_rewardedAd != null || _isRewardedLoading) return;

    _isRewardedLoading = true;
    debugPrint('[AdService] Lade RewardedAd...');
    RewardedAd.load(
      adUnitId: rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
          _isRewardedLoading = false;
          debugPrint('[AdService] RewardedAd erfolgreich geladen.');
        },
        onAdFailedToLoad: (error) {
          _rewardedAd = null;
          _isRewardedLoading = false;
          debugPrint('[AdService] Fehler beim Laden der RewardedAd: $error');
        },
      ),
    );
  }

  /// Zeigt die Rewarded-Ad an und belohnt den Nutzer
  static void showRewardedAd({
    required VoidCallback onUserEarnedReward,
    VoidCallback? onDismissed,
    VoidCallback? onFailedToLoad,
  }) {
    if (_rewardedAd == null) {
      debugPrint('[AdService] Rewarded Ad not ready, loading now...');
      loadRewardedAd();
      onFailedToLoad?.call();
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
        debugPrint('[AdService] Fehler beim Anzeigen der RewardedAd: $error');
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

