import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

class ProgressiveToolbarBlur extends StatelessWidget {
  const ProgressiveToolbarBlur({super.key});

  @override
  Widget build(BuildContext context) =>
      const FadingBackdrop(direction: AxisDirection.down);
}

/// One system blur with a continuous opacity mask from opaque to transparent.
class FadingBackdrop extends StatelessWidget {
  const FadingBackdrop({super.key, required this.direction});
  final AxisDirection direction;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return IgnorePointer(
        child: ExcludeSemantics(
          child: UiKitView(
            key: ValueKey((direction, dark)),
            viewType: 'pixez/fadingBackdrop',
            creationParams: {'direction': direction.name, 'dark': dark},
            creationParamsCodec: const StandardMessageCodec(),
          ),
        ),
      );
    }
    final start = switch (direction) {
      AxisDirection.down => Alignment.topCenter,
      AxisDirection.right => Alignment.centerLeft,
      AxisDirection.left => Alignment.centerRight,
      AxisDirection.up => Alignment.bottomCenter,
    };
    final surface = Theme.of(context).scaffoldBackgroundColor;
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: start,
            end: -start,
            colors: [
              surface.withValues(alpha: .85),
              surface.withValues(alpha: 0),
            ],
          ),
        ),
      ),
    );
  }
}
