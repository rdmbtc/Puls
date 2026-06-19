// Web text-to-speech via the browser SpeechSynthesis API.
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

  static void speak(String text) {
    try {
      final synth = web.window.speechSynthesis;
      synth.cancel(); // stop anything already playing
      // Chunk long text — some browsers truncate very long utterances.
      final chunks = _chunk(text, 220);
      for (final c in chunks) {
        final u = web.SpeechSynthesisUtterance(c);
        u.rate = 1.0;
        u.pitch = 1.0;
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
