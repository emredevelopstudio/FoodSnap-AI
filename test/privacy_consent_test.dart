import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:foodsnap_ai/services/hive_service.dart';
import 'package:foodsnap_ai/widgets/privacy_consent_dialog.dart';

void main() {
  late Directory directory;

  setUpAll(() async {
    directory = await Directory.systemTemp.createTemp('foodsnap_privacy_test_');
    Hive.init(directory.path);
    await HiveService.init();
  });

  tearDownAll(() async {
    await Hive.close();
    try {
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    } catch (_) {}
  });

  setUp(() async {
    await Hive.box<Map>(HiveService.settingsBoxName).clear();
  });

  group('HiveService Privacy Flag', () {
    test('defaults to false when not set', () {
      expect(HiveService.hasAcceptedPrivacy(), isFalse);
    });

    test('sets and returns true when accepted', () async {
      await HiveService.setPrivacyAccepted(true);
      expect(HiveService.hasAcceptedPrivacy(), isTrue);

      final raw = Hive.box<Map>(HiveService.settingsBoxName)
          .get(HiveService.privacyAcceptedKey);
      expect(raw, isNotNull);
      expect(raw!['accepted'], isTrue);
      expect(raw['value'], isTrue);
    });

    test('sets and returns false when declined', () async {
      await HiveService.setPrivacyAccepted(true);
      expect(HiveService.hasAcceptedPrivacy(), isTrue);

      await HiveService.setPrivacyAccepted(false);
      expect(HiveService.hasAcceptedPrivacy(), isFalse);
    });
  });

  group('PrivacyConsentDialog Widget', () {
    testWidgets('renders all required elements correctly', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => PrivacyConsentDialog.show(context),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      );

      // Open dialog
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Verify title & shield icon
      expect(find.text('Datenschutz & KI-Nutzung'), findsOneWidget);
      expect(find.byIcon(Icons.security_rounded), findsOneWidget);

      // Verify description & local on-device ML info
      expect(
        find.textContaining('lokal und offline auf deinem Gerät verarbeitet'),
        findsOneWidget,
      );

      // Verify link button
      expect(find.text('Datenschutzerklärung lesen'), findsOneWidget);

      // Verify action buttons
      expect(find.text('Ablehnen'), findsOneWidget);
      expect(find.text('Zustimmen'), findsOneWidget);
    });

    testWidgets('tapping Zustimmen saves true and closes dialog', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      bool? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () async {
                    result = await PrivacyConsentDialog.show(context);
                  },
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Tap Zustimmen inside runAsync because Hive writes to disk
      await tester.runAsync(() async {
        await tester.tap(find.text('Zustimmen'));
        await Future.delayed(const Duration(milliseconds: 100));
      });
      await tester.pumpAndSettle();

      // Dialog is dismissed and result is true
      expect(find.text('Datenschutz & KI-Nutzung'), findsNothing);
      expect(result, isTrue);
      expect(HiveService.hasAcceptedPrivacy(), isTrue);
    });

    testWidgets('tapping Ablehnen saves false, closes dialog and shows SnackBar',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      bool? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () async {
                    result = await PrivacyConsentDialog.show(context);
                  },
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Tap Ablehnen inside runAsync because Hive writes to disk
      await tester.runAsync(() async {
        await tester.tap(find.text('Ablehnen'));
        await Future.delayed(const Duration(milliseconds: 100));
      });
      await tester.pump(); // Start dismiss animation
      await tester.pump(const Duration(milliseconds: 500)); // Finish dialog animation

      // Dialog is dismissed and result is false
      expect(find.text('Datenschutz & KI-Nutzung'), findsNothing);
      expect(result, isFalse);
      expect(HiveService.hasAcceptedPrivacy(), isFalse);

      // SnackBar explaining AI scanning remains disabled
      expect(
        find.textContaining('KI-Scan bleibt deaktiviert'),
        findsOneWidget,
      );
    });
  });
}
