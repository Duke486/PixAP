import 'package:pixez/component/cover_blur.dart';
/*
 * Copyright (C) 2020. by perol_notsf, All rights reserved
 *
 * This program is free software: you can redistribute it and/or modify it under
 * the terms of the GNU General Public License as published by the Free Software
 * Foundation, either version 3 of the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful, but WITHOUT ANY
 * WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
 * FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License along with
 * this program. If not, see <http://www.gnu.org/licenses/>.
 *
 */

import 'package:pixez/component/ipad_surface.dart';
import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:easy_refresh/easy_refresh.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:mobx/mobx.dart' show runInAction;
import 'package:pixez/component/illust_card.dart';
import 'package:pixez/component/pixez_default_header.dart';
import 'package:pixez/component/pixiv_image.dart';
import 'package:pixez/er/prefer.dart';
import 'package:pixez/exts.dart';
import 'package:pixez/i18n.dart';
import 'package:pixez/lighting/lighting_store.dart';
import 'package:pixez/main.dart';
import 'package:pixez/models/recommend.dart';
import 'package:pixez/models/spotlight_response.dart';
import 'package:pixez/models/user_preview.dart';
import 'package:pixez/network/api_client.dart';
import 'package:pixez/page/hello/recom/home_feed_refresh.dart';
import 'package:pixez/page/hello/recom/recom_user_road.dart';
import 'package:pixez/page/hello/recom/recom_user_store.dart';
import 'package:pixez/page/hello/recom/spotlight_store.dart';
import 'package:pixez/page/hello/setting/demo_mode.dart';
import 'package:pixez/page/soup/soup_page.dart';
import 'package:pixez/page/spotlight/spotlight_page.dart';
import 'package:waterfall_flow/waterfall_flow.dart';

class RecomSpolightPage extends StatefulWidget {
  RecomSpolightPage({Key? key}) : super(key: key);

  @override
  _RecomSpolightPageState createState() => _RecomSpolightPageState();
}

class _RecomSpolightPageState extends State<RecomSpolightPage>
    with AutomaticKeepAliveClientMixin {
  static const double coverWidth = 278;
  static const double coverHeight = 173;
  static const double blurRadius = 16;
  static const double blurExtent = .42;
  static const double veil = .36;
  static const double midpoint = .44;
  static const double plateau = .09;
  static const double opacity = 1;

  late SpotlightStore spotlightStore;
  late LightingStore _lightingStore;
  late RecomUserStore _recomUserStore;
  late StreamSubscription<String> subscription;
  late EasyRefreshController _easyRefreshController;
  late ScrollController _scrollController;
  late HomeFeedRefresh<_HomeRecommendations> _homeRefresh;

  @override
  void dispose() {
    _homeRefresh.dispose();
    subscription.cancel();
    _scrollController.dispose();
    _easyRefreshController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    _scrollController = ScrollController();
    _easyRefreshController = EasyRefreshController(controlFinishLoad: true);
    _recomUserStore = RecomUserStore(null);
    spotlightStore = SpotlightStore(null);
    _lightingStore = LightingStore(
      ApiForceSource(
          futureGet: (e) => apiClient.getRecommend(), glanceKey: "recom"),
    )..easyRefreshController = _easyRefreshController;
    super.initState();
    final userId = accountStore.now?.userId;
    _homeRefresh = HomeFeedRefresh(
      cacheKey: userId == null || DemoMode.active
          ? null
          : 'home_feed.v1.$userId.${Prefer.getInt("language_num")}',
      decode: _HomeRecommendations.fromJson,
      encode: (snapshot) => snapshot.toJson(),
      fetch: _fetchHome,
      show: _applySnapshot,
    )..restore();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_homeRefresh.refresh(manual: false));
    });
    subscription = topStore.topStream.listen((event) {
      if (event == "100" && _scrollController.hasClients) {
        _scrollController.jumpTo(0);
      }
    });
  }

  Future<HomeFeedResult<_HomeRecommendations>> _fetchHome(_HomeRecommendations? previous) async {
    final (feed, articles, users) = await (
      fetchHomeFeedPart(() => apiClient.getRecommend(force: true), Recommend.fromJson),
      fetchHomeFeedPart(() => apiClient.getSpotlightArticles('all', force: true), SpotlightResponse.fromJson),
      fetchHomeFeedPart(() => apiClient.getUserRecommended(force: true), UserPreviewsResponse.fromJson),
    ).wait;
    return (
      snapshot: _HomeRecommendations(
        feed.snapshot,
        articles.snapshot ?? previous?.spotlight,
        users.snapshot ?? previous?.users,
      ),
      error: feed.error,
    );
  }

  void _applySnapshot(_HomeRecommendations? snapshot, {required bool fromNetwork}) {
    runInAction(() {
      _lightingStore.replaceRecommendations(snapshot?.feed, publishWidget: fromNetwork);
      spotlightStore.articles
        ..clear()
        ..addAll(snapshot?.spotlight?.spotlightArticles ?? const []);
      _recomUserStore.users
        ..clear()
        ..addAll(snapshot?.users?.user_previews ?? const []);
      _recomUserStore.nextUrl = snapshot?.users?.next_url;
    });
    _easyRefreshController.resetFooter();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return HomeFeedOverlay(
      refresh: _homeRefresh,
      child: ListenableBuilder(
        listenable: _homeRefresh,
        builder: (context, _) => buildEasyRefresh(context),
      ),
    );
  }

  bool backToTopVisible = false;

  Widget buildEasyRefresh(BuildContext context) {
    return Stack(
      children: [
        if (!usesAppleControls(context)) NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) => [
            SliverAppBar(
              elevation: 0.0,
              titleSpacing: 0.0,
              automaticallyImplyLeading: false,
              // backgroundColor: Theme.of(context).canvasColor,
              title: Text(""),
            )
          ],
          body: ListView(),
        ),
        EasyRefresh.builder(
          controller: _easyRefreshController,
          callLoadOverOffset: Platform.isIOS ? 2 : 5,
          header: usesAppleControls(context)
              ? PixezDefault.header(context, position: IndicatorPosition.locator, safeArea: false)
              : PixezDefault.header(context),
          footer: PixezDefault.footer(context),
          onRefresh: () async => await _homeRefresh.refresh(manual: true)
              ? IndicatorResult.success : IndicatorResult.fail,
          onLoad: () async {
            await _lightingStore.fetchNext();
          },
          childBuilder: (context, physics) => Observer(
            builder: (context) => _buildWaterFall(context, physics),
          ),
        ),
      ],
    );
  }

  Widget _buildWaterFall(BuildContext context, ScrollPhysics physics) {
    _lightingStore.iStores
        .removeWhere((element) => element.illusts!.hateByUser());
    return NotificationListener<ScrollNotification>(
      onNotification: (ScrollNotification notification) {
        ScrollMetrics metrics = notification.metrics;
        if (backToTopVisible == metrics.atEdge && mounted) {
          setState(() {
            backToTopVisible = !backToTopVisible;
          });
        }
        return true;
      },
      child: CustomScrollView(
        controller: _scrollController,
        physics: physics,
        slivers: [
          SliverToBoxAdapter(
            child: Container(height: MediaQuery.of(context).padding.top),
          ),
          if (usesAppleControls(context)) const HeaderLocator.sliver(),
          SliverToBoxAdapter(
            child: _buildFirstRow(context),
          ),
          SliverToBoxAdapter(
            child: _buidTagSpotlightRow(context),
          ),
          SliverToBoxAdapter(
            child: _buildSecondRow(context, I18n.of(context).recommend_for_you),
          ),
          SliverPadding(padding: EdgeInsets.only(right: usesAppleControls(context) ? 12 : 0),
            sliver: _buildWaterfall(context, MediaQuery.of(context).orientation))
        ],
      ),
    );
  }

  int _buildSliderValue(BuildContext context, Orientation orientation) {
    final currentValue = (orientation == Orientation.portrait
            ? userSetting.crossAdapterWidth
            : userSetting.hCrossAdapterWidth)
        .toDouble();
    var nowAdaptWidth = max(currentValue, 50.0);
    nowAdaptWidth = min(nowAdaptWidth, 2160);
    return max((MediaQuery.of(context).size.width / nowAdaptWidth), 1.0)
        .toInt();
  }

  Widget _buildWaterfall(BuildContext context, Orientation orientation) {
    var count = 2;
    if (orientation == Orientation.portrait
        ? userSetting.crossAdapt
        : userSetting.hCrossAdapt) {
      count = _buildSliderValue(context, orientation);
    } else {
      count = (orientation == Orientation.portrait)
          ? userSetting.crossCount
          : userSetting.hCrossCount;
    }
    return _lightingStore.iStores.isNotEmpty
        ? SliverWaterfallFlow(
            gridDelegate: SliverWaterfallFlowDelegateWithFixedCrossAxisCount(
              crossAxisCount: count,
            ),
            delegate:
                SliverChildBuilderDelegate((BuildContext context, int index) {
              return IllustCard(
                lightingStore: _lightingStore,
                store: _lightingStore.iStores[index],
                iStores: _lightingStore.iStores,
              );
            }, childCount: _lightingStore.iStores.length),
          )
        : (_homeRefresh.error != null
            ? SliverToBoxAdapter(
                child: Container(
                  child: Column(
                    mainAxisSize: MainAxisSize.max,
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: <Widget>[
                      Container(
                        height: 50,
                      ),
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text(':(',
                            style: Theme.of(context).textTheme.headlineMedium),
                      ),
                      TextButton(
                          onPressed: () {
                            _easyRefreshController.callRefresh(scrollController: _scrollController);
                          },
                          child: Text(I18n.of(context).retry)),
                      Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Text(
                            (_homeRefresh.error.toString().contains('400')
                                ? '${I18n.of(context).error_400_hint}\n ${_homeRefresh.error}'
                                : '${_homeRefresh.error}'),
                          ))
                    ],
                  ),
                ),
              )
            : SliverToBoxAdapter(
                child: Container(
                  height: 30,
                ),
              ));
  }

  Widget _buidTagSpotlightRow(BuildContext context) {
    var expectCardWidget = MediaQuery.of(context).size.width * 0.7;
    expectCardWidget = expectCardWidget > 244 ? 244 : expectCardWidget;
    final cardWidth = usesIPadLayout(context) ? coverWidth : expectCardWidget;
    final expectCardHeight = usesIPadLayout(context) ? coverHeight : cardWidth * .525;
    return Container(
      height: expectCardHeight + (usesAppleControls(context) ? 12 : 0),
      padding: EdgeInsets.zero,
      child: spotlightStore.articles.isNotEmpty
          ? ListView.builder(
              padding: usesAppleControls(context) ? const EdgeInsets.only(top: 3, bottom: 9) : null,
              primary: false,
              physics: usesAppleControls(context) ? const ClampingScrollPhysics() : null,
              itemBuilder: (context, index) {
                final spotlight = spotlightStore.articles[index];
                return Card(
                  clipBehavior: Clip.antiAlias,
                  margin: EdgeInsets.symmetric(horizontal: 8.0),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.all(Radius.circular(usesAppleControls(context) ? 16 : 8))),
                  child: Hero(
                    tag: "spotlight_image_${spotlight.hashCode}",
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          Navigator.of(context).push(MaterialPageRoute(
                              builder: (BuildContext context) {
                            return SoupPage(
                              url: spotlight.articleUrl,
                              spotlight: spotlight,
                              heroTag: 'spotlight_image_${spotlight.hashCode}',
                            );
                          }));
                        },
                        child: Container(
                            width: cardWidth,
                            height: expectCardHeight,
                            decoration: BoxDecoration(
                                image: DecorationImage(
                                    fit: BoxFit.cover,
                                    image: PixivProvider.url(
                                        spotlight.thumbnail))),
                            child: usesAppleControls(context) ? Stack(fit: StackFit.expand, children: [
                              CoverBlur(image: PixivProvider.url(spotlight.thumbnail), sigma: blurRadius,
                                extent: blurExtent, midpoint: midpoint, plateau: plateau, opacity: opacity, tint: Colors.black.withValues(alpha: veil)),
                              Align(alignment: Alignment.bottomLeft, child: Padding(padding: const EdgeInsets.fromLTRB(12,0,12,8),
                                child: Text(spotlight.title, maxLines: 2, overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)))),
                            ]) : Container(
                                child: Align(
                              alignment: Alignment.bottomCenter,
                              child: Container(
                                decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.black.withValues(alpha: .38),
                                    Colors.black.withValues(alpha: .82),
                                  ],
                                )),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8.0, vertical: 8.0),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.max,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          "${spotlight.title}",
                                          maxLines: 2,
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            // shadows: [
                                            //   Shadow(
                                            //       color: Colors.black,
                                            //       offset: Offset(0.5, 0.5),
                                            //       blurRadius: 1.0)
                                            // ]
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ))),
                      ),
                    ),
                  ),
                );
              },
              itemCount: spotlightStore.articles.length,
              scrollDirection: Axis.horizontal,
            )
          : Container(),
    );
  }

  Widget _buildFirstRow(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 0.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Container(
            child: Padding(
              child: Text(
                I18n.of(context).spotlight,
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 24.0,
                    color: Theme.of(context).textTheme.titleLarge!.color),
              ),
              padding: EdgeInsets.only(left: 20.0, bottom: 10.0),
            ),
          ),
          const Spacer(),
          Padding(
            child: TextButton.icon(
              iconAlignment: IconAlignment.end,
              icon: const Icon(Icons.chevron_right, size: 17),
              label: Text(
                I18n.of(context).more,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              onPressed: () {
                Navigator.of(context)
                    .push(MaterialPageRoute(builder: (BuildContext context) {
                  return SpotLightPage();
                }));
              },
            ),
            padding: EdgeInsets.all(8.0),
          )
        ],
      ),
    );
  }

  Widget _buildSecondRow(BuildContext context, String title) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Padding(
          child: Center(
            child: Text(
              title,
              overflow: TextOverflow.clip,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24.0),
            ),
          ),
          padding: EdgeInsets.only(left: 20.0),
        ),
        Expanded(child: RecomUserRoad(recomUserStore: _recomUserStore))
      ],
    );
  }

  @override
  bool get wantKeepAlive => true;
}

class _HomeRecommendations {
  const _HomeRecommendations(this.feed, this.spotlight, this.users);

  final Recommend? feed;
  final SpotlightResponse? spotlight;
  final UserPreviewsResponse? users;

  factory _HomeRecommendations.fromJson(Map<String, dynamic> json) {
    final feed = Recommend.fromJson(json['feed'] as Map<String, dynamic>);
    final spotlight = json['spotlight'] as Map<String, dynamic>?;
    final users = json['users'] as Map<String, dynamic>?;
    return _HomeRecommendations(
      feed,
      spotlight == null ? null : SpotlightResponse.fromJson(spotlight),
      users == null ? null : UserPreviewsResponse.fromJson(users),
    );
  }

  Map<String, dynamic> toJson() => {
    'feed': feed?.toJson(),
    'spotlight': spotlight?.toJson(),
    'users': users?.toJson(),
  };
}
