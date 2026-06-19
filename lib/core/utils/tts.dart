// Tiny cross-platform text-to-speech facade.
// On web it uses the browser SpeechSynthesis API; on other platforms it's a
// no-op (returns false from isSupported). Mirrors the kv_store conditional
// import pattern.
export 'tts_io.dart' if (dart.library.html) 'tts_web.dart';
