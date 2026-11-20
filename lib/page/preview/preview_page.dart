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
import 'package:pixez/component/pixiv_image.dart';
import 'package:pixez/i18n.dart';
import 'package:pixez/lighting/lighting_store.dart';
import 'package:pixez/models/illust.dart';
import 'package:pixez/network/api_client.dart';
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
    final dark = Theme.of(context).brightness == Brightness.dark;
    final blue = dark ? const Color(0xFF1D8FBA) : const Color(0xFF70D8F7);
    return IPadSurface(
      tint: blue.withValues(alpha: .69),
      child: TextButton(
        style: TextButton.styleFrom(
          minimumSize: const Size(112, 48),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          backgroundColor: usesIPadLayout(context) ? null : blue,
          foregroundColor: dark ? Colors.white : const Color(0xFF07394A),
        ),
        onPressed: () => Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => LoginPage())),
        child: Text(I18n.of(context).login),
      ),
    );
  }
}

class PreviewPage extends StatefulWidget {
  const PreviewPage({super.key, this.showLoginPrompt = false});

  final bool showLoginPrompt;

  @override
  _PreviewPageState createState() => _PreviewPageState();
}

class _PreviewPageState extends State<PreviewPage>
    with AutomaticKeepAliveClientMixin {
  bool _dismissedLoginPrompt = false;

  @override
  bool get wantKeepAlive => widget.showLoginPrompt;
  late LightingStore _lightingStore;
  EasyRefreshController _easyRefreshController = EasyRefreshController(
    controlFinishLoad: true,
    controlFinishRefresh: true,
  );

  @override
  void initState() {
    _lightingStore = LightingStore(
      ApiSource(futureGet: () => apiClient.walkthroughIllusts()),
    );
    _lightingStore.easyRefreshController = _easyRefreshController;
    super.initState();
    _lightingStore.fetch();
  }

  @override
  void dispose() {
    _easyRefreshController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Observer(
      builder: (_) {
        final tablet = usesIPadLayout(context);
        final columns = tablet
            ? (MediaQuery.sizeOf(context).width / 220).floor().clamp(2, 8)
            : 2;
        final spacing = tablet ? 8.0 : 0.0;
        final items = _lightingStore.iStores.toList(growable: false);
        return SafeArea(
          child: EasyRefresh(
            controller: _easyRefreshController,
            onRefresh: () => _lightingStore.fetch(url: "walkthrough"),
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
                        clipBehavior: tablet ? Clip.antiAlias : Clip.none,
                        elevation: tablet ? 0 : null,
                        child: tablet
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
                    child: IPadSurface(
                      child: TextButton(
                        style: TextButton.styleFrom(
                          minimumSize: const Size(112, 48),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                        ),
                        onPressed: _seconds == 0 ? widget.onLater : null,
                        child: Text(
                          _seconds == 0
                              ? strings.login_later
                              : '${strings.login_later} ($_seconds)',
                        ),
                      ),
                    ),
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
