import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:material_ui/material_ui.dart';
import 'package:pixez/component/ipad_surface.dart';
import 'package:pixez/er/prefer.dart';
import 'package:pixez/i18n.dart';

typedef HomeFeedResult<T> = ({T? snapshot, Object? error});

Future<HomeFeedResult<T>> fetchHomeFeedPart<T>(
  Future<Response<dynamic>> Function() request,
  T Function(Map<String, dynamic>) decode,
) async {
  try {
    final response = await request();
    return (
      snapshot: decode(response.data as Map<String, dynamic>),
      error: null,
    );
  } catch (error) {
    return (snapshot: null, error: error);
  }
}

class HomeFeedRefresh<T> extends ChangeNotifier {
  HomeFeedRefresh({
    required this.cacheKey,
    required this.decode,
    required this.encode,
    required this.fetch,
    required this.show,
  });

  static const undoDuration = Duration(seconds: 3);

  final String? cacheKey;
  final T Function(Map<String, dynamic>) decode;
  final Map<String, dynamic> Function(T) encode;
  final Future<HomeFeedResult<T>> Function(T?) fetch;
  final void Function(T?, {required bool fromNetwork}) show;

  T? _current;
  T? _previous;
  bool _showingCache = false;
  bool _disposed = false;
  int _generation = 0;
  Timer? _undoTimer;
  bool refreshingOnStart = false;
  Object? error;

  bool get canUndo => _previous != null;

  void restore() {
    final key = cacheKey;
    final saved = key == null ? null : Prefer.getString(key);
    if (saved == null) return;
    try {
      final snapshot = decode(jsonDecode(saved) as Map<String, dynamic>);
      _current = snapshot;
      _showingCache = true;
      show(snapshot, fromNetwork: false);
    } catch (_) {
      _save(null);
    }
  }

  Future<bool> refresh({required bool manual}) async {
    final generation = ++_generation;
    if (manual) {
      _discardUndo();
      _save(null);
      if (_showingCache) {
        _current = null;
        _showingCache = false;
        show(null, fromNetwork: false);
      }
    }
    refreshingOnStart = !manual;
    error = null;
    notifyListeners();

    final HomeFeedResult<T> result;
    try {
      result = await fetch(_current);
    } catch (failure) {
      return _complete(generation, manual, (snapshot: null, error: failure));
    }
    return _complete(generation, manual, result);
  }

  bool _complete(int generation, bool manual, HomeFeedResult<T> result) {
    if (_disposed || generation != _generation) return false;
    refreshingOnStart = false;
    error = result.error;
    final snapshot = result.snapshot;
    final succeeded = error == null && snapshot != null;
    if (succeeded) {
      if (!manual && _showingCache) {
        _previous = _current;
        _undoTimer = Timer(undoDuration, () {
          _discardUndo();
          notifyListeners();
        });
      }
      _current = snapshot;
      _showingCache = false;
      show(snapshot, fromNetwork: true);
      _save(snapshot);
    } else if (_current == null && snapshot != null) {
      _current = snapshot;
      show(snapshot, fromNetwork: false);
    }
    notifyListeners();
    return succeeded;
  }

  void undo() {
    final previous = _previous;
    if (previous == null) return;
    _discardUndo();
    _current = previous;
    _showingCache = true;
    show(previous, fromNetwork: false);
    _save(previous);
    notifyListeners();
  }

  void _discardUndo() {
    _undoTimer?.cancel();
    _undoTimer = null;
    _previous = null;
  }

  void _save(T? snapshot) {
    final key = cacheKey;
    if (key == null) return;
    unawaited(_write(key, snapshot));
  }

  Future<void> _write(String key, T? snapshot) async {
    try {
      if (snapshot == null) {
        await Prefer.remove(key);
      } else {
        await Prefer.setString(key, jsonEncode(encode(snapshot)));
      }
    } catch (error) {
      debugPrint('Home feed cache: $error');
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _discardUndo();
    super.dispose();
  }
}

class HomeFeedOverlay<T> extends StatelessWidget {
  const HomeFeedOverlay({
    super.key,
    required this.refresh,
    required this.child,
  });

  final HomeFeedRefresh<T> refresh;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.paddingOf(context);
    return ListenableBuilder(
      listenable: refresh,
      child: child,
      builder: (context, child) => Stack(
        fit: StackFit.expand,
        children: [
          child!,
          if (refresh.refreshingOnStart)
            Positioned(
              top: padding.top + 6,
              left: 0,
              right: 0,
              child: const IgnorePointer(
                child: Center(
                  child: SizedBox.square(
                    dimension: 24,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  ),
                ),
              ),
            ),
          if (refresh.canUndo)
            Positioned(
              bottom: padding.bottom + 12,
              left: 16,
              right: 16,
              child: Center(child: _RefreshTip(onUndo: refresh.undo)),
            ),
        ],
      ),
    );
  }
}

class _RefreshTip extends StatelessWidget {
  const _RefreshTip({required this.onUndo});

  final VoidCallback onUndo;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final glass = defaultTargetPlatform == TargetPlatform.iOS;
    final radius = BorderRadius.circular(24);
    final strings = I18n.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .16),
            blurRadius: 18,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: SizedBox(
        width: 216,
        child: IPadSurface(
          includeIPhone: true,
          darkGlass: theme.brightness == Brightness.dark,
          glassFillOpacity: .24,
          child: Material(
            type: glass ? MaterialType.transparency : MaterialType.card,
            color: glass ? null : colors.surfaceContainerHigh,
            borderRadius: radius,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 1, 14, 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                        child: Text(
                          strings.home_feed_refreshed,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      TextButton.icon(
                        onPressed: onUndo,
                        icon: const Icon(Icons.undo, size: 17),
                        label: Text(strings.undo),
                      ),
                    ],
                  ),
                  TweenAnimationBuilder<double>(
                    duration: HomeFeedRefresh.undoDuration,
                    curve: Curves.easeInOutCubic,
                    tween: Tween(begin: 0, end: 1),
                    builder: (context, value, _) => Directionality(
                      textDirection: TextDirection.ltr,
                      child: LinearProgressIndicator(
                        value: value,
                        minHeight: 2,
                        borderRadius: BorderRadius.circular(2),
                        color: colors.primary,
                        backgroundColor: colors.primary.withValues(alpha: .17),
                        trackGap: 0,
                        stopIndicatorRadius: 0,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
