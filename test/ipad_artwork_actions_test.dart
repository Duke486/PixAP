import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pixez/component/ipad_surface.dart';
import 'package:pixez/page/comment/comment_page.dart';
import 'package:pixez/page/picture/user_follow_button.dart';
import 'package:pixez/src/generated/i18n/app_localizations.dart';

void main() {
  testWidgets('artwork actions have normal touch sizes on iPad', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1000, 800);
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      SystemChannels.platform_views,
      (_) async => null,
    );
    addTearDown(() {
      tester.view.reset();
      debugDefaultTargetPlatformOverride = null;
      messenger.setMockMethodCallHandler(SystemChannels.platform_views, null);
    });

    final follow = Completer<Null>();
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const ArtworkCommentButton(id: 42),
                UserFollowButton(
                  id: 42,
                  followed: false,
                  glass: true,
                  onPressed: () => follow.future,
                  onConfirm: (_, _) {},
                ),
                GalleryFavoriteButton(
                  heroTag: 42,
                  onPressed: () {},
                  child: const Icon(Icons.favorite_border),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final comments = find.byType(ArtworkCommentButton);
    expect(tester.getSize(comments).height, greaterThanOrEqualTo(44));
    expect(
      find.descendant(of: comments, matching: find.byType(UiKitView)),
      findsNothing,
    );
    expect(
      tester.getSize(find.byType(GalleryFavoriteButton)),
      const Size.square(56),
    );

    final followButton = find.byType(UserFollowButton);
    expect(
      find.descendant(of: followButton, matching: find.byType(UiKitView)),
      findsOneWidget,
    );
    await tester.tap(followButton);
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    follow.complete(null);
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsNothing);

    await tester.pumpWidget(const SizedBox());
    debugDefaultTargetPlatformOverride = null;
  });
}
