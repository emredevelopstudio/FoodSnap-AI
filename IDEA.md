# FoodSnap AI (Kalorientracker)

## Projektübersicht
FoodSnap AI ist eine plattformübergreifende mobile Tracking-App (Flutter/Dart & Android/Kotlin) mit lokaler Datenhaltung via Hive und RevenueCat-Abrechnung.

## Kernaufgabe & Status
- **Hauptfunktion:** Schnelles Erfassen von Mahlzeiten und Getränken mit automatischer Berechnung von Kalorien und Makronährstoffen.
- **Vision-Pipeline:** Vollständig autonome, 100 % offline funktionierende Bilderkennung direkt auf dem Gerät ohne Cloud-APIs (kein Gemini, kein OpenAI).
- **Aktuelle Architektur:** MediaPipe Tasks Vision (`tasks-vision`) auf Android via MethodChannel (`com.foodsnap.ai/vision` in `MainActivity.kt`), gekoppelt an den `LocalVisionService` in Dart.
- **Aktuelles Problem:** Gescannte Bilder werden mangels passender Modellbindung oder Mapping-Eintrag noch als "Unbekanntes Lebensmittel" gewertet. Ziel ist die zuverlässige Erkennung von Standard-Lebensmitteln und Getränken (z. B. Wasserflaschen, Obst, Basismahlzeiten) und deren Zuordnung zu präzisen Nährwerten.
