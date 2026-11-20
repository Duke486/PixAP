import 'dart:io';

import 'package:url_launcher/url_launcher_string.dart';
import 'package:bot_toast/bot_toast.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pixez/utils/webview.dart';
import 'package:pixez/er/leader.dart';
import 'package:pixez/main.dart';

class WebViewPage extends StatefulWidget {
  final String url;

  const WebViewPage({Key? key, required this.url}) : super(key: key);

  @override
  _WebViewPageState createState() => _WebViewPageState();
}

class _WebViewPageState extends State<WebViewPage> {
  late final WebViewController _webViewController;
  double progressValue = 0.0;
  bool _handlingLogin = false;

  @override
  void initState() {
    super.initState();
    _webViewController = WebViewController();
    initializeWebViewController(
      _webViewController,
      isActive: () => mounted,
      navigationDelegate: NavigationDelegate(
        onProgress: (int progress) {
          if (!mounted) return;
          setState(() {
            progressValue = progress / 100;
          });
        },
        onPageStarted: (String url) {},
        onPageFinished: (String url) async {
          if (!mounted) return;
          final uri = Uri.parse(url);
          if (userSetting.oauthNetworkMode.usesCompatibleConnection &&
              uri.host == "accounts.pixiv.net") {
            _webViewController.runJavaScript("""
javascript:(function() {
 let forms = document.getElementsByTagName('form'); 
 for (let name of forms) {
    if (name['method'] === 'post' || name['method'] === 'POST') {
        name.style.display = 'none';
    }
  
}
 let list = document.getElementsByClassName("sns-button-list");
 for (let name of list) {
        name.style.display = 'none';
} 
  })()
""");
          }
        },
        onWebResourceError: (WebResourceError error) {},
        onNavigationRequest: (NavigationRequest request) async {
          if (!mounted) return NavigationDecision.prevent;
          final uri = Uri.parse(request.url);
          final redirect = Platform.isIOS ? pixivLoginRedirect(uri) : null;
          if (redirect != null && redirect.host.contains('account')) {
            if (!_handlingLogin) {
              _handlingLogin = true;
              final loggedIn = await Leader.pushWithUri(context, redirect);
              if (!loggedIn) _handlingLogin = false;
            }
            return NavigationDecision.prevent;
          }
          if (uri.scheme == "pixiv") {
            Leader.pushWithUri(context, uri);
            Navigator.of(context).pop("OK");
            return NavigationDecision.prevent;
          }
          return NavigationDecision.navigate;
        },
      ),
      load: () => _webViewController.loadRequest(Uri.parse(widget.url)),
    );
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(""),
        actions: <Widget>[
          IconButton(
            icon: Icon(Icons.open_in_browser),
            onPressed: () {
              try {
                launchUrlString(widget.url);
              } catch (e) {
                BotToast.showText(text: e.toString());
              }
            },
          ),
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: () => _webViewController.reload(),
          ),
        ],
      ),
      body: Builder(
        builder: (BuildContext context) {
          return Column(
            children: [
              Visibility(
                visible: progressValue < 1.0,
                child: LinearProgressIndicator(value: progressValue),
              ),
              Expanded(child: WebViewWidget(controller: _webViewController)),
            ],
          );
        },
      ),
    );
  }
}
