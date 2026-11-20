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

import 'package:dio/dio.dart';
import 'package:easy_refresh/easy_refresh.dart';
import 'package:mobx/mobx.dart';
import 'package:pixez/models/spotlight_response.dart';
import 'package:pixez/network/api_client.dart';
part 'spotlight_store.g.dart';

class SpotlightStore extends _SpotlightStoreBase with _$SpotlightStore {
  SpotlightStore(EasyRefreshController? controller, {int? pageSize})
    : super(controller, pageSize: pageSize);
}

abstract class _SpotlightStoreBase with Store {
  final ApiClient client = apiClient;
  ObservableList<SpotlightArticle> articles = ObservableList();
  String? nextUrl;
  final EasyRefreshController? _controller;

  _SpotlightStoreBase(this._controller, {this.pageSize});

  final int? pageSize;
  final List<SpotlightArticle> _pending = [];

  // Pixiv controls the API page size. Buffer any extra items for the next load.
  Future<(List<SpotlightArticle>, String?)> _collect(
    List<SpotlightArticle> items,
    String? cursor,
  ) async {
    final limit = pageSize;
    final visited = <String>{};
    while (limit != null &&
        items.length < limit &&
        cursor != null &&
        cursor.isNotEmpty &&
        visited.add(cursor)) {
      final response = await client.getNext(cursor);
      final result = SpotlightResponse.fromJson(response.data);
      items.addAll(result.spotlightArticles);
      cursor = result.nextUrl;
    }
    return (items, visited.contains(cursor) ? null : cursor);
  }

  void _append(List<SpotlightArticle> items, String? cursor) {
    final count = (pageSize ?? items.length).clamp(0, items.length);
    articles.addAll(items.take(count));
    _pending
      ..clear()
      ..addAll(items.skip(count));
    nextUrl = cursor;
  }

  bool _lock = false;
  @action
  Future<bool> fetch() async {
    if (_lock) return false;
    _lock = true;
    try {
      Response response = await client.getSpotlightArticles("all");
      final result = SpotlightResponse.fromJson(response.data);
      final (items, cursor) = await _collect(
        List.of(result.spotlightArticles),
        result.nextUrl,
      );
      articles.clear();
      _append(items, cursor);
      _controller?.resetFooter();
      _controller?.finishRefresh(IndicatorResult.success);
      return true;
    } catch (e) {
      _controller?.finishRefresh(IndicatorResult.fail);
      return false;
    } finally {
      _lock = false;
    }
  }

  @action
  Future<bool> next() async {
    if (_lock) return false;
    _lock = true;
    try {
      if (_pending.isNotEmpty || nextUrl?.isNotEmpty == true) {
        final (items, cursor) = pageSize == null
            ? await _fetchNext()
            : await _collect(List.of(_pending), nextUrl);
        _append(items, cursor);
      }
      _controller?.finishLoad(
        _pending.isNotEmpty || nextUrl?.isNotEmpty == true
            ? IndicatorResult.success
            : IndicatorResult.noMore,
      );
      return true;
    } catch (_) {
      _controller?.finishLoad(IndicatorResult.fail);
      return false;
    } finally {
      _lock = false;
    }
  }

  Future<(List<SpotlightArticle>, String?)> _fetchNext() async {
    final response = await client.getNext(nextUrl!);
    final result = SpotlightResponse.fromJson(response.data);
    return (result.spotlightArticles, result.nextUrl);
  }
}
