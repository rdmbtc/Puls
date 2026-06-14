// Web implementation — persists to the browser's localStorage so settings
// (e.g. theme) survive a page reload.
import 'package:web/web.dart' as web;

String? kvGet(String key) => web.window.localStorage.getItem(key);

void kvSet(String key, String value) {
  web.window.localStorage.setItem(key, value);
}
