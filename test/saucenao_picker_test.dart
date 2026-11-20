import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pixez/page/saucenao/sauce_nao_modal.dart';
import 'package:pixez/src/generated/i18n/app_localizations.dart';

void main() {
  testWidgets('SauceNAO offers both single-image pickers before upload', (
    tester,
  ) async {
    final original = FilePickerPlatform.instance;
    final picker = _CancelledPicker();
    FilePickerPlatform.instance = picker;
    addTearDown(() => FilePickerPlatform.instance = original);
    const channel = MethodChannel('pixez/sauceNaoImage');
    final messenger = tester.binding.defaultBinaryMessenger;
    final sourceCalls = <MethodCall>[];
    String? source;
    messenger.setMockMethodCallHandler(channel, (call) async {
      sourceCalls.add(call);
      return source;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh', 'CN'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => SauceNaoModal.showFromPicker(context),
              child: const Text('SauceNAO'),
            ),
          ),
        ),
      ),
    );

    final button = find.widgetWithText(TextButton, 'SauceNAO');
    final rect = tester.getRect(button);
    for (final option in <String?>[null, 'photos', 'files']) {
      source = option;
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(find.byType(SauceNaoModal), findsNothing);
    }

    expect(sourceCalls, hasLength(3));
    for (final call in sourceCalls) {
      expect(call.method, 'pickSource');
      expect(call.arguments, {
        'x': rect.left,
        'y': rect.top,
        'width': rect.width,
        'height': rect.height,
        'photos': '相册',
        'files': '文件',
      });
    }
    expect(picker.types, [FileType.image, FileType.custom]);
    expect(picker.photoMode, DarwinAssetRepresentationMode.compatible);
    expect(picker.fileExtensions, containsAll(['jpg', 'png', 'heic', 'webp']));
  });
}

class _CancelledPicker extends FilePickerPlatform {
  final types = <FileType>[];
  DarwinAssetRepresentationMode? photoMode;
  List<String>? fileExtensions;

  @override
  Future<PlatformFile?> pickFile({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    int compressionQuality = 0,
    AndroidOptions androidOptions = const AndroidOptions(),
    DarwinOptions darwinOptions = const DarwinOptions(),
    WindowsOptions windowsOptions = const WindowsOptions(),
    LinuxOptions linuxOptions = const LinuxOptions(),
    WebOptions webOptions = const WebOptions(),
  }) async {
    types.add(type);
    if (type == FileType.image)
      photoMode = darwinOptions.assetRepresentationMode;
    if (type == FileType.custom) fileExtensions = allowedExtensions;
    return null;
  }
}
