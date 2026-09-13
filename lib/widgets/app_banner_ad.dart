import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../services/ad_service.dart';
import '../services/hive_service.dart';
import '../services/purchase_service.dart';

class AppBannerAd extends ConsumerStatefulWidget {
  const AppBannerAd({super.key});

  @override
  ConsumerState<AppBannerAd> createState() => _AppBannerAdState();
}

class _AppBannerAdState extends ConsumerState<AppBannerAd> {
  BannerAd? _bannerAd;
  bool _isLoaded = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (!PurchaseService.isProUser) {
      _loadBanner();
    }
  }

  void _loadBanner() {
    final isPro = PurchaseService.isProUser || (mounted && ref.read(premiumProvider));
    if (isPro || _bannerAd != null || _isLoading) return;
    _isLoading = true;

    _bannerAd = BannerAd(
      adUnitId: AdService.bannerAdUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          debugPrint('>>> [AdMob] Banner loaded successfully!');
          _isLoading = false;
          if (!mounted) {
            ad.dispose();
            return;
          }
          if (PurchaseService.isProUser) {
            ad.dispose();
            _bannerAd = null;
            _isLoaded = false;
            return;
          }
          setState(() {
            _isLoaded = true;
          });
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint('>>> [AdMob] Banner FAILED to load: code=${error.code}, message=${error.message}, domain=${error.domain}');
          _isLoading = false;
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
    _isLoaded = false;
    _isLoading = false;
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
        final isPro = proNotifier ||
            PurchaseService.proStatusNotifier.value ||
            HiveService.getIsProUser() ||
            proRiverpod ||
            PurchaseService.isProUser;

        debugPrint('[AppBannerAd] Build aufgerufen - isPro: $isPro');

        if (isPro) {
          _disposeAd();
          return const SizedBox.shrink();
        }

        // Falls Nutzer nicht Pro ist und noch kein Banner existiert: jetzt nachgeladen
        if (_bannerAd == null && !_isLoading) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && !PurchaseService.isProUser && _bannerAd == null && !_isLoading) {
              _loadBanner();
            }
          });
        }

        if (!_isLoaded || _bannerAd == null) {
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
      },
    );
  }
}
