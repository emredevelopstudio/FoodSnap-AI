/// Build-Zeit-Konfiguration für Gemini. Enthält KEINE Secrets im Quellcode.
///
/// Empfohlen (kein Key in der App):
///   flutter build appbundle --dart-define=GEMINI_PROXY_URL=https://<region>-<projekt>.cloudfunctions.net/geminiProxy
///
/// Nur für lokale Entwicklung (Key landet im Binary!):
///   flutter run --dart-define-from-file=.env
/// (.env wird dabei NICHT als Asset gebündelt, nur zur Build-Zeit gelesen.)
class ApiKeys {
  ApiKeys._();

  static const String geminiApiKey = String.fromEnvironment(
    'GEMINI_KEY',
    defaultValue: String.fromEnvironment('GEMINI_API_KEY'),
  );
  static const String geminiProxyUrl =
      String.fromEnvironment('GEMINI_PROXY_URL');

  static bool get useProxy => geminiProxyUrl.isNotEmpty;
  static bool get isGeminiConfigured => useProxy || geminiApiKey.isNotEmpty;
}
