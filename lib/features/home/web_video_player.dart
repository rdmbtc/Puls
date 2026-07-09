import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

// ignore: avoid_web_libraries_in_flutter
import 'web_video_player_stub.dart'
    if (dart.library.js_interop) 'web_video_player_impl.dart';

/// On web: renders a native <video> element with crossorigin="anonymous".
/// On native: returns null (use VideoPlayer instead).
Widget? buildWebVideoPlayer(String url, {bool loop = true}) {
  if (!kIsWeb) return null;
  return buildWebVideoWidget(url, loop: loop);
}
