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

import 'package:fluent_ui/fluent_ui.dart';
import 'package:pixez/i18n.dart';
import 'package:pixez/main.dart';

class InitPage extends StatefulWidget {
  @override
  _InitPageState createState() => _InitPageState();
}

class _InitPageState extends State<InitPage> {
  final languageList = userSetting.languageList;

  @override
  Widget build(BuildContext context) {
    return ScaffoldPage(
      backgroundColor: Colors.transparent,
      header: PageHeader(title: Text(I18n.of(context).select_language)),
      content: Center(
        child: RadioGroup<int>(
          groupValue: userSetting.languageNum,
          onChanged: (v) async {
            if (v == null) return;
            await userSetting.setLanguageNum(v);
            if (mounted) setState(() {});
          },
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (int i = 0; i < languageList.length; i++) ...[
                  RadioButton(value: i, content: Text(languageList[i])),
                  if (i != languageList.length - 1) const SizedBox(height: 8),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
