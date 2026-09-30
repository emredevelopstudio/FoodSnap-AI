/// Build-Zeit-Konfiguration für Gemini. Enthält KEINE Secrets im Quellcode.
///
/// Empfohlen (kein Key in der App):
///   flutter build appbundle --dart-define=GEMINI_PROXY_URL=https://<region>-<projekt>.cloudfunctions.net/geminiProxy
///
/// Lokale Entwicklung: einfach `flutter run` / `flutter build` – der Android-Build
/// (android/app/build.gradle.kts) liest ../.env und gibt die Werte automatisch als
/// dart-define weiter. Der Key landet dabei im Binary → solche Builds nicht in den Store.
/// (.env wird NICHT als Asset gebündelt, nur zur Build-Zeit gelesen.)
class ApiKeys {
  ApiKeys._();

  // `final` statt `const`: verhindert, dass der Compiler den Wert in andere Dateien
  // einkopiert – sonst könnte ein Hot Reload den (dort leeren) Wert übernehmen.
  // ignore: prefer_const_declarations
  static final String geminiApiKey = const String.fromEnvironment(
    'GEMINI_KEY',
    defaultValue: String.fromEnvironment('GEMINI_API_KEY'),
  );
  static const String geminiProxyUrl =
      String.fromEnvironment('GEMINI_PROXY_URL');

  static bool get useProxy => geminiProxyUrl.isNotEmpty;
  static bool get isGeminiConfigured => useProxy || geminiApiKey.isNotEmpty;
}
