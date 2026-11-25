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

import 'package:pixez/component/ipad_surface.dart';
import 'dart:io';
import 'package:flutter/services.dart';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:pixez/component/new_version_chip.dart';
import 'package:pixez/component/painter_avatar.dart';
import 'package:pixez/constants.dart';
import 'package:pixez/er/leader.dart';
import 'package:pixez/er/updater.dart';
import 'package:pixez/i18n.dart';
import 'package:pixez/main.dart';
import 'package:pixez/models/account.dart';
import 'package:pixez/models/board_info.dart';
import 'package:pixez/models/glance_illust_persist.dart';
import 'package:pixez/page/about/about_page.dart';
import 'package:pixez/page/account/edit/account_edit_page.dart';
import 'package:pixez/page/account/select/account_select_page.dart';
import 'package:pixez/page/board/board_page.dart';
import 'package:pixez/page/book/tag/book_tag_page.dart';
import 'package:pixez/page/hello/recom/recom_manga_page.dart';
import 'package:pixez/page/hello/setting/data_export_page.dart';
import 'package:pixez/page/hello/setting/setting_quality_page.dart';
import 'package:pixez/page/history/history_page.dart';
import 'package:pixez/page/login/login_page.dart';
import 'package:pixez/page/novel/history/novel_history_page.dart';
import 'package:pixez/page/novel/novel_rail.dart';
import 'package:pixez/page/shield/shield_page.dart';
import 'package:pixez/page/task/job_page.dart';
import 'package:pixez/page/theme/theme_page.dart';

class SettingPage extends StatefulWidget {
  const SettingPage({Key? key, this.transparentMenu = false}) : super(key: key);

  final bool transparentMenu;

  @override
  SettingPageState createState() => SettingPageState();
}

class SettingPageState extends State<SettingPage> {
  @override
  void initState() {
    super.initState();
    initMethod();
    fetchBoard();
  }

  bool hideEmail = true;

  bool get _effectiveHasNewVersion =>
      Updater.result == Result.yes &&
      Updater.latestVersion != userSetting.ignoreUpdateVersion;

  initMethod() async {
    if (!Platform.isMacOS) return;
    if (Updater.result != Result.timeout) return;
    await Updater.check();
    if (mounted) setState(() {});
  }

  final _detail = GlobalKey<NavigatorState>();

  bool _authenticatingHistory = false;

  void showPreferences() {
    _detail.currentState?.popUntil((route) => route.isFirst);
  }

  Future<void> _openHistory(BuildContext context) async {
    if (_authenticatingHistory) return;
    if (Platform.isIOS) {
      _authenticatingHistory = true;
      bool authenticated = false;
      try {
        authenticated = await const MethodChannel('pixez/historyPrivacy')
            .invokeMethod<bool>('authenticate', I18n.of(context).history_record) ?? false;
      } on PlatformException {
        // Fail closed if Face ID is unavailable or the system rejects the prompt.
      } on MissingPluginException {
        // The platform must provide authentication before the history opens.
      } finally {
        _authenticatingHistory = false;
      }
      if (!context.mounted) return;
      if (!authenticated) return;
    }
    if (!context.mounted || ModalRoute.of(context)?.isCurrent != true) return;
    Navigator.of(_destination(context)).push(MaterialPageRoute(
      builder: (_) => Constants.type == 0 ? const HistoryPage() : NovelHistory(),
    ));
  }

  BuildContext _destination(BuildContext fallback) => _detail.currentState?.overlay?.context ?? fallback;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      if (!usesIPadLayout(context) || box.maxWidth < 760) return _menu(context);
      return Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SizedBox(width: (box.maxWidth * .30).clamp(250.0, 350.0).toDouble(), child: _menu(context)),
        const VerticalDivider(width: 1),
        Expanded(child: Navigator(
          key: _detail,
          onGenerateInitialRoutes: (_, _) => [
            MaterialPageRoute<void>(builder: (_) => SettingQualityPage()),
          ],
        )),
      ]);
    });
  }

  Widget _menu(BuildContext context) {
    return Scaffold(
      backgroundColor: widget.transparentMenu ? Colors.transparent : null,
      body: SafeArea(
        bottom: !isIPhone,
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.fromLTRB(8, 8, 8, 8 + (isIPhone ? MediaQuery.paddingOf(context).bottom : 0)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Observer(builder: (context) {
                  if (accountStore.now != null)
                    return SingleChildScrollView(
                      child: Column(
                        children: <Widget>[
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: InkWell(
                              onTap: () {
                                Navigator.of(context, rootNavigator: true)
                                    .push(MaterialPageRoute(builder: (_) {
                                  return AccountSelectPage();
                                }));
                              },
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  PainterAvatar(
                                    url: accountStore.now!.userImage,
                                    id: int.parse(accountStore.now!.userId),
                                  ),
                                  Expanded(child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8.0),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.max,
                                      mainAxisAlignment:
                                          MainAxisAlignment.start,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Padding(
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 8.0),
                                          child: Text(accountStore.now!.name,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .titleMedium),
                                        ),
                                        if (accountStore
                                            .now!.mailAddress.isNotEmpty)
                                          Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.center,
                                            children: [
                                              Flexible(child: Text(
                                                hideEmail
                                                    ? accountStore.now!
                                                        .hiddenEmail()
                                                    : accountStore
                                                        .now!.mailAddress,
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .bodySmall, overflow: TextOverflow.ellipsis, maxLines: 1,
                                              )),
                                              SizedBox(
                                                width: 6,
                                              ),
                                              GestureDetector(
                                                onTap: () {
                                                  setState(() {
                                                    hideEmail = !hideEmail;
                                                  });
                                                },
                                                child: Text(
                                                    hideEmail
                                                        ? I18n.of(context)
                                                            .reveal
                                                        : I18n.of(context).hide,
                                                    style: Theme.of(context)
                                                        .textTheme
                                                        .bodySmall!
                                                        .copyWith(
                                                            color: Theme.of(
                                                                    context)
                                                                .colorScheme
                                                                .primary)),
                                              )
                                            ],
                                          )
                                      ],
                                    ),
                                  ))
                                ],
                              ),
                            ),
                          ),
                          ListTile(
                            leading: Icon(Icons.account_box),
                            title: Text(I18n.of(context).account_message),
                            onTap: () {
                              Navigator.of(_destination(context)).push(MaterialPageRoute(
                                  builder: (BuildContext context) =>
                                      AccountEditPage()));
                            },
                          )
                        ],
                      ),
                    );
                  return Container();
                }),
                Divider(),
                _sections(context, [
Column(
                  children: <Widget>[
                    ListTile(
                      leading: Icon(Icons.history),
                      title: Text(I18n.of(context).history_record),
                      onTap: () => _openHistory(context),
                    ),
                    ListTile(
                      leading: Icon(Icons.settings),
                      title: Text(I18n.of(context).quality_setting),
                      onTap: () {
                        if (_detail.currentState != null) {
                          showPreferences();
                        } else {
                          Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => SettingQualityPage(),
                          ));
                        }
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.palette_outlined),
                      title: Text(I18n.of(context).theme),
                      onTap: () => Navigator.of(_destination(context)).push(
                        MaterialPageRoute(builder: (_) => ThemePage()),
                      ),
                    ),
                    ListTile(
                      leading: Icon(Icons.bookmark),
                      title: Text(I18n.of(context).favorited_tag),
                      onTap: () =>
                          Leader.pushWithScaffold(_destination(context), BookTagPage()),
                    ),
                    ListTile(
                      leading: Icon(Icons.block),
                      title: Text(I18n.of(context).shielding_settings),
                      onTap: () => Leader.push(_destination(context), ShieldPage()),
                    ),
                    ListTile(
                      leading: Icon(Icons.save_alt),
                      title: Text(I18n.of(context).task_progress),
                      onTap: () => Leader.push(_destination(context), JobPage()),
                    ),
                    ListTile(
                      onTap: () => Leader.push(_destination(context), DataExportPage()),
                      title: Text(I18n.of(context).app_data),
                      leading: Icon(Icons.folder_open_rounded),
                    ),
                  ],
                ),
                Column(
                  children: <Widget>[
                    ListTile(
                      leading: Icon(Icons.library_books),
                      title: Text(I18n.of(context).manga),
                      onTap: () => Leader.push(_destination(context), RecomMangaPage()),
                    ),
                    ListTile(
                      leading: Icon(Icons.book),
                      title: Text(I18n.of(context).novel),
                      onTap: () => Navigator.of(context, rootNavigator: true)
                          .pushReplacement(MaterialPageRoute(
                              builder: (context) => NovelRail())),
                    ),
                    ListTile(
                      leading: Icon(Icons.message),
                      title: Text(I18n.of(context).about),
                      onTap: () => Leader.push(
                        _destination(context),
                        AboutPage(newVersion: _effectiveHasNewVersion),
                      ),
                      trailing: Observer(
                        builder: (context) {
                          return Visibility(
                            child: NewVersionChip(),
                            visible: _effectiveHasNewVersion,
                          );
                        },
                      ),
                    ),
                    if (_needBoardSection)
                      ListTile(
                        leading: Icon(Icons.article),
                        title: Text(I18n.of(context).bulletin_board),
                        onTap: () => Leader.push(
                            _destination(context),
                            BoardPage(
                              boardList: _boardList,
                            )),
                      ),
                    Observer(builder: (context) {
                      if (accountStore.now != null)
                        return ListTile(
                          leading: Icon(Icons.arrow_back),
                          title: Text(I18n.of(context).logout),
                          onTap: () => _showLogoutDialog(context),
                        );
                      else
                        return ListTile(
                          leading: Icon(Icons.arrow_back),
                          title: Text(I18n.of(context).login),
                          onTap: () => Leader.push(_destination(context), LoginPage()),
                        );
                    })
                  ],
                )
                ])
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _sections(BuildContext context, List<Widget> groups) {
    if (!usesIPadLayout(context)) return Column(children: [groups.first, Divider(), groups.last]);
    return LayoutBuilder(builder: (context, constraints) {
      if (constraints.maxWidth < 760) return Column(children: [groups.first, const Divider(height: 24), groups.last]);
      return Align(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 1040),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: groups.first), const SizedBox(width: 16), Expanded(child: groups.last),
        ]),
      ));
    });
  }

  Future _showLogoutDialog(BuildContext context) async {
    final result = await showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: Text(I18n.of(context).logout),
            actions: <Widget>[
              TextButton(
                child: Text(I18n.of(context).cancel),
                onPressed: () {
                  Navigator.of(context).pop("CANCEL");
                },
              ),
              TextButton(
                child: Text(I18n.of(context).ok),
                onPressed: () {
                  Navigator.of(context).pop("OK");
                },
              ),
            ],
          );
        });
    switch (result) {
      case "OK":
        {
          accountStore.deleteAll();
        }
        break;
      case "CANCEL":
        {}
        break;
    }
  }

  Future<void> cleanGlanceData() => GlanceIllustPersistProvider.clearCache();

  bool _needBoardSection = false;
  List<BoardInfo> _boardList = [];

  fetchBoard() async {
    try {
      if (BoardInfo.boardDataLoaded) {
        setState(() {
          _boardList = BoardInfo.boardList;
          _needBoardSection = _boardList.isNotEmpty;
        });
        return;
      }
      final list = await BoardInfo.load();
      setState(() {
        BoardInfo.boardDataLoaded = true;
        _boardList = list;
        _needBoardSection = _boardList.isNotEmpty;
      });
    } catch (e) {}
  }
}
