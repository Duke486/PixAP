import 'package:dio/dio.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_cache_manager_dio/flutter_cache_manager_dio.dart'
    show DioHttpFileService;

class DioCacheManager extends CacheManager {
  static late final DioCacheManager instance;
  static void initialize(Dio client) => instance = DioCacheManager._(client);
  DioCacheManager._(Dio client)
    : super(Config('dioCache', fileService: _ImageFileService(client)));
}

class _ImageFileService extends DioHttpFileService {
  _ImageFileService(super.client);
  @override
  Future<FileServiceResponse> get(
    String url, {
    Map<String, String>? headers,
  }) async => ImageFileResponse(await super.get(url, headers: headers));
}

class ImageFileResponse implements FileServiceResponse {
  ImageFileResponse(this.source);
  final FileServiceResponse source;
  @override
  int? get contentLength {
    final size = source.contentLength;
    return size != null && size >= 0 ? size : null;
  }

  @override
  Stream<List<int>> get content => source.content;
  @override
  int get statusCode => source.statusCode;
  @override
  DateTime get validTill => source.validTill;
  @override
  String? get eTag => source.eTag;
  @override
  String get fileExtension => source.fileExtension;
}
