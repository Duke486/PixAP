import 'dart:ui' as ui;
import 'package:material_ui/material_ui.dart';

/// Composite a blurred copy of the cover locally, without sampling platform views.
class CoverBlur extends StatelessWidget {
  const CoverBlur({
    super.key,
    required this.image,
    required this.sigma,
    required this.extent,
    required this.tint,
    this.fromTop = false, this.midpoint = .5, this.plateau = 0, this.opacity = 1,
  });
  final ImageProvider image;
  final double sigma, extent, midpoint, plateau, opacity;
  final Color tint;
  final bool fromTop;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: ClipRect(
      child: ShaderMask(
        blendMode: BlendMode.dstIn,
        shaderCallback: (rect) => LinearGradient(
          begin: fromTop ? Alignment.bottomCenter : Alignment.topCenter,
          end: fromTop ? Alignment.topCenter : Alignment.bottomCenter,
          colors: [Colors.transparent, Colors.white.withValues(alpha: opacity * .5), Colors.white.withValues(alpha: opacity)],
          stops: [1 - extent, 1 - extent + extent * (1 - plateau) * midpoint, 1 - extent * plateau],
        ).createShader(rect),
        child: Stack(
          fit: StackFit.expand,
          children: [
            ImageFiltered(
              imageFilter: ui.ImageFilter.blur(
                sigmaX: sigma,
                sigmaY: sigma,
                tileMode: TileMode.clamp,
              ),
              child: Image(
                image: image,
                fit: BoxFit.cover,
                excludeFromSemantics: true,
                errorBuilder: (_, _, _) => const SizedBox(),
              ),
            ),
            ColoredBox(color: tint),
          ],
        ),
      ),
    ),
  );
}
