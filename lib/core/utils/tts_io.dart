// Non-web stub for text-to-speech. No-op everywhere except web.
class PulsTts {
  static bool get isSupported => false;
  static bool get speaking => false;
  static void speak(String text) {}
  static void stop() {}
}
