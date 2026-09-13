import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../services/hive_service.dart';

class FastingProvider extends ChangeNotifier {
  static const String boxName = HiveService.fastingBoxName;
  static const String isFastingKey = 'is_fasting';
  static const String startTimeKey = 'start_time';
  static const String targetFastingHoursKey = 'target_fasting_hours';
  static const String targetEatingHoursKey = 'target_eating_hours';

  bool _isFasting = false;
  DateTime? _startTime;
  int _targetFastingHours = 16;
  int _targetEatingHours = 8;
  Timer? _timer;

  bool get isFasting => _isFasting;
  DateTime? get startTime => _startTime;
  int get targetFastingHours => _targetFastingHours;
  int get targetEatingHours => _targetEatingHours;

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

  /// Plan anpassen (z. B. 16:8, 14:10, 18:6)
  Future<void> changePlan(int fastHours, int eatHours) async {
    _targetFastingHours = fastHours;
    _targetEatingHours = eatHours;
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

