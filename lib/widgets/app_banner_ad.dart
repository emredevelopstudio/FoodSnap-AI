import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../services/ad_service.dart';
import '../services/purchase_service.dart';

class AppBannerAd extends ConsumerStatefulWidget {
  const AppBannerAd({super.key});

  @override
  ConsumerState<AppBannerAd> createState() => _AppBannerAdState();
}

class _AppBannerAdState extends ConsumerState<AppBannerAd> {
  BannerAd? _bannerAd;
  bool _isLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadBanner();
  }

  void _loadBanner() {
    final isPremium = ref.read(premiumProvider);
    if (isPremium || _bannerAd != null) return;

    _bannerAd = BannerAd(
      adUnitId: AdService.bannerAdUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          debugPrint('>>> [AdMob] Banner loaded successfully!');
          if (!mounted) {
            ad.dispose();
            return;
          }
          setState(() {
            _isLoaded = true;
          });
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint('>>> [AdMob] Banner FAILED to load: code=${error.code}, message=${error.message}, domain=${error.domain}');
          ad.dispose();
          if (mounted) {
            setState(() {
              _bannerAd = null;
              _isLoaded = false;
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
    if (_isLoaded && mounted) {
      setState(() {
        _isLoaded = false;
      });
    } else {
      _isLoaded = false;
    }
  }

  @override
  void dispose() {
    _disposeAd();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<bool>(premiumProvider, (previous, next) {
      if (!next && _bannerAd == null) {
        _loadBanner();
      } else if (next && _bannerAd != null) {
        _disposeAd();
      }
    });

    final isPremium = ref.watch(premiumProvider);
    if (isPremium || !_isLoaded || _bannerAd == null) {
      return const SizedBox.shrink();
    }

    return SafeArea(
      top: false,
      child: Center(
        child: SizedBox(
          width: _bannerAd!.size.width.toDouble(),
          height: _bannerAd!.size.height.toDouble(),
          child: AdWidget(ad: _bannerAd!),
        ),
      ),
    );
  }
}
