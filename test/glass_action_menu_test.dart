import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pixez/component/glass_form_control.dart';

void main() {
  testWidgets('profile action menu builds with no selected item and forwards selection', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform_views, (_) async => null);
    addTearDown(() {
      messenger.setMockMethodCallHandler(SystemChannels.platform_views, null);
      debugDefaultTargetPlatformOverride = null;
    });
    int? selected;
    await tester.pumpWidget(MaterialApp(home: Builder(builder: (context) =>
      Center(child: glassPopup(context, PopupMenuButton<int>(
        itemBuilder: (_) => [const PopupMenuItem(value: 7, child: Text('Copy'))],
        onSelected: (value) => selected = value,
      ), 'ellipsis')))));
    final menu = tester.widget<GlassFormControl>(find.byType(GlassFormControl));
    expect(menu.parameters['index'], -1);
    menu.onChange(0);
    expect(selected, 7);
    expect(tester.takeException(), isNull);
    debugDefaultTargetPlatformOverride = null;
  });
}
