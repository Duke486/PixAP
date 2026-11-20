import 'dart:async';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pixez/component/ipad_surface.dart';
import 'package:pixez/component/painter_avatar.dart';
import 'package:pixez/component/sort_group.dart';
import 'package:pixez/main.dart';
import 'package:pixez/models/account.dart';
import 'package:pixez/network/api_client.dart';
import 'package:pixez/page/hello/new/new_page.dart';
import 'package:pixez/src/generated/i18n/app_localizations.dart';

void main() {
  testWidgets('iPad activity toolbar stays centered while its pages swipe', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1080, 800);
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      SystemChannels.platform_views,
      (_) async => null,
    );
    addTearDown(() {
      messenger.setMockMethodCallHandler(SystemChannels.platform_views, null);
      tester.view.reset();
      debugDefaultTargetPlatformOverride = null;
      accountStore.now = null;
    });
    accountStore.now = AccountPersist(
      userId: '42',
      userImage: '',
      accessToken: '',
      refreshToken: '',
      deviceToken: '',
      passWord: '',
      name: '',
      account: '',
      mailAddress: '',
      isPremium: 0,
      xRestrict: 0,
      isMailAuthorized: 0,
    );
    final network = _PendingDio();
    apiClient.httpClient = network;
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(body: NewPage()),
        ),
      ),
    );
    await tester.pump();

    final pager = find.byWidgetPredicate(
      (widget) => widget is NativeGlassControl && widget.labels.length == 4,
    );
    final filters = find.byType(SortGroup);
    final translations = AppLocalizations.of(tester.element(pager))!;
    NativeGlassControl tabs() => tester.widget<NativeGlassControl>(pager);
    final fixedRect = tester.getRect(pager);
    expect(fixedRect.center.dx, 540);
    expect(tabs().labels.take(2), [translations.bookmark, translations.news]);
    expect(tabs().index, 0);
    expect(tester.getRect(filters).left, greaterThan(fixedRect.right));
    expect(find.byType(PainterAvatar), findsNothing);
    expect(find.byIcon(Icons.tag), findsNothing);

    tester
        .widget<NativeGlassControl>(
          find.descendant(
            of: filters,
            matching: find.byType(NativeGlassControl),
          ),
        )
        .onSelect(1);
    await tester.pump();
    expect(network.restrictions.last, 'private');
    expect(tester.getRect(pager), fixedRect);

    final gesture = await tester.startGesture(const Offset(850, 350));
    await gesture.moveBy(
      const Offset(-330, 0),
      timeStamp: const Duration(milliseconds: 30),
    );
    await tester.pump();
    expect(tester.getRect(pager), fixedRect);
    await gesture.moveBy(
      const Offset(-450, 0),
      timeStamp: const Duration(milliseconds: 80),
    );
    await tester.pump();
    await gesture.up(timeStamp: const Duration(milliseconds: 90));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pump();
    expect(tabs().index, 1);
    expect(tester.getRect(pager), fixedRect);

    tabs().onSelect(2);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(tabs().index, 2);
    expect(filters, findsNothing);
    expect(tester.getRect(pager), fixedRect);

    topStore.setTop('300');
    await tester.pump();
    expect(tabs().index, 2);

    tabs().onSelect(0);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(tabs().index, 0);
    expect(tester.widget<SortGroup>(filters).initIndex, 1);
    expect(tester.getRect(pager), fixedRect);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    debugDefaultTargetPlatformOverride = null;
  });
}

class _PendingDio extends DioForNative {
  final restrictions = <Object?>[];

  @override
  Future<Response<T>> get<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onReceiveProgress,
  }) {
    if (queryParameters?.containsKey('restrict') ?? false) {
      restrictions.add(queryParameters!['restrict']);
    }
    return Completer<Response<T>>().future;
  }
}
