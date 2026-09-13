import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:foodsnap_ai/services/hive_service.dart';
import 'package:foodsnap_ai/services/gemini_service.dart';

void main() {
  late Directory directory;
  setUpAll(() async {
    directory = await Directory.systemTemp.createTemp('foodsnap_scan_limits_');
    Hive.init(directory.path);
    await HiveService.init();
  });
  tearDownAll(() async {
    await Hive.close();
    await directory.delete(recursive: true);
  });
  setUp(() async {
    await Hive.box<Map>(HiveService.settingsBoxName).clear();
  });

  test('only five concurrent scan reservations succeed', () async {
    final today = DateTime(2026, 9, 12, 12);
    final accepted = await Future.wait(List.generate(
        10, (_) => HiveService.tryConsumeDailyScan(today)));
    expect(accepted.where((value) => value).length, 5);
    expect(HiveService.getDailyScansUsed(today), 5);
    expect(HiveService.hasDailyScanAvailable(today), isFalse);
  });

  test('allowance resets at local midnight and survives reopening Hive', () async {
    final today = DateTime(2026, 12, 31, 23, 59);
    for (var i = 0; i < 5; i++) {
      expect(await HiveService.tryConsumeDailyScan(today), isTrue);
    }
    await Hive.box<Map>(HiveService.settingsBoxName).close();
    await HiveService.init();
    expect(HiveService.hasDailyScanAvailable(today), isFalse);
    final tomorrow = DateTime(2027, 1, 1);
    expect(HiveService.getDailyScansUsed(tomorrow), 0);
    expect(await HiveService.tryConsumeDailyScan(tomorrow), isTrue);
    expect(HiveService.getDailyScansUsed(tomorrow), 1);
  });

  test('existing bonus scan is preserved', () async {
    final today = DateTime(2026, 9, 12);
    await HiveService.addDailyBonusScan(today);
    for (var i = 0; i < 6; i++) {
      expect(await HiveService.tryConsumeDailyScan(today), isTrue);
    }
    expect(await HiveService.tryConsumeDailyScan(today), isFalse);
  });

  test('quota error variants map to the friendly message', () {
    for (final message in [
      'HTTP 429', 'RESOURCE_EXHAUSTED', 'ResourceExhausted',
      'Quota exceeded for metric', 'You exceeded your current quota',
      'Rate limit exceeded', 'Too many requests',
    ]) {
      expect(GeminiVisionService.isRateLimitError(Exception(message)), isTrue);
    }
    expect(GeminiVisionService.isRateLimitError(Exception('Invalid API key')), isFalse);
    expect(ScanRateLimitException().toString(),
        'Die Bilderkennung ist gerade kurz ausgelastet. Bitte versuche es in wenigen Sekunden erneut.');
  });

  test('daily scans count tracks daily limit of 5 scans and resets on next day', () async {
    final today = DateTime(2026, 9, 12);
    final tomorrow = DateTime(2026, 9, 13);

    expect(HiveService.getDailyScansCount(today), 0);
    expect(HiveService.hasFreeScansRemaining(today), isTrue);
    expect(HiveService.getRemainingDailyScans(today), 5);

    for (int i = 1; i <= 4; i++) {
      await HiveService.incrementDailyScansCount(today);
      expect(HiveService.getDailyScansCount(today), i);
      expect(HiveService.hasFreeScansRemaining(today), isTrue);
      expect(HiveService.getRemainingDailyScans(today), 5 - i);
    }

    // 5th scan reaches the limit
    await HiveService.incrementDailyScansCount(today);
    expect(HiveService.getDailyScansCount(today), 5);
    expect(HiveService.hasFreeScansRemaining(today), isFalse);
    expect(HiveService.getRemainingDailyScans(today), 0);

    // 6th scan remains blocked
    await HiveService.incrementDailyScansCount(today);
    expect(HiveService.getDailyScansCount(today), 6);
    expect(HiveService.hasFreeScansRemaining(today), isFalse);
    expect(HiveService.getRemainingDailyScans(today), 0);

    // Next day: counter resets automatically to 0 and 5 scans are available again
    expect(HiveService.getDailyScansCount(tomorrow), 0);
    expect(HiveService.hasFreeScansRemaining(tomorrow), isTrue);
    expect(HiveService.getRemainingDailyScans(tomorrow), 5);
  });

  test('pro user status persistence in HiveService', () async {
    expect(HiveService.getIsProUser(), isFalse);
    await HiveService.setIsProUser(true);
    expect(HiveService.getIsProUser(), isTrue);

    // Survives box reload
    await Hive.box<Map>(HiveService.settingsBoxName).close();
    await HiveService.init();
    expect(HiveService.getIsProUser(), isTrue);

    await HiveService.setIsProUser(false);
    expect(HiveService.getIsProUser(), isFalse);
  });

  test('theme mode and isDarkMode persistence in HiveService', () async {
    // Default initial value can be queried
    final initialDark = HiveService.isDarkMode();
    expect(HiveService.getThemeMode(), initialDark ? ThemeMode.dark : ThemeMode.light);

    // Explicitly toggle to light
    await HiveService.setDarkMode(false);
    expect(HiveService.isDarkMode(), isFalse);
    expect(HiveService.getThemeMode(), ThemeMode.light);

    // Survives reload
    await Hive.box<Map>(HiveService.settingsBoxName).close();
    await HiveService.init();
    expect(HiveService.isDarkMode(), isFalse);
    expect(HiveService.getThemeMode(), ThemeMode.light);

    // Toggle to dark
    await HiveService.setDarkMode(true);
    expect(HiveService.isDarkMode(), isTrue);
    expect(HiveService.getThemeMode(), ThemeMode.dark);
  });
}

