import 'dart:typed_data';

/// Non-web stub — there's no plugin-free way to write to the gallery, so this
/// reports unsupported and the UI falls back to copy/share.
class PulsImageSaver {
  static bool get isSupported => false;

  static Future<bool> savePng(Uint8List bytes, String filename) async => false;
}
