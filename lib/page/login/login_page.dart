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
import 'package:pixez/component/ipad_surface.dart';
import 'package:pixez/constants.dart';
import 'package:pixez/custom_tab_plugin.dart';
import 'package:pixez/er/leader.dart';
import 'package:pixez/i18n.dart';
import 'package:pixez/main.dart';
import 'package:pixez/network/oauth_client.dart';
import 'package:pixez/page/about/about_page.dart';
import 'package:pixez/page/hello/setting/setting_quality_page.dart';
import 'package:pixez/page/login/token_page.dart';
import 'package:pixez/page/webview/webview_page.dart';
import 'package:pixez/weiss_plugin.dart';
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
    if (Theme.of(context).platform == TargetPlatform.iOS) {
      return _buildGlassPage(context);
    }
    return Scaffold(
      bottomNavigationBar: BottomAppBar(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: <Widget>[
            IconButton(
              icon: Icon(Icons.settings),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => SettingQualityPage()),
                );
              },
            ),
            IconButton(
              icon: Icon(Icons.message),
              onPressed: () {
                Navigator.of(
                  context,
                ).push(MaterialPageRoute(builder: (context) => AboutPage()));
              },
            ),
          ],
        ),
      ),
      appBar: AppBar(elevation: 0.0, backgroundColor: Colors.transparent),
      extendBody: true,
      extendBodyBehindAppBar: true,
      body: Builder(
        builder: (context) {
          return _buildBody(context);
        },
      ),
    );
  }

  Widget _buildGlassPage(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
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
                        ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          child: Image.asset(
                            'assets/images/pixap_login_icon.png',
                            width: 96,
                            height: 96,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          Constants.appleAppName,
                          style: theme.textTheme.headlineMedium,
                        ),
                        const SizedBox(height: 24),
                        IPadSurface(
                          includeIPhone: true,
                          darkGlass: theme.brightness == Brightness.dark,
                          child: Padding(
                            padding: const EdgeInsets.all(18),
                            child: _buildActions(context),
                          ),
                        ),
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

  Widget _buildBody(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: MediaQuery.paddingOf(context).top),
      child: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 20),
            Image.asset('assets/images/icon.png', height: 80, width: 80),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: _buildActions(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActions(BuildContext context) {
    final strings = I18n.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 10),
        FilledButton(onPressed: () => _openLogin(), child: Text(strings.login)),
        const SizedBox(height: 4),
        FilledButton(
          onPressed: () => _openLogin(create: true),
          child: Text(strings.dont_have_account),
        ),
        const SizedBox(height: 4),
        OutlinedButton(
          onPressed: () => showDialog<void>(
            context: context,
            builder: (context) => TokenPage(),
          ),
          child: const Text('Token'),
        ),
        const SizedBox(height: 4),
        TextButton(
          onPressed: () async {
            try {
              await launchUrlString('https://www.pixiv.net/terms/?page=term');
            } catch (e) {}
          },
          child: Text(strings.terms),
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
    if (Platform.isMacOS) {
      try {
        CustomTabPlugin.launch(url);
      } catch (e) {
        BotToast.showText(text: e.toString());
      }
      return;
    }
    if (userSetting.oauthNetworkMode.usesCompatibleConnection) {
      // await WeissServer.listener();
      await WeissPlugin.start();
      await WeissPlugin.proxy();
      Leader.push(context, WebViewPage(url: url));
    } else {
      try {
        CustomTabPlugin.launch(url);
      } catch (e) {
        BotToast.showText(text: e.toString());
      }
    }
  }
}
