import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pixez/main.dart';
import 'package:pixez/page/picture/artwork_edge_back.dart';

void main() {
  testWidgets(
    'only inward edge drags exit; center swipes page and edge taps pass through',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      final edgeBack = userSetting.artworkRightEdgeBack;
      userSetting.artworkRightEdgeBack = true;
      addTearDown(() => userSetting.artworkRightEdgeBack = edgeBack);
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      var index = 0, taps = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            pageTransitionsTheme: const PageTransitionsTheme(
              builders: {TargetPlatform.iOS: ArtworkPageTransitionsBuilder()},
            ),
          ),
          home: Builder(
            builder: (context) => TextButton(
              child: const Text('open'),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => Scaffold(
                    body: ArtworkEdgeBack(
                      child: PageView(
                        onPageChanged: (value) => index = value,
                        children: List.generate(
                          3,
                          (_) => GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => taps++,
                            child: const SizedBox.expand(),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      Future<void> open() async {
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();
      }

      await open();
      final pageContext = tester.element(find.byType(PageView));
      final route = ModalRoute.of(pageContext)!;
      expect(route.popGestureEnabled, isFalse);
      final preview = await tester.startGesture(const Offset(798, 200));
      await preview.moveBy(const Offset(-120, 0));
      await tester.pump();
      expect(route.animation!.value, inExclusiveRange(0, 1));
      expect(tester.getTopLeft(find.byType(PageView)).dx, lessThan(0));
      final previousPage = find.byType(TextButton);
      final firstPosition = tester.getTopLeft(previousPage).dx;
      expect(firstPosition, greaterThan(0));
      await preview.moveBy(const Offset(-90, 0));
      await tester.pump();
      expect(tester.getTopLeft(previousPage).dx, lessThan(firstPosition));
      await preview.cancel();
      await tester.pumpAndSettle();
      expect(route.animation!.isCompleted, isTrue);
      expect(route.navigator!.userGestureInProgress, isFalse);
      await tester.tapAt(const Offset(740, 200));
      expect(taps, 1);
      await tester.dragFrom(const Offset(400, 200), const Offset(-490, 0));
      await tester.pumpAndSettle();
      expect(index, 1);
      await tester.dragFrom(const Offset(735, 200), const Offset(60, 0));
      await tester.pumpAndSettle();
      expect(find.byType(PageView), findsOneWidget);
      expect(index, 1);
      await tester.dragFrom(const Offset(760, 200), const Offset(-180, 0));
      await tester.pumpAndSettle();
      expect(find.byType(PageView), findsOneWidget);
      final lastIndex = index;
      await tester.dragFrom(const Offset(780, 200), const Offset(-180, 0));
      await tester.pumpAndSettle();
      expect(find.text('open'), findsOneWidget);
      expect(index, lastIndex);
      await open();
      userSetting.artworkRightEdgeBack = false;
      await tester.pump();
      await tester.dragFrom(const Offset(780, 200), const Offset(-180, 0));
      await tester.pumpAndSettle();
      expect(find.byType(PageView), findsOneWidget);
      await tester.dragFrom(const Offset(2, 200), const Offset(180, 0));
      await tester.pumpAndSettle();
      expect(find.text('open'), findsOneWidget);
      debugDefaultTargetPlatformOverride = null;
    },
  );
}
