import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../l10n/app_localizations.dart';
import '../models/user_profile.dart';
import '../providers/goals_provider.dart';
import '../services/ad_service.dart';
import '../services/purchase_service.dart';

class CalculatorView extends ConsumerStatefulWidget {
  const CalculatorView({super.key});

  @override
  ConsumerState<CalculatorView> createState() => _CalculatorViewState();
}

class _CalculatorViewState extends ConsumerState<CalculatorView> {
  late TextEditingController _heightController;
  late TextEditingController _weightController;
  late TextEditingController _ageController;

  late String _gender;
  late String _activityLevel;
  late String _goal;

  @override
  void initState() {
    super.initState();
    final profile = ref.read(userProfileProvider);

    _heightController = TextEditingController(text: profile.heightCm.toStringAsFixed(0));
    _weightController = TextEditingController(text: profile.weightKg.toStringAsFixed(1));
    _ageController = TextEditingController(text: profile.age.toString());

    _gender = profile.gender == 'w' ? 'w' : 'm';
    _activityLevel = profile.activityLevel;
    _goal = profile.goal;
  }

  @override
  void dispose() {
    _heightController.dispose();
    _weightController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  UserProfile _currentProfile() {
    return UserProfile(
      heightCm: double.tryParse(_heightController.text) ?? 175.0,
      weightKg: double.tryParse(_weightController.text) ?? 75.0,
      age: int.tryParse(_ageController.text) ?? 28,
      gender: _gender,
      activityLevel: _activityLevel,
      goal: _goal,
    );
  }

  void _applyCalculatedTargets(AppLocalizations l10n) {
    final profile = _currentProfile();
    final targets = profile.calculateTargets();

    ref.read(userProfileProvider.notifier).updateProfile(profile, applyToGoals: true);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${l10n.goalApplied}${targets.calories.toInt()} kcal • ${targets.protein.toInt()} g ${l10n.protein}',
        ),
        backgroundColor: const Color(0xFF10B981),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = context.l10n;

    final profile = _currentProfile();
    final calculated = profile.calculateTargets();

    final scaffoldBg = isDark ? const Color(0xFF121212) : const Color(0xFFF4F6F9);
    final cardBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final inputFill = isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF8FAFC);

    final cardShadow = [
      BoxShadow(
        color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
        blurRadius: 10,
        offset: const Offset(0, 4),
      ),
    ];

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        title: Text(
          l10n.calcTitle,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
        ),
        backgroundColor: scaffoldBg,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Obere Fokus-Karte: "Dein Tagesbedarf"
            Container(
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(24),
                boxShadow: cardShadow,
              ),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.dailyRequirement,
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? Colors.grey[400] : Colors.grey[700],
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Zeile mit den Werten (22sp Kalorien bold, 18sp Protein)
                  RichText(
                    text: TextSpan(
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black87,
                        letterSpacing: -0.3,
                      ),
                      children: [
                        TextSpan(
                          text: '${calculated.calories.toInt()} kcal',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        TextSpan(
                          text: '  •  ',
                          style: TextStyle(
                            fontSize: 18,
                            color: isDark ? Colors.grey[500] : Colors.grey[600],
                            fontWeight: FontWeight.normal,
                          ),
                        ),
                        TextSpan(
                          text: '${calculated.protein.toInt()} g ${l10n.protein}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Button "Als Tagesziel übernehmen"
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      icon: const Icon(Icons.check_circle_outline_rounded, size: 20),
                      label: Text(
                        l10n.applyAsGoal,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                      onPressed: () => _applyCalculatedTargets(l10n),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Native Ad Card (Kompakt)
            const _CalculatorNativeAd(),

            // 2. Untere Karte: "Persönliche Daten"
            Container(
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(24),
                boxShadow: cardShadow,
              ),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.personalData,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Geschlecht Toggle
                  Text(
                    l10n.gender,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: isDark ? Colors.grey[300] : const Color(0xFF475569),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildToggleGroup<String>(
                    values: ['m', 'w'],
                    labels: [l10n.male, l10n.female],
                    selectedValue: _gender,
                    onSelected: (val) => setState(() => _gender = val),
                    isDark: isDark,
                  ),
                  const SizedBox(height: 16),

                  // Alter, Größe, Gewicht
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _ageController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: l10n.age,
                            filled: true,
                            fillColor: inputFill,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _heightController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: l10n.height,
                            suffixText: 'cm',
                            suffixStyle: TextStyle(
                              fontSize: 12,
                              color: isDark ? Colors.grey[400] : Colors.grey[600],
                            ),
                            filled: true,
                            fillColor: inputFill,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _weightController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(
                            labelText: l10n.weight,
                            suffixText: 'kg',
                            suffixStyle: TextStyle(
                              fontSize: 12,
                              color: isDark ? Colors.grey[400] : Colors.grey[600],
                            ),
                            filled: true,
                            fillColor: inputFill,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Aktivitätslevel Dropdown
                  Text(
                    l10n.activityLevel,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: isDark ? Colors.grey[300] : const Color(0xFF475569),
                    ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: _activityLevel,
                    isExpanded: true,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: inputFill,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    items: [
                      DropdownMenuItem(
                        value: 'sedentary',
                        child: Text(
                          l10n.activitySedentary,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'light',
                        child: Text(
                          l10n.activityLight,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'moderate',
                        child: Text(
                          l10n.activityModerate,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'very_active',
                        child: Text(
                          l10n.activityVery,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _activityLevel = val);
                    },
                  ),
                  const SizedBox(height: 16),

                  // Ziel Toggle
                  Text(
                    l10n.calcGoal,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: isDark ? Colors.grey[300] : const Color(0xFF475569),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildToggleGroup<String>(
                    values: ['lose', 'maintain', 'gain'],
                    labels: l10n.isEn ? ['Deficit', 'Maintain', 'Surplus'] : ['Defizit', 'Halten', 'Aufbau'],
                    selectedValue: _goal,
                    onSelected: (val) => setState(() => _goal = val),
                    isDark: isDark,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildToggleGroup<T>({
    required List<T> values,
    required List<String> labels,
    required T selectedValue,
    required ValueChanged<T> onSelected,
    required bool isDark,
  }) {
    return Row(
      children: List.generate(values.length, (i) {
        final val = values[i];
        final label = labels[i];
        final isSelected = val == selectedValue;

        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(
              left: i == 0 ? 0 : 4,
              right: i == values.length - 1 ? 0 : 4,
            ),
            child: InkWell(
              onTap: () => onSelected(val),
              borderRadius: BorderRadius.circular(14),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                height: 44,
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFF10B981)
                      : (isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF1F5F9)),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (isSelected) ...[
                      const Icon(Icons.check, size: 16, color: Colors.white),
                      const SizedBox(width: 6),
                    ],
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        color: isSelected
                            ? Colors.white
                            : (isDark ? Colors.grey.shade300 : const Color(0xFF475569)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}

class _CalculatorNativeAd extends ConsumerStatefulWidget {
  const _CalculatorNativeAd();

  @override
  ConsumerState<_CalculatorNativeAd> createState() => _CalculatorNativeAdState();
}

class _CalculatorNativeAdState extends ConsumerState<_CalculatorNativeAd> {
  NativeAd? _nativeAd;
  bool _isLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadAd();
  }

  void _loadAd() {
    final isPro = ref.read(premiumProvider) || PurchaseService.isProUser;
    if (isPro) return;
    if (!Platform.isAndroid && !Platform.isIOS) return;
    if (_nativeAd != null) return;

    final isDark = WidgetsBinding.instance.platformDispatcher.platformBrightness == Brightness.dark;

    final style = NativeTemplateStyle(
      templateType: TemplateType.small,
      mainBackgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      cornerRadius: 16.0,
      callToActionTextStyle: NativeTemplateTextStyle(
        textColor: Colors.white,
        backgroundColor: const Color(0xFF10B981),
        style: NativeTemplateFontStyle.bold,
        size: 13.0,
      ),
      primaryTextStyle: NativeTemplateTextStyle(
        textColor: isDark ? Colors.white : const Color(0xFF0F172A),
        style: NativeTemplateFontStyle.bold,
        size: 13.0,
      ),
      secondaryTextStyle: NativeTemplateTextStyle(
        textColor: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
        style: NativeTemplateFontStyle.normal,
        size: 11.5,
      ),
      tertiaryTextStyle: NativeTemplateTextStyle(
        textColor: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
        style: NativeTemplateFontStyle.normal,
        size: 10.5,
      ),
    );

    _nativeAd = NativeAd(
      adUnitId: AdService.calculatorNativeAdUnitId,
      request: const AdRequest(),
      listener: NativeAdListener(
        onAdLoaded: (ad) {
          debugPrint('>>> [AdMob] Calculator Native Ad loaded successfully!');
          if (!mounted) {
            ad.dispose();
            return;
          }
          setState(() {
            _isLoaded = true;
          });
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint('>>> [AdMob] Calculator Native Ad FAILED to load: code=${error.code}, message=${error.message}, domain=${error.domain}');
          ad.dispose();
          if (mounted) {
            setState(() {
              _nativeAd = null;
              _isLoaded = false;
            });
          }
        },
      ),
      nativeTemplateStyle: style,
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
    ref.listen<bool>(premiumProvider, (previous, next) {
      if (!next && _nativeAd == null) {
        _loadAd();
      } else if (next && _nativeAd != null) {
        _disposeAd();
      }
    });

    final isPro = ref.watch(premiumProvider) || PurchaseService.isProUser;
    if (isPro || !_isLoaded || _nativeAd == null) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE2E8F0),
          width: 0.8,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        height: 90,
        child: AdWidget(ad: _nativeAd!),
      ),
    );
  }
}
