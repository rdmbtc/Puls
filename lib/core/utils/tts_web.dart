// Web text-to-speech via the browser SpeechSynthesis API.
import 'dart:js_interop';
import 'package:web/web.dart' as web;

class PulsTts {
  static bool get isSupported {
    try {
      return web.window.speechSynthesis != null;
    } catch (_) {
      return false;
    }
  }

  static bool get speaking {
    try {
      return web.window.speechSynthesis.speaking;
    } catch (_) {
      return false;
    }
  }

  static web.SpeechSynthesisVoice? _voice;

  // Pick the best available English voice. `getVoices()` is populated
  // asynchronously (often empty until the browser fires `voiceschanged`), so we
  // resolve lazily and cache the result the first time it's available.
  static void _resolveVoice() {
    try {
      final voices = web.window.speechSynthesis.getVoices().toDart;
      if (voices.isEmpty) return;

      // 1. Known high-quality English voices, in order of preference.
      const preferred = [
        'Google US English',
        'Microsoft Aria', 'Microsoft Jenny', 'Microsoft Michelle',
        'Microsoft Guy', 'Microsoft Zira', 'Microsoft David',
        'Samantha', 'Daniel', 'Karen', 'Tessa', // Apple
      ];
      for (final name in preferred) {
        for (final v in voices) {
          if (v.name.contains(name)) {
            _voice = v;
            return;
          }
        }
      }
      // 2. Any en-US voice.
      for (final v in voices) {
        if (v.lang.toLowerCase().replaceAll('_', '-') == 'en-us') {
          _voice = v;
          return;
        }
      }
      // 3. Any English voice at all.
      for (final v in voices) {
        if (v.lang.toLowerCase().startsWith('en')) {
          _voice = v;
          return;
        }
      }
    } catch (_) {}
  }

  static void speak(String text) {
    try {
      final synth = web.window.speechSynthesis;
      synth.cancel(); // stop anything already playing
      if (_voice == null) _resolveVoice();
      // Chunk long text — some browsers truncate very long utterances.
      final chunks = _chunk(text, 220);
      for (final c in chunks) {
        final u = web.SpeechSynthesisUtterance(c);
        // Pin English so a non-English browser/system locale can't hijack the
        // engine — the root cause of "reads English in a Russian-sounding
        // voice". With lang fixed, the browser also defaults to an English
        // voice even before our explicit pick resolves.
        u.lang = 'en-US';
        final v = _voice;
        if (v != null) u.voice = v;
        u.rate = 1.0;
        u.pitch = 1.0;
        u.volume = 1.0;
        synth.speak(u);
      }
    } catch (_) {}
  }

  static void stop() {
    try {
      web.window.speechSynthesis.cancel();
    } catch (_) {}
  }

  static List<String> _chunk(String text, int maxLen) {
    final clean = text.replaceAll(RegExp(r'[#*`>_]'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
    final sentences = clean.split(RegExp(r'(?<=[.!?])\s+'));
    final out = <String>[];
    var cur = '';
    for (final s in sentences) {
      if ((cur + ' ' + s).length > maxLen) {
        if (cur.isNotEmpty) out.add(cur.trim());
        cur = s;
      } else {
        cur = cur.isEmpty ? s : '$cur $s';
      }
    }
    if (cur.trim().isNotEmpty) out.add(cur.trim());
    return out;
  }
}
