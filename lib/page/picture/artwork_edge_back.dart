import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:cupertino_ui/cupertino_ui.dart'
    show CupertinoPageTransitionsBuilder;
import 'package:material_ui/material_ui.dart';

final _rightEdgePreview = Expando<bool>();

class ArtworkPageTransitionsBuilder extends CupertinoPageTransitionsBuilder {
  const ArtworkPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final navigator = route.navigator!;
    final contentDirection = Directionality.of(context);
    return ValueListenableBuilder<bool>(
      valueListenable: navigator.userGestureInProgressNotifier,
      child: Directionality(textDirection: contentDirection, child: child),
      builder: (_, dragging, page) {
        final fromRight = dragging && _rightEdgePreview[navigator] == true;
        return Directionality(
          textDirection: fromRight ? TextDirection.rtl : contentDirection,
          child: Builder(
            builder: (transitionContext) => super.buildTransitions(
              route,
              transitionContext,
              animation,
              secondaryAnimation,
              page!,
            ),
          ),
        );
      },
    );
  }
}

class ArtworkEdgeBack extends StatefulWidget {
  const ArtworkEdgeBack({super.key, required this.child});
  final Widget child;

  @override
  State<ArtworkEdgeBack> createState() => _ArtworkEdgeBackState();
}

class _ArtworkEdgeBackState extends State<ArtworkEdgeBack> {
  double travel = 0;
  PageRoute<dynamic>? activeRoute;

  void update(double delta, double width, bool left) {
    travel += delta;
    if (activeRoute == null) {
      final route = ModalRoute.of(context);
      if (travel <= 0 ||
          route is! PageRoute ||
          !route.isCurrent ||
          route.isFirst ||
          route.willHandlePopInternally ||
          route.popDisposition != RoutePopDisposition.pop ||
          !route.animation!.isCompleted ||
          route.navigator!.userGestureInProgress)
        return;
      activeRoute = route;
      if (!left) {
        final navigator = route.navigator!;
        final gestures = navigator.userGestureInProgressNotifier;
        void clearDirection() {
          if (gestures.value) return;
          _rightEdgePreview[navigator] = null;
          gestures.removeListener(clearDirection);
        }

        _rightEdgePreview[navigator] = true;
        gestures.addListener(clearDirection);
      }
      route.handleStartBackGesture(progress: 1);
    }
    activeRoute!.handleUpdateBackGestureProgress(
      progress: (1 - travel / width).clamp(.001, 1.0),
    );
  }

  void finish({bool commit = false}) {
    final route = activeRoute;
    activeRoute = null;
    if (route == null) return;
    if (!commit ||
        !route.isCurrent ||
        route.popDisposition != RoutePopDisposition.pop) {
      route.handleCancelBackGesture();
      if (route.isCurrent && route.animation?.isCompleted == false) {
        // ignore: invalid_use_of_protected_member
        route.controller?.animateTo(
          1,
          duration: const Duration(milliseconds: 140),
        );
      }
      return;
    }
    final navigator = route.navigator!;
    // Keep the slide at the current drag position and settle quickly after release.
    // ignore: invalid_use_of_protected_member
    final controller = route.controller;
    navigator.pop();
    if (controller?.isAnimating == true) {
      controller!.animateBack(0, duration: const Duration(milliseconds: 170));
    }
    route.completed.whenComplete(() {
      if (navigator.mounted) navigator.didStopUserGesture();
    });
  }

  Widget _edge(double width, {required bool left}) => Positioned(
    left: left ? 0 : null,
    right: left ? null : 0,
    top: 0,
    bottom: 0,
    width: width * (left ? .10 : .04),
    child: Listener(
      behavior: HitTestBehavior.translucent,
      onPointerCancel: (_) => finish(),
      child: GestureDetector(
        // Register ahead of the pager while letting taps and vertical drags hit the content.
        behavior: HitTestBehavior.translucent,
        excludeFromSemantics: true,
        dragStartBehavior: DragStartBehavior.down,
        onHorizontalDragStart: (_) => travel = 0,
        onHorizontalDragUpdate: (d) =>
            update((left ? 1 : -1) * d.delta.dx, width, left),
        onHorizontalDragCancel: finish,
        onHorizontalDragEnd: (d) {
          final speed = (left ? 1 : -1) * (d.primaryVelocity ?? 0);
          finish(
            commit:
                speed > -350 && (travel >= 44 || (travel >= 16 && speed > 350)),
          );
        },
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    if (defaultTargetPlatform != TargetPlatform.iOS) return widget.child;
    // The Cupertino edge recognizer checks for a scoped callback before joining
    // the arena. Ordinary back-button requests still pass through.
    // ignore: deprecated_member_use
    return WillPopScope(
      onWillPop: () async => true,
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light.copyWith(
          statusBarColor: Colors.transparent,
          systemStatusBarContrastEnforced: false,
        ),
        child: LayoutBuilder(
          builder: (_, box) => Stack(
            fit: StackFit.expand,
            children: [
              widget.child,
              _edge(box.maxWidth, left: true),
              _edge(box.maxWidth, left: false),
            ],
          ),
        ),
      ),
    );
  }
}
