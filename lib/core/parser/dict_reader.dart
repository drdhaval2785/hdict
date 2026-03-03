import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io';
import 'dart:convert';
import 'package:hdict/core/database/database_helper.dart';
import 'package:dictzip_reader/dictzip_reader.dart';
import 'package:path/path.dart' as p;

/// Reads definitions from a StarDict .dict or .dict.dz file at specified offsets and lengths.
///
/// For plain `.dict` files, uses a [RandomAccessFile] for direct byte reads.
/// For `.dict.dz` files, delegates to [DictzipReader] which performs
/// chunk-based random access without decompressing the file to disk.
class DictReader {
  final File? file;
  final String path;
  final int? dictId;

  DictReader(this.path, {this.dictId}) : file = kIsWeb ? null : File(path);

  RandomAccessFile? _raf;
  DictzipReader? _dzReader;

  bool get _isDz => path.toLowerCase().endsWith('.dz');

  /// Opens the file for reading. Use with [readAtIndex] and [close].
  Future<void> open() async {
    if (kIsWeb) return; // No-op on web
    if (_isDz) {
      _dzReader = DictzipReader(path);
      await _dzReader!.open();
    } else {
      _raf = await file!.open(mode: FileMode.read);
    }
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

    if (_isDz) {
      if (_dzReader == null) throw Exception('DictReader not opened. Call open() first.');
      return await _dzReader!.read(offset, length);
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
    if (_isDz) {
      await _dzReader?.close();
      _dzReader = null;
    } else {
      await _raf?.close();
      _raf = null;
    }
  }

  /// Reads the definition at the given offset and length in a one-off operation.
  Future<String> readEntry(int offset, int length) async {
    if (kIsWeb) {
      return await readAtIndex(offset, length);
    }
    if (_isDz) {
      // One-shot: open, read, close.
      final dz = DictzipReader(path);
      await dz.open();
      try {
        return await dz.read(offset, length);
      } finally {
        await dz.close();
      }
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
