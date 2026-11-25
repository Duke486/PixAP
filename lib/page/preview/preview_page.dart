import 'package:pixez/component/glass_form_control.dart';
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
import 'dart:math' as math;

import 'package:pixez/component/ipad_surface.dart';
import 'package:easy_refresh/easy_refresh.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:pixez/component/painter_avatar.dart';
import 'package:pixez/component/pixez_default_header.dart';
import 'package:pixez/component/pixiv_image.dart';
import 'package:pixez/er/prefer.dart';
import 'package:pixez/i18n.dart';
import 'package:pixez/lighting/lighting_store.dart';
import 'package:pixez/models/illust.dart';
import 'package:pixez/models/recommend.dart';
import 'package:pixez/network/api_client.dart';
import 'package:pixez/page/hello/recom/home_feed_refresh.dart';
import 'package:pixez/page/hello/setting/demo_mode.dart';
import 'package:pixez/page/login/login_page.dart';
import 'package:waterfall_flow/waterfall_flow.dart';

class GoToLoginPage extends StatelessWidget {
  final Illusts illust;

  const GoToLoginPage({Key? key, required this.illust}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(illust.title)),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              PixivImage(illust.imageUrls.medium),
              Row(
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: PainterAvatar(
                      id: illust.user.id,
                      url: illust.user.profileImageUrls.medium,
                      onTap: () {},
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text(illust.user.name),
                      ),
                      Text(illust.createDate),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class LoginInFirst extends StatelessWidget {
  const LoginInFirst({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: 20,
          children: [
            Semantics(
              header: true,
              child: Text(
                I18n.of(context).login_required,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
            const _LoginButton(),
          ],
        ),
      ),
    );
  }
}

class _LoginButton extends StatelessWidget {
  const _LoginButton();

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(constraints: const BoxConstraints(minWidth: 112, minHeight: 48),
      child: GlassActionButton(prominent: true, label: I18n.of(context).login,
        onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => LoginPage()))));

  }
}

class PreviewPage extends StatefulWidget {
  const PreviewPage({super.key, this.showLoginPrompt = false, this.cacheHome = false});

  final bool showLoginPrompt;
  final bool cacheHome;

  @override
  _PreviewPageState createState() => _PreviewPageState();
}

class _PreviewPageState extends State<PreviewPage>
    with AutomaticKeepAliveClientMixin {
  bool _dismissedLoginPrompt = false;

  @override
  bool get wantKeepAlive => widget.showLoginPrompt;
  late LightingStore _lightingStore;
  late final EasyRefreshController _easyRefreshController;
  HomeFeedRefresh<Recommend>? _homeRefresh;

  @override
  void initState() {
    super.initState();
    _easyRefreshController = EasyRefreshController(
      controlFinishLoad: true,
      controlFinishRefresh: !widget.cacheHome,
    );
    _lightingStore = LightingStore(
      ApiSource(futureGet: () => apiClient.walkthroughIllusts()),
    );
    _lightingStore.easyRefreshController = _easyRefreshController;
    if (widget.cacheHome) {
      final refresh = HomeFeedRefresh<Recommend>(
        cacheKey: DemoMode.active ? null : 'home_feed.v1.guest.${Prefer.getInt("language_num")}',
        decode: Recommend.fromJson,
        encode: (snapshot) => snapshot.toJson(),
        fetch: (_) => fetchHomeFeedPart(() => apiClient.walkthroughIllusts(force: true), Recommend.fromJson),
        show: (snapshot, {required fromNetwork}) {
          _lightingStore.replaceRecommendations(snapshot);
          _easyRefreshController.resetFooter();
        },
      )..restore();
      _homeRefresh = refresh;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(refresh.refresh(manual: false));
      });
    } else {
      _lightingStore.fetch();
    }
  }

  @override
  void dispose() {
    _homeRefresh?.dispose();
    _easyRefreshController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final refresh = _homeRefresh;
    final content = Observer(
      builder: (_) {
        final tablet = usesIPadLayout(context);
        final columns = tablet
            ? (MediaQuery.sizeOf(context).width / 220).floor().clamp(2, 8)
            : 2;
        final styled = usesAppleControls(context);
        final spacing = styled ? 8.0 : 0.0;
        final items = _lightingStore.iStores.toList(growable: false);
        return SafeArea(
          child: EasyRefresh(
            controller: _easyRefreshController,
            header: refresh == null ? null : PixezDefault.header(context),
            onRefresh: refresh == null
                ? () => _lightingStore.fetch(url: 'walkthrough')
                : () async => await refresh.refresh(manual: true)
                    ? IndicatorResult.success : IndicatorResult.fail,
            onLoad: () => _lightingStore.fetchNext(),
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                if (widget.showLoginPrompt && !_dismissedLoginPrompt)
                  SliverLayoutBuilder(
                    builder: (context, constraints) {
                      final theme = Theme.of(context);
                      final margin =
                          (CardTheme.of(context).margin ??
                                  const EdgeInsets.all(4))
                              .resolve(Directionality.of(context));
                      final tileWidth =
                          (constraints.crossAxisExtent -
                              (columns - 1) * spacing) /
                          columns;
                      final textScale = MediaQuery.textScalerOf(context);
                      final captionHeight =
                          [
                            theme.textTheme.titleSmall,
                            theme.textTheme.bodySmall,
                          ].fold(20.0, (height, style) {
                            final painter = TextPainter(
                              text: TextSpan(text: ' ', style: style),
                              textDirection: Directionality.of(context),
                              textScaler: textScale,
                            );
                            final lineHeight = painter.preferredLineHeight;
                            painter.dispose();
                            return height + lineHeight;
                          });
                      final tileHeight =
                          tileWidth -
                          margin.horizontal +
                          margin.vertical +
                          captionHeight;
                      final previewHeight = tileHeight * 1.5 + spacing;
                      return SliverToBoxAdapter(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: math.max(
                              0,
                              constraints.viewportMainAxisExtent -
                                  previewHeight,
                            ),
                          ),
                          child: GuestHomeLoginPrompt(
                            onLater: () {
                              setState(() => _dismissedLoginPrompt = true);
                            },
                          ),
                        ),
                      );
                    },
                  ),
                SliverWaterfallFlow(
                  gridDelegate:
                      SliverWaterfallFlowDelegateWithFixedCrossAxisCount(
                        crossAxisCount: columns,
                        mainAxisSpacing: spacing,
                        crossAxisSpacing: spacing,
                      ),
                  delegate: SliverChildBuilderDelegate((
                    BuildContext context,
                    int index,
                  ) {
                    final illust = items[index].illusts!;
                    return InkWell(
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (BuildContext context) =>
                                GoToLoginPage(illust: illust),
                          ),
                        );
                      },
                      child: Card(
                        clipBehavior: styled ? Clip.antiAlias : Clip.none,
                        elevation: styled ? 0 : null,
                        child: styled
                            ? Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  AspectRatio(
                                    aspectRatio: 1,
                                    child: PixivImage(
                                      illust.imageUrls.squareMedium,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                      12,
                                      8,
                                      12,
                                      0,
                                    ),
                                    child: Text(
                                      illust.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleSmall,
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                      12,
                                      2,
                                      12,
                                      10,
                                    ),
                                    child: Text(
                                      illust.user.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodySmall,
                                    ),
                                  ),
                                ],
                              )
                            : Container(
                                child: PixivImage(
                                  illust.imageUrls.squareMedium,
                                ),
                              ),
                      ),
                    );
                  }, childCount: items.length),
                ),
              ],
            ),
          ),
        );
      },
    );
    return refresh == null ? content : HomeFeedOverlay(refresh: refresh, child: content);
  }
}

class GuestHomeLoginPrompt extends StatefulWidget {
  const GuestHomeLoginPrompt({super.key, required this.onLater});
  final VoidCallback onLater;

  @override
  State<GuestHomeLoginPrompt> createState() => _GuestHomeLoginPromptState();
}

class _GuestHomeLoginPromptState extends State<GuestHomeLoginPrompt>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  int _seconds = 10;
  late final Timer _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() => _seconds--);
      if (_seconds == 0) timer.cancel();
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final strings = I18n.of(context);
    final theme = Theme.of(context);
    return Center(
      heightFactor: 1,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Semantics(
                header: true,
                child: Text(
                  strings.login_message,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 28),
              Row(
                mainAxisSize: MainAxisSize.min,
                textDirection: TextDirection.ltr,
                spacing: 12,
                children: [
                  Flexible(
                    child: ConstrainedBox(constraints: const BoxConstraints(minWidth: 112, minHeight: 48),
                      child: GlassActionButton(
                        onPressed: _seconds == 0 ? widget.onLater : null,
                        label: _seconds == 0 ? strings.login_later : '${strings.login_later} ($_seconds)',
                      )),
                  ),
                  const Flexible(child: _LoginButton()),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
