import 'package:pixez/component/glass_form_control.dart';
import 'dart:async';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pixez/component/progressive_toolbar_blur.dart';
import 'package:pixez/component/ipad_surface.dart';
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
        matching: find.byType(GlassActionButton),
      );
      expect(tester.widget<GlassActionButton>(buttons.first).onPressed, isNull);
      expect(
        tester.widget<GlassActionButton>(buttons.last).onPressed,
        isNotNull,
      );
      await tester.pump(const Duration(seconds: 9));
      expect(tester.widget<GlassActionButton>(buttons.first).onPressed, isNull);
      await tester.pump(const Duration(seconds: 1));
      expect(
        tester.widget<GlassActionButton>(buttons.first).onPressed,
        isNotNull,
      );
      tester.widget<GlassActionButton>(buttons.first).onPressed!();
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
      expect(find.widgetWithText(GlassActionButton, '登录'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      expect(find.byType(TabBarView), findsNothing);
    }

    await tester.pumpWidget(const SizedBox());
    debugDefaultTargetPlatformOverride = null;
  });
  testWidgets(
    'phone search opens with a small inset and fills the space above the keyboard',
    (tester) async {
      const device = MethodChannel('pixez/device');
      final messenger = tester.binding.defaultBinaryMessenger;
      var phone = true;
      messenger.setMockMethodCallHandler(device, (_) async => phone);
      messenger.setMockMethodCallHandler(
        SystemChannels.platform_views,
        (_) async => null,
      );
      await initializeAppleDevice();
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(375, 812);
      tester.view.padding = const FakeViewPadding(top: 52);
      final scroll = ScrollController();
      addTearDown(scroll.dispose);
      addTearDown(() async {
        phone = false;
        await initializeAppleDevice();
        messenger.setMockMethodCallHandler(device, null);
        messenger.setMockMethodCallHandler(SystemChannels.platform_views, null);
        tester.view.reset();
      });
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('zh', 'CN'),
          localizationsDelegates: [
            AppLocalizations.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SearchSuggestionPage(
              idleScrollController: scroll,
              idleContent: ListView(
                controller: scroll,
                children: const [SizedBox(height: 1200)],
              ),
              historySlivers: () => [
                SliverList.builder(
                  itemCount: 24,
                  itemBuilder: (_, index) =>
                      ListTile(title: Text('History $index')),
                ),
              ],
            ),
          ),
        ),
      );
      final field = find.byType(TextField);
      final bar = find.byKey(const ValueKey('search-input-toolbar'));
      final title = find.text('搜索');
      final titleFade = find.byKey(const ValueKey('search-title-opacity'));
      final scrim = find.byKey(const ValueKey('search-background-scrim'));
      final panel = find.byKey(const ValueKey('search-suggestions-panel'));
      final idle = tester.getRect(bar);
      expect(idle.width, closeTo(315, .1));
      expect(tester.getCenter(title).dx, idle.center.dx);
      expect(idle.top - tester.getBottomLeft(titleFade).dy, closeTo(12, .1));
      expect(tester.widget<Text>(title).style?.fontWeight, FontWeight.bold);
      expect(tester.widget<Text>(title).style?.fontSize, 28);
      expect(scrim, findsNothing);

      final editable = tester.state<EditableTextState>(
        find.byType(EditableText),
      );
      await tester.tap(field);
      tester.view.viewInsets = const FakeViewPadding(bottom: 318);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 120));
      expect(tester.getTopLeft(bar).dy, inExclusiveRange(60, idle.top));
      expect(tester.getSize(bar).width, inExclusiveRange(idle.width, 359));
      expect(tester.widget<Opacity>(titleFade).opacity, inExclusiveRange(0, 1));
      expect(
        tester.widget<ColoredBox>(scrim).color.a,
        inExclusiveRange(0, .36),
      );

      await tester.pump(const Duration(milliseconds: 250));
      final focused = tester.getRect(bar);
      expect(focused.top, 60);
      expect(focused.left, 8);
      expect(focused.right, 367);
      expect(tester.getRect(panel).left, focused.left);
      expect(tester.getRect(panel).right, focused.right);
      expect(tester.widget<Opacity>(titleFade).opacity, 0);
      expect(tester.getTopLeft(panel).dy, focused.bottom + 8);
      expect(tester.getBottomLeft(panel).dy, 812 - 318 - 8);
      await tester.drag(panel, const Offset(0, -150));
      await tester.pump();
      expect(tester.widget<TextField>(field).focusNode!.hasFocus, isTrue);

      for (final query in ['123456', '', '1234567']) {
        tester.testTextInput.enterText(query);
        await tester.pump();
        expect(
          tester.state<EditableTextState>(find.byType(EditableText)),
          same(editable),
        );
        expect(tester.widget<TextField>(field).focusNode!.hasFocus, isTrue);
        expect(tester.testTextInput.isVisible, isTrue);
        if (query.isNotEmpty)
          expect(find.widgetWithText(ListTile, query), findsWidgets);
      }

      tester.widget<TextField>(field).focusNode!.unfocus();
      tester.view.resetViewInsets();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 330));
      expect(tester.getRect(bar), idle);
      expect(tester.widget<Opacity>(titleFade).opacity, 1);
      expect(scrim, findsNothing);
      await tester.pumpWidget(const SizedBox());
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets(
    'iPad search scrolls while idle and focuses at the safe top without widening',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1100, 800);
      tester.view.padding = const FakeViewPadding(top: 24);
      addTearDown(tester.view.reset);
      final scroll = ScrollController();
      addTearDown(scroll.dispose);
      await tester.pumpWidget(
        MaterialApp(
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
        ),
      );

      final field = find.byType(TextField);
      final bar = find.byKey(const ValueKey('search-input-toolbar'));
      final title = find.byKey(const ValueKey('search-title-opacity'));
      final initialTop = tester.getTopLeft(field).dy;
      final idleWidth = tester.getSize(bar).width;
      expect(initialTop, greaterThan(160));
      expect(tester.getCenter(title).dx, tester.getCenter(bar).dx);
      expect(
        tester.getBottomLeft(title).dy,
        lessThan(tester.getTopLeft(bar).dy),
      );
      expect(find.byType(ProgressiveToolbarBlur), findsOneWidget);
      expect(tester.getTopLeft(find.byType(ProgressiveToolbarBlur)).dy, 0);

      scroll.jumpTo(60);
      await tester.pump();
      expect(tester.getTopLeft(field).dy, closeTo(initialTop - 60, .1));

      scroll.jumpTo(300);
      await tester.pump();
      final pinnedTop = tester.getTopLeft(field).dy;
      expect(pinnedTop, lessThan(initialTop - 60));
      expect(pinnedTop, greaterThan(32));

      scroll.jumpTo(500);
      await tester.pump();
      expect(tester.getTopLeft(field).dy, pinnedTop);

      scroll.jumpTo(0);
      await tester.pump();
      expect(tester.getTopLeft(field).dy, initialTop);

      await tester.enterText(field, '123456');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 330));
      expect(tester.getTopLeft(bar).dy, 32);
      expect(tester.getSize(bar).width, idleWidth);
      expect(tester.widget<Opacity>(title).opacity, 0);
      expect(find.byType(ListTile), findsWidgets);
      await tester.dragFrom(const Offset(950, 500), const Offset(0, -250));
      await tester.pumpAndSettle();
      expect(scroll.offset, greaterThan(176));
      expect(find.byType(ListTile), findsNothing);
      expect(tester.widget<TextField>(field).controller!.text, '123456');
      await tester.pumpWidget(const SizedBox());
    },
  );
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
