import 'dart:async';
import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

class HomeAurora extends StatefulWidget {
  const HomeAurora({super.key});

  @override
  State<HomeAurora> createState() => _HomeAuroraState();
}

class _HomeAuroraState extends State<HomeAurora> with WidgetsBindingObserver {
  // At this speed the glow travels less than one logical pixel per update.
  static const _interval = Duration(milliseconds: 100);
  static const _stepsPerCycle = 600;
  final _step = ValueNotifier<int>(0);
  Timer? _timer;
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _visible =
        (ModalRoute.isCurrentOf(context) ?? true) &&
        TickerMode.valuesOf(context).enabled &&
        !MediaQuery.disableAnimationsOf(context);
    _updateMotion(WidgetsBinding.instance.lifecycleState);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) =>
      _updateMotion(state);

  void _updateMotion(AppLifecycleState? state) {
    if (!_visible || state != AppLifecycleState.resumed) {
      _timer?.cancel();
      _timer = null;
    } else if (_timer == null) {
      final start = _step.value;
      _timer = Timer.periodic(_interval, (timer) {
        _step.value = (start + timer.tick) % _stepsPerCycle;
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _step.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: RepaintBoundary(
      child: CustomPaint(
        painter: _AuroraPainter(_step, Theme.of(context).brightness),
      ),
    ),
  );
}

class _AuroraPainter extends CustomPainter {
  _AuroraPainter(this.step, this.brightness) : super(repaint: step);

  final ValueNotifier<int> step;
  final Brightness brightness;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final w = size.width;
    final h = size.height;
    final spread = ((w - 480) / 360).clamp(0.0, 1.0);
    final phase = step.value * 2 * math.pi / _HomeAuroraState._stepsPerCycle;
    final drift = size.shortestSide * .04;
    final dx = drift * math.cos(phase);
    final dy = drift * math.sin(phase);
    final alpha = brightness == Brightness.dark ? .06 : .08;

    void glow(
      Offset center,
      double rx,
      double ry,
      Color color,
      double opacity,
    ) {
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.scale(rx, ry);
      const bounds = Rect.fromLTRB(-1, -1, 1, 1);
      final gradient = RadialGradient(
        colors: [
          color.withValues(alpha: opacity),
          color.withValues(alpha: opacity * .45),
          color.withValues(alpha: 0),
        ],
        stops: const [0, .52, 1],
      );
      canvas.drawOval(bounds, Paint()..shader = gradient.createShader(bounds));
      canvas.restore();
    }

    glow(
      Offset(w * (1.03 - 1.06 * spread) + dx, h * (.05 + .19 * spread) + dy),
      w * (.90 - .30 * spread),
      h * (.55 + .24 * spread),
      const Color(0xFF0096FA),
      alpha,
    );
    glow(
      Offset(w * (.06 + .89 * spread) - dy, h * (.96 - .89 * spread) - dx),
      w * .75,
      h * .50,
      const Color(0xFF36BEEB),
      alpha * .50,
    );
  }

  @override
  bool shouldRepaint(_AuroraPainter oldDelegate) =>
      oldDelegate.brightness != brightness || oldDelegate.step != step;
}
