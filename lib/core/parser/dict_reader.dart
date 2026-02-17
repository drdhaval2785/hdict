import 'dart:io';
import 'dart:convert';

/// Reads definitions from a StarDict .dict file at specified offsets and lengths.
class DictReader {
  final File file;

  DictReader(String path) : file = File(path);

  /// Reads the definition at the given offset and length.
  /// Assumes the file is a raw .dict file (not compressed).
  Future<String> readEntry(int offset, int length) async {
    final raf = await file.open(mode: FileMode.read);
    try {
      await raf.setPosition(offset);
      final bytes = await raf.read(length);
      return utf8.decode(bytes); // Assuming UTF-8, StarDict usually is.
    } finally {
      await raf.close();
    }
  }
}
