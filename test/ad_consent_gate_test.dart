import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodsnap_ai/services/ad_service.dart';

class _GatedAd extends StatefulWidget {
  const _GatedAd({required this.onLoad});
  final VoidCallback onLoad;

  @override
  State<_GatedAd> createState() => _GatedAdState();
}

class _GatedAdState extends State<_GatedAd> with AdsReadyGate {
  @override
  void initState() {
    super.initState();
    loadWhenAdsReady(widget.onLoad);
  }

  @override
  Widget build(BuildContext context) => const SizedBox();
}

void main() {
  setUp(() => AdService.adsReady.value = false);

  testWidgets('lädt keine Anzeige vor der Werbe-Einwilligung', (tester) async {
    var loads = 0;
    await tester.pumpWidget(_GatedAd(onLoad: () => loads++));
    expect(loads, 0);

    AdService.adsReady.value = true;
    await tester.pump();
    expect(loads, 1);
  });

  testWidgets('lädt sofort, wenn die Einwilligung schon vorliegt', (tester) async {
    AdService.adsReady.value = true;
    var loads = 0;
    await tester.pumpWidget(_GatedAd(onLoad: () => loads++));
    expect(loads, 1);
  });

  testWidgets('lädt nicht mehr nach dem Entfernen des Widgets', (tester) async {
    var loads = 0;
    await tester.pumpWidget(_GatedAd(onLoad: () => loads++));
    await tester.pumpWidget(const SizedBox());

    AdService.adsReady.value = true;
    await tester.pump();
    expect(loads, 0);
  });
}
