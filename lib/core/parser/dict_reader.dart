import 'dart:io';
import 'dart:convert';

/// Reads definitions from a StarDict .dict file at specified offsets and lengths.
class DictReader {
  final File file;

  DictReader(String path) : file = File(path);

  RandomAccessFile? _raf;

  /// Opens the file for reading. Use with [readAtIndex] and [close].
  Future<void> open() async {
    _raf = await file.open(mode: FileMode.read);
  }

  /// Reads from the already opened file.
  Future<String> readAtIndex(int offset, int length) async {
    if (_raf == null)
      throw Exception('DictReader not opened. Call open() first.');
    await _raf!.setPosition(offset);
    final bytes = await _raf!.read(length);
    return utf8.decode(bytes);
  }

  /// Closes the file.
  Future<void> close() async {
    await _raf?.close();
    _raf = null;
  }

  /// Reads the definition at the given offset and length in a one-off operation.
  Future<String> readEntry(int offset, int length) async {
    final raf = await file.open(mode: FileMode.read);
    try {
      await raf.setPosition(offset);
      final bytes = await raf.read(length);
      return utf8.decode(bytes);
    } finally {
      await raf.close();
    }
  }
}
