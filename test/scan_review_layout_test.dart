import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'helpers/test_meal.dart';
import 'package:foodsnap_ai/views/scan_review_view.dart';

void main() {
  for (final size in [const Size(800, 1280), const Size(1024, 768), const Size(360, 740)]) {
    testWidgets('kein Overflow bei $size', (tester) async {
      final file = (await tester.runAsync(() async {
        final dir = await Directory.systemTemp.createTemp('t_');
        final f = File('${dir.path}/s.jpg');
        await f.writeAsBytes(img.encodeJpg(img.Image(width: 4, height: 4)));
        return f;
      }))!;
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final meal = testMeal();
      await tester.pumpWidget(ProviderScope(child: MaterialApp(home: ScanReviewView(initialMeal: meal, imagePath: file.path))));
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
