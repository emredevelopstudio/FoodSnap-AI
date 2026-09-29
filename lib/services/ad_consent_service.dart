import 'dart:async';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../core/logging/app_log.dart';

const _tag = 'AdConsent';

/// Werbe-Einwilligung über Googles User Messaging Platform (UMP, IAB TCF).
///
/// In EWR/UK/CH zeigt Google beim ersten Start automatisch den Einwilligungsdialog,
/// den du in AdMob unter „Datenschutz & Mitteilungen“ gestaltest. Außerhalb dieser
/// Regionen ist kein Dialog nötig und [canRequestAds] ist direkt `true`.
class AdConsentService {
  AdConsentService._();

  /// Holt den aktuellen Einwilligungsstatus und zeigt bei Bedarf den Dialog.
  /// Liefert, ob Werbung angefragt werden darf.
  static Future<bool> gatherConsent() async {
    final updated = Completer<void>();
    ConsentInformation.instance.requestConsentInfoUpdate(
      ConsentRequestParameters(),
      () => updated.complete(),
      (FormError error) {
        // Z. B. offline: Mit dem zuletzt gespeicherten Status weitermachen.
        AppLog.w(_tag, 'Status-Update fehlgeschlagen: ${error.message}');
        updated.complete();
      },
    );
    await updated.future;

    final dismissed = Completer<void>();
    await ConsentForm.loadAndShowConsentFormIfRequired((FormError? error) {
      if (error != null) {
        AppLog.w(_tag, 'Dialog-Fehler: ${error.message}');
      }
      dismissed.complete();
    });
    await dismissed.future;

    return canRequestAds();
  }

  static Future<bool> canRequestAds() =>
      ConsentInformation.instance.canRequestAds();

  /// `true`, wenn der Nutzer (z. B. in der EU) die Einwilligung ändern können muss.
  /// Dann MUSS die App einen Einstieg dafür anbieten (Einstellungen).
  static Future<bool> isPrivacyOptionsRequired() async =>
      await ConsentInformation.instance.getPrivacyOptionsRequirementStatus() ==
      PrivacyOptionsRequirementStatus.required;

  /// Öffnet den Google-Dialog erneut, um die Werbe-Einwilligung zu ändern.
  static Future<void> showPrivacyOptionsForm() {
    final done = Completer<void>();
    ConsentForm.showPrivacyOptionsForm((FormError? error) {
      if (error != null) {
        AppLog.w(_tag, 'Datenschutz-Optionen: ${error.message}');
      }
      done.complete();
    });
    return done.future;
  }
}
