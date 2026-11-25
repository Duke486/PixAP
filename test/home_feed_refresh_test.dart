import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pixez/er/prefer.dart';
import 'package:pixez/page/hello/recom/home_feed_refresh.dart';
import 'package:pixez/src/generated/i18n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Prefer.init();
  });

  testWidgets('launch shows the saved feed and expires the animated undo tip', (
    tester,
  ) async {
    const key = 'home_feed.test.launch';
    await Prefer.setString(key, '{"title":"Old feed"}');
    final fixture = _RefreshFixture(key);
    addTearDown(fixture.dispose);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: HomeFeedOverlay(
            refresh: fixture.refresh,
            child: ValueListenableBuilder<String?>(
              valueListenable: fixture.visible,
              builder: (_, title, _) =>
                  Center(child: Text(title ?? 'Empty feed')),
            ),
          ),
        ),
      ),
    );

    final startup = fixture.refresh.refresh(manual: false);
    await tester.pump();
    expect(find.text('Old feed'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    fixture.complete(0, 'First update');
    expect(await startup, isTrue);
    await tester.pump();
    expect(find.text('First update'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('Refreshed'), findsOneWidget);
    expect(find.byIcon(Icons.undo), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 400));
    expect(
      tester
          .widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator))
          .value,
      inExclusiveRange(0, .2),
    );

    await tester.tap(find.text('Undo'));
    await tester.pump();
    expect(find.text('Old feed'), findsOneWidget);
    expect(find.text('Refreshed'), findsNothing);

    final secondStartup = fixture.refresh.refresh(manual: false);
    fixture.complete(1, 'Second update');
    expect(await secondStartup, isTrue);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 2999));
    expect(find.text('Undo'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1));
    expect(find.text('Undo'), findsNothing);
    fixture.refresh.undo();
    expect(fixture.visible.value, 'Second update');
    expect(Prefer.getString(key), '{"title":"Second update"}');
    await tester.pumpWidget(const SizedBox());
  });

  test(
    'manual refresh clears old content and supersedes the startup request',
    () async {
      const key = 'home_feed.test.manual';
      await Prefer.setString(key, '{"title":"Old feed"}');
      final fixture = _RefreshFixture(key);
      addTearDown(fixture.dispose);
      final startup = fixture.refresh.refresh(manual: false);
      final manual = fixture.refresh.refresh(manual: true);
      expect(fixture.visible.value, isNull);
      expect(Prefer.getString(key), isNull);

      fixture.complete(0, 'Outdated startup response');
      expect(await startup, isFalse);
      expect(fixture.visible.value, isNull);
      fixture.complete(1, 'Manual update');
      expect(await manual, isTrue);
      expect(fixture.visible.value, 'Manual update');
      expect(fixture.refresh.canUndo, isFalse);
      expect(Prefer.getString(key), '{"title":"Manual update"}');
    },
  );

  test('startup refresh failure keeps the cached feed available', () async {
    const key = 'home_feed.test.offline';
    await Prefer.setString(key, '{"title":"Old feed"}');
    final fixture = _RefreshFixture(key);
    addTearDown(fixture.dispose);
    final startup = fixture.refresh.refresh(manual: false);
    fixture.requests.single.complete((
      snapshot: null,
      error: StateError('Offline'),
    ));
    expect(await startup, isFalse);
    expect(fixture.visible.value, 'Old feed');
    expect(fixture.refresh.canUndo, isFalse);
    expect(Prefer.getString(key), '{"title":"Old feed"}');
  });
}

class _RefreshFixture {
  _RefreshFixture(String key) {
    refresh = HomeFeedRefresh<String>(
      cacheKey: key,
      decode: (json) => json['title'] as String,
      encode: (title) => {'title': title},
      fetch: (_) {
        final request = Completer<HomeFeedResult<String>>();
        requests.add(request);
        return request.future;
      },
      show: (title, {required fromNetwork}) => visible.value = title,
    )..restore();
  }

  final visible = ValueNotifier<String?>(null);
  final requests = <Completer<HomeFeedResult<String>>>[];
  late final HomeFeedRefresh<String> refresh;

  void complete(int index, String value) =>
      requests[index].complete((snapshot: value, error: null));

  void dispose() {
    refresh.dispose();
    visible.dispose();
  }
}
