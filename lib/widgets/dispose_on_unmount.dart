import 'package:flutter/widgets.dart';

/// Gibt [disposables] (z. B. TextEditingController eines Bottom-Sheets/Dialogs) frei,
/// sobald dieser Teilbaum endgültig entfernt wird – also erst NACH der
/// Schließ-Animation. Ein `.whenComplete(dispose)` auf showModalBottomSheet wäre zu
/// früh: Das Future endet beim Pop, die TextFields leben während der Animation weiter.
///
/// ```dart
/// showModalBottomSheet(
///   context: context,
///   builder: (ctx) => DisposeOnUnmount(
///     disposables: [nameController, calController],
///     child: ...,
///   ),
/// );
/// ```
class DisposeOnUnmount extends StatefulWidget {
  const DisposeOnUnmount({
    super.key,
    required this.disposables,
    required this.child,
  });

  final List<ChangeNotifier> disposables;
  final Widget child;

  @override
  State<DisposeOnUnmount> createState() => _DisposeOnUnmountState();
}

class _DisposeOnUnmountState extends State<DisposeOnUnmount> {
  @override
  void dispose() {
    for (final d in widget.disposables) {
      d.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
