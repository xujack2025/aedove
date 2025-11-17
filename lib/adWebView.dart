import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'dart:async';
import 'package:url_launcher/url_launcher.dart';

class WebViewPage extends StatefulWidget {
  const WebViewPage({Key? key, required this.url}) : super(key: key);

  final String url;

  @override
  _WebViewPageState createState() => _WebViewPageState();
}

class _WebViewPageState extends State<WebViewPage> {
  late InAppWebViewController _webViewController;

  void _backWebView() async {
    await _webViewController.goBack();
  }

  void _forwardWebView() async {
    await _webViewController.goForward();
  }

  void _refreshWebView() {
    _webViewController.reload();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        return true;
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
              icon: Icon(Icons.arrow_back, color: Colors.white, size: 35),
              onPressed: () async {
                Navigator.pop(context);
              }),
          actions: [
            Row(
              children: [
                IconButton(
                  onPressed: () async {
                    _backWebView();
                  },
                  icon: Icon(Icons.arrow_back_ios),
                  color: Colors.white,
                ),
                IconButton(
                  onPressed: () async {
                    _forwardWebView();
                  },
                  icon: Icon(Icons.arrow_forward_ios),
                  color: Colors.white,
                ),
                IconButton(
                  onPressed: () async {
                    _refreshWebView();
                  },
                  icon: Icon(Icons.refresh),
                  color: Colors.white,
                ),
                // IconButton(
                //   onPressed: () async {
                //     String? currentUrl = await webViewController.currentUrl();
                //     if (currentUrl != null) {
                //       _launchUrl(Uri.parse(currentUrl));
                //     }
                //   },
                //   icon: Icon(Icons.launch_rounded),
                //   color: Colors.white,
                // ),
              ],
            ),
          ],
          centerTitle: true,
          toolbarHeight: 50,
          backgroundColor: Colors.black,
        ),
        body: InAppWebView(
          initialUrlRequest: URLRequest(url: WebUri(widget.url)),
          initialSettings: InAppWebViewSettings(
            javaScriptEnabled: true,
            geolocationEnabled: true,
          ),
          onWebViewCreated: (controller) {
            _webViewController = controller;
          },
          shouldOverrideUrlLoading: (controller, action) async {
            final url = action.request.url;
            if (url == null) return NavigationActionPolicy.CANCEL;

            final scheme = url.scheme; // http / https / mailto ...
            if (scheme == 'http' || scheme == 'https') {
              return NavigationActionPolicy.ALLOW;
            } else if (scheme == 'mailto') {
              await _launchUrl(Uri.parse(url.toString()));
              return NavigationActionPolicy.CANCEL;
            } else {
              return NavigationActionPolicy.CANCEL;
            }
          },
        ),
      ),
    );
  }

  Future<void> _launchUrl(Uri url) async {
    try {
      await launchUrl((url), mode: LaunchMode.externalApplication);
    } catch (exception) {
      print(exception);
    }
  }
}
