import 'package:flutter_test/flutter_test.dart';
import 'package:pixez/models/illust.dart';
import 'package:pixez/network/demo_catalog.dart';
import 'package:pixez/store/user_setting.dart';
import 'package:pixez/store/welcome_page_type.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('quality defaults apply only until the user saves a choice', () async {
    SharedPreferences.setMockInitialValues({});
    final settings = UserSetting();
    await settings.init();
    expect(settings.feedPreviewQuality, 1);
    expect(settings.pictureQuality, 2);
    expect(settings.mangaQuality, 2);
    expect(settings.zoomQuality, 1);

    await settings.changeFeedPreviewQuality(0);
    await settings.setPictureQuality(1);
    await settings.setMangaQuality(0);
    await settings.change(0);
    final restored = UserSetting();
    await restored.init();
    expect(restored.feedPreviewQuality, 0);
    expect(restored.pictureQuality, 1);
    expect(restored.mangaQuality, 0);
    expect(restored.zoomQuality, 0);
  });

  test('missing original image metadata falls back to the large rendition', () {
    final illust = Illusts.fromJson(DemoCatalog.instance.work(1))
      ..metaPages = []
      ..metaSinglePage = null;
    expect(illust.originalImageUrlAt(0), isNull);
    expect(illust.illustDetailUrl, illust.imageUrls.large);
    expect(illust.managaDetailUrl, illust.imageUrls.large);
  });

  test(
    'startup choices follow tab order and old settings choices open home',
    () {
      const platform = WelcomePagePlatform.material;
      expect(platform.supportedTypes, [
        WelcomePageType.home,
        WelcomePageType.rank,
        WelcomePageType.quickView,
        WelcomePageType.search,
      ]);
      expect(platform.indexOf(WelcomePageType.fromCode('setting')), 0);
      expect(
        platform.indexOf(
          welcomePageTypeFromLegacyIndex(
            4,
            legacyLayout: WelcomePageLegacyLayout.material,
          ),
        ),
        0,
      );
    },
  );
}
