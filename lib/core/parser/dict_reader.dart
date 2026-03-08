import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io';
import 'dart:convert';
import 'package:hdict/core/database/database_helper.dart';
import 'package:dictzip_reader/dictzip_reader.dart';
import 'package:path/path.dart' as p;

/// Reads definitions from a StarDict .dict or .dict.dz file at specified offsets and lengths.
///
/// For plain `.dict` files, uses [File.openRead] for fully stateless random-access
/// reads — each call opens a fresh OS-level read stream, making concurrent calls safe
/// with no locking required on the caller side.
///
/// For `.dict.dz` files, delegates to [DictzipLocalReader] which performs
/// chunk-based random access; its internal chunk cache is mutable, so the caller
/// must still serialize concurrent accesses.
class DictReader {
  final File? file;
  final String path;
  final int? dictId;

  DictReader(this.path, {this.dictId}) : file = kIsWeb ? null : File(path);

  DictzipReader? _dzReader;

  /// True for .dict.dz files; false for plain .dict.
  /// Exposed so callers can decide whether locking is needed.
  bool get isDz => path.toLowerCase().endsWith('.dz');

  /// Opens the file for reading.
  /// For plain `.dict` files this is a no-op (reads use stateless [File.openRead]).
  /// For `.dict.dz` files this initialises the [DictzipLocalReader].
  Future<void> open() async {
    if (kIsWeb) return;
    if (isDz) {
      _dzReader = DictzipReader(path);
      await _dzReader!.open();
    }
    // Plain .dict: nothing to open — readAtIndex uses File.openRead per call.
  }

  /// Reads [length] bytes starting at [offset].
  ///
  /// **Plain `.dict`:** uses [File.openRead] — fully stateless, safe to call
  /// concurrently from multiple futures without any external lock.
  ///
  /// **`.dict.dz`:** delegates to [DictzipLocalReader] whose chunk cache is
  /// shared mutable state; the caller must serialise concurrent accesses.
  Future<String> readAtIndex(int offset, int length) async {
    if (kIsWeb) {
      if (dictId == null) throw Exception('dictId required for Web reading');
      final bytes = await DatabaseHelper().getFilePart(dictId!, p.basename(path), offset, length);
      if (bytes == null) throw Exception('Failed to read from virtual FS: ${p.basename(path)}');
      return utf8.decode(bytes, allowMalformed: true);
    }

    if (isDz) {
      if (_dzReader == null) throw Exception('DictReader not opened. Call open() first.');
      return await _dzReader!.read(offset, length);
    }

    // Plain .dict: File.openRead(start, end) opens a fresh OS read-stream.
    // No shared state → concurrent calls are safe and truly parallel.
    final bytes = await file!
        .openRead(offset, offset + length)
        .fold<List<int>>([], (buf, chunk) => buf..addAll(chunk));
    return utf8.decode(bytes, allowMalformed: true);
  }

  /// Reads multiple definitions at the given offsets and lengths.
  Future<List<String>> readBulk(List<({int offset, int length})> entries) async {
    if (kIsWeb) {
      // For Web, we can still do it sequentially or optimize DatabaseHelper if needed,
      // but for now, let's keep it simple for the wrapper.
      final List<String> results = [];
      for (final entry in entries) {
        results.add(await readAtIndex(entry.offset, entry.length));
      }
      return results;
    }

    if (isDz) {
      if (_dzReader == null) await open();
      final dzEntries = entries.map((e) => (e.offset, e.length)).toList();
      final results = await _dzReader!.readBulk(dzEntries);
      return results;
    }

    // For plain .dict, we can run them in parallel since File.openRead is stateless.
    final futures = entries.map((e) => readAtIndex(e.offset, e.length));
    return await Future.wait(futures);
  }

  /// Closes the file.
  /// For plain `.dict` files this is a no-op (no persistent handle was opened).
  Future<void> close() async {
    if (kIsWeb) return;
    if (isDz) {
      await _dzReader?.close();
      _dzReader = null;
    }
    // Plain .dict: nothing to close.
  }

  /// Reads the definition at the given offset and length.
  /// For plain `.dict` files, [readAtIndex] is always safe to call directly.
  /// For `.dict.dz` files, opens+reads+closes if the reader isn't already open.
  Future<String> readEntry(int offset, int length) async {
    if (kIsWeb || !isDz || _dzReader != null) {
      return await readAtIndex(offset, length);
    }

    await open();
    try {
      return await readAtIndex(offset, length);
    } finally {
      await close();
    }
  }
}
