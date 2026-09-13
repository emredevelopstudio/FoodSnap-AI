import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../services/hive_service.dart';

enum FastingPlan {
  plan12_12(
    fastHours: 12,
    eatHours: 12,
    displayName: '12:12',
    tagline: 'Sanft / Einsteiger',
    description: 'Optimal für den Einstieg in das Intervallfasten.',
    badge: 'Für Einsteiger',
  ),
  plan14_10(
    fastHours: 14,
    eatHours: 10,
    displayName: '14:10',
    tagline: 'Moderat',
    description: 'Sanfte Fettverbrennung mit ausreichendem Essensfenster.',
    badge: 'Sanfte Fettverbrennung',
  ),
  plan16_8(
    fastHours: 16,
    eatHours: 8,
    displayName: '16:8',
    tagline: 'Standard / Fettabbau',
    description: 'Der beliebteste Allrounder für effektive Fettverbrennung.',
    badge: 'Bester Allrounder',
  ),
  plan18_6(
    fastHours: 18,
    eatHours: 6,
    displayName: '18:6',
    tagline: 'Fortgeschritten',
    description: 'Für erfahrene Faster mit intensiver Ketose.',
    badge: 'Intensive Ketose',
  ),
  plan20_4(
    fastHours: 20,
    eatHours: 4,
    displayName: '20:4',
    tagline: 'Krieger-Diät / Intensiv',
    description: 'Warrior-Fasten für maximale Autophagie und Fettabbau.',
    badge: 'Maximale Autophagie',
  ),
  custom(
    fastHours: 16,
    eatHours: 8,
    displayName: 'Individuell',
    tagline: 'Benutzerdefiniert',
    description: 'Passe Fasten- und Essensfenster flexibel an.',
    badge: 'Benutzerdefiniert',
  );

  final int fastHours;
  final int eatHours;
  final String displayName;
  final String tagline;
  final String description;
  final String badge;

  const FastingPlan({
    required this.fastHours,
    required this.eatHours,
    required this.displayName,
    required this.tagline,
    required this.description,
    required this.badge,
  });

  static FastingPlan fromHours(int fastHours) {
    switch (fastHours) {
      case 12:
        return FastingPlan.plan12_12;
      case 14:
        return FastingPlan.plan14_10;
      case 16:
        return FastingPlan.plan16_8;
      case 18:
        return FastingPlan.plan18_6;
      case 20:
        return FastingPlan.plan20_4;
      default:
        return FastingPlan.custom;
    }
  }
}

class FastingProvider extends ChangeNotifier {
  static const String boxName = HiveService.fastingBoxName;
  static const String isFastingKey = 'is_fasting';
  static const String startTimeKey = 'start_time';
  static const String targetFastingHoursKey = 'target_fasting_hours';
  static const String targetEatingHoursKey = 'target_eating_hours';
  static const String startWeightKey = 'start_weight';
  static const String currentWeightKey = 'current_weight';
  static const String targetWeightKey = 'target_weight';
  static const String selectedPlanKey = 'selected_plan';

  bool _isFasting = false;
  DateTime? _startTime;
  int _targetFastingHours = 16;
  int _targetEatingHours = 8;
  Timer? _timer;

  double? _startWeight;
  double? _currentWeight;
  double? _targetWeight;
  FastingPlan _selectedPlan = FastingPlan.plan16_8;

  bool get isFasting => _isFasting;
  DateTime? get startTime => _startTime;
  int get targetFastingHours => _targetFastingHours;
  int get targetEatingHours => _targetEatingHours;
  double? get startWeight => _startWeight;
  double? get currentWeight => _currentWeight;
  double? get targetWeight => _targetWeight;
  FastingPlan get selectedPlan => _selectedPlan;

  FastingProvider() {
    _loadFromHive();
  }

  Box get _box {
    if (Hive.isBoxOpen(boxName)) {
      return Hive.box(boxName);
    }
    throw StateError('Hive box "$boxName" is not open. Call HiveService.init() first.');
  }

  void _loadFromHive() {
    try {
      if (!Hive.isBoxOpen(boxName)) return;
      final box = _box;
      _isFasting = box.get(isFastingKey, defaultValue: false) as bool;
      final rawStart = box.get(startTimeKey);
      if (rawStart is String && rawStart.isNotEmpty) {
        _startTime = DateTime.tryParse(rawStart);
      } else if (rawStart is int) {
        _startTime = DateTime.fromMillisecondsSinceEpoch(rawStart);
      } else {
        _startTime = null;
      }
      _targetFastingHours = box.get(targetFastingHoursKey, defaultValue: 16) as int;
      _targetEatingHours = box.get(targetEatingHoursKey, defaultValue: 8) as int;

      final savedPlan = box.get(selectedPlanKey);
      if (savedPlan is String) {
        try {
          _selectedPlan = FastingPlan.values.byName(savedPlan);
        } catch (_) {
          _selectedPlan = FastingPlan.fromHours(_targetFastingHours);
        }
      } else {
        _selectedPlan = FastingPlan.fromHours(_targetFastingHours);
      }

      _startWeight = (box.get(startWeightKey) as num?)?.toDouble();
      _currentWeight = (box.get(currentWeightKey) as num?)?.toDouble();
      _targetWeight = (box.get(targetWeightKey) as num?)?.toDouble();

      // Initialisiere Standardwerte aus UserProfile, falls noch nicht vorhanden
      if (_currentWeight == null) {
        try {
          final profile = HiveService.getUserProfile();
          if (profile.weightKg > 0) {
            _currentWeight = profile.weightKg;
            _startWeight = profile.weightKg;
            _targetWeight = (profile.weightKg - 5.0).clamp(30.0, 300.0);
          }
        } catch (_) {}
      }

      if (_isFasting && _startTime != null) {
        _startTimer();
      } else {
        _isFasting = false;
        _startTime = null;
      }
    } catch (e) {
      debugPrint('[FastingProvider] Fehler beim Laden aus Hive: $e');
    }
  }

  Future<void> _saveToHive() async {
    try {
      if (!Hive.isBoxOpen(boxName)) return;
      final box = _box;
      await box.put(isFastingKey, _isFasting);
      await box.put(startTimeKey, _startTime?.toIso8601String());
      await box.put(targetFastingHoursKey, _targetFastingHours);
      await box.put(targetEatingHoursKey, _targetEatingHours);
      await box.put(startWeightKey, _startWeight);
      await box.put(currentWeightKey, _currentWeight);
      await box.put(targetWeightKey, _targetWeight);
      await box.put(selectedPlanKey, _selectedPlan.name);
    } catch (e) {
      debugPrint('[FastingProvider] Fehler beim Speichern in Hive: $e');
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      notifyListeners();
    });
  }

  /// Verstrichene Zeit seit Fastenstart
  Duration get elapsed {
    if (!_isFasting || _startTime == null) return Duration.zero;
    return DateTime.now().difference(_startTime!);
  }

  /// Ziel-Dauer des Fastens
  Duration get targetDuration => Duration(hours: _targetFastingHours);

  /// Verbleibende Fastenzeit
  Duration get remaining {
    if (!_isFasting) return targetDuration;
    final rem = targetDuration - elapsed;
    return rem.isNegative ? Duration.zero : rem;
  }

  /// Fortschritt als Dezimalwert zwischen 0.0 und 1.0
  double get progress {
    if (!_isFasting || targetDuration.inSeconds == 0) return 0.0;
    final p = elapsed.inSeconds / targetDuration.inSeconds;
    return p.clamp(0.0, 1.0);
  }

  /// Gewichts-Differenz zum Zielgewicht
  double? get weightDifference {
    if (_currentWeight == null || _targetWeight == null) return null;
    return _currentWeight! - _targetWeight!;
  }

  /// Gewichts-Fortschritt in Prozent (0.0 bis 1.0)
  double get weightProgress {
    if (_startWeight == null || _currentWeight == null || _targetWeight == null) {
      return 0.0;
    }
    final totalDiff = (_startWeight! - _targetWeight!).abs();
    if (totalDiff == 0) return 1.0;
    final achieved = (_startWeight! - _currentWeight!).abs();
    return (achieved / totalDiff).clamp(0.0, 1.0);
  }

  /// Aktuelle Stoffwechsel-Phase
  String get currentStage {
    final hours = elapsed.inMinutes / 60.0;
    if (hours < 4) {
      return "Blutzucker normalisiert sich";
    } else if (hours < 8) {
      return "Verdauung ruht, Blutzucker sinkt";
    } else if (hours < 12) {
      return "Fettverbrennung startet";
    } else if (hours < 16) {
      return "Ketose & Fettabbau aktiv";
    } else {
      return "Autophagie & Zellregeneration";
    }
  }

  /// Wissenschaftliche Erklärung zur aktuellen Phase
  String get currentStageDescription {
    final hours = elapsed.inMinutes / 60.0;
    if (hours < 4) {
      return "Der Insulinspiegel sinkt. Dein Körper verdaut die letzte Mahlzeit und verarbeitet Nährstoffe.";
    } else if (hours < 8) {
      return "Der Verdauungstrakt ruht sich aus. Der Blutzuckerspiegel stabilisiert sich.";
    } else if (hours < 12) {
      return "Die Glykogenspeicher in der Leber leeren sich. Dein Körper schaltet auf Fettverbrennung um.";
    } else if (hours < 16) {
      return "Ketose ist aktiv. Fett wird zu Ketonkörpern abgebaut und versorgt Gehirn und Muskeln mit Energie.";
    } else {
      return "Autophagie & Zellregeneration! Beschädigte Zellen und Proteine werden abgebaut und erneuert.";
    }
  }

  /// Passendes Icon für die aktuelle Phase
  IconData get currentStageIcon {
    final hours = elapsed.inMinutes / 60.0;
    if (hours < 4) {
      return Icons.water_drop_outlined;
    } else if (hours < 8) {
      return Icons.nightlight_round;
    } else if (hours < 12) {
      return Icons.local_fire_department_rounded;
    } else if (hours < 16) {
      return Icons.bolt_rounded;
    } else {
      return Icons.autorenew_rounded;
    }
  }

  /// Fasten starten
  Future<void> startFasting([int? hours]) async {
    _isFasting = true;
    _startTime = DateTime.now();
    if (hours != null && hours > 0) {
      _targetFastingHours = hours;
      _targetEatingHours = 24 - hours;
      _selectedPlan = FastingPlan.fromHours(hours);
    }
    await _saveToHive();
    _startTimer();
    notifyListeners();
  }

  /// Fasten beenden
  Future<void> stopFasting() async {
    _isFasting = false;
    _startTime = null;
    _timer?.cancel();
    _timer = null;
    await _saveToHive();
    notifyListeners();
  }

  /// Plan auswählen (z. B. FastingPlan.plan16_8 oder custom)
  Future<void> selectPlan(FastingPlan plan, {int? customFastHours}) async {
    _selectedPlan = plan;
    if (plan == FastingPlan.custom && customFastHours != null) {
      final clamped = customFastHours.clamp(1, 23);
      _targetFastingHours = clamped;
      _targetEatingHours = 24 - clamped;
    } else {
      _targetFastingHours = plan.fastHours;
      _targetEatingHours = plan.eatHours;
    }
    await _saveToHive();
    notifyListeners();
  }

  /// Plan anpassen (z. B. 16:8, 14:10, 18:6)
  Future<void> changePlan(int fastHours, int eatHours) async {
    _targetFastingHours = fastHours;
    _targetEatingHours = eatHours;
    _selectedPlan = FastingPlan.fromHours(fastHours);
    await _saveToHive();
    notifyListeners();
  }

  /// Gewicht aktualisieren (aktuell, optional Ziel und Start)
  Future<void> updateWeight(double current, [double? target, double? start]) async {
    _currentWeight = current;
    if (target != null && target > 0) {
      _targetWeight = target;
    }
    if (start != null && start > 0) {
      _startWeight = start;
    } else {
      _startWeight ??= current;
    }
    await _saveToHive();
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _timer = null;
    super.dispose();
  }
}

final fastingProvider = ChangeNotifierProvider<FastingProvider>((ref) {
  final provider = FastingProvider();
  ref.onDispose(() => provider.dispose());
  return provider;
});
