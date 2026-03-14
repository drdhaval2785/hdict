import 'package:slob_reader/slob_reader.dart' as lib;
export 'package:slob_reader/slob_reader.dart' show SlobBlob;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:convert';

/// Wrapper around the `slob_reader` package.
///
/// Provides a unified interface for reading Slob (.slob) dictionaries.
/// Only supported on native platforms.
class SlobReader {
  final String path;
  lib.SlobReader? _reader;
  bool _isInitialized = false;

  SlobReader(this.path);

  /// Opens the Slob file.
  Future<void> open() async {
    if (kIsWeb) throw UnsupportedError('Slob is not supported on Web.');
    if (_isInitialized) return;
    _reader = await lib.SlobReader.open(path);
    _isInitialized = true;
  }

  /// Returns the internal blob for a given index.
  /// Primarily for internal use or bulk operations.
  Future<lib.SlobBlob?> getBlob(int index) async {
    if (!_isInitialized || _reader == null) return null;
    return await _reader!.getBlob(index);
  }

  /// Returns the dictionary label from tags, or filename if unavailable.
  String get bookName {
    if (!_isInitialized || _reader == null) return '';
    return _reader!.header.tags['label'] ?? '';
  }

  /// Returns total number of blobs.
  int get blobCount {
    if (!_isInitialized || _reader == null) return 0;
    return _reader!.header.blobCount;
  }

  /// Stream of all blobs in the slob file.
  Stream<dynamic> get blobs async* {
    if (kIsWeb) throw UnsupportedError('Slob is not supported on Web.');
    if (!_isInitialized) await open();
    if (_reader == null) return;

    for (int i = 0; i < blobCount; i++) {
      yield await _reader!.getBlob(i);
    }
  }

  /// Looks up the HTML definition for a word.
  /// Returns null if the word is not found.
  /// Note: This is O(N). Use [getBlobContent] with an index for O(1) lookup.
  Future<String?> lookup(String word) async {
    if (kIsWeb) throw UnsupportedError('Slob is not supported on Web.');
    if (!_isInitialized) await open();
    if (_reader == null) return null;

    for (int i = 0; i < blobCount; i++) {
        final blob = await _reader!.getBlob(i);
        if (blob.key == word) {
            return utf8.decode(blob.content, allowMalformed: true);
        }
    }
    return null;
  }

  /// Returns the content of the blob at the given [index] (global ref index).
  /// This is O(1) once the file is open but involves a reference lookup.
  Future<String?> getBlobContent(int index) async {
    if (kIsWeb) throw UnsupportedError('Slob is not supported on Web.');
    if (!_isInitialized) await open();
    if (_reader == null) return null;
    if (index < 0 || index >= blobCount) return null;

    final blob = await _reader!.getBlob(index);
    return utf8.decode(blob.content, allowMalformed: true);
  }

  /// Returns the content of the blob for a specific [id] (packed binIndex/itemIndex).
  /// This is the fastest O(1) lookup method.
  Future<String?> getBlobContentById(int id) async {
    if (kIsWeb) throw UnsupportedError('Slob is not supported on Web.');
    if (!_isInitialized) await open();
    if (_reader == null) return null;

    final binIndex = id >> 16;
    final itemIndex = id & 0xFFFF;
    final content = await _reader!.getBlobContent(binIndex, itemIndex);
    return utf8.decode(content, allowMalformed: true);
  }

  /// Returns the content of multiple blobs for given [ids].
  /// This is faster than calling [getBlobContentById] multiple times.
  Future<List<String>> getBlobsContentByIds(List<int> ids) async {
    if (kIsWeb) throw UnsupportedError('Slob is not supported on Web.');
    if (!_isInitialized) await open();
    if (_reader == null) return [];

    final List<(int, int)> blobIds = ids.map((id) => (
      id >> 16,
      id & 0xFFFF,
    )).toList();

    final blobs = await _reader!.getBlobs(blobIds);
    return blobs.map((b) => utf8.decode(b.content, allowMalformed: true)).toList();
  }

  /// Fetches [count] blobs starting at global reference [start] in a single
  /// batched call.  Uses [getBlobs()] which decompresses each compressed bin
  /// exactly once and returns key + content together — the fastest way to
  /// sequentially iterate all blobs in a slob file.
  Future<List<lib.SlobBlob>> getBlobsByRange(int start, int count) async {
    if (kIsWeb) throw UnsupportedError('Slob is not supported on Web.');
    if (!_isInitialized) await open();
    if (_reader == null) return [];
    if (count <= 0) return [];
    return await _reader!.getBlobs([(start, count)]);
  }

  /// Closes the Slob file.

  Future<void> close() async {
    if (kIsWeb) return;
    await _reader?.close();
    _reader = null;
    _isInitialized = false;
  }
}
