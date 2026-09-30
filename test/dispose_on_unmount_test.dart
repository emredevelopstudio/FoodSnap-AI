import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodsnap_ai/widgets/dispose_on_unmount.dart';

bool _isDisposed(ChangeNotifier n) {
  try {
    n.addListener(() {});
    return false;
  } catch (_) {
    return true;
  }
}

void main() {
  testWidgets('Controller eines Bottom-Sheets werden erst nach dem Schließen freigegeben',
      (tester) async {
    final controller = TextEditingController(text: 'Pizza');
    late BuildContext pageContext;

    await tester.pumpWidget(MaterialApp(
      home: Builder(builder: (ctx) {
        pageContext = ctx;
        return const Scaffold();
      }),
    ));

    showModalBottomSheet<void>(
      context: pageContext,
      builder: (_) => DisposeOnUnmount(
        disposables: [controller],
        child: Material(child: TextField(controller: controller)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Pizza'), findsOneWidget);

    // Schließen starten: während der Animation noch NICHT freigegeben
    Navigator.of(pageContext).pop();
    await tester.pump(const Duration(milliseconds: 50));
    expect(_isDisposed(controller), isFalse);

    // Nach der Animation freigegeben, ohne Fehler
    await tester.pumpAndSettle();
    expect(_isDisposed(controller), isTrue);
    expect(tester.takeException(), isNull);
  });
}
