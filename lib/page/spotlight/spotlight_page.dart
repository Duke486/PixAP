import 'package:pixez/component/ipad_surface.dart';
import 'package:pixez/page/hello/hello_page.dart';
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

import 'dart:math';

import 'package:easy_refresh/easy_refresh.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:pixez/component/pixez_default_header.dart';
import 'package:pixez/component/progressive_toolbar_blur.dart';
import 'package:pixez/component/spotlight_card.dart';
import 'package:pixez/i18n.dart';
import 'package:pixez/main.dart';
import 'package:pixez/page/hello/recom/spotlight_store.dart';
import 'package:waterfall_flow/waterfall_flow.dart';

class SpotLightPage extends StatefulWidget {
  @override
  State<SpotLightPage> createState() => _SpotLightPageState();
}

class _SpotLightPageState extends State<SpotLightPage> {
  final _controller = ScrollController();
  final _refreshController = EasyRefreshController(
    controlFinishLoad: true,
    controlFinishRefresh: true,
  );
  SpotlightStore? _spotlightStore;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _spotlightStore ??= SpotlightStore(
      _refreshController,
      pageSize: usesIPadLayout(context) ? 12 : null,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _refreshController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tablet = usesAppleControls(context);
    final store = _spotlightStore!;
    final top = MediaQuery.paddingOf(context).top + kToolbarHeight;
    final toolbar = AppBar(
      title: Text(I18n.of(context).spotlight),
      centerTitle: tablet ? true : null,
      forceMaterialTransparency: tablet,
      actions: [
        IconButton(
          icon: const Icon(Icons.arrow_upward),
          onPressed: () {
            if (_controller.hasClients) {
              _controller.animateTo(
                0,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
              );
            }
          },
        ),
      ],
    );
    final grid = EasyRefresh.builder(
      onLoad: store.next,
      onRefresh: store.fetch,
      header: tablet
          ? PixezDefault.header(
              context,
              position: IndicatorPosition.locator,
              safeArea: false,
            )
          : PixezDefault.header(context),
      refreshOnStart: true,
      controller: _refreshController,
      childBuilder: (context, physics) => Observer(
        builder: (context) {
          if (!tablet) {
            return WaterfallFlow.builder(
              physics: physics,
              gridDelegate: _buildGridDelegate(context),
              controller: _controller,
              itemCount: store.articles.length,
              itemBuilder: (_, index) =>
                  SpotlightCard(spotlight: store.articles[index]),
            );
          }
          // Observe the list before entering the deferred sliver builders.
          final articles = store.articles.toList(growable: false);
          return CustomScrollView(
            controller: _controller,
            physics: physics.applyTo(const AlwaysScrollableScrollPhysics()),
            slivers: [
              SliverToBoxAdapter(child: SizedBox(height: top + 12)),
              const HeaderLocator.sliver(),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                sliver: SliverLayoutBuilder(
                  builder: (context, constraints) {
                    // Every card has the same 1.91:1 cover and two-line caption.
                    final columns = isIPhone ? 2 : 3;
                    final width = constraints.crossAxisExtent / columns - 24;
                    final height =
                        width / 1.91 +
                        MediaQuery.textScalerOf(context).scale(16) * 2.8 +
                        48;
                    return SliverGrid.builder(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: columns,
                        mainAxisExtent: height,
                      ),
                      itemCount: articles.length,
                      itemBuilder: (_, index) {
                        final article = articles[index];
                        return SpotlightCard(
                          key: ValueKey(article.id),
                          spotlight: article,
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
    return IPadReadingPage(
      landscapeWidth: 800,
      portraitWidth: 760,
      child: Scaffold(
        appBar: tablet ? null : toolbar,
        body: tablet
            ? Stack(
                fit: StackFit.expand,
                children: [
                  grid,
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    height: top,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [const ProgressiveToolbarBlur(), toolbar],
                    ),
                  ),
                ],
              )
            : grid,
      ),
    );
  }

  SliverWaterfallFlowDelegate _buildGridDelegate(BuildContext context) {
    var count = 2;
    if (MediaQuery.of(context).orientation == Orientation.portrait
        ? userSetting.crossAdapt
        : userSetting.hCrossAdapt) {
      count = _buildSliderValue(context);
    } else {
      count = (MediaQuery.of(context).orientation == Orientation.portrait)
          ? userSetting.crossCount
          : userSetting.hCrossCount;
    }
    return SliverWaterfallFlowDelegateWithFixedCrossAxisCount(
      crossAxisCount: usesIPadLayout(context) ? 3 : count,
    );
  }

  int _buildSliderValue(BuildContext context) {
    final currentValue =
        (MediaQuery.of(context).orientation == Orientation.portrait
                ? userSetting.crossAdapterWidth
                : userSetting.hCrossAdapterWidth)
            .toDouble();
    var nowAdaptWidth = max(currentValue, 50.0);
    nowAdaptWidth = min(nowAdaptWidth, 2160.0);
    final screenWidth = MediaQuery.of(context).size.width;
    final result = max(screenWidth / nowAdaptWidth, 1.0).toInt();
    return result;
  }
}
