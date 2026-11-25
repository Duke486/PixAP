import 'package:pixez/main.dart';
import 'package:pixez/store/user_setting.dart';
import 'package:pixez/component/nsfw_artwork.dart';
import 'package:pixez/component/card_reflection.dart';
import 'package:pixez/component/ipad_surface.dart';
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
import 'package:pixez/component/painter_avatar.dart';
import 'package:pixez/component/pixiv_image.dart';
import 'package:pixez/exts.dart';
import 'package:pixez/models/user_preview.dart';
import 'package:pixez/network/api_client.dart';
import 'package:pixez/page/novel/user/novel_users_page.dart';
import 'package:pixez/page/picture/user_follow_button.dart';
import 'package:pixez/page/user/user_store.dart';
import 'package:pixez/page/user/users_page.dart';

class PainterCard extends StatefulWidget {
  final UserPreviews user;
  final bool isNovel;
  const PainterCard({Key? key, required this.user, this.isNovel = false})
      : super(key: key);

  @override
  State<PainterCard> createState() => _PainterCardState();
}

class _PainterCardState extends State<PainterCard> {
  late bool isNovel = widget.isNovel;
  late UserPreviews _user = widget.user;

  @override
  void didUpdateWidget(covariant PainterCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    isNovel = widget.isNovel;
    _user = widget.user;
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        await Navigator.of(context, rootNavigator: true)
            .push(MaterialPageRoute(builder: (BuildContext context) {
          if (isNovel) {
            return NovelUsersPage(
              id: _user.user.id,
            );
          }
          return UsersPage(
            id: _user.user.id,
            userStore: UserStore(_user.user.id, null, _user.user),
          );
        }));
        setState(() {});
      },
      child: usesAppleControls(context)
        ? IPadGalleryCard(scrolling: true, child: Column(children: [_buildPreviewSlivers(context), Stack(children: [
            Positioned.fill(child: Observer(builder: (_) {
              final urls = isNovel ? _user.novels.take(3).map((n) => n.imageUrls.squareMedium)
                : _user.illusts.take(3).map((i) => (i.isNsfw && userSetting.nsfwDisplayMode == NsfwDisplayMode.replace) ? null : i.imageUrls.squareMedium);
              return CardReflection(style: artistReflection, images: [
                for (final url in urls) url == null ? null : PixivProvider.url(url),
                ...List<ImageProvider?>.filled(3 - urls.length, null),
              ]);
            })),
            buildPadding(context),
          ])]))
        : Card(clipBehavior: Clip.antiAlias,
            child: Column(children: [_buildPreviewSlivers(context), buildPadding(context)])),
    );
  }

  _buildPreviewSlivers(BuildContext context) {
    return (isNovel)
        ? Row(
            children: [
              for (var i = 0; i < 3; i++)
                Expanded(
                  child: i < _user.novels.length
                      ? AspectRatio(
                          aspectRatio: 1.0,
                          child: Stack(
                            children: [
                              AspectRatio(
                                aspectRatio: 1.0,
                                child: PixivImage(
                                  _user.novels[i].imageUrls.squareMedium,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              Align(
                                alignment: Alignment.bottomCenter,
                                child: Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Text(
                                    _user.novels[i].title,
                                    style:
                                        Theme.of(context).textTheme.titleSmall,
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              )
                            ],
                          ),
                        )
                      : Container(),
                )
            ],
          )
        : Row(
            children: [
              for (var i = 0; i < 3; i++)
                Expanded(
                  child: i < _user.illusts.length
                      ? AspectRatio(
                          aspectRatio: 1.0,
                          child: Observer(
                            builder: (_) {
                              final illust = _user.illusts[i];
                              return NsfwArtwork.preview(illust, buildPreview: (mask) => PixivImage(
                                illust.imageUrls.squareMedium, fit: BoxFit.cover,
                                loadedImageBuilder: mask,
                              ));
                            },
                          ),
                        )
                      : Container(),
                )
            ],
          );
  }

  Widget buildPadding(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.start,
        children: <Widget>[
          Hero(
            tag: _user.user.profileImageUrls.medium + this.hashCode.toString(),
            child: SizedBox.square(dimension: 60, child: PainterAvatar(
              url: _user.user.profileImageUrls.medium,
              id: _user.user.id,
              onTap: () {
                Navigator.of(context, rootNavigator: true)
                    .push(MaterialPageRoute(builder: (BuildContext context) {
                  if (isNovel) {
                    return NovelUsersPage(
                      id: _user.user.id,
                    );
                  }
                  return UsersPage(
                    id: _user.user.id,
                    userStore: UserStore(_user.user.id, null, _user.user),
                    heroTag: this.hashCode.toString(),
                  );
                }));
              },
            )),
          ),
          Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 10), child: Text(_user.user.name, maxLines: 2, overflow: TextOverflow.ellipsis))),
          if (_user.user.isFollowed != null)
            UserFollowButton(
              id: _user.user.id,
              followed: _user.user.isFollowed!,
              onPressed: () async {
                try {
                  if (_user.user.isFollowed!) {
                    await apiClient.postUnFollowUser(_user.user.id);
                    if (mounted) {
                      setState(() {
                        _user.user.isFollowed = false;
                      });
                    }
                  } else {
                    await apiClient.postFollowUser(_user.user.id, 'public');
                    if (mounted) {
                      setState(() {
                        _user.user.isFollowed = true;
                      });
                    }
                  }
                } catch (e) {}
              },
              onConfirm: (follow, restrict) async {
                try {
                  if (follow) {
                    await apiClient.postFollowUser(_user.user.id, restrict);
                  } else {
                    await apiClient.postUnFollowUser(_user.user.id);
                  }
                  if (mounted) {
                    setState(() {
                      _user.user.isFollowed = follow;
                    });
                  }
                } catch (e) {
                  print(e);
                }
              },
            )
        ],
      ),
    );
  }
}
