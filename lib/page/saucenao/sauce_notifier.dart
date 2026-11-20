import 'dart:async';
import 'dart:io';

import 'package:bot_toast/bot_toast.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:html/parser.dart' show parse;
import 'package:image/image.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobx/mobx.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pixez/er/lprinter.dart';
import 'package:pixez/i18n.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'sauce_notifier.freezed.dart';
part 'sauce_notifier.g.dart';

@freezed
abstract class SauceState with _$SauceState {
  const factory SauceState({required bool notStart}) = _SauceState;
}

@riverpod
class Sauce extends _$Sauce {
  Dio dio = Dio(
    BaseOptions(
      baseUrl: "https://saucenao.com",
    ),
  );
  List<int> results = [];
  late StreamController _streamController;
  late ObservableStream observableStream;

  Sauce() {
    _streamController = StreamController();
    observableStream = ObservableStream(
      _streamController.stream.asBroadcastStream(),
    );
  }

  void dispose() async {
    await _streamController.close();
  }

  @override
  SauceState build() {
    return SauceState(notStart: true);
  }

  Future findImage({
    BuildContext? context,
    String? path,
    bool retry = false,
  }) async {
    state = state.copyWith(notStart: false);
    results.clear();
    final picker = ImagePicker();
    if (path == null) {
      final pickedFile = await picker.pickImage(source: ImageSource.gallery);
      if (pickedFile == null) return;
      Uint8List originImageBytes = await pickedFile.readAsBytes();
      var newImageBytes = compressImage(originImageBytes);
      LPrinter.d(
        "Uncompressed image size: ${originImageBytes.length}, compressed image size: ${newImageBytes.length}",
      );
      path =
          "${(await getTemporaryDirectory()).path}/${DateTime.now().millisecondsSinceEpoch}.jpg";
      await File(path).writeAsBytes(newImageBytes);
    }
    var formData = FormData();
    formData.files.addAll([
      MapEntry("file", await MultipartFile.fromFile(path)),
    ]);
    try {
      BotToast.showText(text: I18n.ofContext().uploading);
      Response response = await dio.post('/search.php', data: formData);
      BotToast.showText(text: I18n.ofContext().parsing);
      var document = parse(response.data);
      document.querySelectorAll('a').forEach((element) {
        var link = element.attributes['href'];
        if (link != null) {
          bool need =
              link.startsWith('https://www.pixiv.net') &&
              link.contains('illust_id');
          if (need) {
            var result = Uri.parse(link).queryParameters['illust_id'];
            if (result != null) {
              try {
                results.add(int.parse(result));
              } catch (e) {}
            }
          }
        }
      });
      _streamController.add(1);
    } catch (e) {
      BotToast.showText(text: "error${e}");
    }
  }

  Uint8List compressImage(Uint8List originImageBytes) {
    var originImage = decodeImage(originImageBytes);
    var originWidth = originImage!.width;
    var originHeight = originImage.height;
    int newWidth, newHeight;
    if (originWidth < 720 || originHeight < 720) {
      newWidth = originWidth;
      newHeight = originHeight;
    } else if (originWidth > originHeight) {
      newHeight = 720;
      newWidth = originWidth * newHeight ~/ originHeight;
    } else {
      newWidth = 720;
      newHeight = originHeight * newWidth ~/ originWidth;
    }
    var newImage = copyResize(originImage, width: newWidth, height: newHeight);
    return encodeJpg(newImage, quality: 75);
  }
}
