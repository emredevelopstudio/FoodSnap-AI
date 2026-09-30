import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image/image.dart' as img;
import 'package:foodsnap_ai/l10n/app_localizations.dart';
import 'package:foodsnap_ai/services/gemini_vision_service.dart';
import 'package:foodsnap_ai/services/local_vision_service.dart';
import 'package:foodsnap_ai/views/scan_review_view.dart';

Widget _en(Widget home) => ProviderScope(
      child: MaterialApp(
        locale: const Locale('en'),
        supportedLocales: const [Locale('de'), Locale('en')],
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: home,
      ),
    );

void main() {
  testWidgets('Eintrag prüfen ist auf Englisch vollständig englisch', (tester) async {
    tester.view.physicalSize = const Size(412, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final meal = LocalVisionService.createMealEntry(
        displayName: 'Pizza', calories: 266, confidence: 0.9, isRecognized: true);

    await tester.pumpWidget(_en(ScanReviewView(initialMeal: meal)));

    expect(find.text('Review & adjust entry'), findsOneWidget);
    expect(find.text('Save meal to diary'), findsOneWidget);
    for (final de in ['Speichern', 'Kalorien', 'Mahlzeit', 'Zutat', 'Menge', 'Eintrag']) {
      expect(find.textContaining(de), findsNothing, reason: 'deutsches Wort "$de" sichtbar');
    }
    await tester.pumpWidget(const SizedBox.shrink());
  });

  test('KI-Prompt verlangt bei englischer App englische Namen', () async {
    String? sentPrompt;
    final client = MockClient((req) async {
      final body = jsonDecode(req.body) as Map<String, dynamic>;
      sentPrompt = body['contents'][0]['parts'][0]['text'] as String;
      final text = jsonEncode({'meal_name': 'Apple', 'total_calories': 52});
      return http.Response(
          jsonEncode({
            'candidates': [
              {
                'content': {
                  'parts': [
                    {'text': text}
                  ]
                }
              }
            ]
          }),
          200);
    });
    final service = GeminiVisionService(apiKey: 'test', proxyUrl: '', client: client);
    final jpg = Uint8List.fromList(img.encodeJpg(img.Image(width: 4, height: 4)));

    await service.analyzeFoodImage(imageBytes: jpg, english: true);
    expect(sentPrompt, contains('auf ENGLISCH'));

    await service.analyzeFoodImage(imageBytes: jpg);
    expect(sentPrompt, isNot(contains('auf ENGLISCH')));
  });

  test('Gesundheits-Kategorie wird nur für die Anzeige übersetzt', () {
    final en = AppLocalizations(const Locale('en'));
    final de = AppLocalizations(const Locale('de'));
    expect(en.healthCategory('Gesund'), 'Healthy');
    expect(en.healthCategory('Ausgewogen'), 'Balanced');
    expect(de.healthCategory('Gesund'), 'Gesund');
  });
}
