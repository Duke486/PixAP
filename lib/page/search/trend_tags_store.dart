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

import 'dart:convert';
import 'package:pixez/er/prefer.dart';
import 'package:mobx/mobx.dart';
import 'package:pixez/main.dart';
import 'package:pixez/models/ban_tag.dart';
import 'package:pixez/models/trend_tags.dart';
import 'package:pixez/network/api_client.dart';

part 'trend_tags_store.g.dart';

class TrendTagsStore = _TrendTagsStoreBase with _$TrendTagsStore;

abstract class _TrendTagsStoreBase with Store {
  @observable
  ObservableList<TrendTags> trendTags = ObservableList();

  _TrendTagsStoreBase();

  /// Trend tags without the ones muted by the user.
  List<TrendTags> get visibleTrendTags => trendTags
      .where(
        (tag) => !muteStore.banTags.any((ban) => ban.isRegexMatch(tag.tag)),
      )
      .toList();

  String? _loadedKey;
  String? _snapshot;
  Future<void>? _pending;
  int _generation = 0;

  String? get _key {
    final id = accountStore.now?.userId;
    return id == null ? null : 'search_grid_v1.${id}.${userSetting.locale}';
  }

  @action
  Future<void> fetch() async {
    final key = _key;
    if (key != _loadedKey) {
      _generation++;
      _pending = null;
      _loadedKey = key;
      _snapshot = key == null ? null : Prefer.getString(key);
      trendTags = ObservableList();
      if (_snapshot != null) {
        try {
          trendTags = ObservableList.of(
            TrendingTag.fromJson(jsonDecode(_snapshot!)).trend_tags,
          );
        } catch (_) {
          _snapshot = null;
        }
      }
    }
    if (key == null) return;
    final generation = _generation;
    try {
      await (_pending ??= _refresh(key, generation));
    } finally {
      if (_generation == generation) _pending = null;
    }
  }

  Future<void> _refresh(String key, int generation) async {
    try {
      final response = await apiClient.getIllustTrendTags(force: true);
      if (generation != _generation || key != _key) return;
      final tags = TrendingTag.fromJson(response.data).trend_tags;
      final snapshot = jsonEncode({
        'trend_tags': [
          for (final tag in tags)
            {
              'tag': tag.tag,
              'translated_name': tag.translatedName,
              'illust': {
                'id': tag.illust.id,
                'image_urls': tag.illust.imageUrls.toJson(),
              },
            },
        ],
      });
      if (snapshot == _snapshot) return;
      runInAction(() => trendTags = ObservableList.of(tags));
      await Prefer.setString(key, snapshot);
      if (generation == _generation) _snapshot = snapshot;
    } catch (error) {
      print('Search grid refresh failed: $error');
    }
  }
}
