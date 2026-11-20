import 'dart:ui' as ui;
import 'package:material_ui/material_ui.dart';

typedef ReflectionStyle = ({double strength, double radius, double reach, double sample, double ambient});
class ThemedReflection {
  ThemedReflection({required ReflectionStyle light, required ReflectionStyle dark})
      : light = ValueNotifier(light), dark = ValueNotifier(dark);

  final ValueNotifier<ReflectionStyle> light;
  final ValueNotifier<ReflectionStyle> dark;

  ValueNotifier<ReflectionStyle> forTheme(Brightness brightness) =>
      brightness == Brightness.dark ? dark : light;
}

final artworkReflection = ThemedReflection(
  light: (strength: .19, radius: 8, reach: .92, sample: .05, ambient: 0),
  dark: (strength: .26, radius: 9, reach: .92, sample: .09, ambient: 0),
);
final artistReflection = ThemedReflection(
  light: (strength: .25, radius: 6, reach: .91, sample: .18, ambient: 0),
  dark: (strength: .31, radius: 13, reach: .57, sample: .18, ambient: 0),
);

class CardReflection extends StatelessWidget {
  const CardReflection({super.key, required this.style, required this.images});
  final ThemedReflection style;
  final List<ImageProvider?> images;

  @override
  Widget build(BuildContext context) => IgnorePointer(child: ExcludeSemantics(
    child: ValueListenableBuilder<ReflectionStyle>(valueListenable: style.forTheme(Theme.of(context).brightness),
      builder: (_, value, child) {
        final backing = Theme.of(context).colorScheme.surface.withValues(alpha: 1 - value.ambient);
        if (value.strength == 0) return ColoredBox(color: backing);
        return RepaintBoundary(child: ColoredBox(color: backing, child: ClipRect(child: ShaderMask(blendMode: BlendMode.dstIn,
          shaderCallback: (rect) => LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
            colors: [Colors.white.withValues(alpha: value.strength), Colors.transparent],
            stops: [0, value.reach]).createShader(rect),
          child: ImageFiltered(imageFilter: ui.ImageFilter.blur(sigmaX: value.radius, sigmaY: value.radius,
            tileMode: TileMode.clamp), child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              for (final image in images) Expanded(child: image == null ? const SizedBox() : _ImageStrip(image: image, sample: value.sample)),
            ]))))));
      })));
}

class _ImageStrip extends StatefulWidget {
  const _ImageStrip({required this.image, required this.sample});
  final ImageProvider image;
  final double sample;
  @override
  State<_ImageStrip> createState() => _ImageStripState();
}

class _ImageStripState extends State<_ImageStrip> {
  ImageStream? _stream;
  ImageInfo? _frame;
  late final _listener = ImageStreamListener(_received, onError: (Object error, StackTrace? stack) {});

  void _received(ImageInfo frame, bool synchronous) {
    final previous = _frame;
    setState(() => _frame = frame);
    previous?.dispose();
  }

  void _resolve() {
    final stream = widget.image.resolve(createLocalImageConfiguration(context));
    if (_stream?.key == stream.key) return;
    _stream?.removeListener(_listener);
    _frame?.dispose();
    _frame = null;
    _stream = stream..addListener(_listener);
  }

  @override
  void didChangeDependencies() { super.didChangeDependencies(); _resolve(); }
  @override
  void didUpdateWidget(_ImageStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.image != oldWidget.image) _resolve();
  }
  @override
  void dispose() {
    _stream?.removeListener(_listener);
    _frame?.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) => CustomPaint(painter: _StripPainter(_frame?.image, widget.sample));
}

class _StripPainter extends CustomPainter {
  _StripPainter(this.image, this.sample);
  final ui.Image? image;
  final double sample;
  @override
  void paint(Canvas canvas, Size size) {
    final source = image;
    if (source == null || size.isEmpty) return;
    final height = source.height.toDouble();
    final strip = Rect.fromLTRB(0, height * (1 - sample), source.width.toDouble(), height);
    canvas.save();
    canvas.translate(0, size.height);
    canvas.scale(1, -1);
    canvas.drawImageRect(source, strip, Offset.zero & size, Paint()..filterQuality = FilterQuality.low);
    canvas.restore();
  }
  @override
  bool shouldRepaint(_StripPainter old) => old.image != image || old.sample != sample;
}
