import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pixez/component/ipad_surface.dart';

void main() {
  testWidgets('iPad tab taps and page swipes update the same controller', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 900);
    addTearDown(tester.view.reset);
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform_views, (_) async => null);
    addTearDown(() => messenger.setMockMethodCallHandler(SystemChannels.platform_views, null));
    int? tapped;
    await tester.pumpWidget(MaterialApp(home: DefaultTabController(length: 3,
      child: Scaffold(body: Column(children: [
        IPadPageTabs(tabs: TabBar(onTap: (i) => tapped = i,
          tabs: const [Tab(text: 'One'), Tab(text: 'Two'), Tab(text: 'Three')])),
        const Expanded(child: TabBarView(children: [Text('A'), Text('B'), Text('C')])),
      ])))));
    final native = tester.widget<NativeGlassControl>(find.byType(NativeGlassControl));
    expect(native.labels, ['One', 'Two', 'Three']);
    native.onSelect(2);
    await tester.pumpAndSettle();
    final controller = DefaultTabController.of(tester.element(find.byType(TabBarView)));
    expect(tapped, 2);
    expect(controller.index, 2);
    await tester.drag(find.byType(TabBarView), const Offset(850, 0));
    await tester.pumpAndSettle();
    expect(controller.index, 1);
    expect(tester.widget<NativeGlassControl>(find.byType(NativeGlassControl)).index, 1);
    await tester.pumpWidget(const SizedBox());
    debugDefaultTargetPlatformOverride = null;
  });
}
