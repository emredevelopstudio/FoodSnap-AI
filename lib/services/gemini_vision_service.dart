import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:uuid/uuid.dart';
import '../core/config/api_keys.dart';
import '../core/logging/app_log.dart';
import '../models/meal_entry.dart';
import '../models/meal_item.dart';
import '../models/nutrition_value.dart';
import 'image_mime_type.dart';

const _tag = 'Gemini';

class ScanRateLimitException implements Exception {
  static const message =
      'Die Bilderkennung ist gerade ausgelastet. Bitte versuche es in einer Minute erneut.';

  @override
  String toString() => message;
}

class ScanAnalysisException implements Exception {
  static const message = 'Fehler bei der Analyse. Bitte versuche es erneut.';

  final String customMessage;

  const ScanAnalysisException([this.customMessage = message]);

  @override
  String toString() => customMessage;
}

/// Nutzer hat den Scan abgebrochen – kein Fehler, keine Fehlermeldung.
class ScanCancelledException implements Exception {
  const ScanCancelledException();
}

/// Abbruch-Signal für einen laufenden Scan (z. B. „Abbrechen“-Knopf im Ladedialog).
class ScanCancellation {
  final _completer = Completer<void>();

  bool get isCancelled => _completer.isCompleted;
  Future<void> get whenCancelled => _completer.future;

  void cancel() {
    if (!_completer.isCompleted) _completer.complete();
  }

  void throwIfCancelled() {
    if (isCancelled) throw const ScanCancelledException();
  }
}

/// Gemini-Bildanalyse. Läuft bevorzugt über einen Server-Proxy (GEMINI_PROXY_URL),
/// sodass kein API-Key in der App liegt. Fallback: GEMINI_KEY via --dart-define (nur Dev).
class GeminiVisionService {
  static const String modelName = 'gemini-3.5-flash';

  /// Ausweichkette bei Überlast (503), Rate-Limit (429) oder nicht verfügbarem
  /// Modell (404). Reihenfolge nach Messung vom 30.09.2026 (Foto + echter Prompt):
  /// 3.5-flash ~1,6–3,8 s, 3.5-flash-lite ~1,2 s. 3.7/3.8-flash waren fast immer
  /// überlastet (503, bis 37 s) und kosteten nur Zeit – daher nicht mehr in der Kette.
  static const List<String> fallbackModels = [
    modelName,
    'gemini-3.5-flash-lite',
    'gemini-3.1-flash-lite',
  ];

  /// Minimales „Nachdenken“: bei 3.5-flash ~570 Denk-Tokens und 1–2 s weniger pro Scan.
  /// Von allen Modellen in [fallbackModels] unterstützt (3.7/3.8 würden 400 liefern).
  static const Map<String, dynamic> _fastThinking = {'thinkingLevel': 'minimal'};

  static bool _shouldTryNextModel(int status) =>
      status == 503 || status == 429 || status == 404;

  final String apiKey;
  final String proxyUrl;
  final http.Client _client;

  GeminiVisionService({String? apiKey, String? proxyUrl, http.Client? client})
      : apiKey = (apiKey ?? ApiKeys.geminiApiKey).trim(),
        proxyUrl = (proxyUrl ?? ApiKeys.geminiProxyUrl).trim(),
        _client = client ?? http.Client() {
    if (!isConfigured) {
      AppLog.w(_tag,
          'Kein Key/Proxy gesetzt. Starten mit: flutter run --dart-define-from-file=.env');
    }
  }

  bool get isConfigured => proxyUrl.isNotEmpty || apiKey.isNotEmpty;

  void dispose() => _client.close();

  static bool isRateLimitError(Object error) {
    final message = error.toString().toLowerCase();
    return error is ScanRateLimitException ||
        RegExp(r'\b429\b').hasMatch(message) ||
        message.contains('resource_exhausted') ||
        message.contains('quota') ||
        message.contains('rate limit') ||
        message.contains('too many requests');
  }

  // ---------------------------------------------------------------------------
  // Transport
  // ---------------------------------------------------------------------------

  /// Sendet einen generateContent-Body und liefert den Text des ersten Kandidaten.
  /// Proxy: Body geht 1:1 an die Cloud Function, die den Key serverseitig ergänzt.
  /// Direkt: Key im Header (nicht in der URL → taucht nicht in Logs/Proxies auf).
  /// Direktmodus: bei 503/429 automatisch auf das nächste Modell in [fallbackModels]
  /// ausweichen (der Proxy macht das serverseitig selbst).
  ///
  /// [perModelTimeout]: Zeitlimit pro Modell-Anfrage – bei Überschreitung (Direktmodus)
  /// wird das nächste Modell probiert statt aufzugeben.
  /// [deadline]: harte Obergrenze für den gesamten Aufruf.
  /// [cancel]: bricht sofort ab ([ScanCancelledException]).
  Future<String?> _generate(
    Map<String, dynamic> body,
    Duration perModelTimeout, {
    DateTime? deadline,
    ScanCancellation? cancel,
  }) async {
    final config = Map<String, dynamic>.from(
        body['generationConfig'] as Map? ?? const <String, dynamic>{});
    config.putIfAbsent('thinkingConfig', () => _fastThinking);
    final encoded = jsonEncode({...body, 'generationConfig': config});

    Future<http.Response> send(Uri uri, Map<String, String> headers) {
      cancel?.throwIfCancelled();
      var limit = perModelTimeout;
      if (deadline != null) {
        final remaining = deadline.difference(DateTime.now());
        if (remaining <= Duration.zero) {
          throw TimeoutException('Gesamtzeit für den Scan überschritten');
        }
        if (remaining < limit) limit = remaining;
      }
      final request =
          _client.post(uri, headers: headers, body: encoded).timeout(limit);
      if (cancel == null) return request;
      return Future.any([
        request,
        cancel.whenCancelled
            .then<http.Response>((_) => throw const ScanCancelledException()),
      ]);
    }

    if (proxyUrl.isNotEmpty) {
      final response = await send(
          Uri.parse(proxyUrl), {'Content-Type': 'application/json'});
      return _extractText(response);
    }

    for (var i = 0; i < fallbackModels.length; i++) {
      final model = fallbackModels[i];
      final isLast = i == fallbackModels.length - 1;
      final http.Response response;
      try {
        response = await send(
          Uri.parse(
              'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent'),
          {'Content-Type': 'application/json', 'x-goog-api-key': apiKey},
        );
      } on TimeoutException {
        final deadlineLeft = deadline == null ||
            deadline.difference(DateTime.now()) > Duration.zero;
        if (isLast || !deadlineLeft) rethrow;
        AppLog.w(_tag,
            '$model antwortet nicht rechtzeitig, weiche aus auf ${fallbackModels[i + 1]}');
        continue;
      }

      if (_shouldTryNextModel(response.statusCode) && !isLast) {
        AppLog.w(_tag,
            '$model antwortet ${response.statusCode}, weiche aus auf ${fallbackModels[i + 1]}');
        continue;
      }
      return _extractText(response);
    }
    return null;
  }

  String? _extractText(http.Response response) {
    // 429 = Kontingent, 503 = Google-Überlast → beides dem Nutzer als „ausgelastet“ melden.
    if (response.statusCode == 429 ||
        response.statusCode == 503 ||
        response.body.toLowerCase().contains('resource_exhausted')) {
      throw ScanRateLimitException();
    }
    if (response.statusCode != 200) {
      throw HttpException('HTTP ${response.statusCode}');
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final candidates = decoded['candidates'] as List<dynamic>?;
    if (candidates == null || candidates.isEmpty) return null;
    final parts =
        (candidates.first['content'] as Map<String, dynamic>?)?['parts']
            as List<dynamic>?;
    if (parts == null || parts.isEmpty) return null;
    final text = parts.first['text'] as String?;
    return (text == null || text.trim().isEmpty) ? null : text;
  }

  static Map<String, dynamic> _textRequest(String prompt) => {
        'contents': [
          {
            'parts': [
              {'text': prompt}
            ]
          }
        ],
        'generationConfig': {'response_mime_type': 'application/json'},
      };

  // ---------------------------------------------------------------------------
  // Öffentliche API
  // ---------------------------------------------------------------------------

  /// `true`, wenn das Bild bereits ein JPEG innerhalb von [maxDimension] ist
  /// (z. B. von image_picker mit maxWidth/maxHeight 1024) – dann kein Neu-Kodieren.
  /// Liest nur den Header, dekodiert keine Pixel.
  static bool isAlreadyOptimized(Uint8List bytes, {int maxDimension = 1024}) {
    try {
      final decoder = img.findDecoderForData(bytes);
      if (decoder is! img.JpegDecoder) return false;
      final info = decoder.startDecode(bytes);
      return info != null &&
          info.width <= maxDimension &&
          info.height <= maxDimension;
    } catch (_) {
      return false;
    }
  }

  /// Wie [compressImageIfNeeded], aber ohne die Oberfläche zu blockieren:
  /// schon optimierte Fotos werden direkt übernommen, sonst läuft das
  /// Dekodieren/Kodieren in einem Hintergrund-Isolate.
  static Future<Uint8List> prepareImageForUpload(Uint8List bytes,
      {int maxDimension = 1024, int quality = 85}) async {
    if (isAlreadyOptimized(bytes, maxDimension: maxDimension)) return bytes;
    return compute(
      (Uint8List b) => compressImageIfNeeded(b,
          maxDimension: maxDimension, quality: quality),
      bytes,
    );
  }

  /// Skaliert auf max. [maxDimension] px und komprimiert als JPEG.
  static Uint8List compressImageIfNeeded(Uint8List bytes,
      {int maxDimension = 1024, int quality = 85}) {
    try {
      final image = img.decodeImage(bytes);
      if (image == null) return bytes;

      var processed = image;
      if (image.width > maxDimension || image.height > maxDimension) {
        processed = image.width >= image.height
            ? img.copyResize(image,
                width: maxDimension,
                height: (image.height * maxDimension / image.width).round())
            : img.copyResize(image,
                width: (image.width * maxDimension / image.height).round(),
                height: maxDimension);
      }
      return Uint8List.fromList(img.encodeJpg(processed, quality: quality));
    } catch (e, st) {
      AppLog.e(_tag, 'Bildkompression fehlgeschlagen, sende Original', e, st);
      return bytes;
    }
  }

  /// Schätzt Nährwerte pro 100 g/ml anhand eines Produktnamens.
  Future<Map<String, double>?> estimateProductNutrition(
      String productName) async {
    final cleanName = productName.trim();
    if (cleanName.isEmpty || !isConfigured) return null;

    try {
      final text = await _generate(
        _textRequest(
            'Ermittle durchschnittliche Nährwerte pro 100g/ml für folgendes Lebensmittel: "$cleanName". '
            'Gib ausschließlich ein valides JSON zurück mit: {"calories": number, "protein": number, "carbs": number, "fat": number}.'),
        const Duration(seconds: 8),
      );
      if (text == null) return null;
      final decoded = _decodeJsonObject(text);
      return {
        'calories': parseNutritionValue(decoded['calories']) ?? 0.0,
        'protein': parseNutritionValue(decoded['protein']) ?? 0.0,
        'carbs': parseNutritionValue(decoded['carbs']) ?? 0.0,
        'fat': parseNutritionValue(decoded['fat']) ?? 0.0,
      };
    } catch (e, st) {
      AppLog.e(_tag, 'Nährwert-Schätzung fehlgeschlagen', e, st);
      return null;
    }
  }

  /// Schätzt Produktname und Nährwerte pro 100 g/ml anhand eines Barcodes.
  Future<Map<String, dynamic>?> estimateProductByBarcode(String barcode) async {
    final cleanCode = barcode.trim();
    if (cleanCode.isEmpty || !isConfigured) return null;

    try {
      final text = await _generate(
        _textRequest(
            'Ermittle das Produkt und durchschnittliche Nährwerte pro 100g/ml für folgenden Barcode (EAN/GTIN): "$cleanCode". '
            'Gib ausschließlich ein valides JSON zurück mit: {"name": string, "calories": number, "protein": number, "carbs": number, "fat": number}. '
            'Falls der Barcode unbekannt ist, gib {"name": "Unbekannt", "calories": 0, "protein": 0, "carbs": 0, "fat": 0} zurück.'),
        const Duration(seconds: 8),
      );
      if (text == null) return null;
      final decoded = _decodeJsonObject(text);
      final name = decoded['name']?.toString();
      if (name == null || name == 'Unbekannt') return null;

      final result = <String, dynamic>{
        'name': name,
        'calories': parseNutritionValue(decoded['calories']) ?? 0.0,
        'protein': parseNutritionValue(decoded['protein']) ?? 0.0,
        'carbs': parseNutritionValue(decoded['carbs']) ?? 0.0,
        'fat': parseNutritionValue(decoded['fat']) ?? 0.0,
      };
      final hasValues =
          result.values.whereType<double>().any((value) => value > 0);
      return hasValues ? result : null;
    } catch (e, st) {
      AppLog.e(_tag, 'Barcode-Schätzung fehlgeschlagen', e, st);
      return null;
    }
  }

  /// Einstiegspunkt für den Foto-Scan im Dashboard.
  Future<MealEntry> analyzeMeal(String imagePath,
          {ScanCancellation? cancel, bool english = false}) =>
      analyzeFoodImage(filePath: imagePath, cancel: cancel, english: english);

  /// Zeitlimit pro Modell-Anfrage und harte Obergrenze für den gesamten Scan.
  static const Duration perModelTimeout = Duration(seconds: 12);
  static const Duration scanDeadline = Duration(seconds: 60);

  static const String timeoutMessage =
      'Die Analyse hat zu lange gedauert. Bitte prüfe deine Verbindung und versuche es erneut.';

  static const String notConfiguredMessage =
      'Die KI-Analyse ist in dieser Version nicht konfiguriert.';

  Future<MealEntry> analyzeFoodImage({
    String? filePath,
    Uint8List? imageBytes,
    String? mimeType,
    void Function(String status)? onStatusUpdate,
    ScanCancellation? cancel,
    Duration perModelTimeout = perModelTimeout,
    bool english = false,
    Duration scanDeadline = scanDeadline,
  }) async {
    final deadline = DateTime.now().add(scanDeadline);
    final Uint8List bytes;
    if (imageBytes != null) {
      bytes = imageBytes;
    } else if (filePath != null) {
      final file = File(filePath);
      if (!await file.exists()) {
        throw const FileSystemException('Bilddatei wurde nicht gefunden.');
      }
      bytes = await file.readAsBytes();
    } else {
      throw ArgumentError('Entweder filePath oder imageBytes angeben.');
    }

    if (bytes.isEmpty) {
      throw const FormatException('Die ausgewählte Bilddatei ist leer.');
    }
    if (!isConfigured) {
      throw ScanAnalysisException(kDebugMode
          ? 'Kein Gemini-Key: App mit --dart-define-from-file=.env starten.'
          : notConfiguredMessage);
    }

    final compressed =
        await prepareImageForUpload(bytes, maxDimension: 1024, quality: 85);
    final finalMimeType = !identical(compressed, bytes)
        ? 'image/jpeg'
        : (mimeType ?? detectImageMimeType(bytes, filePath: filePath));

    final body = {
      'contents': [
        {
          'parts': [
            {'text': english ? '$_mealPrompt$_englishOutputRule' : _mealPrompt},
            {
              'inline_data': {
                'mime_type': finalMimeType,
                'data': base64Encode(compressed),
              }
            }
          ]
        }
      ],
      'generationConfig': {'response_mime_type': 'application/json'},
    };

    const maxAttempts = 2;
    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        final text = await _generate(body, perModelTimeout,
            deadline: deadline, cancel: cancel);
        if (text == null) throw const ScanAnalysisException();
        return parseGeminiResponse(text, imagePath: filePath);
      } on FormatException {
        rethrow;
      } on ScanCancelledException {
        rethrow;
      } catch (e, st) {
        AppLog.e(_tag, 'Scan fehlgeschlagen (Versuch $attempt)', e, st);

        final err = e.toString().toLowerCase();
        final retryable = isRateLimitError(e) ||
            e is TimeoutException ||
            err.contains('503') ||
            err.contains('unavailable');
        // Retry nur, wenn inkl. 2 s Pause noch Zeit bis zur Deadline bleibt
        final timeLeft = deadline.difference(DateTime.now()) >
            const Duration(seconds: 5);

        if (retryable && attempt < maxAttempts && timeLeft) {
          onStatusUpdate?.call(
              'Die Bilderkennung ist kurz ausgelastet. Wiederholung in 2 Sekunden...');
          await Future.any([
            Future<void>.delayed(const Duration(seconds: 2)),
            if (cancel != null) cancel.whenCancelled,
          ]);
          cancel?.throwIfCancelled();
          continue;
        }
        if (isRateLimitError(e)) throw ScanRateLimitException();
        if (e is TimeoutException) {
          throw const ScanAnalysisException(timeoutMessage);
        }
        if (e is ScanAnalysisException) rethrow;
        throw const ScanAnalysisException();
      }
    }
    throw const ScanAnalysisException();
  }

  /// Parst die Gemini-Antwort (roh, Markdown-Codeblock oder mit Fließtext).
  /// Unterstützt snake_case (`meal_name`, `total_calories`) und camelCase (`name`, `calories`).
  static MealEntry parseGeminiResponse(String rawText, {String? imagePath}) {
    final decoded = _decodeJsonObject(rawText);

    final rawItems = decoded['items'] ?? decoded['components'] ?? const [];
    if (rawItems is! List) {
      throw const FormatException(
          'Die KI-Antwort enthält eine ungültige Komponentenliste.');
    }
    final items = rawItems.map((item) {
      if (item is! Map) {
        throw const FormatException(
            'Die KI-Antwort enthält eine ungültige Komponente.');
      }
      final map = Map<String, dynamic>.from(item);
      map['amount_grams'] ??= map['weightGrams'] ?? map['weight_grams'];
      return MealItem.fromMap(map);
    }).toList();

    double? num_(List<String> keys) {
      for (final key in keys) {
        final value = parseNutritionValue(decoded[key]);
        if (value != null) return value;
      }
      return null;
    }

    final name = (decoded['meal_name'] ?? decoded['name'])?.toString() ??
        'Erkannte Mahlzeit';
    var calories = num_(['total_calories', 'calories']) ?? 0.0;
    var protein =
        num_(['total_protein_g', 'total_protein', 'protein']) ?? 0.0;
    var carbs = num_(['total_carbs_g', 'total_carbs', 'carbs']) ?? 0.0;
    var fat = num_(['total_fat_g', 'total_fat', 'fat']) ?? 0.0;
    final declaredWeight =
        num_(['total_weight_g', 'weightGrams', 'weight_grams']);

    if (items.isNotEmpty) {
      if (calories == 0) calories = items.fold(0.0, (s, i) => s + i.calories);
      if (protein == 0) protein = items.fold(0.0, (s, i) => s + i.proteinG);
      if (carbs == 0) carbs = items.fold(0.0, (s, i) => s + i.carbsG);
      if (fat == 0) fat = items.fold(0.0, (s, i) => s + i.fatG);
    } else {
      // Keine Einzelkomponenten geliefert → Gesamtwerte als eine Komponente.
      items.add(MealItem(
        name: name,
        estimatedWeightG: declaredWeight ?? 0.0,
        calories: calories,
        proteinG: protein,
        carbsG: carbs,
        fatG: fat,
      ));
    }

    final weight = declaredWeight ??
        items.fold<double>(0.0, (s, i) => s + i.estimatedWeightG);

    return MealEntry(
      id: const Uuid().v4(),
      name: name,
      timestamp: DateTime.now(),
      items: items,
      calories: calories.round(),
      protein: protein,
      carbs: carbs,
      fat: fat,
      weightGrams: weight > 0 ? weight.round() : null,
      localImagePath: imagePath,
      healthScore: num_(['health_score', 'healthScore'])?.toInt(),
      healthCategory:
          (decoded['health_category'] ?? decoded['healthCategory'])?.toString(),
      healthReason:
          (decoded['health_reason'] ?? decoded['healthReason'])?.toString(),
    );
  }

  static Map<String, dynamic> _decodeJsonObject(String rawText) {
    var raw = rawText;
    final fence = RegExp(r'```(?:json)?\s*([\s\S]*?)```').firstMatch(raw);
    if (fence != null) raw = fence.group(1)!;
    raw = raw.trim();

    try {
      final value = jsonDecode(raw);
      if (value is Map<String, dynamic>) return value;
    } on FormatException {
      // Fällt unten auf die {…}-Extraktion zurück.
    }

    final start = raw.indexOf('{');
    final end = raw.lastIndexOf('}');
    if (start != -1 && end > start) {
      try {
        final value = jsonDecode(raw.substring(start, end + 1));
        if (value is Map<String, dynamic>) return value;
      } on FormatException {
        // Wird unten einheitlich gemeldet.
      }
    }
    throw const FormatException(
        'Die KI-Antwort ist unvollständig oder ungültig. Bitte erneut scannen.');
  }

  /// Englische App: Texte auf Englisch, Kategorie bleibt ein fester deutscher Wert
  /// (Filter im Verlauf und Anzeige-Übersetzung hängen daran).
  static const String _englishOutputRule = '''

SPRACHE DER ANTWORT:
Schreibe "meal_name", alle "name"-Felder in "items" und "health_reason" auf ENGLISCH.
"health_category" bleibt exakt einer der Werte "Gesund", "Ausgewogen" oder "Fast Food / Cheat".''';

  static const String _mealPrompt = '''
Du bist ein präziser Ernährungs-, Lebensmittel- und Computer-Vision-Experte.
Analysiere dieses Foto (Mahlzeit, Lebensmittelverpackung, Dose, Flasche oder Tellergericht) und ermittle die exakten Nährwerte und Komponenten.

WICHTIGE ANWEISUNGEN:
1. OCR-PRIORITÄT (Verpackte Lebensmittel & Produkte):
   - Wenn auf dem Bild Text, ein Marken- oder Produktname, Füllmengen (z. B. 250g, 500ml) oder eine Nährwerttabelle sichtbar sind, lies diese exakt ab!
   - Erfinde oder schätze KEINE abweichenden Werte, wenn gedruckte Daten vorliegen.

2. PORTIONS-LOGIK:
   a) Ist eine Portionsgröße oder Gesamtfüllmenge erkennbar, berechne die Nährwerte exakt bezogen auf diese Menge
      (z. B. 500ml-Flasche mit Angaben pro 100ml → alle Werte × 5).
   b) Gib in "meal_name" an, worauf sich die Werte beziehen (z. B. "Cola Zero (500ml Flasche)").

3. TELLERGERICHTE:
   - Ohne Verpackung/Nährwerttabelle realistisch anhand Portionsgröße schätzen; Einzelkomponenten mit Gramm angeben.

Bewertung:
- health_score: 1-10
- health_category: "Gesund", "Ausgewogen" oder "Fast Food / Cheat"
- health_reason: 1 kurzer Satz

Antworte ausschließlich mit einem validen JSON-Objekt. Nährwerte sind Zahlen; Protein/Kohlenhydrate/Fett in Gramm, Energie in kcal.

Formatbeispiel:
{
  "meal_name": "Cola Zero (500ml Flasche)",
  "total_calories": 2,
  "total_protein": 0,
  "total_carbs": 0,
  "total_fat": 0,
  "health_score": 5,
  "health_category": "Ausgewogen",
  "health_reason": "Zuckerfrei und kalorienarm, enthält Süßungsmittel.",
  "items": [
    {"name": "Cola Zero", "amount_grams": 500, "calories": 2, "protein": 0, "carbs": 0, "fat": 0}
  ]
}''';
}
