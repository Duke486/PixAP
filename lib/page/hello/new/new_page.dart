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

import 'package:material_ui/material_ui.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:pixez/component/sort_group.dart';
import 'package:pixez/component/progressive_toolbar_blur.dart';
import 'package:pixez/i18n.dart';
import 'package:pixez/main.dart';
import 'package:pixez/page/follow/follow_list.dart';
import 'package:pixez/page/hello/new/illust/new_illust_page.dart';
import 'package:pixez/page/preview/preview_page.dart';
import 'package:pixez/page/user/bookmark/bookmark_page.dart';
import 'package:pixez/page/watchlist/watchlist.dart';
import 'package:pixez/utils/haptic_util.dart';

class NewPage extends StatefulWidget {
  final String newRestrict, bookRestrict, painterRestrict;

  const NewPage({
    Key? key,
    this.newRestrict = "public",
    this.bookRestrict = "public",
    this.painterRestrict = "public",
  }) : super(key: key);

  @override
  _NewPageState createState() => _NewPageState();
}

class _NewPageState extends State<NewPage>
    with AutomaticKeepAliveClientMixin, TickerProviderStateMixin {
  late TabController _tabController;
  static const _bookmarkTab = 0;
  static const _activityTab = 1;
  static const _watchlistTab = 2;
  static const _followingTab = 3;
  static const _scrollTargets = ['302', '301', '303', '304'];
  final _filterIndices = [0, 0, 0, 0];
  static const _activityRestrictions = ['all', 'public', 'private'];
  static const _visibilityRestrictions = ['public', 'private'];
  late StreamSubscription<String> subscription;

  @override
  void initState() {
    _tabController = TabController(length: 4, vsync: this);
    super.initState();
    subscription = topStore.topStream.listen((event) {
      if (event == '300') topStore.setTop(_scrollTargets[_tabController.index]);
    });
  }

  @override
  void dispose() {
    subscription.cancel();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Observer(
      builder: (context) {
        if (accountStore.now != null) {
          final tablet = usesIPadLayout(context);
          final id = int.parse(accountStore.now!.userId);
          final top = kToolbarHeight + MediaQuery.paddingOf(context).top;
          final labels = [
            I18n.of(context).bookmark,
            I18n.of(context).news,
            I18n.of(context).watchlist,
            I18n.of(context).news_follow_title,
          ];
          void select(int i) {
            HapticUtil.selectionClick();
            if (_tabController.index == i) topStore.setTop(_scrollTargets[i]);
            _tabController.animateTo(i);
          }

          final topInset = tablet ? top : 0.0;
          final bookRestriction =
              _visibilityRestrictions[_filterIndices[_bookmarkTab]];
          final activityRestriction =
              _activityRestrictions[_filterIndices[_activityTab]];
          final followRestriction =
              _visibilityRestrictions[_filterIndices[_followingTab]];
          final pages = TabBarView(
            controller: _tabController,
            children: [
              BookmarkPage(
                key: ValueKey((id, bookRestriction)),
                id: id,
                restrict: bookRestriction,
                topInset: topInset,
                showFilter: !tablet,
              ),
              NewIllustPage(
                key: ValueKey((id, activityRestriction)),
                restrict: activityRestriction,
                topInset: topInset,
                showFilter: !tablet,
              ),
              WatchlistPage(topInset: topInset),
              FollowList(
                key: ValueKey((id, followRestriction)),
                id: id,
                restrict: followRestriction,
                topInset: topInset,
                showFilter: !tablet,
              ),
            ],
          );
          if (tablet) {
            final visibilityLabels = [
              I18n.of(context).public,
              I18n.of(context).private,
            ];
            return Stack(
              fit: StackFit.expand,
              children: [
                pages,
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: top,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      const ProgressiveToolbarBlur(),
                      SafeArea(
                        bottom: false,
                        child: LayoutBuilder(
                          builder: (context, bounds) => AnimatedBuilder(
                            animation: _tabController,
                            builder: (context, _) {
                              final tab = _tabController.index;
                              return Row(
                                textDirection: TextDirection.ltr,
                                children: [
                                  const Spacer(),
                                  GlassSegmentPicker(
                                    compact: true,
                                    maxWidth: bounds.maxWidth * .54,
                                    labels: labels,
                                    index: tab,
                                    onSelect: select,
                                  ),
                                  Expanded(
                                    child: tab == _watchlistTab
                                        ? const SizedBox.shrink()
                                        : Align(
                                            alignment: Alignment.centerLeft,
                                            child: Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 6,
                                                  ),
                                              child: SortGroup(
                                                key: ValueKey(tab),
                                                compact: true,
                                                initIndex: _filterIndices[tab],
                                                children: tab == _activityTab
                                                    ? [
                                                        I18n.of(context).all,
                                                        ...visibilityLabels,
                                                      ]
                                                    : visibilityLabels,
                                                onChange: (int index) =>
                                                    setState(
                                                      () =>
                                                          _filterIndices[tab] =
                                                              index,
                                                    ),
                                              ),
                                            ),
                                          ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          }

          return Column(
            children: [
              AppBar(
                automaticallyImplyLeading: false,
                title: TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  indicatorSize: TabBarIndicatorSize.label,
                  onTap: select,
                  tabs: [for (final label in labels) Tab(text: label)],
                ),
              ),
              Expanded(child: pages),
            ],
          );
        }
        return const LoginInFirst();
      },
    );
  }

  @override
  bool get wantKeepAlive => true;
}
