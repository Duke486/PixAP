import 'package:pixez/page/login/pixap_glass_logo.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pixez/component/glass_form_control.dart';
import 'package:pixez/er/leader.dart';
import 'package:pixez/page/hello/hello_page.dart';
import 'package:pixez/page/login/login_page.dart';
import 'package:pixez/src/generated/i18n/app_localizations.dart';

void main() {
  testWidgets('iOS login shows the PixAP icon and omits the bottom bar', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en', 'US'),
        theme: ThemeData(platform: TargetPlatform.iOS),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: LoginPage(),
      ),
    );

    expect(find.text('PixAP'), findsOneWidget);
    expect(find.byType(PixapGlassLogo), findsOneWidget);
    expect(find.text('Sign up'), findsOneWidget);
    expect(find.byType(GlassActionButton), findsNWidgets(2));
    expect(find.text('|'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('|')).dy,
      greaterThan(tester.getBottomLeft(find.text('Log in with Token')).dy),
    );
    expect(find.byType(BottomAppBar), findsNothing);
    expect(find.text('Log in with Token'), findsOneWidget);
    expect(
      tester
          .widgetList<GlassActionButton>(find.byType(GlassActionButton))
          .where((button) => button.prominent),
      hasLength(1),
    );
  });

  testWidgets('login from a detail navigator replaces the root route', (
    tester,
  ) async {
    final root = _PushObserver();
    final detail = _PushObserver();
    late BuildContext detailContext;
    await tester.pumpWidget(
      MaterialApp(
        navigatorObservers: [root],
        home: Navigator(
          observers: [detail],
          onGenerateRoute: (_) => MaterialPageRoute<void>(
            builder: (context) {
              detailContext = context;
              return const SizedBox();
            },
          ),
        ),
      ),
    );

    await Leader.pushUntilHome(detailContext);

    expect(detail.routes, hasLength(1));
    expect(root.routes, hasLength(2));
    final home = root.routes.last as MaterialPageRoute<dynamic>;
    expect(home.builder(detailContext), isA<HelloPage>());
    await tester.pumpWidget(const SizedBox());
  });
}

class _PushObserver extends NavigatorObserver {
  final routes = <Route<dynamic>>[];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    routes.add(route);
  }
}
