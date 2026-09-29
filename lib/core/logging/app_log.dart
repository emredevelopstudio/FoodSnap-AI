import 'package:flutter/foundation.dart';

/// Zentraler Logger. In Release-Builds komplett stumm (kein Kauf-/Debug-Leak in Logcat).
///
/// Nutzung:
///   AppLog.d('Purchase', 'Status geladen');
///   AppLog.e('Hive', 'Lesen fehlgeschlagen', e, st);
class AppLog {
  AppLog._();

  /// Schaltet zusätzlich alle bestehenden `debugPrint`-Aufrufe im Release stumm.
  /// Einmal ganz oben in `main()` aufrufen.
  static void silenceInRelease() {
    if (kReleaseMode) {
      debugPrint = (String? message, {int? wrapWidth}) {};
    }
  }

  static void d(String tag, String message) {
    if (kDebugMode) debugPrint('[$tag] $message');
  }

  static void w(String tag, String message, [Object? error]) {
    if (kDebugMode) {
      debugPrint('[$tag] WARN: $message${error != null ? ' ($error)' : ''}');
    }
  }

  /// Für abgefangene Fehler, die die App NICHT crashen lassen sollen.
  static void e(String tag, String message,
      [Object? error, StackTrace? stackTrace]) {
    if (!kDebugMode) return;
    debugPrint('[$tag] ERROR: $message${error != null ? ': $error' : ''}');
    if (stackTrace != null) debugPrint(stackTrace.toString());
  }
}
