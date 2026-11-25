import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pixez/component/nsfw_artwork.dart';
import 'package:pixez/main.dart';
import 'package:pixez/store/user_setting.dart';

void main() {
  testWidgets('first tap on a masked preview opens its artwork', (
    tester,
  ) async {
    userSetting.nsfwDisplayMode = NsfwDisplayMode.mask;
    addTearDown(() => userSetting.nsfwDisplayMode = NsfwDisplayMode.show);
    var opens = 0;
    Widget preview(String id, {bool loaded = true}) => Directionality(
      textDirection: TextDirection.ltr,
      child: NsfwMedia.preview(
        identity: id,
        restricted: true,
        buildPreview: (mask) {
          final image = GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => opens++,
            child: const SizedBox.expand(),
          );
          return loaded ? mask?.call(image) ?? image : const SizedBox.expand();
        },
      ),
    );
    await tester.pumpWidget(preview('a', loaded: false));
    expect(find.byType(ImageFiltered), findsNothing);
    await tester.pumpWidget(preview('a'));
    expect(find.byType(ImageFiltered), findsOneWidget);
    await tester.tapAt(const Offset(50, 60));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();
    expect(opens, 1);
    await tester.tapAt(const Offset(50, 60));
    expect(opens, 2);
    await tester.pumpWidget(preview('b'));
    await tester.tapAt(const Offset(50, 60));
    expect(opens, 3);
    await tester.pumpWidget(
      const NsfwMedia(
        identity: 'b',
        restricted: true,
        child: SizedBox.expand(),
      ),
    );
    expect(find.byType(ImageFiltered), findsNothing);
  });
}
