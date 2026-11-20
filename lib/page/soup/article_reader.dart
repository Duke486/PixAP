import 'package:material_ui/material_ui.dart';

/// The scroll viewport paints first so the pinned toolbar can sample its content.
class ArticleReader extends StatelessWidget {
  const ArticleReader({super.key, required this.toolbar, required this.cover,
    required this.itemCount, required this.itemBuilder, this.status, this.coverOverlap = 0});
  final Widget toolbar, cover;
  final Widget? status;
  final double coverOverlap;
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;

  @override
  Widget build(BuildContext context) => Stack(fit: StackFit.expand, children: [
    CustomScrollView(slivers: [
      SliverToBoxAdapter(
        child: SizedBox(
          height: MediaQuery.paddingOf(context).top + kToolbarHeight - coverOverlap,
        ),
      ),
      SliverToBoxAdapter(child: cover),
      if (status != null) SliverToBoxAdapter(child: status!)
      else SliverList(delegate: SliverChildBuilderDelegate(itemBuilder, childCount: itemCount)),
      SliverToBoxAdapter(child: SizedBox(height: MediaQuery.paddingOf(context).bottom + 12)),
    ]),
    Positioned(top: 0, left: 0, right: 0, child: toolbar),
  ]);
}

/// Author details stay in the list while the artwork stream awaits its first frame.
class ArticleImage extends StatefulWidget {
  const ArticleImage({super.key, required this.image, required this.retryLabel});
  final ImageProvider image;
  final String retryLabel;

  @override
  State<ArticleImage> createState() => _ArticleImageState();
}

class _ArticleImageState extends State<ArticleImage> {
  int attempt = 0;
  bool revealed = false;

  @override
  void didUpdateWidget(ArticleImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.image != widget.image) revealed = false;
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, box) {
    final width = (box.maxWidth * MediaQuery.devicePixelRatioOf(context)).ceil();
    return Image(
      key: ValueKey((widget.image, attempt)),
      image: ResizeImage(widget.image, width: width.clamp(1, 2048), height: 3072, policy: ResizeImagePolicy.fit),
      width: box.maxWidth,
      fit: BoxFit.fitWidth,
      frameBuilder: (imageContext, child, frame, synchronous) {
        if (frame == null) return const SizedBox.shrink();
        final moving = Scrollable.maybeOf(imageContext)?.position.isScrollingNotifier;
        if (revealed || synchronous || moving == null || !moving.value) {
          revealed = true;
          return child;
        }
        // Keep the sliver geometry stable when the first frame arrives mid-fling.
        return ValueListenableBuilder<bool>(valueListenable: moving, child: child,
          builder: (_, scrolling, picture) {
            if (!scrolling) revealed = true;
            return revealed ? picture! : const SizedBox.shrink();
          });
      },
      errorBuilder: (_, _, _) => TextButton(onPressed: () => setState(() => attempt++), child: Text(widget.retryLabel)),
    );
  });
}
