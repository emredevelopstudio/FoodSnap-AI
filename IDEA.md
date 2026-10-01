# FoodSnap AI (Kalorientracker)

## Projektübersicht
FoodSnap AI ist eine plattformübergreifende mobile Tracking-App (Flutter/Dart & Android/Kotlin) mit lokaler Datenhaltung via Hive und RevenueCat-Abrechnung.

## Kernaufgabe & Status
- **Hauptfunktion:** Schnelles Erfassen von Mahlzeiten und Getränken mit automatischer Berechnung von Kalorien und Makronährstoffen.
- **Vision-Pipeline:** Fotoanalyse über die Google Gemini API (Direktaufruf per `--dart-define` im Dev-Build, Firebase-Proxy `functions/` für Release), mit Modell-Ausweichkette, Zeitlimits und Abbruch.
- **Aktuelle Architektur:** `GeminiVisionService` (lib/services/gemini_vision_service.dart). Die frühere Offline-Erkennung (MediaPipe/TFLite, `LocalVisionService`) wurde am 30.09.2026 entfernt, da ungenutzt.
