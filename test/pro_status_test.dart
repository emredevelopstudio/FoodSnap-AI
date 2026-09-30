import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:foodsnap_ai/services/hive_service.dart';
import 'package:foodsnap_ai/services/purchase_service.dart';

void main() {
  late Directory directory;

  setUpAll(() async {
    directory = await Directory.systemTemp.createTemp('foodsnap_pro_test_');
    Hive.init(directory.path);
    await HiveService.init();
  });

  tearDownAll(() async {
    await Hive.close();
    if (await directory.exists()) await directory.delete(recursive: true);
  });

  setUp(() async {
    await Hive.box<Map>(HiveService.settingsBoxName).clear();
    PurchaseService.setDevOverrideIsPremium(null);
  });

  test('Echter Kauf gespeichert → Pro', () async {
    await HiveService.setIsProUser(true);
    expect(PurchaseService.isProUser, isTrue);
  });

  test('Dev-Schalter AUS überschreibt echten Kauf (Debug) → Free', () async {
    await HiveService.setIsProUser(true);
    PurchaseService.setDevOverrideIsPremium(false);
    expect(PurchaseService.isProUser, isFalse);
    expect(PurchaseService.proStatusNotifier.value, isFalse);
  });

  test('Dev-Schalter AN ohne Kauf → Pro', () {
    PurchaseService.setDevOverrideIsPremium(true);
    expect(PurchaseService.isProUser, isTrue);
  });

  test('Kein Kauf, kein Schalter → Free', () {
    expect(PurchaseService.isProUser, isFalse);
  });
}
