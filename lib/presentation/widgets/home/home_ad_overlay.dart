import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

class HomeAdOverlay extends StatelessWidget {
  const HomeAdOverlay({
    super.key,
    required this.isVisible,
    required this.currentLink,
    required this.height,
    required this.onRedirect,
  });

  final bool isVisible;
  final String currentLink;
  final double height;
  final Future<void> Function(Uri? url, InAppWebViewController controller)
  onRedirect;

  @override
  Widget build(BuildContext context) {
    if (!isVisible) {
      return const SizedBox.shrink();
    }

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      height: height,
      child: Container(
        color: Colors.black,
        child: InAppWebView(
          key: ValueKey(currentLink),
          initialUrlRequest: URLRequest(url: WebUri(currentLink)),
          initialSettings: InAppWebViewSettings(
            javaScriptEnabled: true,
            allowsBackForwardNavigationGestures: false,
            transparentBackground: false,
          ),
          shouldOverrideUrlLoading: (controller, action) async {
            final url = action.request.url;
            if (url == null) {
              return NavigationActionPolicy.CANCEL;
            }

            if (url.toString().contains('AEDOVE-AD-Redirect')) {
              await onRedirect(url, controller);
              return NavigationActionPolicy.CANCEL;
            }

            return NavigationActionPolicy.ALLOW;
          },
        ),
      ),
    );
  }
}
