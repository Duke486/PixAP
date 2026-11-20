import 'package:dio/dio.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:pixez/constants.dart';

enum Result { yes, no, timeout }

class Updater {
  static Result result = Result.timeout;
  static String? latestVersion;

  static Future<Result> check() async {
    try {
      final response = await Dio().get<Map<String, dynamic>>(
        Constants.latestReleaseApi,
      );
      final tag = response.data?['tag_name'];
      if (tag is! String) return result = Result.timeout;

      final remote = _versionParts(tag);
      final local = _versionParts((await PackageInfo.fromPlatform()).version);
      if (remote == null || local == null) return result = Result.timeout;

      latestVersion = tag;
      for (var i = 0; i < remote.length; i++) {
        if (remote[i] != local[i]) {
          return result = remote[i] > local[i] ? Result.yes : Result.no;
        }
      }
      return result = Result.no;
    } catch (_) {
      return result = Result.timeout;
    }
  }

  static List<int>? _versionParts(String version) {
    final match = RegExp(r'^v?(\d+)\.(\d+)\.(\d+)$').firstMatch(version);
    if (match == null) return null;
    return [for (var i = 1; i <= 3; i++) int.parse(match.group(i)!)];
  }
}
