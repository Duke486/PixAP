import 'dart:convert';
import 'dart:math';
import 'package:dio/dio.dart';
import 'package:pixez/models/account.dart' show AccountPersist;
import 'package:pixez/models/amwork.dart';

typedef Json = Map<String, dynamic>;

class DemoCatalog extends Interceptor {
  static final instance = DemoCatalog();
  static const names = ['晴川', '小舟', '山野手记', '林间来信', '海盐', '谷雨', '白岸', '晚风'];
  static const subjects = [
    '湖边的早晨',
    '山间散步',
    '海岸日记',
    '林中的光',
    '城市一角',
    '午后花园',
    '风经过旷野',
    '雨后街道',
    '远山来信',
    '树影之间',
    '旅途片段',
    '黄昏时分',
  ];
  static const date = '2026-04-18T09:30:00+09:00';
  static const photos = [
    '1470770841072-f978cf4d019e',
    '1464822759023-fed622ff2c3b',
    '1507525428034-b723cf961d3e',
    '1448375240586-882707db888b',
    '1477959858617-67f85cf4f1df',
    '1490750967868-88aa4486c946',
    '1501785888041-af3ef285b470',
    '1433086966358-54859d0ed716',
    '1472214103451-9374bd1c798e',
    '1470252649378-9c29740c9fa8',
    '1470071459604-3b5ec3a7fe05',
    '1441974231531-c6227db76b6e',
    '1472396961693-142e6e269027',
    '1473448912268-2022ce9509d8',
    '1500530855697-b586d89ba3ee',
    '1475924156734-496f6cac6ec1',
    '1518837695005-2083093ee35b',
    '1484291470158-b8f8d608850d',
    '1500534314209-a25ddb2bd429',
    '1455218873509-8097305ee378',
    '1454496522488-7a8e488e8606',
    '1519681393784-d120267933ba',
    '1462275646964-a0e3386b89fa',
    '1511497584788-876760111969',
    '1418065460487-3e41a6c84dc5',
    '1500534623283-312aade485b7',
    '1476673160081-cf065607f449',
    '1444723121867-7a241cacace9',
    '1519501025264-65ba15a82390',
    '1519608487953-e999c86e7455',
    '1511300636408-a63a89df3482',
    '1502082553048-f009c37129b9',
    '1501004318641-b39e6451bec6',
    '1469334031218-e382a71b716b',
  ];
  static const portraits = [
    '1517841905240-472988babdf9',
    '1534528741775-53994a69daeb',
    '1506794778202-cbfcc65ca6b2',
    '1544005313-94ddf0286df2',
    '1500648767791-00dcc994a43e',
    '1507003211169-0a1dd7228f2d',
    '1524504388940-b1c1722653e1',
    '1508214751196-bcfd4ca60f91',
  ];
  final picks = List.of(photos)..shuffle(Random());
  final ids = [
    for (var start = 0; start < 72; start += photos.length)
      ...(List.generate(min(72 - start, photos.length), (i) => start + i + 1)
        ..shuffle()),
  ];
  final bookmarks = {1, 3, 5, 8, 11, 14, 17, 23, 29};
  final novelBookmarks = {2, 4, 9, 13, 18, 28};
  final following = {2, 3, 4, 6, 8};
  final watched = {1, 2, 4, 5, 7};
  bool restricted = false;
  bool showAi = true;
  final comments = <String, List<Json>>{};
  String photo(int id, int w, int h) =>
      'https://images.unsplash.com/photo-${picks[id % picks.length]}?auto=format&fit=crop&w=$w&h=$h';
  String avatar(int id) =>
      'https://images.unsplash.com/photo-${portraits[(id - 1) % portraits.length]}?auto=format&fit=crop&w=144&h=144';
  String title(int id) =>
      '${subjects[id % subjects.length]} · ${(id - 1) ~/ subjects.length + 1}';
  int author(int id) => (id - 1) % names.length + 1;
  Json user(int id) => {
    'id': id,
    'name': names[(id - 1) % names.length],
    'account': 'studio$id',
    'comment': const [
      '散步时记录四季的颜色。',
      '喜欢去海边看日落。',
      '闲下来就往山里走。',
      '收集旅途中遇到的小故事。',
      '在街角找灵感。',
      '写一点花草和天气。',
      '把周末留给相机。',
      '偶尔写写散步日记。',
    ][(id - 1) % names.length],
    'profile_image_urls': {'medium': avatar(id)},
    'is_followed': following.contains(id),
    'is_access_blocking_user': false,
  };
  AccountPersist get account => AccountPersist.fromJson({
    'id': 1,
    'user_id': '1',
    'name': names.first,
    'account': 'studio1',
    'user_image': avatar(1),
    'device_token': '',
    'access_token': '',
    'refresh_token': '',
    'password': '',
    'mail_address': '',
    'is_premium': 0,
    'is_mail_authorized': 0,
    'x_restrict': 0,
  });
  Json work(int id, {bool novel = false}) {
    final height = novel ? 1080 : [720, 1000, 640][id % 3];
    final image = photo(id, 800, height);
    return {
      'id': id,
      'title': title(id),
      'caption': '这一篇记录的是${subjects[id % subjects.length]}。',
      'type': 'illust',
      'user': user(author(id)),
      'image_urls': {
        'square_medium': photo(id, 400, 400),
        'medium': image,
        'large': image,
      },
      'tags': [
        {
          'name': subjects[id % subjects.length],
          'translated_name': '日常',
          'added_by_uploaded_user': true,
        },
      ],
      'tools': ['相机'],
      'create_date': date,
      'page_count': 1,
      'width': 800,
      'height': height,
      'restrict': 0,
      'x_restrict': 0,
      'sanity_level': 2,
      'meta_single_page': {'original_image_url': image},
      'meta_pages': [],
      'total_view': 300 + id,
      'total_bookmarks': 42,
      'total_comments': 4,
      'visible': true,
      'is_bookmarked': (novel ? novelBookmarks : bookmarks).contains(id),
      'is_muted': false,
      'illust_ai_type': 1,
      if (novel) ...{
        'series': {'id': author(id), 'title': '四季手记'},
        'is_original': true,
        'text_length': 68,
        'is_mypixiv_only': false,
        'is_x_restricted': false,
        'novel_ai_type': 1,
      },
    };
  }

  AmWork articleWork(int id) => AmWork()
    ..title = title(id)
    ..user = user(author(id))['name']
    ..userLink = 'https://www.pixiv.net/users/${author(id)}'
    ..arworkLink = 'https://www.pixiv.net/artworks/$id'
    ..showImage = photo(id, 800, 640)
    ..userImage = avatar(author(id));

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final data = respond(options.uri.path, {
      ...options.uri.queryParameters,
      if (options.data is Map) ...Map<String, dynamic>.from(options.data),
    });
    handler.resolve(
      Response(
        requestOptions: options,
        statusCode: 200,
        data: data is String ? data : jsonDecode(jsonEncode(data)),
      ),
    );
  }

  dynamic respond(String path, Json params) {
    int number(String key) => int.tryParse('${params[key]}') ?? 1;
    final novel = path.contains('novel');
    final id = number(novel ? 'novel_id' : 'illust_id');
    final uid = number('user_id');
    final saved = novel ? novelBookmarks : bookmarks;
    if (path.contains('restricted-mode-settings')) {
      if (params.containsKey('is_restricted_mode_enabled'))
        restricted = params['is_restricted_mode_enabled'].toString() == 'true';
      return {'is_restricted_mode_enabled': restricted};
    }
    if (path.contains('ai-show-settings')) {
      if (params.containsKey('show_ai'))
        showAi = params['show_ai'].toString() == 'true';
      return {'show_ai': showAi};
    }
    if (path.endsWith('/follow/detail'))
      return {
        'follow_detail': {
          'is_followed': following.contains(uid),
          'restrict': 'public',
        },
      };
    if (path.contains('/watchlist/')) {
      final sid = number('series_id');
      if (path.endsWith('/add')) watched.add(sid);
      if (path.endsWith('/delete')) watched.remove(sid);
      return {
        'series': [
          for (final i in watched)
            {
              'id': i,
              'title': title(i),
              'user': user(author(i)),
              'latest_content_id': i,
              'published_content_count': 8,
              'url': photo(i, 600, 400),
              'last_published_content_datetime': date,
            },
        ],
        'next_url': null,
      };
    }
    if (path.contains('illust/series') || path.contains('illust-series/')) {
      final sid = number('illust_series_id');
      return {
        'illust_series_detail': {
          'id': sid,
          'title': title(sid),
          'create_date': date,
          'caption': '四季摄影手记',
          'user': user(1),
          'series_work_count': 8,
          'watchlist_added': watched.contains(sid),
        },
        'illust_series_first_illust': work(sid),
        'illusts': [for (final i in ids.take(8)) work(i)],
        'next_url': null,
      };
    }
    final collection = novel ? 'novels' : 'illusts';
    final tagList = [
      for (final name in subjects) {'name': name, 'translated_name': '日常'},
    ];
    if (path.endsWith('/autocomplete')) return {'tags': tagList};
    if (path.contains('trending-tags'))
      return {
        'trend_tags': [
          for (final i in ids.take(30))
            {
              'tag': title(i),
              'translated_name': '风景',
              'illust': work(i),
              'novel': work(i, novel: true),
            },
        ],
      };
    if (path.contains('/bookmark/add') || path.contains('/bookmark/delete')) {
      if (path.endsWith('/add')) {
        saved.add(id);
      } else {
        saved.remove(id);
      }
      return {};
    }
    if (path.contains('/follow/add') || path.contains('/follow/delete')) {
      if (path.endsWith('/add')) {
        following.add(uid);
      } else {
        following.remove(uid);
      }
      return {};
    }
    if (path.contains('/comment')) {
      final entries = comments.putIfAbsent(
        '$novel/$id',
        () => [
          for (final (index, text) in const [
            '很喜欢这里的光线。',
            '这个角度拍得真好。',
            '路过这里的时候也看到过这样的景色。',
            '配色看起来很舒服。',
          ].indexed)
            {
              'id': index + 1,
              'comment': text,
              'user': user(index + 2),
              'date': date,
              'has_replies': false,
            },
        ],
      );
      if (path.endsWith('/add'))
        entries.insert(0, {
          'id': entries.length + 1,
          'comment': params['comment'],
          'user': user(1),
          'date': date,
          'has_replies': false,
        });
      return {
        'comments': entries,
        'comment': entries.first,
        'total_comments': entries.length,
        'next_url': null,
      };
    }
    if (path.endsWith('/user/detail'))
      return {
        'user': user(uid),
        'profile': {
          for (final name in [
            'follow_users',
            'mypixiv_users',
            'illusts',
            'manga',
            'novels',
            'illust_bookmarks_public',
            'illust_series',
            'novel_series',
          ])
            'total_$name': 9,
          'background_image_url': photo(uid, 1000, 360),
          'is_premium': false,
          'is_using_custom_profile_image': true,
        },
        'profile_publicity': {
          for (final k in [
            'gender',
            'region',
            'birth_day',
            'birth_year',
            'job',
          ])
            k: 'public',
          'pawoo': false,
        },
        'workspace': {
          for (final k in [
            'pc',
            'monitor',
            'tool',
            'scanner',
            'tablet',
            'mouse',
            'printer',
            'desktop',
            'music',
            'desk',
            'chair',
            'comment',
          ])
            k: '',
        },
      };
    if (path.endsWith('/illust/detail')) return {'illust': work(id)};
    if (path.endsWith('/novel/detail')) return {'novel': work(id, novel: true)};
    if (path.contains('/webview/')) {
      final i = number('id');
      final data = {
        'id': '$i',
        'title': title(i),
        'userId': '${author(i)}',
        'coverUrl': photo(i, 600, 800),
        'tags': ['日常'],
        'caption': '散步手记',
        'cdate': date,
        'rating': {'like': 8, 'bookmark': 3, 'view': 18},
        'text':
            '${title(i)}\n\n'
            '${const ['我们沿着小路来到湖边。风吹过树梢，远处的小船慢慢靠岸。', '雨停后，石板路映着窗边的灯。街角的花店正在收拾门口的木箱。', '潮水刚刚退去，礁石间留下几面小小的镜子。我们在堤岸坐了一会。', '山路拐了几个弯才看见村庄。炊烟从屋顶升起来，消失在晚霞里。'][i % 4]}\n\n'
            '回去前，我们在附近转了一圈，把这段路记进了随身的本子。',
      };
      return '<html><script>var data = {novel: ${jsonEncode(data)}};</script></html>';
    }
    if (path.contains('spotlight'))
      return {
        'spotlight_articles': [
          for (final i in ids.take(18))
            {
              'id': i,
              'title': title(i),
              'pure_title': title(i),
              'thumbnail': photo(i, 764, 400),
              'article_url': 'https://www.pixivision.net/zh/a/$i',
              'publish_date': date,
            },
        ],
        'next_url': null,
      };
    if (path.contains('bookmark-tags'))
      return {
        'bookmark_tags': [
          {'name': '日常', 'count': saved.length},
        ],
      };
    if (path.endsWith('bookmark/detail'))
      return {
        'bookmark_detail': {
          'is_bookmarked': saved.contains(id),
          'tags': [],
          'restrict': 'public',
        },
      };
    if (path.endsWith('/user') ||
        path.contains('user/recommended') ||
        path.contains('user/related') ||
        path.contains('user/following') ||
        path.contains('user/follower')) {
      return {
        'user_previews': [
          for (var i = 1; i <= names.length; i++)
            if (!path.endsWith('following') || following.contains(i))
              {
                'user': user(i),
                'illusts': [
                  for (final j in ids.where((j) => author(j) == i).take(3))
                    work(j),
                ],
                'novels': [
                  for (final j in ids.where((j) => author(j) == i).take(3))
                    work(j, novel: true),
                ],
                'is_muted': false,
              },
        ],
        'next_url': null,
      };
    }
    if (path.endsWith('/novel/series')) {
      final sid = number('series_id');
      return {
        'novel_series_detail': {
          'id': sid,
          'title': '四季手记',
          'caption': '沿途的风景',
          'is_original': true,
          'is_concluded': false,
          'content_count': 8,
          'total_character_count': 544,
          'user': user(sid),
          'display_text': '四季手记',
          'novel_ai_type': 1,
          'watchlist_added': watched.contains(sid),
        },
        'novel_series_first_novel': work(sid, novel: true),
        'novel_series_latest_novel': work(sid + 2, novel: true),
        'novels': [for (final i in ids.take(8)) work(i, novel: true)],
        'next_url': null,
      };
    }
    final query = params['word']?.toString().trim() ?? '';
    final items = ids.where(
      (i) =>
          (!path.contains('/search/') ||
              title(i).contains(query) ||
              query == '日常') &&
          (!path.contains('/bookmarks/') || saved.contains(i)) &&
          (!path.contains('/user/illusts') && !path.contains('/user/novels') ||
              author(i) == uid),
    );
    return {
      collection: [for (final i in items) work(i, novel: novel)],
      'ranking_illusts': novel ? [] : [for (final i in ids.take(12)) work(i)],
      'ranking_novels': novel
          ? [for (final i in ids.take(12)) work(i, novel: true)]
          : [],
      'contest_exists': false,
      'privacy_policy': {},
      'next_url': null,
    };
  }
}
