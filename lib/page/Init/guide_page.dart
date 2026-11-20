import 'dart:ui' show ImageFilter;

import 'package:animations/animations.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:material_ui/material_ui.dart';
import 'package:pixez/component/ipad_surface.dart';
import 'package:pixez/er/leader.dart';
import 'package:pixez/er/prefer.dart';
import 'package:pixez/i18n.dart';
import 'package:pixez/main.dart';
import 'package:pixez/page/Init/init_page.dart';
import 'package:pixez/page/network/network_page.dart';

class GuidePage extends StatefulWidget {
  @override
  State<GuidePage> createState() => _GuidePageState();
}

class _GuidePageState extends State<GuidePage> {
  bool _showNetwork = false;
  bool _busy = false;

  Future<void> _advance() async {
    setState(() => _busy = true);
    try {
      if (_showNetwork) {
        await Prefer.setBool('guide_enable', false);
        if (mounted) Leader.pushUntilHome(context);
      } else {
        await userSetting.setLanguageNum(userSetting.languageNum);
        if (mounted) setState(() => _showNetwork = true);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final strings = I18n.of(context);
    final isIOS = defaultTargetPlatform == TargetPlatform.iOS;
    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          color: isIOS ? colors.surface : null,
          gradient: isIOS
              ? null
              : RadialGradient(
                  center: const Alignment(-.65, -.8),
                  radius: 1.4,
                  colors: [
                    colors.primaryContainer,
                    colors.surface,
                    colors.tertiaryContainer,
                  ],
                  stops: const [0, .6, 1],
                ),
        ),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 540,
                  maxHeight: 660,
                ),
                child: _glassPanel(
                  context,
                  Material(
                    type: MaterialType.transparency,
                    child: Column(
                      children: [
                        Expanded(
                          child: PageTransitionSwitcher(
                            duration: const Duration(milliseconds: 300),
                            reverse: !_showNetwork,
                            transitionBuilder:
                                (child, animation, secondaryAnimation) {
                                  return SharedAxisTransition(
                                    animation: animation,
                                    secondaryAnimation: secondaryAnimation,
                                    transitionType:
                                        SharedAxisTransitionType.horizontal,
                                    fillColor: Colors.transparent,
                                    child: child,
                                  );
                                },
                            child: _showNetwork
                                ? CardTheme(
                                    data: theme.cardTheme.copyWith(
                                      color: colors.surfaceContainerHighest
                                          .withValues(alpha: .40),
                                      elevation: 0,
                                    ),
                                    child: const NetworkPage(embedded: true),
                                  )
                                : const InitPage(),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              if (_showNetwork) ...[
                                OutlinedButton(
                                  onPressed: _busy
                                      ? null
                                      : () => setState(
                                          () => _showNetwork = false,
                                        ),
                                  child: Text(
                                    MaterialLocalizations.of(
                                      context,
                                    ).backButtonTooltip,
                                  ),
                                ),
                                const Spacer(),
                              ],
                              FilledButton.tonalIcon(
                                onPressed: _busy ? null : _advance,
                                icon: Icon(
                                  _showNetwork
                                      ? Icons.check_rounded
                                      : Icons.arrow_forward_rounded,
                                ),
                                label: Text(
                                  _showNetwork
                                      ? strings.complete
                                      : strings.next,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _glassPanel(BuildContext context, Widget child) {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return IPadSurface(
        includeIPhone: true,
        darkGlass: Theme.of(context).brightness == Brightness.dark,
        child: child,
      );
    }
    final colors = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(24);
    return ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: radius,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                colors.surface.withValues(alpha: .76),
                colors.surfaceContainerHigh.withValues(alpha: .42),
              ],
            ),
            border: Border.all(color: colors.onSurface.withValues(alpha: .12)),
          ),
          child: child,
        ),
      ),
    );
  }
}
