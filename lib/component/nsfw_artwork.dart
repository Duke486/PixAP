import 'dart:typed_data';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:pixez/component/null_hero.dart';
import 'package:pixez/constants.dart';
import 'package:pixez/exts.dart';
import 'package:pixez/main.dart';
import 'package:pixez/models/illust.dart';
import 'package:pixez/store/user_setting.dart';

class NsfwArtwork extends StatelessWidget {
  const NsfwArtwork(
    this.artwork, {
    super.key,
    required Widget child,
    this.page = 0,
  }) : child = child,
       buildPreview = null,
       heroTag = null;

  const NsfwArtwork.preview(
    this.artwork, {
    super.key,
    required Widget Function(Widget Function(Widget)? mask) buildPreview,
    this.heroTag,
  }) : child = null,
       buildPreview = buildPreview,
       page = 0;

  final Illusts artwork;
  final int page;
  final Widget? child;
  final Widget Function(Widget Function(Widget)? mask)? buildPreview;
  final String? heroTag;

  @override
  Widget build(BuildContext context) {
    final identity = '${artwork.id}/$page';
    final preview = buildPreview;
    if (preview == null) {
      return NsfwMedia(
        identity: identity,
        restricted: artwork.isNsfw,
        child: child!,
      );
    }
    return NsfwMedia.preview(
      identity: identity,
      restricted: artwork.isNsfw,
      buildPreview: (mask) => HeroMode(
        enabled: mask == null,
        child: NullHero(tag: heroTag, child: preview(mask)),
      ),
    );
  }
}

class NsfwMedia extends StatelessWidget {
  const NsfwMedia({
    super.key,
    required this.identity,
    required this.restricted,
    required Widget child,
  }) : child = child,
       buildPreview = null;
  const NsfwMedia.preview({
    super.key,
    required this.identity,
    required this.restricted,
    required Widget Function(Widget Function(Widget)? mask) buildPreview,
  }) : child = null,
       buildPreview = buildPreview;
  final String identity;
  final bool restricted;
  final Widget? child;
  final Widget Function(Widget Function(Widget)? mask)? buildPreview;

  @override
  Widget build(BuildContext context) {
    final preview = buildPreview;
    if (!restricted) return preview?.call(null) ?? child!;
    return Observer(
      builder: (_) => switch (userSetting.nsfwDisplayMode) {
        NsfwDisplayMode.show => preview?.call(null) ?? child!,
        NsfwDisplayMode.replace => Image.asset(
          Constants.no_h,
          fit: BoxFit.contain,
        ),
        NsfwDisplayMode.mask =>
          preview == null
              ? child!
              : preview(
                  (image) => _MediaDust(
                    key: ValueKey(identity),
                    seed: identity.hashCode,
                    child: image,
                  ),
                ),
      },
    );
  }
}

class _DustPreset {
  static const double density = .023;
  static const double size = 1.638;
  static const double spacing = 27.511;
  static const double width = 4.230;
  static const double scatter = .045;
  static const double bend = 1.000;
  static const double drift = 2.631;
  static const double opacity = 1.240;
  static const double pulse = 38.569;
  static const double blur = 15.638;
  static const double tint = .056;
}

class _MediaDust extends StatefulWidget {
  const _MediaDust({super.key, required this.child, required this.seed});
  final int seed;
  final Widget child;
  @override
  State<_MediaDust> createState() => _MediaDustState();
}

class _MediaDustState extends State<_MediaDust>
    with SingleTickerProviderStateMixin {
  late final dust = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 7191),
  );
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      dust.stop();
    } else if (!dust.isAnimating) {
      dust.repeat();
    }
  }

  @override
  void dispose() {
    dust.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final particles = RepaintBoundary(
      child: CustomPaint(painter: _DustPainter(dust, widget.seed)),
    );
    return ClipRect(
      child: Stack(
        fit: StackFit.passthrough,
        children: [
          ImageFiltered(
            imageFilter: ui.ImageFilter.blur(
              sigmaX: _DustPreset.blur,
              sigmaY: _DustPreset.blur,
            ),
            child: widget.child,
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: ColoredBox(
                color: const Color(
                  0xff282830,
                ).withValues(alpha: _DustPreset.tint),
                child: particles,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Draw persistent grains around warped cell boundaries. The distance to the
// two nearest centers determines density; most cell interiors stay clear.
class _DustPainter extends CustomPainter {
  _DustPainter(this.time, this.seed) : super(repaint: time);
  final Animation<double> time;
  final int seed;
  Size? layoutSize;
  final grains =
      <({Offset position, Offset tangent, double phase, double tone})>[];
  late Float32List coordinates;
  final paintBrush = Paint()..strokeCap = StrokeCap.round;

  void layout(Size size) {
    layoutSize = size;
    grains.clear();
    final rng = math.Random(seed);
    final spacing = _DustPreset.spacing;
    final centers = <Offset>[
      for (int y = -2; y <= size.height / spacing + 2; y++)
        for (int x = -2; x <= size.width / spacing + 2; x++)
          Offset(
            (x + rng.nextDouble()) * spacing,
            (y + rng.nextDouble()) * spacing,
          ),
    ];
    final count = (size.width * size.height * _DustPreset.density)
        .round()
        .clamp(0, 3200);
    while (grains.length < count) {
      final position = Offset(
        rng.nextDouble() * (size.width + 16) - 8,
        rng.nextDouble() * (size.height + 16) - 8,
      );
      final sample =
          position +
          Offset(
                6 * math.sin(position.dy / 18),
                7 * math.sin(position.dx / 24),
              ) *
              _DustPreset.bend;
      var first = double.infinity, second = double.infinity;
      var near = Offset.zero, next = Offset.zero;
      for (final center in centers) {
        final distance = (sample - center).distanceSquared;
        if (distance < first) {
          second = first;
          next = near;
          first = distance;
          near = center;
        } else if (distance < second) {
          second = distance;
          next = center;
        }
      }
      final normal = next - near;
      final length = normal.distance;
      final edge = (second - first) / (2 * length);
      final scatter = _DustPreset.scatter;
      if (rng.nextDouble() >
          scatter +
              (1 - scatter) *
                  math.exp(-edge * edge / math.pow(_DustPreset.width, 2)))
        continue;
      grains.add((
        position: position,
        tangent: Offset(-normal.dy, normal.dx) / length,
        phase: rng.nextDouble() * 2 * math.pi,
        tone: rng.nextDouble(),
      ));
    }
    grains.sort((a, b) => a.tone.compareTo(b.tone));
    coordinates = Float32List(grains.length * 2);
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (layoutSize != size) layout(size);
    final angle = time.value * 2 * math.pi;
    var start = 0;
    for (int i = 0; i < grains.length; i++) {
      final grain = grains[i];
      final p = grain.position;
      final flow = angle + p.dx / 36 + p.dy / 57;
      final drift = _DustPreset.drift;
      final slide = 4.8 * math.sin(flow) + 1.4 * math.sin(angle + grain.phase);
      coordinates[2 * i] =
          p.dx +
          drift *
              (grain.tangent.dx * slide + 2.8 * math.sin(angle + p.dy / 30));
      coordinates[2 * i + 1] =
          p.dy +
          drift *
              (grain.tangent.dy * slide + 2.8 * math.cos(angle + p.dx / 34));
      final band = (grain.tone * 8).floor();
      if (i + 1 < grains.length && (grains[i + 1].tone * 8).floor() == band)
        continue;
      paintBrush
        ..strokeWidth = (.54 + band * .064) * _DustPreset.size
        ..color = Color.fromARGB(
          ((55 + band * 19 + _DustPreset.pulse * math.sin(angle + band)) *
                  _DustPreset.opacity)
              .round()
              .clamp(0, 255),
          255,
          255,
          255,
        );
      canvas.drawRawPoints(
        ui.PointMode.points,
        Float32List.sublistView(coordinates, start * 2, (i + 1) * 2),
        paintBrush,
      );
      start = i + 1;
    }
  }

  @override
  bool shouldRepaint(_DustPainter old) => old.time != time || old.seed != seed;
}
