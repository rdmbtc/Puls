import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

// webview_flutter is not supported on web — conditionally import
import 'circle_web_view_native.dart' if (dart.library.html) 'circle_web_view_stub.dart';
import '../../core/widgets/puls_sheet.dart';

/// Opens Circle's hosted challenge UI in a bottom sheet WebView.
/// On web, falls back to opening the URL in a new browser tab.
class CircleWebView extends StatefulWidget {
  const CircleWebView({
    required this.challengeUrl,
    required this.onComplete,
    required this.onError,
    super.key,
  });

  final String challengeUrl;
  final VoidCallback onComplete;
  final ValueChanged<String> onError;

  static Future<void> show({
    required BuildContext context,
    required String challengeUrl,
    required VoidCallback onComplete,
    required ValueChanged<String> onError,
  }) {
    if (kIsWeb) {
      // On web: open in new tab and immediately call onComplete
      // (Circle's challenge flow handles its own redirect)
      openUrlInNewTab(challengeUrl);
      onComplete();
      return Future.value();
    }
    return PulsSheet.show(
      context,
      builder: (_) => CircleWebView(
        challengeUrl: challengeUrl,
        onComplete: onComplete,
        onError: onError,
      ),
    );
  }

  @override
  State<CircleWebView> createState() => _CircleWebViewState();
}

class _CircleWebViewState extends State<CircleWebView> {
  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      // Should not be reached since show() handles web case above
      return const SizedBox.shrink();
    }
    return buildNativeWebView(context, widget);
  }
}
