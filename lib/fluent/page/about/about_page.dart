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

import 'dart:io';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:material_ui/material_ui.dart' as material;
import 'package:pixez/constants.dart';
import 'package:pixez/er/leader.dart';
import 'package:pixez/fluent/page/about/update_page.dart';
import 'package:pixez/i18n.dart';
import 'package:pixez/page/about/about_page.dart' show AboutContent;

class AboutPage extends StatelessWidget {
  final bool? newVersion;

  const AboutPage({super.key, this.newVersion});

  @override
  Widget build(BuildContext context) {
    final strings = I18n.of(context);
    return ScaffoldPage(
      header: PageHeader(title: Text(strings.about)),
      content: material.Theme(
        data: material.ThemeData(
          brightness: FluentTheme.of(context).brightness,
        ),
        child: material.Material(
          type: material.MaterialType.transparency,
          child: AboutContent(
            newVersion: newVersion ?? false,
            onCheckUpdates: !Platform.isAndroid || Constants.isGooglePlay
                ? null
                : () => Leader.push(
                    context,
                    UpdatePage(),
                    title: Text(strings.check_for_updates),
                    icon: const Icon(FluentIcons.update_restore),
                  ),
          ),
        ),
      ),
    );
  }
}
