import 'dart:async';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pixez/component/ipad_surface.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pixez/component/progressive_toolbar_blur.dart';
import 'package:pixez/er/prefer.dart';
import 'package:pixez/network/api_client.dart';
import 'package:pixez/page/hello/ranking/rank_page.dart';
import 'package:pixez/page/hello/ranking/rank_store.dart';
import 'package:pixez/src/generated/i18n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('all ranking tabs fit and remain tappable at narrow widths', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(() {
      tester.view.reset();
      debugDefaultTargetPlatformOverride = null;
    });
    SharedPreferences.setMockInitialValues({
      'mode_list': RankStore().intialModeList,
    });
    await Prefer.init();
    // Leave requests pending so this test exercises only the toolbar.
    final network = _PendingDio();
    apiClient.httpClient = network;

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh', 'CN'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: RankPage()),
      ),
    );
    await tester.pump();

    final pages = find.byType(TabBarView);
    final controller = DefaultTabController.of(tester.element(pages));
    const labels = [
      '每日',
      '男性向',
      '女性向',
      '原创',
      '新人',
      '每周',
      '每月',
      'AI',
      '🆁18 AI',
      '🆁18',
      '🆁18 周榜',
      '🆁18 怪诞',
    ];
    expect(
      tester.getCenter(find.text('重选')).dx,
      lessThan(tester.getCenter(find.byIcon(Icons.date_range)).dx),
    );
    for (final label in labels) {
      expect(find.text(label).hitTestable(), findsOneWidget);
    }
    final last = find.text(labels.last);
    await tester.drag(last, const Offset(-120, 0));
    await tester.pump();
    expect(controller.index, 0);
    await tester.tap(last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(controller.index, labels.length - 1);

    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      SystemChannels.platform_views,
      (_) async => null,
    );
    addTearDown(
      () => messenger.setMockMethodCallHandler(
        SystemChannels.platform_views,
        null,
      ),
    );
    final glass = find.byType(NativeGlassControl);
    for (final width in [650.0, 1100.0]) {
      tester.view.physicalSize = Size(width, 800);
      await tester.pump();
      expect(find.byType(ProgressiveToolbarBlur), findsOneWidget);
      final rows = tester.widgetList<NativeGlassControl>(glass).toList();
      expect(rows.expand((row) => row.labels), orderedEquals(labels));
      expect(rows.last.index, rows.last.labels.length - 1);
      expect(rows.every((row) => row.prominent), isTrue);
      for (final view in glass.evaluate()) {
        final rect = tester.getRect(
          find.byElementPredicate((element) => element == view),
        );
        expect(rect.left, greaterThanOrEqualTo(0));
        expect(rect.right, lessThanOrEqualTo(width));
      }
    }
    tester.widgetList<NativeGlassControl>(glass).first.onSelect(0);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(controller.index, 0);

    const dates = MethodChannel('pixez/rankDatePicker');
    final requests = <MethodCall>[];
    List<int>? response;
    messenger.setMockMethodCallHandler(dates, (call) async {
      requests.add(call);
      return response;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(dates, null));
    await tester.tap(find.byIcon(Icons.date_range));
    await tester.pump();
    expect(requests.single.method, 'pick');
    expect(requests.single.arguments['minimum'], [2007, 8, 1]);
    expect(network.dates.last, isNull);

    response = [2020, 2, 3];
    await tester.tap(find.byIcon(Icons.date_range));
    await tester.pump();
    await tester.pump();
    expect(network.dates.last, '2020-02-03');
    expect(controller.index, 0);
    await tester.tap(find.text('重选'));
    await tester.pumpAndSettle();
    final save = find.widgetWithText(TextButton, '保存');
    expect(
      find.ancestor(of: save, matching: find.byType(IPadSurface)),
      findsOneWidget,
    );
    expect(
      tester.getTopLeft(save).dy,
      greaterThan(tester.getBottomLeft(find.byType(Wrap).last).dy),
    );
    await tester.tap(find.widgetWithText(FilterChip, '🆁18 周榜'));
    await tester.tap(find.widgetWithText(FilterChip, '🆁18 怪诞'));
    await tester.tap(save);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(Prefer.getStringList('mode_list'), ['week_r18', 'week_r18g']);
    expect(
      tester.widgetList<NativeGlassControl>(glass).expand((row) => row.labels),
      ['🆁18 周榜', '🆁18 怪诞'],
    );

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    debugDefaultTargetPlatformOverride = null;
  });
}

class _PendingDio extends DioForNative {
  final dates = <Object?>[];
  @override
  Future<Response<T>> get<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onReceiveProgress,
  }) {
    dates.add(queryParameters?['date']);
    return Completer<Response<T>>().future;
  }
}
