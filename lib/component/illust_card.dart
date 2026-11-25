import 'package:pixez/component/nsfw_artwork.dart';
import 'package:pixez/component/card_reflection.dart';
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
import 'dart:io';

import 'package:bot_toast/bot_toast.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:pixez/component/pixiv_image.dart';
import 'package:pixez/component/star_icon.dart';
import 'package:pixez/er/illust_cacher.dart';
import 'package:pixez/er/lprinter.dart';
import 'package:pixez/er/prefer.dart';
import 'package:pixez/i18n.dart';
import 'package:pixez/lighting/lighting_store.dart';
import 'package:pixez/main.dart';
import 'package:pixez/page/picture/illust_lighting_page.dart';
import 'package:pixez/page/picture/illust_store.dart';
import 'package:pixez/page/picture/picture_list_page.dart';
import 'package:pixez/page/picture/tag_for_illust_page.dart';
import 'package:pixez/page/series/illust_series_page.dart';
import 'package:pixez/utils/haptic_util.dart';

class IllustCard extends StatefulWidget {
  final IllustStore store;
  final List<IllustStore>? iStores;
  final bool needToBan;
  final bool compactLandscapeSpacing;
  final LightingStore lightingStore;

  IllustCard({
    required this.store,
    required this.lightingStore,
    this.iStores,
    this.needToBan = false,
    this.compactLandscapeSpacing = false,
  });

  @override
  _IllustCardState createState() => _IllustCardState();
}

class _IllustCardState extends State<IllustCard> {
  late IllustStore store;
  late List<IllustStore>? iStores;
  late String tag;
  late LightingStore _lightingStore;

  @override
  void initState() {
    store = widget.store;
    iStores = widget.iStores;
    _lightingStore = widget.lightingStore;
    tag = this.hashCode.toString();
    super.initState();
  }

  @override
  void didUpdateWidget(covariant IllustCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    store = widget.store;
    iStores = widget.iStores;
    _lightingStore = widget.lightingStore;
  }

  @override
  Widget build(BuildContext context) {
    return _buildInkWell(context);
  }

  _onLongPressSave() async {
    HapticUtil.heavy();
    if (userSetting.longPressSaveConfirm) {
      final result = await showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: Text(I18n.of(context).save),
            content: Text(store.illusts?.title ?? ""),
            actions: <Widget>[
              TextButton(
                child: Text(I18n.of(context).cancel),
                onPressed: () {
                  Navigator.of(context).pop(false);
                },
              ),
              TextButton(
                child: Text(I18n.of(context).ok),
                onPressed: () {
                  Navigator.of(context).pop(true);
                },
              ),
            ],
          );
        },
      );
      if (!result) {
        return;
      }
    }
    saveStore.saveImage(store.illusts!);
    if (userSetting.starAfterSave && (store.state == 0)) {
      bool success = await store.star(
        restrict: userSetting.defaultPrivateLike ? "private" : "public",
      );
      if (success && userSetting.followAfterStar) {
        await store.followAfterStar();
      }
    }
  }

  Widget cardText() {
    if (store.illusts!.type != "illust") {
      return Text(store.illusts!.type, style: TextStyle(color: Colors.white));
    }
    if (store.illusts!.metaPages.isNotEmpty) {
      return Text(
        store.illusts!.metaPages.length.toString(),
        style: TextStyle(color: Colors.white),
      );
    }
    return Text('');
  }

  String get _previewUrl => switch (userSetting.feedPreviewQuality) {
      0 => store.illusts!.imageUrls.medium,
      1 => store.illusts!.imageUrls.large,
      2 =>
        store.illusts!.metaSinglePage?.originalImageUrl ??
            store.illusts!.metaPages[0].imageUrls!.original,
      _ => store.illusts!.imageUrls.medium,
    };
  Widget _buildPic(String tag, bool tooLong, Widget Function(Widget)? mask) {
    final quality = IllustQualityExtension.fromValue(
      userSetting.feedPreviewQuality,
    );
    return PixivImage(
      tooLong ? store.illusts!.imageUrls.squareMedium : _previewUrl,
      fit: BoxFit.fitWidth,
      cacheHeaderData: tooLong ? null : PixEzCacheHeaderData(key: tag, quality: quality),
      loadedImageBuilder: mask,
    );
  }

  Widget _buildInkWell(BuildContext context) {
    var tooLong =
        store.illusts!.height.toDouble() / store.illusts!.width.toDouble() > 3;
    var radio = (tooLong)
        ? 1.0
        : store.illusts!.width.toDouble() / store.illusts!.height.toDouble();
    final tablet = usesAppleControls(context);
    final content = _buildAnimationWraper(
        context,
        Column(
          children: <Widget>[
            AspectRatio(
              aspectRatio: radio,
              child: Stack(
                children: [
                  Positioned.fill(child: NsfwArtwork.preview(
                    store.illusts!,
                    heroTag: tag,
                    buildPreview: (mask) => _buildPic(tag, tooLong, mask),
                  )),
                  Positioned(
                    top: 5.0,
                    right: 5.0,
                    child: Row(
                      children: [
                        if (userSetting.feedAIBadge &&
                            store.illusts!.illustAIType == 2)
                          _buildAIBadge(),
                        _buildVisibility(),
                      ],
                    ),
                  ),
                  // Positioned(
                  //   top: 0,
                  //   left: 0,
                  //   child: CustomPaint(
                  //     size: Size(36, 36),
                  //     painter: TrianglePainter(),
                  //   ),
                  // ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildBottom(context),
                if (store.illusts?.series != null) ...[
                  GestureDetector(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              IllustSeriesPage(id: store.illusts!.series!.id),
                        ),
                      );
                    },
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      margin: EdgeInsets.only(left: tablet ? 12 : 8, bottom: 4),
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '${store.illusts?.series?.title ?? ''}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
    );
    if (tablet) {
      final compactSpacing = widget.compactLandscapeSpacing &&
          MediaQuery.orientationOf(context) == Orientation.landscape;
      return IPadGalleryCard(
        scrolling: true,
        inset: 0,
        horizontalMargin: compactSpacing ? 3 : 5,
        child: content,
      );
    }
    return Card(margin: const EdgeInsets.all(8), clipBehavior: Clip.antiAlias,
      color: Theme.of(context).colorScheme.surface, child: content);
  }

  Widget _buildAIBadge() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.all(Radius.circular(4.0)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 0.0, horizontal: 4.0),
        child: Text("AI", style: TextStyle(color: Colors.white)),
      ),
    );
  }

  Widget _buildAnimationWraper(BuildContext context, Widget child) {
    return InkWell(
      onLongPress: () {
        _buildLongPressToSaveHint();
      },
      onTap: () {
        _buildInkTap(context, tag);
      },
      child: child,
    );
  }

  _buildLongPressToSaveHint() async {
    if (Platform.isIOS) {
      final firstLongPress = await Prefer.getBool("first_long_press") ?? true;
      if (firstLongPress) {
        await Prefer.setBool("first_long_press", false);
        await showDialog(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: Text('长按保存'),
              content: Text('长按卡片将会保存插画到相册'),
              actions: <Widget>[
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: Text(I18n.of(context).ok),
                ),
              ],
            );
          },
        );
      }
    }
    _onLongPressSave();
  }

  Future<void> _buildInkTap(BuildContext context, String heroTag) async {
    HapticUtil.selectionClick();
    await Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(
        allowSnapshotting: false,
        builder: (_) {
          if (iStores != null) {
            return PictureListPage(
              heroString: heroTag,
              store: store,
              lightingStore: _lightingStore,
              iStores: iStores!,
            );
          }
          return IllustLightingPage(
            id: store.illusts!.id,
            heroString: heroTag,
            store: store,
          );
        },
      ),
    );
  }

  Widget _buildBottom(BuildContext context) {
    return Container(
      child: Stack(
        children: <Widget>[
          if (usesAppleControls(context)) Positioned.fill(child: CardReflection(style: artworkReflection,
            images: [PixivProvider.url(store.illusts!.height > store.illusts!.width * 3 ? store.illusts!.imageUrls.squareMedium : _previewUrl)])),
          Padding(
            padding: EdgeInsets.only(
              left: usesAppleControls(context) ? 12.0 : 8.0,
              right: 36.0,
              top: usesAppleControls(context) ? 6 : 4,
              bottom: 4,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  store.illusts!.title,
                  maxLines: 1,
                  overflow: TextOverflow.clip,
                  style: usesAppleControls(context) ? Theme.of(context).textTheme.titleSmall : Theme.of(context).textTheme.bodyMedium,
                  strutStyle: StrutStyle(forceStrutHeight: true, leading: 0),
                ),
                Text(
                  store.illusts!.user.name,
                  maxLines: 1,
                  overflow: TextOverflow.clip,
                  style: Theme.of(context).textTheme.bodySmall,
                  strutStyle: StrutStyle(forceStrutHeight: true, leading: 0),
                ),
              ],
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: GestureDetector(
              child: Observer(
                builder: (_) {
                  return StarIcon(state: store.state);
                },
              ),
              onTap: () async {
                if (userSetting.saveAfterStar && (store.state == 0)) {
                  saveStore.saveImage(store.illusts!);
                }
                // TODO: 添加配置项 开关和过滤器
                final List<String>? tags;
                if (userSetting.autoTagWhenStar) {
                  final filters = [RegExp(r"\d+users入り")];
                  tags = store.illusts?.tags
                      .map((tag) => tag.name)
                      .where(
                        (tag) => !filters.any((regex) => regex.hasMatch(tag)),
                      )
                      .toList();
                } else {
                  tags = null;
                }
                bool success = await store.star(
                  restrict: userSetting.defaultPrivateLike
                      ? "private"
                      : "public",
                  tags: tags,
                );
                if (success && userSetting.followAfterStar) {
                  bool followSuccess = await store.followAfterStar();
                  if (followSuccess) {
                    BotToast.showText(
                      text:
                          "${store.illusts!.user.name} ${I18n.of(context).followed}",
                    );
                  }
                }
              },
              onLongPress: () async {
                HapticUtil.heavy();
                final result = await showModalBottomSheet(
                  context: context,
                  clipBehavior: Clip.hardEdge,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(16),
                    ),
                  ),
                  constraints: BoxConstraints.expand(
                    height: MediaQuery.of(context).size.height * .618,
                  ),
                  isScrollControlled: true,
                  builder: (_) => TagForIllustPage(id: store.illusts!.id),
                );
                if (result?.isNotEmpty ?? false) {
                  LPrinter.d(result);
                  String restrict = result['restrict'];
                  List<String>? tags = result['tags'];
                  store.star(restrict: restrict, tags: tags, force: true);
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVisibility() {
    return Visibility(
      visible:
          store.illusts!.type != "illust" ||
          store.illusts!.metaPages.isNotEmpty,
      child: Align(
        alignment: Alignment.topRight,
        child: Padding(
          padding: EdgeInsets.all(4.0),
          child: Container(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                vertical: 0.0,
                horizontal: 4.0,
              ),
              child: cardText(),
            ),
            decoration: BoxDecoration(
              color: Colors.black26,
              borderRadius: BorderRadius.all(Radius.circular(4.0)),
            ),
          ),
        ),
      ),
    );
  }
}

class TrianglePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    var paint = Paint()
      ..color = Colors.yellow
      ..style = PaintingStyle.fill;

    var path = Path();
    path.moveTo(0, 0);
    path.lineTo(size.width, 0);
    path.lineTo(0, size.height);
    path.lineTo(0, 0);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    return false;
  }
}
