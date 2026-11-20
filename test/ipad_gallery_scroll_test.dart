import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pixez/component/ipad_surface.dart';
import 'package:pixez/component/card_reflection.dart';

void main() {
  testWidgets('scrolling gallery cards track the viewport without native surfaces', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final controller = ScrollController();
    await tester.pumpWidget(MaterialApp(home: ListView.builder(
      controller: controller, itemCount: 50, itemExtent: 160,
      itemBuilder: (_, i) => IPadGalleryCard(scrolling: true, key: ValueKey(i),
        child: CardReflection(style: i.isEven ? artworkReflection : artistReflection, images: const [null])))));
    final card = find.byKey(const ValueKey(2));
    final before = tester.getTopLeft(card).dy;
    controller.jumpTo(190);
    await tester.pump();
    expect(tester.getTopLeft(card).dy, before - 190);
    expect(find.byType(UiKitView), findsNothing);
    expect(find.byType(FractionallySizedBox), findsNothing);
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
    debugDefaultTargetPlatformOverride = null;
  });
}
