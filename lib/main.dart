import 'package:pixez/page/hello/setting/demo_mode.dart';
import 'package:pixez/page/hello/hello_page.dart' show iPadRailObserver, IPadRailLayer;
/*
 * Copyright (C) 2020. by perol_notsf, All rights reserved
 *
 * This program is free software: you can redistribute it and/or modify it under
 * the terms of the GNU General Public License as published by the Free Software
 * Foundation, either version 3 of the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful, but WITHOUT ANY
 * WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
 * FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License along with
 * this program. If not, see <http://www.gnu.org/licenses/>.
 *
 */
import 'dart:async';
import 'dart:io';
import 'package:pixez/component/ipad_surface.dart';

import 'package:bot_toast/bot_toast.dart';
import 'package:pixez/page/picture/artwork_edge_back.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/foundation.dart'
    show LicenseEntryWithLineBreaks, LicenseRegistry;
import 'package:flutter/material.dart' as legacy_material show ColorScheme;
import 'package:material_ui/material_ui.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:pixez/constants.dart';
import 'package:pixez/er/fetcher.dart';
import 'package:pixez/er/illust_cacher.dart';
import 'package:pixez/i18n.dart';
import 'package:pixez/page/novel/history/novel_history_store.dart';
import 'package:pixez/page/splash/splash_page.dart';
import 'package:pixez/page/splash/splash_store.dart';
import 'package:pixez/src/generated/i18n/app_localizations.dart';
import 'package:pixez/store/account_store.dart';
import 'package:pixez/store/book_tag_store.dart';
import 'package:pixez/store/fullscreen_store.dart';
import 'package:pixez/store/mute_store.dart';
import 'package:pixez/store/save_store.dart';
import 'package:pixez/store/tag_history_store.dart';
import 'package:pixez/store/top_store.dart';
import 'package:pixez/store/user_setting.dart';
import 'package:rhttp/rhttp.dart';

import 'package:pixez/utils/tray_manager_helper.dart';

final RouteObserver<ModalRoute<void>> routeObserver =
    RouteObserver<ModalRoute<void>>();
final UserSetting userSetting = UserSetting();
final SaveStore saveStore = SaveStore();
final MuteStore muteStore = MuteStore();
final AccountStore accountStore = AccountStore();
final TagHistoryStore tagHistoryStore = TagHistoryStore();
final NovelHistoryStore novelHistoryStore = NovelHistoryStore();
final TopStore topStore = TopStore();
final BookTagStore bookTagStore = BookTagStore();
final SplashStore splashStore = SplashStore();
final Fetcher fetcher = new Fetcher();
final FullScreenStore fullScreenStore = FullScreenStore();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (Platform.isIOS) {
    await initializeAppleDevice();
    await DemoMode.initialize();
  }
  await Rhttp.init();
  await MmapCache.init();
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks(
      [Constants.displayName],
      await rootBundle.loadString('LICENSE'),
    );
  });

  if (Platform.isMacOS) await TrayManagerHelper.instance.init();

  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  AppLifecycleState? _appState;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (Platform.isIOS) {
      setState(() {
        _appState = state;
      });
    }
  }

  @override
  void dispose() {
    TrayManagerHelper.instance.dispose();
    saveStore.dispose();
    topStore.dispose();
    fetcher.stop();
    subscription.cancel();
    if (Platform.isIOS) WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  late StreamSubscription<String> subscription;
  late final Future<void> _initialAccount;

  @override
  void initState() {
    subscription = topStore.topStream.listen((event) {
      if (event == "main") {
        setState(() {});
      }
    });
    userSetting.askInit();
    userSetting.init();
    _initialAccount = accountStore.fetch();
    bookTagStore.init();
    muteStore.init();

    super.initState();
    if (Platform.isIOS) WidgetsBinding.instance.addObserver(this);
  }

  @override
  Widget build(BuildContext context) {
    return _buildMaterial(context);
  }

  Widget _buildMaterial(BuildContext context) {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarDividerColor: Colors.transparent,
        systemNavigationBarContrastEnforced: false,
        statusBarColor: Colors.transparent,
      ),
    );
    final botToastBuilder = BotToastInit();
    return DynamicColorBuilder(
      builder:
          (
            legacy_material.ColorScheme? lightDynamic,
            legacy_material.ColorScheme? darkDynamic,
          ) {
            return Observer(
              builder: (context) {
                ColorScheme lightColorScheme;
                ColorScheme darkColorScheme;
                if (userSetting.useDynamicColor &&
                    lightDynamic != null &&
                    darkDynamic != null) {
                  lightColorScheme = _colorSchemeFromLegacy(
                    lightDynamic.harmonized(),
                  );
                  darkColorScheme = _colorSchemeFromLegacy(
                    darkDynamic.harmonized(),
                  );
                } else {
                  Color primary = userSetting.seedColor;
                  lightColorScheme = ColorScheme.fromSeed(seedColor: primary);
                  darkColorScheme = ColorScheme.fromSeed(
                    seedColor: primary,
                    brightness: Brightness.dark,
                  );
                }
                final brightness = SchedulerBinding
                    .instance
                    .platformDispatcher
                    .platformBrightness;
                if (userSetting.themeInitState != 1) {
                  return Container(
                    color: brightness == Brightness.dark
                        ? Colors.black
                        : Colors.white,
                    child: Center(
                      child: Material(child: CircularProgressIndicator()),
                    ),
                  );
                }
                return MaterialApp(
                  debugShowCheckedModeBanner: false,
                  navigatorObservers: [
                    BotToastNavigatorObserver(),
                    routeObserver,
                    iPadRailObserver,
                  ],
                  locale: userSetting.locale,
                  home: Builder(
                    builder: (context) {
                      return AnnotatedRegion<SystemUiOverlayStyle>(
                        value: SystemUiOverlayStyle(
                          systemNavigationBarColor: Colors.transparent,
                          systemNavigationBarDividerColor: Colors.transparent,
                          systemNavigationBarContrastEnforced: false,
                          statusBarColor: Colors.transparent,
                        ),
                        child: SplashPage(accountReady: _initialAccount),
                      );
                    },
                  ),
                  title: Constants.displayName,
                  builder: (context, child) {
                    if (Platform.isIOS && (isIPhone || MediaQuery.sizeOf(context).shortestSide >= 600)) {
                      final theme = Theme.of(context);
                      final dark = theme.brightness == Brightness.dark;
                      final scheme = ColorScheme.fromSeed(
                        seedColor: Colors.grey, brightness: theme.brightness,
                        dynamicSchemeVariant: DynamicSchemeVariant.monochrome,
                      ).copyWith(primary: theme.colorScheme.primary, onPrimary: theme.colorScheme.onPrimary,
                        primaryContainer: theme.colorScheme.primaryContainer, onPrimaryContainer: theme.colorScheme.onPrimaryContainer,
                        surface: dark ? Colors.black : Colors.white, surfaceTint: Colors.transparent);
                      child = Theme(data: theme.copyWith(colorScheme: scheme,
                        appBarTheme: isIPhone ? theme.appBarTheme.copyWith(
                          centerTitle: true, elevation: 0, scrolledUnderElevation: 0,
                          actionsPadding: const EdgeInsetsDirectional.only(end: 8),
                          backgroundColor: scheme.surface, foregroundColor: scheme.onSurface,
                        ) : theme.appBarTheme,
                        primaryColor: scheme.primary, scaffoldBackgroundColor: scheme.surface,
                        canvasColor: scheme.surface, cardColor: scheme.surface,
                        chipTheme: theme.chipTheme.copyWith(backgroundColor: scheme.surfaceContainerLow),
                        dialogTheme: theme.dialogTheme.copyWith(backgroundColor: scheme.surface),
                      ), child: isIPhone ? (child ?? const SizedBox.shrink()) : IPadRailLayer(child: child ?? const SizedBox.shrink()));
                    }
                    if (Platform.isIOS) child = _buildMaskBuilder(context, child);
                    I18n.context = context;
                    return botToastBuilder(context, child);
                  },
                  themeMode: userSetting.themeMode,
                  theme: ThemeData(
                    brightness: Brightness.light,
                    useMaterial3: true,
                    pageTransitionsTheme: const PageTransitionsTheme(
                      builders: {
                        TargetPlatform.iOS: ArtworkPageTransitionsBuilder(),
                      },
                    ),
                    primaryColor: lightColorScheme.primary,
                    colorScheme: lightColorScheme,
                    scaffoldBackgroundColor: lightColorScheme.surface,
                    cardColor: lightColorScheme.surfaceContainer,
                    chipTheme: ChipThemeData(
                      backgroundColor: lightColorScheme.surface,
                    ),
                    canvasColor: lightColorScheme.surfaceContainer,
                    dialogTheme: DialogThemeData(
                      backgroundColor: lightColorScheme.surfaceContainer,
                    ),
                  ),
                  darkTheme: ThemeData(
                    brightness: Brightness.dark,
                    useMaterial3: true,
                    pageTransitionsTheme: const PageTransitionsTheme(
                      builders: {
                        TargetPlatform.iOS: ArtworkPageTransitionsBuilder(),
                      },
                    ),
                    scaffoldBackgroundColor: userSetting.isAMOLED
                        ? Colors.black
                        : null,
                    // tabBarTheme: TabBarTheme(dividerColor: Colors.transparent),
                    tabBarTheme: TabBarThemeData(
                      dividerColor: Colors.transparent,
                    ),
                    colorScheme: darkColorScheme,
                  ),
                  localizationsDelegates: [
                    AppLocalizations.delegate,
                    ...GlobalMaterialLocalizations.delegates,
                  ],
                  supportedLocales: AppLocalizations.supportedLocales,
                );
              },
            );
          },
    );
  }

  Widget? _buildMaskBuilder(BuildContext context, Widget? widget) {
    if (!userSetting.nsfwMask) return widget;
    final needShowMask = _appState == AppLifecycleState.inactive;
    return Stack(
      children: [
        widget ?? const SizedBox.shrink(),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 500),
          child: needShowMask
              ? Container(
                  key: const ValueKey('recent_screen_mask'),
                  color: Theme.of(context).canvasColor,
                  child: const Center(child: Icon(Icons.privacy_tip_outlined)),
                )
              : const SizedBox.shrink(key: ValueKey('recent_screen_unmask')),
        ),
      ],
    );
  }
}

ColorScheme _colorSchemeFromLegacy(legacy_material.ColorScheme scheme) {
  return ColorScheme.fromSeed(
    seedColor: scheme.primary,
    brightness: scheme.brightness,
    primary: scheme.primary,
    onPrimary: scheme.onPrimary,
    primaryContainer: scheme.primaryContainer,
    onPrimaryContainer: scheme.onPrimaryContainer,
    secondary: scheme.secondary,
    onSecondary: scheme.onSecondary,
    secondaryContainer: scheme.secondaryContainer,
    onSecondaryContainer: scheme.onSecondaryContainer,
    tertiary: scheme.tertiary,
    onTertiary: scheme.onTertiary,
    tertiaryContainer: scheme.tertiaryContainer,
    onTertiaryContainer: scheme.onTertiaryContainer,
    error: scheme.error,
    onError: scheme.onError,
    errorContainer: scheme.errorContainer,
    onErrorContainer: scheme.onErrorContainer,
    surface: scheme.surface,
    onSurface: scheme.onSurface,
    surfaceContainerLowest: scheme.surfaceContainerLowest,
    surfaceContainerLow: scheme.surfaceContainerLow,
    surfaceContainer: scheme.surfaceContainer,
    surfaceContainerHigh: scheme.surfaceContainerHigh,
    surfaceContainerHighest: scheme.surfaceContainerHighest,
    onSurfaceVariant: scheme.onSurfaceVariant,
    outline: scheme.outline,
    outlineVariant: scheme.outlineVariant,
    shadow: scheme.shadow,
    scrim: scheme.scrim,
    inverseSurface: scheme.inverseSurface,
    onInverseSurface: scheme.onInverseSurface,
    inversePrimary: scheme.inversePrimary,
    surfaceTint: scheme.surfaceTint,
  );
}
