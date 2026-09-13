import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../services/ad_service.dart';
import '../services/hive_service.dart';
import '../services/purchase_service.dart';

class AdBannerWidget extends ConsumerStatefulWidget {
  const AdBannerWidget({super.key});

  @override
  ConsumerState<AdBannerWidget> createState() => _AdBannerWidgetState();
}

class _AdBannerWidgetState extends ConsumerState<AdBannerWidget> {
  BannerAd? _bannerAd;
  bool _isAdLoaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _checkAndLoadAd();
  }

  void _checkAndLoadAd() {
    final isPremium = ref.read(premiumProvider);
    if (isPremium) {
      _disposeAd();
      return;
    }

    if (_bannerAd == null) {
      _loadBannerAd();
    }
  }

  void _loadBannerAd() {
    _bannerAd = BannerAd(
      adUnitId: AdService.bannerAdUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (!mounted) {
            ad.dispose();
            return;
          }
          setState(() {
            _isAdLoaded = true;
          });
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint(
            '[AdBanner] BannerAd failed to load - Code: ${error.code}, Message: ${error.message}, Domain: ${error.domain}',
          );
          ad.dispose();
          if (mounted) {
            setState(() {
              _bannerAd = null;
              _isAdLoaded = false;
            });
          }
        },
      ),
    );

    _bannerAd!.load();
  }

  void _disposeAd() {
    _bannerAd?.dispose();
    _bannerAd = null;
    if (_isAdLoaded && mounted) {
      setState(() {
        _isAdLoaded = false;
      });
    } else {
      _isAdLoaded = false;
    }
  }

  @override
  void dispose() {
    _disposeAd();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: PurchaseService.proStatusNotifier,
      builder: (context, proNotifier, _) {
        final proRiverpod = ref.watch(premiumProvider);
        final isPremium = proNotifier ||
            PurchaseService.proStatusNotifier.value ||
            HiveService.getIsProUser() ||
            proRiverpod ||
            PurchaseService.isProUser;

        debugPrint('[AdBannerWidget] Build aufgerufen - isPro: $isPremium');

        // Premium-Nutzer sehen niemals Werbung
        if (isPremium) {
          _disposeAd();
          return const SizedBox.shrink();
        }

        if (!_isAdLoaded || _bannerAd == null) {
          return const SizedBox.shrink();
        }

        return SafeArea(
          top: false,
          child: Container(
            alignment: Alignment.center,
            width: _bannerAd!.size.width.toDouble(),
            height: _bannerAd!.size.height.toDouble(),
            child: AdWidget(ad: _bannerAd!),
          ),
        );
      },
    );
  }
}
