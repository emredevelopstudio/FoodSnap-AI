import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodsnap_ai/widgets/pro_upgrade_sheet.dart';

void main() {
  testWidgets('Pro-Angebot: nur echte Vorteile, kein fest eingebauter Preis', (tester) async {
    tester.view.physicalSize = const Size(412, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const ProviderScope(
      child: MaterialApp(home: Scaffold(body: ProUpgradeSheet())),
    ));
    // Preisabfrage schlägt im Test ohne Store fehl → Button ohne Preis
    await tester.pump();

    expect(find.text('Unbegrenzte KI-Mahlzeiten-Scans'), findsOneWidget);
    expect(find.textContaining('Werbefreiheit'), findsOneWidget);
    expect(find.text('Jetzt freischalten'), findsOneWidget);

    // Nicht erfüllte Versprechen und fester Preis dürfen nicht zurückkommen
    for (final removed in ['Latenz', 'Prioritäts-Server', 'Detaillierte Nährwert', '2,99']) {
      expect(find.textContaining(removed), findsNothing, reason: removed);
    }
  });
}
