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


import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:material_ui/material_ui.dart';
import 'package:pixez/component/new_version_chip.dart';
import 'package:pixez/constants.dart';
import 'package:pixez/i18n.dart';
import 'package:pixez/page/about/contributors.dart';
import 'package:pixez/page/about/update_page.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class AboutPage extends StatelessWidget {
  final bool? newVersion;

  const AboutPage({super.key, this.newVersion});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(I18n.of(context).about)),
      body: AboutContent(
        newVersion: newVersion ?? false,
        onCheckUpdates:
            kDebugMode
            ? () => Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => UpdatePage()))
            : null,
      ),
    );
  }
}

class AboutContent extends StatelessWidget {
  const AboutContent({
    super.key,
    required this.newVersion,
    this.onCheckUpdates,
  });

  final bool newVersion;
  final VoidCallback? onCheckUpdates;

  static final _repository = Uri.https('github.com', '/${Constants.repositoryPath}');
  static final _upstream = Uri.https('github.com', '/Notsfsssf/pixez-flutter');

  @override
  Widget build(BuildContext context) {
    final strings = I18n.of(context);
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        if (Constants.hasAppleBranding) ...[
          Text(Constants.appleAppName, style: theme.textTheme.headlineSmall),
          const SizedBox(height: 4),
          Text(Constants.appleAppTagline, style: theme.textTheme.bodyLarge),
          const SizedBox(height: 12),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: OutlinedButton.icon(
              onPressed: () => launchUrl(
                _repository,
                mode: LaunchMode.externalApplication,
              ),
              icon: const Icon(Icons.open_in_new),
              label: const Text('GitHub · Duke486/PixAP'),
            ),
          ),
          const SizedBox(height: 12),
        ],
        Text(strings.about_origin, style: theme.textTheme.bodyLarge),
        const SizedBox(height: 12),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: OutlinedButton.icon(
            onPressed: () =>
                launchUrl(_upstream, mode: LaunchMode.externalApplication),
            icon: const Icon(Icons.open_in_new),
            label: Text(strings.about_original_project),
          ),
        ),
        if (onCheckUpdates != null)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.update),
            title: Text(strings.check_for_updates),
            trailing: newVersion ? NewVersionChip() : null,
            onTap: onCheckUpdates,
          ),
        const Divider(),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.description_outlined),
          title: Text(strings.about_open_source_licenses),
          subtitle: const Text('GNU GPL v3'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => showLicensePage(
            context: context,
            applicationName: Constants.displayName,
          ),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.verified_outlined),
          title: Text(strings.about_signing_certificate),
          subtitle: Text(strings.about_signing_certificate_summary),
        ),
        Builder(
          builder: (context) {
            return ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.share_outlined),
              title: Text(strings.share),
              onTap: () {
                final box = context.findRenderObject() as RenderBox;
                SharePlus.instance.share(
                  ShareParams(
                    text: Constants.displayName,
                    sharePositionOrigin:
                        box.localToGlobal(Offset.zero) & box.size,
                  ),
                );
              },
            );
          },
        ),
        const Divider(),
        const SizedBox(height: 8),
        Text(
          strings.about_original_credits,
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, constraints) {
            const spacing = 8.0;
            final columns = ((constraints.maxWidth + spacing) / 216)
                .floor()
                .clamp(1, 4);
            final width =
                (constraints.maxWidth - spacing * (columns - 1)) / columns;
            final textScaler = MediaQuery.textScalerOf(context);
            final nameSize = theme.textTheme.labelLarge?.fontSize ?? 14;
            final detailSize = theme.textTheme.bodySmall?.fontSize ?? 12;
            final height =
                20 +
                (textScaler.scale(nameSize) +
                        textScaler.scale(detailSize) * 3) *
                    1.25;
            return Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: [
                for (final (name, detail, asset, url) in [
                  (
                    'Perol_Notsfsssf',
                    strings.perol_message,
                    'assets/images/me.jpg',
                    null,
                  ),
                  (
                    'Right now',
                    strings.right_now_message,
                    'assets/images/right_now.jpg',
                    null,
                  ),
                  (
                    'Skimige',
                    strings.skimige_message,
                    null,
                    contributorAvatarUrl('9017470'),
                  ),
                  for (final contributor in originalContributors)
                    (
                      contributor.name,
                      contributor.detail,
                      null,
                      contributorAvatarUrl(contributor.avatar),
                    ),
                ])
                  SizedBox(
                    width: width,
                    height: height,
                    child: _creditCard(context, name, detail, asset, url),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _creditCard(
    BuildContext context,
    String name,
    String detail,
    String? asset,
    String? url,
  ) {
    final textTheme = Theme.of(context).textTheme;
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              foregroundImage: asset == null ? null : AssetImage(asset),
              child: url == null
                  ? const Icon(Icons.person_outline)
                  : ClipOval(
                      child: Image.network(
                        url,
                        width: 40,
                        height: 40,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            const Icon(Icons.person_outline),
                      ),
                    ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Tooltip(
                message: '$name\n$detail',
                excludeFromSemantics: true,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: textTheme.labelLarge?.copyWith(height: 1.25),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      detail,
                      style: textTheme.bodySmall?.copyWith(height: 1.25),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
