import 'package:pixez/component/nsfw_artwork.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pixez/component/pixiv_image.dart';
import 'package:pixez/models/illust.dart';

class PixivImageShielded extends StatefulWidget {
  final String url;
  final List<Tags> tags;
  final Widget? placeWidget;
  final bool fade;
  final BoxFit? fit;
  final bool? enableMemoryCache;
  final double? height;
  final double? width;
  final String? host;

  PixivImageShielded(
    this.url, {
    required this.tags,
    this.placeWidget,
    this.fade = true,
    this.fit,
    this.enableMemoryCache,
    this.height,
    this.host,
    this.width,
  });

  @override
  State<PixivImageShielded> createState() => _PixivImageShieldedState();
}

class _PixivImageShieldedState extends State<PixivImageShielded> {
  @override
  Widget build(BuildContext context) => NsfwMedia(
    restricted: widget.tags.any((tag) => tag.name.startsWith('R-18')),
    identity: widget.url,
    child: PixivImage(widget.url, placeWidget: widget.placeWidget, fade: widget.fade,
      fit: widget.fit, enableMemoryCache: widget.enableMemoryCache, height: widget.height,
      width: widget.width, host: widget.host),
  );
}
