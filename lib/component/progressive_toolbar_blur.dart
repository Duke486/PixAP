import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';

/// Fades the blur and tint toward the content at the bottom of the toolbar.
class ProgressiveToolbarBlur extends StatelessWidget {
  const ProgressiveToolbarBlur({super.key});

  @override
  Widget build(BuildContext context) {
    final surface = Theme.of(context).scaffoldBackgroundColor;
    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final sigma in const [12.0, 9.0, 6.0, 3.0, 1.0])
                Expanded(
                  child: ClipRect(
                    child: BackdropFilter(
                      filter: ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
                      child: const SizedBox.expand(),
                    ),
                  ),
                ),
            ],
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  surface.withValues(alpha: .82),
                  surface.withValues(alpha: .58),
                  surface.withValues(alpha: 0),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
