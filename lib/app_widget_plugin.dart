import 'dart:io';

import 'package:flutter/services.dart';
import 'package:pixez/er/prefer.dart';
import 'package:pixez/page/hello/setting/demo_mode.dart';

class AppWidgetPlugin {
  static const platform = MethodChannel('com.perol.dev/app_widget');

  static Future<String> databaseDirectory() async {
    final path = await platform.invokeMethod<String>('databaseDirectory');
    if (path == null) throw StateError('Widget App Group is unavailable');
    return path;
  }

  static Future<Uint8List?> makeThumbnail(String path) =>
      platform.invokeMethod<Uint8List>('makeThumbnail', path);

  static Future<void> reload({String? updatedSource}) async {
    final selected = Prefer.getString('widget_illust_type');
    final type = switch (selected) {
      'rank' => 'rank',
      'follow_illust' => 'follow_illust',
      _ => 'recom',
    };
    if (updatedSource == null || updatedSource == type) {
      await setRecommendType(type);
    }
  }

  static Future<void> setRecommendType(String type) async {
    if (DemoMode.active) return;
    if (!Platform.isIOS) {
      return;
    }
    await platform.invokeMethod<void>('setRecommendType', {'type': type});
  }
}
