import 'package:pixez/i18n.dart';
import 'article_reader.dart';
import 'dart:ui' as ui;
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

import 'package:material_ui/material_ui.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:pixez/component/null_hero.dart';
import 'package:pixez/component/painter_avatar.dart';
import 'package:pixez/component/pixiv_image.dart';
import 'package:pixez/models/amwork.dart';
import 'package:pixez/models/spotlight_response.dart';
import 'package:pixez/page/picture/illust_lighting_page.dart';
import 'package:pixez/page/picture/illust_store.dart';
import 'package:pixez/page/soup/soup_store.dart';
import 'package:url_launcher/url_launcher_string.dart';

class SoupPage extends StatefulWidget {
  final String url;
  final SpotlightArticle? spotlight;
  final String? heroTag;

  SoupPage({Key? key, required this.url, required this.spotlight, this.heroTag})
    : super(key: key);

  @override
  _SoupPageState createState() => _SoupPageState();
}

class _SoupPageState extends State<SoupPage> {
  late Future _load;
  final SoupStore _soupStore = SoupStore();

  @override
  void initState() {
    _load = _soupStore.fetch(widget.url);
    super.initState();
  }

  @override
  Widget build(BuildContext context) =>
      IPadReadingPage(landscapeWidth: 800, portraitWidth: 760, child: _content(context));

  Widget _content(BuildContext context) {
    return Scaffold(
      body: Observer(
        builder: (context) {
          if (usesIPadLayout(context)) {
            final item = widget.spotlight;
            final coverOverlap = item != null &&
                    MediaQuery.orientationOf(context) == Orientation.landscape
                ? 28.0
                : 0.0;
            final count = _soupStore.amWorks.length;
            return FutureBuilder(future: _load, builder: (context, snapshot) {
              final wait = snapshot.connectionState != ConnectionState.done;
              return ArticleReader(
                coverOverlap: coverOverlap,
                toolbar: SizedBox(height: MediaQuery.paddingOf(context).top + kToolbarHeight,
                  child: Stack(fit: StackFit.expand, children: [
                    IgnorePointer(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [for (final sigma in const [15.0, 12.0, 9.0, 6.0, 3.0, 1.0])
                        Expanded(child: ClipRect(child: BackdropFilter(
                          filter: ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
                          child: const SizedBox.expand())))])),
                    IgnorePointer(child: DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(
                      begin: Alignment.topCenter, end: Alignment.bottomCenter,
                      colors: [Theme.of(context).scaffoldBackgroundColor.withValues(alpha: .68),
                        Theme.of(context).scaffoldBackgroundColor.withValues(alpha: 0)])))),
                    SafeArea(bottom: false, child: Row(children: [
                      const BackButton(),
                      Expanded(child: Text(item?.pureTitle ?? '', textAlign: TextAlign.center,
                        maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.titleMedium)),
                      if (item != null) IconButton(icon: const Icon(Icons.share), onPressed: () => launchUrlString(item.articleUrl)),
                    ])),
                  ])),
                cover: item == null ? const SizedBox.shrink() : ClipRRect(borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)), child: SizedBox(height: 160 + coverOverlap,
                  child: Image(image: PixivProvider.url(item.thumbnail), fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const SizedBox.shrink()))),
                itemCount: count + 1,
                itemBuilder: _article,
                status: wait || count == 0 ? Padding(padding: const EdgeInsets.all(28), child: Center(
                  child: wait ? const CircularProgressIndicator() : Column(children: [
                    Text(_soupStore.loadFailed ? '文章加载失败' : '这篇文章没有可展示的作品'),
                    TextButton(onPressed: () => setState(() => _load = _soupStore.fetch(widget.url)), child: Text(I18n.of(context).retry)),
                  ]))) : null,
              );
            });
          }
          return NestedScrollView(
            headerSliverBuilder: (_, _) => [_header(context)],
            body: buildBlocProvider(),
          );
        },
      ),
    );
  }

  Widget _header(BuildContext context) {
    if (widget.spotlight == null) return SliverAppBar();
    return SliverAppBar(
      pinned: true,
      backgroundColor: usesIPadLayout(context) ? Colors.transparent : null,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      expandedHeight: 200.0,
      flexibleSpace: Stack(
        fit: StackFit.expand,
        children: [
          FlexibleSpaceBar(
            centerTitle: true,

            background: NullHero(
              tag: widget.heroTag,
              child: PixivImage(
                widget.spotlight!.thumbnail,
                fit: BoxFit.cover,
                height: 200,
              ),
            ),
          ),
          FlexibleSpaceBar(
            centerTitle: true,
            title: Text(widget.spotlight!.pureTitle),
          ),
        ],
      ),
      actions: <Widget>[
        IconButton(
          icon: Icon(Icons.share),
          onPressed: () async {
            var url = widget.spotlight!.articleUrl;
            await launchUrlString(url);
          },
        ),
      ],
    );
  }

  Widget _articleCard(BuildContext context, Widget content) =>
      usesIPadLayout(context)
      ? Padding(padding: const EdgeInsets.symmetric(vertical: 7), child: IPadGalleryCard(radius: 28, scrolling: true, child: content))
      : Card(clipBehavior: Clip.antiAlias, child: content);

  Widget buildBlocProvider() {
    if (_soupStore.amWorks.isEmpty) return Container();
    return ListView.builder(
      itemBuilder: _article,
      itemCount: _soupStore.amWorks.length + 1,
    );
  }

  Widget _article(BuildContext context, int index) {
    if (index == 0) {
      if (_soupStore.description == null || _soupStore.description!.isEmpty)
        return Container(height: 1);
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(_soupStore.description ?? ''),
        ),
      );
    }
    AmWork amWork = _soupStore.amWorks[index - 1];
    final card = InkWell(
      overlayColor: usesIPadLayout(context) ? const WidgetStatePropertyAll(Colors.transparent) : null,
      splashFactory: usesIPadLayout(context) ? NoSplash.splashFactory : null,
      onTap: () {
        int id = int.parse(
          Uri.parse(
            amWork.arworkLink!,
          ).pathSegments[Uri.parse(amWork.arworkLink!).pathSegments.length - 1],
        );
        Navigator.of(context, rootNavigator: true).push(
          MaterialPageRoute(
            builder: (BuildContext context) {
              return IllustLightingPage(id: id, store: IllustStore(id, null));
            },
          ),
        );
      },
      child: _articleCard(
        context,
        Column(
          children: <Widget>[
            ListTile(
              leading: PainterAvatar(
                size: usesIPadLayout(context) ? const Size.square(44) : null,
                url: amWork.userImage!,
                id: int.parse(
                  Uri.parse(amWork.userLink!).pathSegments[Uri.parse(
                        amWork.userLink!,
                      ).pathSegments.length -
                      1],
                ),
              ),
              title: Text(amWork.title!),
              subtitle: Text(amWork.user!),
            ),
            if (usesIPadLayout(context))
              ArticleImage(image: PixivProvider.url(amWork.showImage!, preUrl: amWork.showImage),
                retryLabel: I18n.of(context).retry)
            else PixivImage(amWork.showImage!),
          ],
        ),
      ),
    );
    if (usesIPadLayout(context) &&
        MediaQuery.orientationOf(context) == Orientation.landscape) {
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 660),
          child: card,
        ),
      );
    }
    return card;
  }
}
