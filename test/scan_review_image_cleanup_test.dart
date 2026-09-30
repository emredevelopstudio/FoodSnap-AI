import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:foodsnap_ai/services/local_vision_service.dart';
import 'package:foodsnap_ai/views/scan_review_view.dart';

void main() {
  testWidgets('Scan-Foto wird gelöscht, wenn die Prüfansicht ohne Speichern verlassen wird',
      (tester) async {
    final file = (await tester.runAsync(() async {
      final dir = await Directory.systemTemp.createTemp('foodsnap_review_');
      final f = File('${dir.path}/scan.jpg');
      await f.writeAsBytes(img.encodeJpg(img.Image(width: 4, height: 4)));
      return f;
    }))!;

    // Typisches Handy (412 dp breit)
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final meal = LocalVisionService.createMealEntry(
      displayName: 'Pizza',
      calories: 266,
      confidence: 0.9,
      isRecognized: true,
    );

    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(home: ScanReviewView(initialMeal: meal, imagePath: file.path)),
    ));
    // Ansicht verlassen, ohne zu speichern. Im echten Async-Zone ausführen,
    // damit die Datei-I/O im dispose() tatsächlich abläuft.
    await tester.runAsync(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    final exists = await tester.runAsync(() => file.exists());
    expect(exists, isFalse);
  });
}
