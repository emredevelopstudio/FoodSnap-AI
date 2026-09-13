import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../services/ad_service.dart';
import '../services/hive_service.dart';
import '../services/purchase_service.dart';

class AppNativeAdCard extends ConsumerStatefulWidget {
  final NativeTemplateStyle? customStyle;

  const AppNativeAdCard({
    super.key,
    this.customStyle,
  });

  @override
  ConsumerState<AppNativeAdCard> createState() => _AppNativeAdCardState();
}

class _AppNativeAdCardState extends ConsumerState<AppNativeAdCard> {
  NativeAd? _nativeAd;
  bool _isLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadNativeAd();
  }

  void _loadNativeAd() {
    final isPro = ref.read(premiumProvider) || PurchaseService.isProUser;
    if (isPro) return;
    if (!Platform.isAndroid && !Platform.isIOS) return;
    if (_nativeAd != null) return;

    final isDark = WidgetsBinding.instance.platformDispatcher.platformBrightness == Brightness.dark;

    final defaultTemplateStyle = NativeTemplateStyle(
      templateType: TemplateType.medium,
      mainBackgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      cornerRadius: 16.0,
      callToActionTextStyle: NativeTemplateTextStyle(
        textColor: Colors.white,
        backgroundColor: const Color(0xFF10B981),
        style: NativeTemplateFontStyle.bold,
        size: 15.0,
      ),
      primaryTextStyle: NativeTemplateTextStyle(
        textColor: isDark ? Colors.white : const Color(0xFF0F172A),
        style: NativeTemplateFontStyle.bold,
        size: 15.0,
      ),
      secondaryTextStyle: NativeTemplateTextStyle(
        textColor: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
        style: NativeTemplateFontStyle.normal,
        size: 13.0,
      ),
      tertiaryTextStyle: NativeTemplateTextStyle(
        textColor: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
        style: NativeTemplateFontStyle.normal,
        size: 11.0,
      ),
    );

    _nativeAd = NativeAd(
      adUnitId: AdService.nativeAdUnitId,
      request: const AdRequest(),
      listener: NativeAdListener(
        onAdLoaded: (ad) {
          debugPrint('>>> [AdMob] Native Ad loaded successfully!');
          if (!mounted) {
            ad.dispose();
            return;
          }
          setState(() {
            _isLoaded = true;
          });
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint('>>> [AdMob] Native Ad FAILED to load: code=${error.code}, message=${error.message}, domain=${error.domain}');
          ad.dispose();
          if (mounted) {
            setState(() {
              _nativeAd = null;
              _isLoaded = false;
            });
          }
        },
      ),
      nativeTemplateStyle: widget.customStyle ?? defaultTemplateStyle,
    );

    _nativeAd!.load();
  }

  void _disposeAd() {
    _nativeAd?.dispose();
    _nativeAd = null;
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
    return ValueListenableBuilder<bool>(
      valueListenable: PurchaseService.proStatusNotifier,
      builder: (context, proNotifier, _) {
        final proRiverpod = ref.watch(premiumProvider);
        final isPro = proNotifier ||
            PurchaseService.proStatusNotifier.value ||
            HiveService.getIsProUser() ||
            proRiverpod ||
            PurchaseService.isProUser;

        debugPrint('[AppNativeAdCard] Build aufgerufen - isPro: $isPro');

        if (isPro) {
          _disposeAd();
          return const SizedBox.shrink();
        }

        if (!_isLoaded || _nativeAd == null) {
          return const SizedBox.shrink();
        }

        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;

        return Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? Colors.grey.shade800 : const Color(0xFFE2E8F0),
              width: 0.8,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: SizedBox(
            height: 350,
            child: AdWidget(ad: _nativeAd!),
          ),
        );
      },
    );
  }
}
