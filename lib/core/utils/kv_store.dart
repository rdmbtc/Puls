// Tiny cross-platform key/value store.
// On web it persists to localStorage; on other platforms it falls back to an
// in-memory map (no cross-session persistence). Mirrors the conditional-import
// pattern already used for web-only code (e.g. circle_web_view).
export 'kv_store_io.dart' if (dart.library.js_interop) 'kv_store_web.dart';
