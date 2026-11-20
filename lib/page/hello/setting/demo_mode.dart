import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

const demoHint = '所有数据都将暂时替换为演示数据。重启APP生效，再次点击可恢复。';

class DemoMode {
  static const _channel = MethodChannel('pixez/demoSession');
  static bool active = false;
  static Future<void> initialize() async {
    active = await _channel.invokeMethod<bool>('active') ?? false;
    if (active) SharedPreferences.setPrefix('pixap.demo.');
  }

  static Future<void> restart(bool enabled) =>
      _channel.invokeMethod<void>('restart', enabled);
}
