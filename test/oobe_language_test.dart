import 'package:dio/dio.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pixez/main.dart';
import 'package:pixez/network/api_client.dart';
import 'package:pixez/page/Init/guide_page.dart';
import 'package:pixez/page/network/network_page.dart';
import 'package:pixez/src/generated/i18n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('OOBE starts in simplified Chinese and applies a new language', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    userSetting.prefs = await SharedPreferences.getInstance();
    apiClient.httpClient = Dio();
    final guide = GuidePage();
    await tester.pumpWidget(
      Observer(
        builder: (_) => MaterialApp(
          locale: userSetting.locale,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: guide,
        ),
      ),
    );

    final chinese = find.widgetWithText(ListTile, '简体中文');
    expect(tester.widget<ListTile>(chinese).selected, isTrue);
    expect(find.byType(ListTile), findsNWidgets(5));
    for (final name in ['繁體中文', 'English', '日本語', '한국어']) {
      expect(find.widgetWithText(ListTile, name), findsOneWidget);
    }

    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();
    expect(userSetting.prefs.getInt('language_num'), 0);
    expect(ApiClient.Accept_Language, 'en-US');

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.byType(NetworkPage), findsOneWidget);
    expect(find.text('Complete'), findsOneWidget);
  });
}
