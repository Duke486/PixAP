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
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:easy_refresh/easy_refresh.dart';
import 'package:mobx/mobx.dart';
import 'package:pixez/app_widget_plugin.dart';
import 'package:pixez/er/hoster.dart';
import 'package:pixez/er/image_cache_manager.dart';
import 'package:pixez/er/lprinter.dart';
import 'package:pixez/exts.dart';
import 'package:pixez/main.dart';
import 'package:pixez/store/user_setting.dart';
import 'package:pixez/models/glance_illust_persist.dart';
import 'package:pixez/models/illust.dart';
import 'package:pixez/models/recommend.dart';
import 'package:pixez/network/api_client.dart';
import 'package:pixez/page/hello/setting/demo_mode.dart';
import 'package:pixez/page/picture/illust_store.dart';

part 'lighting_store.g.dart';

class LightingStore = _LightingStoreBase with _$LightingStore;

typedef Future<Response> FutureGet();
typedef Future<Response> FutureRefreshGet(bool force);

abstract class LightSource {
  String? glanceKey;
}

class ApiSource extends LightSource {
  FutureGet futureGet;

  String? g;

  ApiSource({required this.futureGet}) : super();

  Future<Response> fetch() {
    return futureGet();
  }
}

class ApiForceSource extends LightSource {
  FutureRefreshGet futureGet;

  ApiForceSource({required this.futureGet, String? glanceKey = null})
    : super() {
    this.glanceKey = glanceKey;
  }

  Future<Response> fetch(bool force) {
    return futureGet(force);
  }
}

abstract class _LightingStoreBase with Store {
  late LightSource source;
  String? nextUrl;
  EasyRefreshController? easyRefreshController;
  Function? onChange;
  String? portal;
  @observable
  ObservableList<IllustStore> iStores = ObservableList();
  @observable
  bool refreshing = false;

  dispose() {
    // iStores.forEach((element) {
    //   final provider = ExtendedNetworkImageProvider(
    //     element.illusts.imageUrls.medium,
    //   );
    //   provider.evict();
    // });
    // iStores.clear();
  }

  @observable
  String? errorMessage;

  _LightingStoreBase(this.source);

  bool okForUser(Illusts illust) {
    // if (userSetting.hIsNotAllow)
    //   for (int i = 0; i < illust.tags.length; i++)
    //     if (illust.tags[i].name.startsWith('R-18')) return false;
    for (var t in muteStore.banTags) {
      for (var f in illust.tags) {
        if (f.name == t.name) return false;
      }
    }
    for (var j in muteStore.banUserIds) {
      if (j.userId == illust.user.id.toString()) {
        return false;
      }
    }
    for (var i in muteStore.banillusts)
      if (illust.id == i.id) {
        return false;
      }
    return true;
  }

  bool _lock = false;
  int _feedGeneration = 0;

  void replaceRecommendations(Recommend? recommend, {bool publishWidget = false}) {
    _feedGeneration++;
    runInAction(() {
      nextUrl = recommend?.nextUrl;
      iStores.clear();
      if (recommend != null) {
        iStores.addAll(recommend.illusts.map((illust) => IllustStore(illust.id, illust)));
      }
    });
    final glanceKey = source.glanceKey;
    if (publishWidget && recommend != null && glanceKey != null &&
        glanceKey.isNotEmpty && Platform.isIOS && !DemoMode.active) {
      unawaited(_publishWidgetSource(glanceKey, recommend.illusts));
    }
  }

  @action
  Future<bool> fetch({String? url, bool force = false}) async {
    if (_lock) return false;
    _lock = true;
    nextUrl = null;
    errorMessage = null;
    refreshing = true;
    try {
      Response? result = null;
      if (source is ApiSource) {
        result = await (source as ApiSource).fetch();
      } else if (source is ApiForceSource) {
        result = await (source as ApiForceSource).fetch(force);
      }

      Recommend recommend = Recommend.fromJson(result!.data);
      replaceRecommendations(recommend, publishWidget: true);
      refreshing = false;
      easyRefreshController?.finishRefresh(IndicatorResult.success);
      return true;
    } catch (e) {
      refreshing = false;
      errorMessage = e.toString();
      easyRefreshController?.finishRefresh(IndicatorResult.fail);
      return false;
    } finally {
      _lock = false;
    }
  }

  Future<void> _publishWidgetSource(
    String type,
    List<Illusts> illustrations,
  ) async {
    try {
      final time = DateTime.now().microsecondsSinceEpoch;
      final entries = illustrations
          .where(
            (illustration) =>
                !illustration.hateByUser() &&
                (!illustration.isNsfw ||
                    userSetting.nsfwDisplayMode == NsfwDisplayMode.show),
          )
          .toGlancePersist(type, time);
      final provider = GlanceIllustPersistProvider();
      await provider.open();
      try {
        await provider.replaceSource(type, entries);
        final sample = entries.toList()..shuffle();
        final thumbnails = <int, Uint8List>{};
        await Future.wait(
          sample.take(6).map((entry) async {
            try {
              final file = await DioCacheManager.instance
                  .getSingleFile(
                    entry.pictureUrl,
                    headers: Hoster.header(url: entry.pictureUrl),
                  )
                  .timeout(const Duration(seconds: 6));
              final thumbnail = await AppWidgetPlugin.makeThumbnail(file.path);
              if (thumbnail != null) thumbnails[entry.illustId] = thumbnail;
            } catch (error) {
              LPrinter.d('Failed to prepare widget thumbnail: $error');
            }
          }),
        );
        if (thumbnails.isNotEmpty) {
          await provider.saveThumbnails(type, time, thumbnails);
        }
      } finally {
        await provider.close();
      }
      await AppWidgetPlugin.reload(updatedSource: type);
    } catch (error) {
      LPrinter.d('Failed to publish widget cache: $error');
    }
  }

  @action
  update(LightSource futureGet) async {
    source = futureGet;
    await fetch();
  }

  @action
  Future<bool> fetchNext() async {
    if (_lock) return false;
    _lock = true;
    final generation = _feedGeneration;
    errorMessage = null;
    try {
      if (nextUrl != null && nextUrl!.isNotEmpty) {
        Response result = await apiClient.getNext(nextUrl!);
        if (generation != _feedGeneration) {
          easyRefreshController?.finishLoad(IndicatorResult.none);
          return false;
        }
        Recommend recommend = Recommend.fromJson(result.data);
        nextUrl = recommend.nextUrl;
        var map = recommend.illusts.map((e) => IllustStore(e.id, e));
        if (portal == "new") {
          var iterable = iStores.map((element) => element.id);
          map = map.where((element) => !iterable.contains(element.id));
        }
        iStores.addAll(map);
        easyRefreshController?.finishLoad(IndicatorResult.success);
      } else {
        easyRefreshController?.finishLoad(IndicatorResult.noMore);
      }
      return true;
    } catch (e) {
      easyRefreshController?.finishLoad(generation == _feedGeneration
          ? IndicatorResult.fail : IndicatorResult.none);
      return false;
    } finally {
      _lock = false;
    }
  }
}
