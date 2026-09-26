import 'package:flutter/widgets.dart';

/// Drag-to-look area. Pans only: taps fall through (translucent) to the
/// tap-to-interact layer underneath.
class LookPad extends StatelessWidget {
  const LookPad({super.key, required this.onDrag});

  /// Called with each drag delta, in logical pixels.
  final ValueChanged<Offset> onDrag;

  @override
  Widget build(BuildContext context) => GestureDetector(
        behavior: HitTestBehavior.translucent,
        onPanUpdate: (d) => onDrag(d.delta),
        child: const SizedBox.expand(),
      );
}
