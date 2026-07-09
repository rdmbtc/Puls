// Cross-platform "save a PNG to the user's device".
// On web it triggers a real browser download; on other platforms it's a no-op
// (returns false). Mirrors the conditional-import pattern used by kv_store/tts.
export 'image_saver_io.dart' if (dart.library.js_interop) 'image_saver_web.dart';
