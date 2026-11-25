import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pixez/component/home_aurora.dart';

void main() {
  testWidgets(
    'aurora only advances on a visible, active page with motion enabled',
    (tester) async {
      final navigator = GlobalKey<NavigatorState>();
      final reduceMotion = ValueNotifier<bool>(false);
      addTearDown(reduceMotion.dispose);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigator,
          home: ValueListenableBuilder<bool>(
            valueListenable: reduceMotion,
            builder: (context, reduce, _) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: reduce),
              child: const HomeAurora(),
            ),
          ),
        ),
      );
      final paint = find.descendant(
        of: find.byType(HomeAurora),
        matching: find.byType(CustomPaint),
      );
      var ticks = 0;
      tester.widget<CustomPaint>(paint).painter!.addListener(() => ticks++);

      Future<void> checkMotion(bool running) async {
        final before = ticks;
        await tester.pump(const Duration(seconds: 1));
        expect(ticks, running ? greaterThan(before) : equals(before));
      }

      await checkMotion(true);
      reduceMotion.value = true;
      await tester.pump();
      await checkMotion(false);
      reduceMotion.value = false;
      await tester.pump();
      await checkMotion(true);

      navigator.currentState!.push(
        MaterialPageRoute<void>(builder: (_) => const Scaffold()),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await checkMotion(false);
      navigator.currentState!.pop();
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await checkMotion(true);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await checkMotion(false);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await checkMotion(true);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
