import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/puls_loader.dart';
import 'circle_web_view.dart';

void openUrlInNewTab(String url) {
  // No-op on native — handled by the WebView bottom sheet
}

Widget buildNativeWebView(BuildContext context, CircleWebView widget) {
  return _NativeWebViewBody(widget: widget);
}

class _NativeWebViewBody extends StatefulWidget {
  const _NativeWebViewBody({required this.widget});
  final CircleWebView widget;

  @override
  State<_NativeWebViewBody> createState() => _NativeWebViewBodyState();
}

class _NativeWebViewBodyState extends State<_NativeWebViewBody> {
  late final WebViewController _ctrl;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _ctrl = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) => setState(() => _loading = false),
          onNavigationRequest: (req) {
            final url = req.url;
            if (url.contains('circle-pw://') ||
                url.contains('challenge-complete') ||
                url.contains('success=true')) {
              Navigator.of(context).pop();
              widget.widget.onComplete();
              return NavigationDecision.prevent;
            }
            if (url.contains('error=') || url.contains('cancelled=true')) {
              final uri = Uri.tryParse(url);
              final err = uri?.queryParameters['error'] ?? 'Challenge cancelled';
              Navigator.of(context).pop();
              widget.widget.onError(err);
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
          onWebResourceError: (err) => widget.widget.onError(err.description),
        ),
      )
      ..loadRequest(Uri.parse(widget.widget.challengeUrl));
  }

  @override
  Widget build(BuildContext context) {
    final t = context.puls;
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: t.surfaceRaised,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 8, 10),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 4,
                  decoration: BoxDecoration(
                    color: t.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const Spacer(),
                Text('Approve Transaction',
                    style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                IconButton(
                  icon: Icon(Icons.close_rounded, color: t.textSubtle),
                  onPressed: () {
                    Navigator.of(context).pop();
                    widget.widget.onError('Cancelled by user');
                  },
                ),
              ],
            ),
          ),
          Divider(color: t.border, height: 1),
          Expanded(
            child: Stack(
              children: [
                WebViewWidget(controller: _ctrl),
                if (_loading) const PulsLoader(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
