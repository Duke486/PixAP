import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:pixez/network/api_client.dart';
import 'package:pixez/models/user_detail.dart';
import 'package:pixez/models/recommend.dart';
import 'package:pixez/models/spotlight_response.dart';
import 'package:pixez/models/novel_recom_response.dart';
import 'package:pixez/models/novel_web_response.dart';
import 'package:pixez/models/trend_tags.dart';
import 'package:pixez/page/novel/viewer/novel_store.dart';
import 'package:pixez/page/hello/setting/demo_mode.dart';
import 'package:pixez/store/account_store.dart';
import 'package:pixez/page/soup/soup_store.dart';

void main() {
  test(
    'original account, feed, profile, search, spotlight and novel readers use demo data',
    () async {
      DemoMode.active = true;
      addTearDown(() => DemoMode.active = false);
      final account = AccountStore();
      await account.fetch();
      expect(account.now!.name, '晴川');
      expect(account.accounts, isEmpty);
      final client = ApiClient();
      final feed = Recommend.fromJson((await client.getRecommend()).data);
      expect(feed.illusts.length, 72);
      expect(
        feed.illusts
            .map((work) => Uri.parse(work.imageUrls.medium).path)
            .toSet()
            .length,
        greaterThanOrEqualTo(30),
      );
      expect(
        Uri.parse(feed.illusts.first.imageUrls.medium).host,
        'images.unsplash.com',
      );
      expect(
        UserDetail.fromJson((await client.getUser(1)).data).user.name,
        account.now!.name,
      );
      final tags = await client.httpClient.get('/v1/trending-tags/illust');
      expect(TrendingTag.fromJson(tags.data).trend_tags, isNotEmpty);
      final articles = SpotlightResponse.fromJson(
        (await client.getSpotlightArticles('all')).data,
      );
      final reader = SoupStore();
      await reader.fetch(articles.spotlightArticles.first.articleUrl);
      expect(reader.amWorks, isNotEmpty);
      expect(
        Novel.fromJson((await client.getNovelDetail(3)).data['novel']).id,
        3,
      );
      final html = (await client.webviewNovel(3)).data;
      expect(
        NovelWebResponse.fromJson(
          jsonDecode(parseNovelJsonFromHtml(html)!),
        ).text,
        isNotEmpty,
      );
    },
  );
}
