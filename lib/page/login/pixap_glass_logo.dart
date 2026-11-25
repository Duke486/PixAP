import 'dart:ui' as ui;
import 'package:flutter/widgets.dart';

/// The two paths are the Ribbon and Turn layers of AppIcon.icon.
class PixapGlassLogo extends StatelessWidget {
  const PixapGlassLogo({super.key});

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: 96,
    child: Stack(
      fit: StackFit.expand,
      children: [
        for (final fold in [false, true])
          ClipPath(
            clipper: _RibbonClip(fold),
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 3, sigmaY: 3),
              child: CustomPaint(painter: _GlassFill(fold)),
            ),
          ),
      ],
    ),
  );
}

class _RibbonClip extends CustomClipper<Path> {
  const _RibbonClip(this.fold);
  final bool fold;

  @override
  Path getClip(Size size) {
    final path = fold
        ? (Path()
            ..moveTo(325, 343)
            ..quadraticBezierTo(332, 319, 353, 303)
            ..lineTo(442, 232)
            ..quadraticBezierTo(467, 212, 507, 212)
            ..lineTo(602, 212)
            ..cubicTo(671, 212, 724, 237, 749, 284)
            ..cubicTo(705, 266, 666, 280, 624, 310)
            ..lineTo(578, 344)
            ..lineTo(483, 344)
            ..cubicTo(435, 344, 394, 356, 352, 386)
            ..lineTo(316, 413)
            ..close())
        : (Path()
            ..fillType = PathFillType.evenOdd
            ..moveTo(269, 776)
            ..lineTo(323, 355)
            ..quadraticBezierTo(327, 324, 353, 303)
            ..lineTo(442, 232)
            ..quadraticBezierTo(467, 212, 507, 212)
            ..lineTo(602, 212)
            ..cubicTo(713, 212, 776, 276, 766, 380)
            ..lineTo(757, 449)
            ..cubicTo(742, 558, 667, 620, 555, 620)
            ..lineTo(442, 620)
            ..lineTo(428, 726)
            ..quadraticBezierTo(425, 746, 406, 761)
            ..lineTo(318, 825)
            ..quadraticBezierTo(294, 842, 279, 830)
            ..quadraticBezierTo(263, 818, 269, 776)
            ..close()
            ..moveTo(463, 496)
            ..lineTo(551, 496)
            ..quadraticBezierTo(613, 496, 622, 441)
            ..lineTo(628, 397)
            ..quadraticBezierTo(634, 344, 580, 344)
            ..lineTo(483, 344)
            ..close());
    final scale = size.shortestSide / 690;
    return path
        .shift(const Offset(-515, -521))
        .transform((Matrix4.diagonal3Values(scale, scale, 1)).storage)
        .shift(size.center(Offset.zero));
  }

  @override
  bool shouldReclip(_RibbonClip old) => fold != old.fold;
}

class _GlassFill extends CustomPainter {
  const _GlassFill(this.fold);
  final bool fold;
  @override
  void paint(Canvas canvas, Size size) {
    final shape = _RibbonClip(fold).getClip(size);
    final paint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(size.width * .20, 0),
        Offset(size.width * .72, size.height),
        fold
            ? const [Color(0xC2C6FCFF), Color(0x9959DFED), Color(0x6676BDFF)]
            : const [Color(0x852EE4EF), Color(0xAD1479D8), Color(0x703492F2)],
        const [0, .5, 1],
      );
    canvas.drawPath(shape, paint);
    canvas.drawPath(
      shape,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..shader = ui.Gradient.linear(
          Offset.zero,
          size.bottomRight(Offset.zero),
          const [Color(0xDEFFFFFF), Color(0x2571CFFF), Color(0xA5CFFFFF)],
          const [0, .5, 1],
        ),
    );
  }

  @override
  bool shouldRepaint(_GlassFill old) => fold != old.fold;
}
