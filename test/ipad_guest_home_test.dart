import 'dart:async';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pixez/component/progressive_toolbar_blur.dart';
import 'package:pixez/main.dart';
import 'package:pixez/network/api_client.dart';
import 'package:pixez/page/hello/new/new_page.dart';
import 'package:pixez/page/search/search_page.dart';
import 'package:pixez/page/search/suggest/search_suggestion_page.dart';
import 'package:pixez/page/preview/preview_page.dart';
import 'package:pixez/src/generated/i18n/app_localizations.dart';

void main() {
  testWidgets(
    'guest home previews one and a half rows and unlocks Later after ten seconds',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1100, 800);
      final messenger = tester.binding.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(
        SystemChannels.platform_views,
        (_) async => null,
      );
      addTearDown(() {
        messenger.setMockMethodCallHandler(SystemChannels.platform_views, null);
        tester.view.reset();
        debugDefaultTargetPlatformOverride = null;
      });
      apiClient.httpClient = _PendingDio();
      await tester.pumpWidget(
        const MaterialApp(
          locale: Locale('zh', 'CN'),
          localizationsDelegates: [
            AppLocalizations.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: PreviewPage(showLoginPrompt: true)),
        ),
      );
      final prompt = find.byType(GuestHomeLoginPrompt);
      expect(find.text('登录使用完整功能'), findsOneWidget);
      // Five columns at this width give cards roughly 270 points high.
      expect(800 - tester.getSize(prompt).height, closeTo(410, 12));
      tester.view.physicalSize = const Size(800, 1100);
      await tester.pump();
      // Three slightly wider columns should reveal a taller strip in portrait.
      expect(1100 - tester.getSize(prompt).height, closeTo(485, 25));
      expect(
        tester.getCenter(find.text('以后 (10)')).dx,
        lessThan(tester.getCenter(find.text('登录')).dx),
      );
      final buttons = find.descendant(
        of: prompt,
        matching: find.byType(TextButton),
      );
      expect(tester.widget<TextButton>(buttons.first).onPressed, isNull);
      expect(tester.widget<TextButton>(buttons.last).onPressed, isNotNull);
      await tester.pump(const Duration(seconds: 9));
      expect(tester.widget<TextButton>(buttons.first).onPressed, isNull);
      await tester.pump(const Duration(seconds: 1));
      expect(tester.widget<TextButton>(buttons.first).onPressed, isNotNull);
      await tester.tap(find.text('以后'));
      await tester.pump();
      expect(prompt, findsNothing);
      await tester.pumpWidget(const SizedBox());
      debugDefaultTargetPlatformOverride = null;
    },
  );
  testWidgets('signed-out activity and search show only the login prompt', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1100, 800);
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      SystemChannels.platform_views,
      (_) async => null,
    );
    addTearDown(() {
      messenger.setMockMethodCallHandler(SystemChannels.platform_views, null);
      tester.view.reset();
      debugDefaultTargetPlatformOverride = null;
    });
    for (final page in [const NewPage(), const SearchPage()]) {
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('zh', 'CN'),
          localizationsDelegates: [
            AppLocalizations.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: page),
        ),
      );
      topStore.setTop('400');
      await tester.pump();
      expect(find.text('请先登录'), findsOneWidget);
      expect(find.widgetWithText(TextButton, '登录'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      expect(find.byType(TabBarView), findsNothing);
    }

    await tester.pumpWidget(const SizedBox());
    debugDefaultTargetPlatformOverride = null;
  });
  testWidgets('the discovery search bar scrolls up and pins at the safe top', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1100, 800);
    tester.view.padding = const FakeViewPadding(top: 24);
    addTearDown(tester.view.reset);
    final scroll = ScrollController();
    addTearDown(scroll.dispose);
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: SearchSuggestionPage(
          idleScrollController: scroll,
          idleContent: ListView.builder(
            controller: scroll,
            itemCount: 30,
            itemExtent: 100,
            itemBuilder: (_, index) => Text('Tile $index'),
          ),
        ),
      ),
    ));

    final field = find.byType(TextField);
    final initialTop = tester.getTopLeft(field).dy;
    expect(initialTop, greaterThan(160));
    expect(find.byType(ProgressiveToolbarBlur), findsOneWidget);
    expect(tester.getTopLeft(find.byType(ProgressiveToolbarBlur)).dy, 0);

    scroll.jumpTo(60);
    await tester.pump();
    expect(tester.getTopLeft(field).dy, closeTo(initialTop - 60, .1));

    scroll.jumpTo(300);
    await tester.pump();
    final pinnedTop = tester.getTopLeft(field).dy;
    expect(pinnedTop, closeTo(initialTop - 176, .1));

    scroll.jumpTo(500);
    await tester.pump();
    expect(tester.getTopLeft(field).dy, pinnedTop);

    scroll.jumpTo(0);
    await tester.pump();
    expect(tester.getTopLeft(field).dy, initialTop);

    await tester.enterText(field, '123456');
    await tester.pump();
    expect(find.byType(ListTile), findsWidgets);
    await tester.dragFrom(const Offset(950, 500), const Offset(0, -250));
    await tester.pumpAndSettle();
    expect(scroll.offset, greaterThan(176));
    expect(find.byType(ListTile), findsNothing);
    expect(tester.widget<TextField>(field).controller!.text, '123456');
    await tester.pumpWidget(const SizedBox());
  });
}

class _PendingDio extends DioForNative {
  @override
  Future<Response<T>> get<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onReceiveProgress,
  }) => Completer<Response<T>>().future;
}
