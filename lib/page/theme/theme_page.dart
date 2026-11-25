import 'package:pixez/component/glass_form_control.dart';
import 'package:pixez/component/ipad_surface.dart';
/*
 * Copyright (C) 2020. by perol_notsf, All rights reserved
 *
 * This program is free software: you can redistribute it and/or modify it under
 * the terms of the GNU General Public License as published by the Free Software
 * Foundation, either version 3 of the License, or (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful, but WITHOUT ANY
 *  WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
 *  FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License along with
 *  this program. If not, see <http://www.gnu.org/licenses/>.
 */

import 'package:flutter/services.dart';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:pixez/i18n.dart';
import 'package:pixez/main.dart';
import 'package:pixez/utils/haptic_util.dart';

class ThemePage extends StatefulWidget {
  @override
  _ThemePageState createState() => _ThemePageState();
}

class _ThemePageState extends State<ThemePage> with TickerProviderStateMixin {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Observer(
      builder: (context) {
        return Scaffold(
          appBar: AppBar(
            title: Text(I18n.of(context).theme),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(48),
              child: IPadPageTabs(
                tabs: TabBar(
                  controller: TabController(
                    length: 3,
                    initialIndex: ThemeMode.values.indexOf(
                      userSetting.themeMode,
                    ),
                    vsync: this,
                  ),
                  onTap: (i) {
                    HapticUtil.selectionClick();
                    userSetting.setThemeMode(i);
                  },
                  tabs: [
                    Tab(text: I18n.of(context).system),
                    Tab(text: I18n.of(context).light),
                    Tab(text: I18n.of(context).dark),
                  ],
                ),
              ),
            ),
          ),
          body: Observer(
            builder: (_) {
              return CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: SettingsSection(
                      child: glassSwitchTile(
                        SwitchListTile(
                          value: userSetting.isAMOLED,
                          onChanged: (v) {
                            HapticUtil.light();
                            userSetting.setIsAMOLED(v);
                          },
                          title: Text("AMOLED"),
                        ),
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: SettingsSection(
                      child: glassSwitchTile(
                        SwitchListTile(
                          value: userSetting.useDynamicColor,
                          onChanged: (v) async {
                            HapticUtil.light();
                            await userSetting.setUseDynamicColor(v);
                            topStore.setTop("main");
                          },
                          title: Text(I18n.of(context).dynamic_color),
                        ),
                      ),
                    ),
                  ),
                  if (!userSetting.useDynamicColor)
                    SliverToBoxAdapter(
                      child: SettingsSection(
                        child: ListTile(
                          leading: SizedBox(
                            width: 30,
                            height: 30,
                            child: Container(
                              decoration: BoxDecoration(
                                color: userSetting.seedColor,
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                          title: Text(I18n.of(context).seed_color),
                          onTap: _pickColor,
                        ),
                      ),
                    ),
                  if (!userSetting.useDynamicColor)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Wrap(
                          children: [
                            for (final shade in const [
                              0xFF0096FA,
                              0xFF00ACC1,
                              0xFF43A047,
                              0xFFFF9800,
                              0xFFFB7299,
                              0xFF8E63CE,
                            ])
                              Semantics(
                                selected:
                                    userSetting.seedColor.toARGB32() == shade,
                                child: IconButton(
                                  tooltip:
                                      '#${shade.toRadixString(16).substring(2).toUpperCase()}',
                                  onPressed: () => _apply(Color(shade)),
                                  icon: DecoratedBox(
                                    decoration: BoxDecoration(
                                      color: Color(shade),
                                      shape: BoxShape.circle,
                                    ),
                                    child: SizedBox.square(
                                      dimension: 28,
                                      child:
                                          userSetting.seedColor.toARGB32() ==
                                              shade
                                          ? const Icon(
                                              Icons.check,
                                              size: 18,
                                              color: Colors.white,
                                            )
                                          : null,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _pickColor() async {
    final color = await const MethodChannel(
      'pixez/themeColor',
    ).invokeMethod<int>('pick', userSetting.seedColor.toARGB32());
    if (color != null) await _apply(Color(color));
  }

  Future<void> _apply(Color color) async {
    await userSetting.setThemeData(color);
    topStore.setTop("main");
  }
}
