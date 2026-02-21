import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io';
import 'dart:convert';
import 'package:hdict/core/database/database_helper.dart';
import 'package:path/path.dart' as p;

/// Reads definitions from a StarDict .dict file at specified offsets and lengths.
class DictReader {
  final File? file;
  final String path;
  final int? dictId;

  DictReader(this.path, {this.dictId}) : file = kIsWeb ? null : File(path);

  RandomAccessFile? _raf;

  /// Opens the file for reading. Use with [readAtIndex] and [close].
  Future<void> open() async {
    if (kIsWeb) return; // No-op on web
    _raf = await file!.open(mode: FileMode.read);
  }

  /// Reads from the already opened file.
  Future<String> readAtIndex(int offset, int length) async {
    if (kIsWeb) {
      if (dictId == null) throw Exception('dictId required for Web reading');
      // Use basename to match how files are stored in the 'files' table
      final bytes = await DatabaseHelper().getFilePart(dictId!, p.basename(path), offset, length);
      if (bytes == null) throw Exception('Failed to read from virtual FS: ${p.basename(path)}');
      return utf8.decode(bytes, allowMalformed: true);
    }

    if (_raf == null) {
      throw Exception('DictReader not opened. Call open() first.');
    }
    await _raf!.setPosition(offset);
    final bytes = await _raf!.read(length);
    return utf8.decode(bytes, allowMalformed: true);
  }

  /// Closes the file.
  Future<void> close() async {
    if (kIsWeb) return;
    await _raf?.close();
    _raf = null;
  }

  /// Reads the definition at the given offset and length in a one-off operation.
  Future<String> readEntry(int offset, int length) async {
    if (kIsWeb) {
      return await readAtIndex(offset, length);
    }
    final raf = await file!.open(mode: FileMode.read);
    try {
      await raf.setPosition(offset);
      final bytes = await raf.read(length);
      return utf8.decode(bytes, allowMalformed: true);
    } finally {
      await raf.close();
    }
  }
}
