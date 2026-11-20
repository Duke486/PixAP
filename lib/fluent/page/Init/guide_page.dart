import 'package:animations/animations.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:pixez/er/leader.dart';
import 'package:pixez/er/prefer.dart';
import 'package:pixez/main.dart';
import 'package:pixez/i18n.dart';
import 'package:pixez/fluent/page/Init/init_page.dart';
import 'package:pixez/fluent/page/network/network_page.dart';

class GuidePage extends StatefulWidget {
  @override
  _GuidePageState createState() => _GuidePageState();
}

class _GuidePageState extends State<GuidePage> {
  late List<Widget> _pageList;
  int index = 0;
  bool isNext = true;

  @override
  void initState() {
    _pageList = [InitPage(), const NetworkPage(embedded: true)];
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final strings = I18n.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.topLeft,
          radius: 1.6,
          colors: [
            theme.accentColor.withValues(alpha: .28),
            theme.scaffoldBackgroundColor,
          ],
        ),
      ),
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 540, maxHeight: 660),
              child: Acrylic(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                  side: BorderSide(
                    color: theme.accentColor.withValues(alpha: .2),
                  ),
                ),
                child: Column(
                  children: [
                    Expanded(
                      child: PageTransitionSwitcher(
                        duration: const Duration(milliseconds: 300),
                        reverse: !isNext,
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
                        child: _pageList[index],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (index == 1) ...[
                            Button(
                              onPressed: () => setState(() {
                                index = 0;
                                isNext = false;
                              }),
                              child: Text(
                                FluentLocalizations.of(
                                  context,
                                ).backButtonTooltip,
                              ),
                            ),
                            const Spacer(),
                          ],
                          FilledButton(
                            onPressed: () async {
                              if (index == 0) {
                                await userSetting.setLanguageNum(
                                  userSetting.languageNum,
                                );
                                if (mounted)
                                  setState(() {
                                    index = 1;
                                    isNext = true;
                                  });
                              } else {
                                await Prefer.setBool('guide_enable', false);
                                if (mounted) Leader.pushUntilHome(context);
                              }
                            },
                            child: Text(
                              index == 0 ? strings.next : strings.complete,
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
    );
  }
}
