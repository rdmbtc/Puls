// Native/fallback implementation — in-memory only.
final Map<String, String> _mem = <String, String>{};

String? kvGet(String key) => _mem[key];

void kvSet(String key, String value) {
  _mem[key] = value;
}
