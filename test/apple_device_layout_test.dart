import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pixez/component/ipad_surface.dart';

void main() {
  testWidgets('phone controls stay separate from iPad window layout', (
    tester,
  ) async {
    const channel = MethodChannel('pixez/device');
    var phone = false;
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (_) async => phone);
    addTearDown(() async {
      phone = false;
      await initializeAppleDevice();
      messenger.setMockMethodCallHandler(channel, null);
    });
    for (final device in [false, true]) {
      phone = device;
      await initializeAppleDevice();
      for (final size in [
        const Size(375, 812),
        const Size(812, 375),
        if (!device) const Size(1024, 768),
      ]) {
        await tester.pumpWidget(
          MediaQuery(
            data: MediaQueryData(size: size),
            child: Builder(
              builder: (context) {
                expect(usesIPadLayout(context), size.shortestSide >= 600);
                expect(
                  usesAppleControls(context),
                  device || size.shortestSide >= 600,
                );
                return const SizedBox();
              },
            ),
          ),
        );
      }
    }
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
}
