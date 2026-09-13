import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:foodsnap_ai/providers/fasting_provider.dart';
import 'package:foodsnap_ai/services/hive_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('fasting_test_');
    Hive.init(tempDir.path);
    await Hive.openBox(HiveService.fastingBoxName);
  });

  tearDownAll(() async {
    await Hive.close();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  setUp(() async {
    final box = Hive.box(HiveService.fastingBoxName);
    await box.clear();
  });

  test('FastingProvider starts with default inactive state', () {
    final provider = FastingProvider();
    expect(provider.isFasting, isFalse);
    expect(provider.startTime, isNull);
    expect(provider.targetFastingHours, 16);
    expect(provider.targetEatingHours, 8);
    expect(provider.elapsed, Duration.zero);
    expect(provider.progress, 0.0);
    expect(provider.remaining, const Duration(hours: 16));
    expect(provider.currentStage, 'Blutzucker normalisiert sich');
    provider.dispose();
  });

  test('FastingProvider startFasting updates state, starts timer and persists', () async {
    final provider = FastingProvider();
    await provider.startFasting(18);

    expect(provider.isFasting, isTrue);
    expect(provider.startTime, isNotNull);
    expect(provider.targetFastingHours, 18);
    expect(provider.targetEatingHours, 6);
    expect(provider.targetDuration, const Duration(hours: 18));

    // Verify persistence in Hive
    final box = Hive.box(HiveService.fastingBoxName);
    expect(box.get(FastingProvider.isFastingKey), isTrue);
    expect(box.get(FastingProvider.targetFastingHoursKey), 18);
    expect(box.get(FastingProvider.targetEatingHoursKey), 6);
    expect(box.get(FastingProvider.startTimeKey), isNotNull);

    provider.dispose();
  });

  test('FastingProvider stopFasting resets state and persists', () async {
    final provider = FastingProvider();
    await provider.startFasting(16);
    expect(provider.isFasting, isTrue);

    await provider.stopFasting();
    expect(provider.isFasting, isFalse);
    expect(provider.startTime, isNull);
    expect(provider.elapsed, Duration.zero);
    expect(provider.progress, 0.0);

    final box = Hive.box(HiveService.fastingBoxName);
    expect(box.get(FastingProvider.isFastingKey), isFalse);
    expect(box.get(FastingProvider.startTimeKey), isNull);

    provider.dispose();
  });

  test('FastingProvider changePlan updates hours and persists', () async {
    final provider = FastingProvider();
    await provider.changePlan(14, 10);
    expect(provider.targetFastingHours, 14);
    expect(provider.targetEatingHours, 10);

    final box = Hive.box(HiveService.fastingBoxName);
    expect(box.get(FastingProvider.targetFastingHoursKey), 14);
    expect(box.get(FastingProvider.targetEatingHoursKey), 10);

    provider.dispose();
  });

  test('FastingProvider stages reflect elapsed hours correctly', () async {
    final box = Hive.box(HiveService.fastingBoxName);
    
    // Simulate 5 hours elapsed
    final fiveHoursAgo = DateTime.now().subtract(const Duration(hours: 5));
    await box.put(FastingProvider.isFastingKey, true);
    await box.put(FastingProvider.startTimeKey, fiveHoursAgo.toIso8601String());
    await box.put(FastingProvider.targetFastingHoursKey, 16);

    final provider = FastingProvider();
    expect(provider.isFasting, isTrue);
    expect(provider.elapsed.inHours, greaterThanOrEqualTo(5));
    expect(provider.currentStage, 'Verdauung ruht, Blutzucker sinkt');
    expect(provider.progress, greaterThan(0.3));

    // Simulate 13 hours elapsed
    final thirteenHoursAgo = DateTime.now().subtract(const Duration(hours: 13));
    await box.put(FastingProvider.startTimeKey, thirteenHoursAgo.toIso8601String());
    final provider13 = FastingProvider();
    expect(provider13.currentStage, 'Ketose & Fettabbau aktiv');

    // Simulate 17 hours elapsed
    final seventeenHoursAgo = DateTime.now().subtract(const Duration(hours: 17));
    await box.put(FastingProvider.startTimeKey, seventeenHoursAgo.toIso8601String());
    final provider17 = FastingProvider();
    expect(provider17.currentStage, 'Autophagie & Zellregeneration');
    expect(provider17.progress, 1.0);
    expect(provider17.remaining, Duration.zero);

    provider.dispose();
    provider13.dispose();
    provider17.dispose();
  });
}

