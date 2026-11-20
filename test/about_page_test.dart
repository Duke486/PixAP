import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pixez/constants.dart';
import 'package:pixez/page/about/about_page.dart';
import 'package:pixez/page/about/contributors.dart';
import 'package:pixez/src/generated/i18n/app_localizations.dart';

void main() {
  testWidgets('About links to upstream and shares only the app name', (
    tester,
  ) async {
    const launcher = MethodChannel('plugins.flutter.io/url_launcher');
    const share = MethodChannel('dev.fluttercommunity.plus/share');
    final messenger = tester.binding.defaultBinaryMessenger;
    MethodCall? launchCall;
    MethodCall? shareCall;
    messenger.setMockMethodCallHandler(launcher, (call) async {
      launchCall = call;
      return true;
    });
    messenger.setMockMethodCallHandler(share, (call) async {
      shareCall = call;
      return null;
    });
    addTearDown(() {
      messenger.setMockMethodCallHandler(launcher, null);
      messenger.setMockMethodCallHandler(share, null);
    });

    await tester.pumpWidget(
      const MaterialApp(
        locale: Locale('zh', 'CN'),
        localizationsDelegates: [
          AppLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: AboutContent(newVersion: false)),
      ),
    );

    await tester.tap(find.text('原项目地址'));
    await tester.pumpAndSettle();
    expect(
      launchCall?.arguments['url'],
      'https://github.com/Notsfsssf/pixez-flutter',
    );

    await tester.tap(find.byIcon(Icons.share_outlined));
    await tester.pumpAndSettle();
    expect(shareCall?.arguments['text'], Constants.displayName);
    if (Constants.hasAppleBranding) {
      expect(shareCall?.arguments['text'], 'PixAP');
      expect(find.text('PixAP'), findsOneWidget);
      expect(find.text('果味的PixEz'), findsOneWidget);
    }
    expect(shareCall?.arguments['uri'], isNull);
    expect(find.text('GNU GPL v3'), findsOneWidget);

    final sizes = <Size>{};
    for (final name in [
      'Perol_Notsfsssf',
      'Right now',
      'Skimige',
      ...originalContributors.map((contributor) => contributor.name),
    ]) {
      final card = find.widgetWithText(Card, name);
      expect(card, findsOneWidget);
      expect(
        find.descendant(of: card, matching: find.byType(CircleAvatar)),
        findsOneWidget,
      );
      sizes.add(tester.getSize(card));
    }
    expect(sizes, hasLength(1));
    expect(sizes.single.height, lessThan(90));
    for (final contributor in originalContributors) {
      final card = find.widgetWithText(Card, contributor.name);
      expect(
        find.descendant(of: card, matching: find.text(contributor.detail)),
        findsOneWidget,
      );
    }
  });
}
