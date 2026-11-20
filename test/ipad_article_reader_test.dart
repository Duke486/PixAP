import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pixez/page/soup/article_reader.dart';

class _DelayedImage extends ImageProvider<_DelayedImage> {
  final frame = Completer<ImageInfo>();
  @override
  Future<_DelayedImage> obtainKey(ImageConfiguration configuration) => SynchronousFuture(this);
  @override
  ImageStreamCompleter loadImage(_DelayedImage key, ImageDecoderCallback decode) =>
      OneFrameImageStreamCompleter(frame.future);
}

void main() {
  testWidgets('a pending artwork occupies no height during a fling, then expands on its first frame', (tester) async {
    final provider = _DelayedImage();
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: ArticleReader(
      toolbar: const Text('Article'), cover: const SizedBox.shrink(), itemCount: 100,
      itemBuilder: (_, index) => Column(children: [
        SizedBox(height: 64, child: Text('Author $index')),
        ArticleImage(image: provider, retryLabel: 'Retry'),
      ]),
    ))));
    expect(tester.getSize(find.byType(ArticleImage).first).height, 0);
    await tester.fling(find.byType(CustomScrollView), const Offset(0,-350), 2600);
    await tester.pump(const Duration(milliseconds: 24));
    final position = tester.state<ScrollableState>(find.byType(Scrollable)).position;
    expect(position.isScrollingNotifier.value, isTrue);
    expect(tester.getSize(find.byType(ArticleImage).first).height, 0);
    provider.frame.complete(ImageInfo(image: (await tester.runAsync(() => createTestImage(width: 120, height: 80)))!));
    await tester.pump();
    expect(tester.getSize(find.byType(ArticleImage).first).height, 0);
    await tester.pumpAndSettle();
    expect(position.pixels, greaterThan(350));
    final size = tester.getSize(find.byType(ArticleImage).first);
    expect(size.width, tester.getSize(find.byType(CustomScrollView)).width);
    expect(size.height, closeTo(size.width * 80 / 120, .01));
    expect(tester.takeException(), isNull);
  });
  testWidgets('the cover can start under the pinned toolbar', (tester) async {
    const toolbarKey = ValueKey('toolbar');
    const coverKey = ValueKey('cover');
    const cardKey = ValueKey('card');
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ArticleReader(
          toolbar: const SizedBox(key: toolbarKey, height: kToolbarHeight),
          cover: const SizedBox(key: coverKey, height: 188),
          coverOverlap: 28,
          itemCount: 1,
          itemBuilder: (_, _) => const SizedBox(key: cardKey, height: 200),
        ),
      ),
    ));

    final toolbar = tester.getRect(find.byKey(toolbarKey));
    final cover = tester.getRect(find.byKey(coverKey));
    expect(toolbar.bottom - cover.top, 28);
    expect(cover.bottom - toolbar.bottom, 160);
    expect(tester.getTopLeft(find.byKey(cardKey)).dy, cover.bottom);
  });

  testWidgets('content occupies viewport; both cover and card scroll under fixed toolbar', (tester) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: Center(child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 720), child: ArticleReader(
        toolbar: const SizedBox(height: 60, child: Text('toolbar')),
        cover: const SizedBox(height: 160, width: double.infinity, child: Text('cover')),
        itemCount: 20, itemBuilder: (_, i) => SizedBox(height: 200, child: Text('card $i')),
      ))))));
    final scroll = tester.state<ScrollableState>(find.byType(Scrollable)).position;
    expect(scroll.viewportDimension, greaterThan(400));
    final anchor = tester.getCenter(find.text('toolbar'));
    await tester.dragFrom(tester.getTopLeft(find.text('cover')) + const Offset(30,100), const Offset(0,-120));
    await tester.pumpAndSettle();
    final first = scroll.pixels;
    expect(first, greaterThan(0));
    await tester.dragFrom(const Offset(400,440), const Offset(0,-250));
    await tester.pumpAndSettle();
    expect(scroll.pixels, greaterThan(first));
    expect(tester.getCenter(find.text('toolbar')), anchor);
  });
}
