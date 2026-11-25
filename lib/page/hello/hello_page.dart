import 'package:pixez/page/hello/setting/demo_mode.dart';
import 'package:pixez/component/ipad_surface.dart';
import 'package:pixez/component/home_aurora.dart';
import 'package:pixez/component/progressive_toolbar_blur.dart';
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

import 'dart:async';
import 'dart:io';
import 'package:flutter/gestures.dart' show Drag;
import 'dart:ui';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:pixez/component/painter_avatar.dart';
import 'package:pixez/constants.dart';
import 'package:pixez/deep_link_plugin.dart';
import 'package:pixez/er/leader.dart';
import 'package:pixez/er/prefer.dart';
import 'package:pixez/i18n.dart';
import 'package:pixez/main.dart';
import 'package:pixez/page/Init/guide_page.dart';
import 'package:pixez/page/hello/new/new_page.dart';
import 'package:pixez/page/hello/ranking/rank_page.dart';
import 'package:pixez/page/hello/recom/recom_spotlight_page.dart';
import 'package:pixez/page/hello/setting/setting_page.dart';
import 'package:pixez/page/preview/preview_page.dart';
import 'package:pixez/page/search/search_page.dart';
import 'package:pixez/page/user/users_page.dart';
import 'package:pixez/utils/haptic_util.dart';

final iPadRailObserver = IPadRailObserver();

class IPadRailObserver extends NavigatorObserver {
  final _railRoutes = Expando<bool>();
  final updates = ValueNotifier<int>(0);
  Route<dynamic>? _top;
  bool _updateScheduled = false;

  bool get showsRail => _top != null && _railRoutes[_top!] == true;

  void register(BuildContext context) {
    final route = ModalRoute.of(context);
    if (route == null || _railRoutes[route] == true) return;
    _railRoutes[route] = true;
    if (route == _top) refresh();
  }

  void refresh() {
    if (_updateScheduled) return;
    _updateScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateScheduled = false;
      updates.value++;
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  @override
  void didChangeTop(Route<dynamic> topRoute, Route<dynamic>? previousTopRoute) {
    _top = topRoute;
    refresh();
  }
}

class IPadRailLayer extends StatelessWidget {
  const IPadRailLayer({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Stack(fit: StackFit.expand, children: [
    child,
    ValueListenableBuilder<int>(
      valueListenable: iPadRailObserver.updates,
      builder: (context, _, _) {
        final home = _HelloPageState.active;
        if (home == null || !home.mounted) return const SizedBox.shrink();
        return Offstage(
          offstage: !iPadRailObserver.showsRail,
          child: home._rail(context),
        );
      },
    ),
  ]);
}

class HelloPage extends StatefulWidget {
  @override
  _HelloPageState createState() => _HelloPageState();
}

class _HelloPageState extends State<HelloPage> {
  static _HelloPageState? active;
  late StreamSubscription _sub;
  late int index;
  late PageController _pageController;
  double? bottomNavigatorHeight = null;
  late List<Widget> _lists;
  final _searchKey = GlobalKey<SearchPageState>();
  final _settingsKey = GlobalKey<SettingPageState>();

  @override
  void dispose() {
    if (active == this) {
      active = null;
      iPadRailObserver.refresh();
    }
    _sub.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    active = this;
    iPadRailObserver.refresh();
    _lists = <Widget>[
      Observer(
        builder: (context) {
          final account = accountStore.now;
          if (account != null) {
            return RecomSpolightPage(key: ValueKey(account.userId));
          }
          return _guestPreview(context, cacheHome: true);
        },
      ),
      Observer(
        builder: (context) {
          if (accountStore.now != null)
            return RankPage();
          else
            return _guestPreview(context);
        },
      ),
      NewPage(),
      SearchPage(key: _searchKey),
      SettingPage(key: _settingsKey, transparentMenu: Platform.isIOS),
    ];
    Constants.type = 0;
    fetcher.context = context;
    index = userSetting.materialWelcomePageIndex;
    _pageController = PageController(
      initialPage: userSetting.materialWelcomePageIndex,
    );
    super.initState();
    saveStore.ctx = this.context;
    saveStore.saveStream.listen((stream) {
      saveStore.listenBehavior(stream);
    });
    initLinksStream();
    initPlatformState();
  }

  Widget _guestPreview(BuildContext context, {bool cacheHome = false}) => PreviewPage(
    cacheHome: cacheHome,
    showLoginPrompt: usesIPadLayout(context) &&
        Prefer.getInt('language_num') != null,
  );

  Future<void> initPlatformState() async {
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      if (mounted && !DemoMode.active && Prefer.getInt('language_num') == null) {
        Navigator.of(
          context,
        ).pushReplacement(MaterialPageRoute(builder: (context) => GuidePage()));
      }
    });
  }

  Future<void> initLinksStream() async {
    try {
      Uri? initialLink = await DeepLinkPlugin.getInitialUri();
      if (initialLink != null) Leader.pushWithUri(context, initialLink);
      _sub = DeepLinkPlugin.uriLinkStream.listen(
        (Uri? link) => Leader.pushWithUri(context, link!),
      );
    } catch (e) {
      print(e);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    iPadRailObserver.register(context);
  }

  @override
  Widget build(BuildContext context) {
    if (bottomNavigatorHeight == null) {
      bottomNavigatorHeight = MediaQuery.of(context).padding.bottom + 80;
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final glassBar = Platform.isIOS && MediaQuery.of(context).size.shortestSide >= 600;
        final wide = !isIPhone && !glassBar && constraints.maxWidth > constraints.maxHeight;
        final pages = _buildPageView(context);
        return Scaffold(
          body: Stack(
            fit: StackFit.expand,
            children: [
              if (Platform.isIOS) const HomeAurora(),
              if (wide)
                Row(children: [..._buildRail(context), Expanded(child: pages)])
              else
                pages,
            ],
          ),
          extendBody: !glassBar,
          bottomNavigationBar: wide || glassBar
              ? null
              : Observer(
                  builder: (context) {
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 400),
                      transform: Matrix4.translationValues(
                        0,
                        fullScreenStore.fullscreen ? bottomNavigatorHeight! : 0,
                        0,
                      ),
                      child: isIPhone ? _phoneNavigation(context) : _buildNavigationBar(context),
                    );
                  },
                ),
        );
      },
    );
  }

  List<Widget> _buildRail(BuildContext context) {
    return [
      Stack(
        children: [
          NavigationRail(
            selectedIndex: index,
            labelType: NavigationRailLabelType.all,
            onDestinationSelected: (int index) {
              HapticUtil.selectionClick();
              if (this.index == index) {
                topStore.setTop("${index + 1}00");
              }
              _pageController.jumpToPage(index);
              setState(() {
                this.index = index;
              });
            },
            destinations: <NavigationRailDestination>[
              NavigationRailDestination(
                icon: Icon(Icons.home),
                label: Text(I18n.of(context).home),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.leaderboard),
                label: Text(I18n.of(context).rank),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.favorite),
                label: Text(I18n.of(context).quick_view),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.search),
                label: Text(I18n.of(context).search),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.more_horiz),
                label: Text(I18n.of(context).more),
              ),
            ],
          ),
          Positioned(
            left: 0.0,
            right: 0.0,
            bottom: 0.0,
            child: Padding(
              padding: EdgeInsets.only(
                left: MediaQuery.of(context).padding.left,
                bottom: MediaQuery.of(context).padding.bottom + 4.0,
              ),
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Theme.of(context).colorScheme.primary,
                    width: 2,
                  ),
                ),
                child: SizedBox(
                  width: 40,
                  height: 40,
                  child: accountStore.now != null
                      ? PainterAvatar(
                          url: accountStore.now!.userImage,
                          id: int.tryParse(accountStore.now!.userId) ?? 0,
                        )
                      : Container(),
                ),
              ),
            ),
          ),
        ],
      ),
      const VerticalDivider(thickness: 1, width: 1),
    ];
  }

  static const _glassRailWidth = 64.0;

  Widget _rail(BuildContext context) => SafeArea(
    right: false,
    child: Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(left: 10),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          _glassSideBar(context),
          Observer(builder: (_) {
            final account = accountStore.now;
            if (account == null) return const SizedBox.shrink();
            final id = int.tryParse(account.userId) ?? 0;
            return Padding(
              padding: const EdgeInsets.only(top: 6),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => Leader.push(this.context, UsersPage(id: id)),
                child: IPadSurface(
                  circular: true,
                  child: SizedBox.square(
                    dimension: 50,
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: IgnorePointer(
                        child: PainterAvatar(url: account.userImage, id: id),
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),
        ]),
      ),
    ),
  );

  void _selectRailDestination(int destination) {
    final home = ModalRoute.of(context);
    if (home == null) return;
    HapticUtil.selectionClick();
    FocusManager.instance.primaryFocus?.unfocus();
    if (!home.isCurrent) home.navigator?.popUntil((route) => route == home);
    if (!_pageController.hasClients) return;
    if (index == destination) {
      if (destination == 4) _settingsKey.currentState?.showPreferences();
      topStore.setTop("${destination + 1}00");
    } else {
      _pageController.jumpToPage(destination);
      setState(() => index = destination);
      iPadRailObserver.refresh();
    }
  }

  Widget _glassSideBar(BuildContext context) {
    final strings = I18n.of(context);
    final control = NativeGlassControl(index: index, pages: _pageController,
          tint: Theme.of(context).colorScheme.primary,
          labels: [strings.home, strings.rank, strings.quick_view, strings.search, strings.more],
          onSelect: _selectRailDestination,
        );
    return SizedBox(width: _glassRailWidth, height: 294, child: control);
  }

  Widget _phoneNavigation(BuildContext context) {
    final strings = I18n.of(context);
    final labels = [strings.home, strings.rank, strings.quick_view, strings.search, strings.more];
    final insets = MediaQuery.viewPaddingOf(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        insets.left + 8,
        0,
        insets.right + 8,
        (insets.bottom - 8).clamp(6.0, double.infinity).toDouble(),
      ),
      child: SizedBox(
        width: double.infinity,
        height: 62,
        child: NativeGlassControl(
          phoneTabs: true,
          pages: _pageController,
          index: index,
          tint: Theme.of(context).colorScheme.primary,
          labels: labels,
          onSelect: _selectRailDestination,
        ),
      ),
    );
  }

  Widget _buildNavigationBar(BuildContext context) {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: NavigationBar(
          height: 68,
          backgroundColor: Theme.of(
            context,
          ).colorScheme.surface.withValues(alpha: 0.9),
          destinations: [
            NavigationDestination(
              icon: Icon(Icons.home),
              label: I18n.of(context).home,
            ),
            NavigationDestination(
              icon: Icon(Icons.leaderboard),
              label: I18n.of(context).rank,
            ),
            NavigationDestination(
              icon: Icon(Icons.favorite),
              label: I18n.of(context).quick_view,
            ),
            NavigationDestination(
              icon: Icon(Icons.search),
              label: I18n.of(context).search,
            ),
            NavigationDestination(
              icon: Icon(Icons.more_horiz),
              label: I18n.of(context).more,
            ),
          ],
          selectedIndex: index,
          onDestinationSelected: (value) {
            HapticUtil.selectionClick();
            if (this.index == value) {
              topStore.setTop("${value + 1}00");
            }
            setState(() {
              this.index = value;
            });
            if (_pageController.hasClients) _pageController.jumpToPage(value);
          },
        ),
      ),
    );
  }

  PageView _buildPageView(BuildContext context) {
    return PageView.builder(
      itemCount: 5,
      controller: _pageController,
      onPageChanged: (index) {
        if (index == 3) _searchKey.currentState?.refreshGrid();
        setState(() {
          this.index = index;
        });
        iPadRailObserver.refresh();
      },
      itemBuilder: (context, index) {
        final page = _lists[index];
        if (!Platform.isIOS || (!usesIPadLayout(context) && !(isIPhone && index == 0))) return page;
        if (index >= 1 && index <= 3) {
          return Padding(padding: const EdgeInsets.only(left: 82), child: page);
        }
        if (index != 0) return Padding(padding: const EdgeInsets.symmetric(horizontal: 82), child: page);
        final top = MediaQuery.paddingOf(context).top;
        return Stack(fit: StackFit.expand, children: [
          if (isIPhone) page else Padding(padding: const EdgeInsets.only(left: 82), child: page),
          if (top > 0)
            Positioned(
              top: 0, left: 0, right: 0, height: top,
              child: const ProgressiveToolbarBlur(),
            ),
        ]);
      },
    );
  }
}

class IPadReadingPage extends StatefulWidget {
  const IPadReadingPage({
    super.key,
    required this.child,
    this.landscapeWidth = 940,
    this.portraitWidth = 940,
    this.landscapeSideInset,
  });
  final double landscapeWidth, portraitWidth;
  final double? landscapeSideInset;
  final Widget child;

  @override
  State<IPadReadingPage> createState() => _IPadReadingPageState();
}

class _IPadReadingPageState extends State<IPadReadingPage> {
  final _scrollables = <ScrollableState, int>{};
  Drag? _marginDrag;

  bool _trackScrollables(Notification notification) {
    final (source, depth) = switch (notification) {
      ScrollMetricsNotification n => (n.context, n.depth),
      ScrollNotification n => (n.context, n.depth),
      _ => (null, 0),
    };
    if (source != null) {
      final scrollable = Scrollable.maybeOf(source, axis: Axis.vertical);
      if (scrollable != null) _scrollables[scrollable] = depth;
    }
    return false;
  }

  void _startDrag(DragStartDetails details) {
    _scrollables.removeWhere((scrollable, _) => !scrollable.mounted);
    final centerX = (context.findRenderObject()! as RenderBox)
        .localToGlobal(Offset(MediaQuery.sizeOf(context).width / 2, 0)).dx;
    final inside = Offset(centerX, details.globalPosition.dy);
    ScrollableState? selected;
    int bestDepth = -1;
    for (final entry in _scrollables.entries) {
      final scrollable = entry.key;
      final box = scrollable.context.findRenderObject();
      if (box is! RenderBox || !box.attached || !box.hasSize) continue;
      if (!scrollable.position.hasContentDimensions ||
          !scrollable.position.physics.shouldAcceptUserOffset(scrollable.position)) continue;
      if (entry.value < bestDepth || !(Offset.zero & box.size).contains(box.globalToLocal(inside))) continue;
      selected = scrollable;
      bestDepth = entry.value;
    }
    if (selected != null) {
      _marginDrag = selected.position.drag(details, () => _marginDrag = null);
    }
  }

  Widget _margin() => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onVerticalDragStart: _startDrag,
    onVerticalDragUpdate: (details) => _marginDrag?.update(details),
    onVerticalDragEnd: (details) => _marginDrag?.end(details),
    onVerticalDragCancel: () => _marginDrag?.cancel(),
  );

  @override
  void dispose() {
    _marginDrag?.cancel();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    iPadRailObserver.register(context);
  }

  @override
  Widget build(BuildContext context) {
    if (!usesIPadLayout(context)) return widget.child;
    final home = _HelloPageState.active;
    final landscape = MediaQuery.orientationOf(context) == Orientation.landscape;
    final sideInset = landscape ? widget.landscapeSideInset : null;
    final maxWidth = landscape ? widget.landscapeWidth : widget.portraitWidth;
    return Scaffold(body: LayoutBuilder(builder: (context, box) {
      final minMargin = home == null ? 20.0 : 82.0;
      final margin = ((box.maxWidth - maxWidth) / 2).clamp(minMargin, box.maxWidth / 2).toDouble();
      final leftMargin = sideInset == null ? margin : (home == null ? 0.0 : minMargin) + sideInset;
      final rightMargin = sideInset ?? margin;
      return Stack(children: [
        Positioned.fill(left: leftMargin, right: rightMargin, child: NotificationListener<Notification>(
          onNotification: _trackScrollables,
          child: widget.child,
        )),
        if (leftMargin > 0)
          Positioned(left: 0, top: 0, bottom: 0, width: leftMargin, child: _margin()),
        if (rightMargin > 0)
          Positioned(right: 0, top: 0, bottom: 0, width: rightMargin, child: _margin()),
      ]);
    }));
  }
}
