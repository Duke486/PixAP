import 'package:pixez/page/login/pixap_glass_logo.dart';
import 'package:pixez/component/glass_form_control.dart';
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

import 'package:bot_toast/bot_toast.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pixez/constants.dart';
import 'package:pixez/er/leader.dart';
import 'package:pixez/i18n.dart';
import 'package:pixez/network/oauth_client.dart';
import 'package:pixez/page/about/about_page.dart';
import 'package:pixez/page/hello/setting/setting_quality_page.dart';
import 'package:pixez/page/login/token_page.dart';
import 'package:pixez/page/webview/webview_page.dart';
import 'package:url_launcher/url_launcher_string.dart';

class LoginPage extends StatefulWidget {
  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  TextEditingController userNameController = TextEditingController();
  TextEditingController passWordController = TextEditingController();

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    userNameController.dispose();
    passWordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _buildGlassPage(context);
  }

  Widget _buildGlassPage(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        actions: [
          if (theme.platform == TargetPlatform.macOS) ...[
            IconButton(
              icon: const Icon(Icons.settings),
              onPressed: () => Leader.push(context, SettingQualityPage()),
            ),
            IconButton(
              icon: const Icon(Icons.info_outline),
              onPressed: () => Leader.push(context, AboutPage()),
            ),
          ],
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _footerLink(
                I18n.of(context).register_account,
                () => _openLogin(create: true),
              ),
              ExcludeSemantics(
                child: Text(
                  '|',
                  style: TextStyle(color: theme.colorScheme.outline),
                ),
              ),
              _footerLink(
                I18n.of(context).terms,
                () => launchUrlString('https://www.pixiv.net/terms/?page=term'),
              ),
            ],
          ),
        ),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: (constraints.maxHeight - 48)
                      .clamp(0.0, double.infinity)
                      .toDouble(),
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const PixapGlassLogo(),
                        const SizedBox(height: 16),
                        Text(
                          Constants.appleAppName,
                          style: theme.textTheme.headlineMedium,
                        ),
                        const SizedBox(height: 24),
                        _buildActions(context),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _footerLink(String text, VoidCallback activate) => Semantics(
    link: true,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: activate,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Center(
            widthFactor: 1,
            heightFactor: 1,
            child: Text(
              text,
              style: const TextStyle(fontSize: 13, color: Color(0xff007aff)),
            ),
          ),
        ),
      ),
    ),
  );

  Widget _buildActions(BuildContext context) {
    final strings = I18n.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 10),
        GlassActionButton(
          prominent: true,
          onPressed: () => _openLogin(),
          label: strings.login,
        ),
        const SizedBox(height: 10),
        GlassActionButton(
          onPressed: () => showDialog<void>(
            context: context,
            builder: (context) => TokenPage(),
          ),
          label: strings.login_with_token,
        ),
      ],
    );
  }

  Future<void> _openLogin({bool create = false}) async {
    try {
      final url = await OAuthClient.generateWebviewUrl(create: create);
      if (mounted) _launch(url);
    } catch (e) {}
  }

  Future<void> _launch(String url) async {
    if (Platform.isIOS) {
      await Leader.push(context, WebViewPage(url: url));
      return;
    }
    try {
      await launchUrlString(url);
    } catch (e) {
      BotToast.showText(text: e.toString());
    }
  }
}
