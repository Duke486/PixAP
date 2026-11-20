import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:html/parser.dart' show parse;
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:pixez/component/ipad_surface.dart';
import 'package:pixez/component/pixiv_image.dart';
import 'package:pixez/er/hoster.dart';
import 'package:pixez/er/leader.dart';
import 'package:pixez/i18n.dart';
import 'package:pixez/models/illust.dart';
import 'package:pixez/network/api_client.dart';
import 'package:pixez/page/picture/illust_lighting_page.dart';
import 'package:pixez/page/saucenao/sauce_nao_result.dart';

enum _SauceNaoPhase { idle, loading, done, error }

class SauceNaoModal extends StatefulWidget {
  const SauceNaoModal({super.key}) : _initialPath = null;

  const SauceNaoModal._withImage(this._initialPath);

  final String? _initialPath;

  static Future<String?> _pickSource(BuildContext context) async {
    final strings = I18n.of(context);
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return null;
    final rect = box.localToGlobal(Offset.zero) & box.size;
    try {
      final source = await const MethodChannel('pixez/sauceNaoImage')
          .invokeMethod<String>('pickSource', {
            'x': rect.left,
            'y': rect.top,
            'width': rect.width,
            'height': rect.height,
            'photos': strings.saucenao_photos,
            'files': strings.saucenao_files,
          });
      if (source == null || !context.mounted) return null;
      final picked = await switch (source) {
        'photos' => FilePicker.pickFile(
          type: FileType.image,
          darwinOptions: const DarwinOptions(
            assetRepresentationMode: DarwinAssetRepresentationMode.compatible,
          ),
        ),
        'files' => FilePicker.pickFile(
          type: FileType.custom,
          allowedExtensions: const [
            'jpg',
            'jpeg',
            'png',
            'heic',
            'heif',
            'webp',
            'gif',
            'tif',
            'tiff',
            'bmp',
            'avif',
            'dng',
          ],
        ),
        _ => Future<PlatformFile?>.value(null),
      };
      return picked?.path;
    } on PlatformException {
      if (context.mounted) {
        await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            content: Text(strings.saucenao_image_error),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(strings.ok),
              ),
            ],
          ),
        );
      }
      return null;
    }
  }

  static Future<void> showFromPicker(BuildContext context) async {
    final path = await _pickSource(context);
    if (path == null || !context.mounted) return;
    final result = await showDialog<SauceNaoResult>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: IPadSurface(
          includeIPhone: true,
          maxWidth: 520,
          darkGlass: Theme.of(context).brightness == Brightness.dark,
          child: SauceNaoModal._withImage(path),
        ),
      ),
    );
    if (result == null || !context.mounted) return;
    Leader.push(context, IllustLightingPage(id: result.illustId));
  }

  static Future<void> show(BuildContext context) async {
    final result = await showModalBottomSheet<SauceNaoResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => const SauceNaoModal(),
    );
    if (result == null || !context.mounted) return;
    Leader.push(context, IllustLightingPage(id: result.illustId));
  }

  @override
  State<SauceNaoModal> createState() => _SauceNaoModalState();
}

class _SauceNaoModalState extends State<SauceNaoModal> {
  final Dio _dio = Dio(BaseOptions(baseUrl: "https://saucenao.com"));
  CancelToken? _cancelToken;
  _SauceNaoPhase _phase = _SauceNaoPhase.idle;
  String? _errorMessage;
  String? _sourcePath;
  Uint8List? _imageBytes;
  double? _progress;
  bool _picking = false;
  final List<SauceNaoResult> _results = [];

  @override
  void initState() {
    super.initState();
    final path = widget._initialPath;
    if (path != null) {
      _sourcePath = path;
      _phase = _SauceNaoPhase.loading;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _search();
      });
    }
  }

  @override
  void dispose() {
    _cancelToken?.cancel("disposed");
    _dio.close(force: true);
    super.dispose();
  }

  void _cancelRequest() {
    _cancelToken?.cancel("cancelled");
    _cancelToken = null;
    if (mounted && _phase == _SauceNaoPhase.loading) {
      setState(() {
        _phase = _SauceNaoPhase.idle;
        _errorMessage = null;
      });
    }
  }

  Future<void> _pickAndSearch({BuildContext? anchor}) async {
    if (_picking) return;
    _picking = true;
    try {
      final String? path;
      if (widget._initialPath != null) {
        path = await SauceNaoModal._pickSource(anchor ?? context);
      } else {
        path = (await ImagePicker().pickImage(
          source: ImageSource.gallery,
        ))?.path;
      }
      if (path == null || !mounted) return;
      _sourcePath = path;
      _imageBytes = null;
      await _search();
    } on PlatformException {
      if (mounted) {
        setState(() {
          _phase = _SauceNaoPhase.error;
          _errorMessage = I18n.of(context).saucenao_image_error;
        });
      }
    } finally {
      _picking = false;
    }
  }

  Future<void> _retry() async {
    if (_sourcePath == null) {
      await _pickAndSearch();
    } else {
      await _search();
    }
  }

  Future<void> _search() async {
    final path = _sourcePath;
    if (path == null) return;
    _cancelToken?.cancel("restart");
    final cancelToken = CancelToken();
    _cancelToken = cancelToken;
    setState(() {
      _phase = _SauceNaoPhase.loading;
      _progress = null;
      _errorMessage = null;
      _results.clear();
    });
    try {
      final bytes = _imageBytes ?? await _prepareImage(path);
      if (!mounted || cancelToken.isCancelled) return;
      setState(() => _imageBytes = bytes);

      final formData = FormData.fromMap({
        'file': MultipartFile.fromBytes(
          bytes,
          filename: 'image.jpg',
          contentType: DioMediaType('image', 'jpeg'),
        ),
      });

      final response = await _dio.post(
        '/search.php',
        data: formData,
        cancelToken: cancelToken,
        onSendProgress: (sent, total) {
          if (!mounted || cancelToken.isCancelled || total <= 0) return;
          setState(() => _progress = (sent / total).clamp(0.0, 1.0));
        },
      );
      if (!mounted || cancelToken.isCancelled) return;

      final results = _parseResponse(response.data);
      setState(() {
        _results
          ..clear()
          ..addAll(results);
        _phase = _SauceNaoPhase.done;
      });
    } on DioException catch (e) {
      if (CancelToken.isCancel(e) || !mounted) return;
      setState(() {
        _phase = _SauceNaoPhase.error;
        _errorMessage = e.message ?? e.toString();
      });
    } on FormatException {
      if (!mounted || cancelToken.isCancelled) return;
      setState(() {
        _phase = _SauceNaoPhase.error;
        _errorMessage = I18n.of(context).saucenao_image_error;
      });
    } catch (e) {
      if (!mounted || cancelToken.isCancelled) return;
      setState(() {
        _phase = _SauceNaoPhase.error;
        _errorMessage = e.toString();
      });
    } finally {
      if (identical(_cancelToken, cancelToken)) {
        _cancelToken = null;
      }
    }
  }

  List<SauceNaoResult> _parseResponse(dynamic raw) {
    try {
      final decoded = raw is String
          ? jsonDecode(raw)
          : raw is Map
          ? raw
          : null;
      if (decoded is Map) {
        return _parseJson(Map<String, dynamic>.from(decoded));
      }
    } catch (_) {}
    if (raw is String) {
      return _parseHtml(raw);
    }
    return [];
  }

  List<SauceNaoResult> _parseJson(Map<String, dynamic> json) {
    final results = <SauceNaoResult>[];
    final seen = <int>{};
    final items = json['results'];
    if (items is! List) return results;

    for (final item in items) {
      if (item is! Map) continue;
      final header = item['header'];
      final data = item['data'];
      if (data is! Map) continue;

      final illustId = _extractPixivId(Map<String, dynamic>.from(data));
      if (illustId == null || !seen.add(illustId)) continue;

      results.add(
        SauceNaoResult(
          illustId: illustId,
          thumbnail: header is Map ? header['thumbnail']?.toString() : null,
          similarity: header is Map ? header['similarity']?.toString() : null,
          title: data['title']?.toString(),
          author: (data['member_name'] ?? data['author_name'] ?? data['author'])
              ?.toString(),
        ),
      );
    }
    return results;
  }

  List<SauceNaoResult> _parseHtml(String html) {
    final results = <SauceNaoResult>[];
    final seen = <int>{};
    final document = parse(html);

    final resultNodes = document.querySelectorAll('.result');
    if (resultNodes.isNotEmpty) {
      for (final node in resultNodes) {
        int? illustId;
        String? title;
        String? author;
        for (final anchor in node.querySelectorAll('a')) {
          final link = anchor.attributes['href'];
          if (link == null) continue;
          final id = _extractPixivIdFromUrl(link);
          if (id != null) {
            illustId = id;
            break;
          }
        }
        if (illustId == null || !seen.add(illustId)) continue;

        final thumbnail =
            node.querySelector('.resultimage img')?.attributes['src'] ??
            node.querySelector('img')?.attributes['src'];
        final similarity = node
            .querySelector('.resultsimilarityinfo')
            ?.text
            .trim();
        title = node.querySelector('.resulttitle')?.text.trim();
        final memberAnchors = node.querySelectorAll('a').where((a) {
          final href = a.attributes['href'] ?? '';
          return href.contains('member.php') || href.contains('/users/');
        });
        if (memberAnchors.isNotEmpty) {
          author = memberAnchors.first.text.trim();
        }

        results.add(
          SauceNaoResult(
            illustId: illustId,
            thumbnail: thumbnail,
            similarity: similarity,
            title: title,
            author: author,
          ),
        );
      }
      if (results.isNotEmpty) return results;
    }

    for (final element in document.querySelectorAll('a')) {
      final link = element.attributes['href'];
      if (link == null) continue;
      final illustId = _extractPixivIdFromUrl(link);
      if (illustId == null || !seen.add(illustId)) continue;

      final imgEl =
          element.querySelector('img') ?? element.parent?.querySelector('img');
      results.add(
        SauceNaoResult(illustId: illustId, thumbnail: imgEl?.attributes['src']),
      );
    }
    return results;
  }

  int? _extractPixivId(Map<String, dynamic> data) {
    final pixivId = data['pixiv_id'];
    if (pixivId is int) return pixivId;
    if (pixivId is String) return int.tryParse(pixivId);

    final extUrls = data['ext_urls'];
    if (extUrls is List) {
      for (final url in extUrls) {
        final id = _extractPixivIdFromUrl(url?.toString() ?? '');
        if (id != null) return id;
      }
    }
    return null;
  }

  int? _extractPixivIdFromUrl(String link) {
    if (!link.contains('pixiv.net')) return null;
    final uri = Uri.tryParse(link);
    if (uri == null) return null;
    final fromQuery = uri.queryParameters['illust_id'];
    if (fromQuery != null) return int.tryParse(fromQuery);
    final match = RegExp(r'artworks/(\d+)').firstMatch(link);
    if (match != null) return int.tryParse(match.group(1)!);
    return null;
  }

  Future<Uint8List> _prepareImage(String path) async {
    if (Platform.isIOS) {
      try {
        final bytes = await const MethodChannel(
          'pixez/sauceNaoImage',
        ).invokeMethod<Uint8List>('prepare', path);
        if (bytes != null && bytes.isNotEmpty) return bytes;
      } on PlatformException {
        throw const FormatException('Could not decode the selected image.');
      }
      throw const FormatException('Could not decode the selected image.');
    }
    return _compressImage(await File(path).readAsBytes());
  }

  Uint8List _compressImage(Uint8List originImageBytes) {
    final originImage = img.decodeImage(originImageBytes);
    if (originImage == null) {
      throw const FormatException('Could not decode the selected image.');
    }
    final originWidth = originImage.width;
    final originHeight = originImage.height;
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
    final newImage = img.copyResize(
      originImage,
      width: newWidth,
      height: newHeight,
    );
    return img.encodeJpg(newImage, quality: 75);
  }


  @override
  Widget build(BuildContext context) {
    final glass = widget._initialPath != null;
    final height =
        MediaQuery.sizeOf(context).height *
        (glass && _phase != _SauceNaoPhase.done ? 0.52 : 0.75);
    return PopScope(
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) _cancelRequest();
      },
      child: SafeArea(
        child: SizedBox(
          height: height,
          child: Column(
            children: [
              const SizedBox(height: 8),
              if (!glass)
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ListTile(
                title: Text("SauceNAO"),
                trailing: IconButton(
                  icon: Icon(Icons.close),
                  onPressed: () {
                    _cancelRequest();
                    Navigator.of(context).pop();
                  },
                ),
              ),
              const Divider(height: 1),
              Expanded(child: _buildBody(context)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    switch (_phase) {
      case _SauceNaoPhase.idle:
        return _buildIdle(context);
      case _SauceNaoPhase.loading:
        return _buildLoading(context);
      case _SauceNaoPhase.done:
        return _buildResults(context);
      case _SauceNaoPhase.error:
        return _buildError(context);
    }
  }

  Widget _buildIdle(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.image_search,
              size: 64,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _pickAndSearch,
              icon: Icon(Icons.add_photo_alternate),
              label: Text(I18n.of(context).upload_picture),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoading(BuildContext context) {
    final strings = I18n.of(context);
    final bytes = _imageBytes;
    final progress = _progress;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (bytes != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.memory(
                  bytes,
                  width: 88,
                  height: 88,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(height: 14),
            ],
            SizedBox(
              width: 200,
              child: LinearProgressIndicator(
                value: progress == 1 ? null : progress,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              bytes == null
                  ? strings.parsing
                  : progress == 1
                  ? strings.saucenao_waiting
                  : progress == null
                  ? strings.uploading
                  : '${strings.uploading} ${(progress * 100).round()}%',
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () {
                _cancelRequest();
                Navigator.of(context).pop();
              },
              child: Text(strings.cancel),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.2,
              ),
              child: SingleChildScrollView(
                child: Text(
                  _errorMessage ?? "",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _retry,
              child: Text(I18n.of(context).retry),
            ),
            if (widget._initialPath != null)
              Builder(
                builder: (anchor) => TextButton(
                  onPressed: () => _pickAndSearch(anchor: anchor),
                  child: Text(I18n.of(context).saucenao_choose_image),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildResults(BuildContext context) {
    if (_results.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(I18n.of(context).no_result),
              const SizedBox(height: 16),
              Builder(
                builder: (anchor) => FilledButton.icon(
                  onPressed: () => _pickAndSearch(anchor: anchor),
                  icon: Icon(Icons.add_photo_alternate),
                  label: Text(I18n.of(context).upload_picture),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  I18n.of(
                    context,
                  ).tap_to_show_results(_results.length.toString()),
                ),
              ),
              Builder(
                builder: (anchor) => TextButton.icon(
                  onPressed: () => _pickAndSearch(anchor: anchor),
                  icon: Icon(Icons.add_photo_alternate),
                  label: Text(I18n.of(context).upload_picture),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            itemCount: _results.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final item = _results[index];
              return ListTile(
                leading: _PixivIllustThumbnail(illustId: item.illustId),
                title: Text(
                  item.title?.isNotEmpty == true
                      ? item.title!
                      : "Pixiv #${item.illustId}",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  [
                    if (item.similarity != null)
                      item.similarity!.contains('%')
                          ? item.similarity
                          : "${item.similarity}%",
                    if (item.author?.isNotEmpty == true) item.author,
                    "#${item.illustId}",
                  ].whereType<String>().join(" · "),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.of(context).pop(item);
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _PixivIllustThumbnail extends StatefulWidget {
  final int illustId;

  const _PixivIllustThumbnail({required this.illustId});

  @override
  State<_PixivIllustThumbnail> createState() => _PixivIllustThumbnailState();
}

class _PixivIllustThumbnailState extends State<_PixivIllustThumbnail> {
  String? _imageUrl;
  bool _loading = true;
  static bool _authBroken = false;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  @override
  void didUpdateWidget(covariant _PixivIllustThumbnail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.illustId != widget.illustId) {
      _imageUrl = null;
      _loading = true;
      _fetch();
    }
  }

  Future<void> _fetch() async {
    if (_authBroken) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    try {
      // apiClient 拦截器会自动带 Authorization: Bearer <access_token>
      final response = await apiClient.getIllustDetail(widget.illustId);
      final illust = Illusts.fromJson(response.data['illust']);
      if (!mounted) return;
      setState(() {
        _imageUrl = illust.imageUrls.squareMedium;
        _loading = false;
      });
    } catch (e) {
      final message = e.toString();
      if (message.contains('OAuth') || message.contains('invalid_request')) {
        _authBroken = true;
      }
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Widget _placeholder({bool failed = false}) {
    return Container(
      width: 56,
      height: 56,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      alignment: Alignment.center,
      child: failed
          ? Text(':(', style: Theme.of(context).textTheme.headlineMedium)
          : const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final child = _imageUrl == null
        ? _placeholder(failed: !_loading)
        : CachedNetworkImage(
            imageUrl: _imageUrl!,
            width: 56,
            height: 56,
            fit: BoxFit.cover,
            cacheManager: pixivCacheManager,
            httpHeaders: Hoster.header(url: _imageUrl),
            placeholder: (_, __) => _placeholder(),
            errorWidget: (_, __, ___) => _placeholder(failed: true),
          );
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(width: 56, height: 56, child: child),
    );
  }
}
