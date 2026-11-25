import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pixez/component/pixiv_image.dart';
import 'package:pixez/er/prefer.dart';
import 'package:pixez/main.dart';
import 'package:pixez/models/account.dart';
import 'package:pixez/models/tags.dart';
import 'package:pixez/network/api_client.dart';
import 'package:pixez/page/search/search_page.dart';
import 'package:pixez/page/search/trend_tags_store.dart';
import 'package:pixez/src/generated/i18n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _GridNetwork extends DioForNative {
  var pending = Completer<Response<dynamic>>();
  @override
  Future<Response<T>> get<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onReceiveProgress,
  }) async => (await pending.future) as Response<T>;
}

class _EmptyHistory extends TagsPersistProvider {
  @override
  Future<void> open() async {}

  @override
  Future<List<TagsPersist>> getAllAccount() async => [];
}

Map<String, dynamic> _grid(String tag, {String url = 's'}) => {
  'trend_tags': [
    {
      'tag': tag,
      'illust': {
        'id': 7,
        'image_urls': {'square_medium': url, 'medium': 'm', 'large': 'l'},
      },
    },
  ],
};

AccountPersist _account() => AccountPersist(
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'cached grid is visible during refresh and survives a network failure',
    () async {
      final key = 'search_grid_v1.42.${userSetting.locale}';
      SharedPreferences.setMockInitialValues({key: jsonEncode(_grid('old'))});
      await Prefer.init();
      accountStore.now = _account();
      addTearDown(() => accountStore.now = null);
      final net = _GridNetwork();
      apiClient.httpClient = net;
      final store = TrendTagsStore();
      final updating = store.fetch();
      expect(store.trendTags.single.tag, 'old');
      net.pending.complete(
        Response<dynamic>(
          requestOptions: RequestOptions(path: '/'),
          data: _grid('new'),
        ),
      );
      await updating;
      expect(store.trendTags.single.tag, 'new');
      net.pending = Completer<Response<dynamic>>();
      final restored = TrendTagsStore();
      final refresh = restored.fetch();
      expect(restored.trendTags.single.tag, 'new');
      net.pending.completeError(StateError('offline'));
      await refresh;
      expect(restored.trendTags.single.tag, 'new');
    },
  );

  testWidgets(
    'a grid tile fades in the decoded replacement over the old image',
    (tester) async {
      const oldUrl = 'https://i.pximg.net/old.jpg';
      const newUrl = 'https://i.pximg.net/new.jpg';
      final key = 'search_grid_v1.42.${userSetting.locale}';
      SharedPreferences.setMockInitialValues({
        key: jsonEncode(_grid('old', url: oldUrl)),
      });
      await Prefer.init();
      await Prefer.setString(key, jsonEncode(_grid('old', url: oldUrl)));
      final history = tagHistoryStore.tagsPersistProvider;
      tagHistoryStore.tagsPersistProvider = _EmptyHistory();
      accountStore.now = _account();
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(800, 1000);
      final messenger = tester.binding.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(
        SystemChannels.platform_views,
        (_) async => null,
      );
      addTearDown(() {
        tagHistoryStore.tagsPersistProvider = history;
        accountStore.now = null;
        tester.view.reset();
        messenger.setMockMethodCallHandler(SystemChannels.platform_views, null);
      });

      final cache = PaintingBinding.instance.imageCache;
      pixivCacheManager = null;
      Completer<ImageInfo> imageFor(String url) {
        final provider = PixivProvider.url(url);
        final frame = Completer<ImageInfo>();
        cache.putIfAbsent(
          provider,
          () => OneFrameImageStreamCompleter(frame.future),
        );
        addTearDown(() => cache.evict(provider));
        return frame;
      }

      ImageInfo decodedImage() {
        final recorder = ui.PictureRecorder();
        ui.Canvas(
          recorder,
        ).drawColor(const ui.Color(0xff002050), ui.BlendMode.src);
        final picture = recorder.endRecording();
        final image = picture.toImageSync(2, 2);
        picture.dispose();
        return ImageInfo(image: image);
      }

      final oldImage = imageFor(oldUrl);
      final newImage = imageFor(newUrl);
      final net = _GridNetwork();
      apiClient.httpClient = net;
      await tester.pumpWidget(
        const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: SearchPage()),
        ),
      );

      final artwork = find.descendant(
        of: find.byType(Card),
        matching: find.byType(RawImage),
      );
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('#old'), findsOneWidget);
      expect(artwork, findsNothing);
      oldImage.complete(decodedImage());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      expect(artwork, findsOneWidget);

      net.pending.complete(
        Response<dynamic>(
          requestOptions: RequestOptions(path: '/'),
          data: _grid('new', url: newUrl),
        ),
      );
      await tester.pump();
      expect(find.text('#old'), findsOneWidget);
      expect(artwork, findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);

      newImage.complete(decodedImage());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('#new'), findsOneWidget);
      expect(artwork, findsNWidgets(2));
      await tester.pump(const Duration(milliseconds: 250));
      expect(artwork, findsOneWidget);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );
}
