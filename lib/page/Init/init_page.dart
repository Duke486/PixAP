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

import 'package:material_ui/material_ui.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:pixez/i18n.dart';
import 'package:pixez/main.dart';
import 'package:pixez/page/about/languages.dart';

class InitPage extends StatelessWidget {
  const InitPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Observer(
      builder: (context) => ListView(
        padding: const EdgeInsets.fromLTRB(18, 24, 18, 16),
        children: [
          Icon(Icons.translate_rounded, color: colors.primary, size: 30),
          const SizedBox(height: 12),
          Text(
            I18n.of(context).select_language,
            style: theme.textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          for (final index in const [1, 2, 0, 3, 4])
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                title: Text(Languages[index].name),
                selected: userSetting.languageNum == index,
                selectedColor: colors.onPrimaryContainer,
                selectedTileColor: colors.primaryContainer.withValues(
                  alpha: .72,
                ),
                trailing: userSetting.languageNum == index
                    ? const Icon(Icons.check_circle_rounded)
                    : null,
                onTap: () => userSetting.setLanguageNum(index),
              ),
            ),
        ],
      ),
    );
  }
}
