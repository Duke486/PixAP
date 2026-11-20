import 'package:webview_all/webview_all.dart';

export 'package:webview_all/webview_all.dart';

// Native desktop initialization can finish after its page has been closed.
Future<void> initializeWebViewController(
  WebViewController controller, {
  required bool Function() isActive,
  NavigationDelegate? navigationDelegate,
  String? userAgent,
  required Future<void> Function() load,
}) async {
  try {
    if (!isActive()) return;
    await controller.setJavaScriptMode(JavaScriptMode.unrestricted);
    if (!isActive()) return;
    if (navigationDelegate != null) {
      await controller.setNavigationDelegate(navigationDelegate);
    }
    if (!isActive()) return;
    if (userAgent != null) await controller.setUserAgent(userAgent);
    if (!isActive()) return;
    await load();
  } catch (_) {
    // Errors from a live page remain visible; a closed page cancels its work.
    if (isActive()) rethrow;
  }
}

Uri? pixivLoginRedirect(Uri uri) {
  if (uri.scheme == 'pixiv') return uri;
  if (uri.scheme == 'https' &&
      uri.host == 'app-api.pixiv.net' &&
      uri.path == '/web/v1/users/auth/pixiv/callback') {
    return Uri(
      scheme: 'pixiv',
      host: 'account',
      path: '/login',
      query: uri.query,
    );
  }
  return null;
}
