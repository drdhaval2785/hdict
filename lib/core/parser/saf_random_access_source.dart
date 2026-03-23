import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'package:saf_stream/saf_stream.dart';
import 'package:docman/docman.dart';
import 'random_access_source.dart';

/// Android SAF implementation of [RandomAccessSource] using [SafStream].
/// Enables high-performance random-access (seekable) reading of large files
/// directly from content:// URIs without copying them to local storage.
///
/// This implementation uses a 64KB read-ahead buffer to drastically
/// minimize the IPC overhead of MethodChannel operations, collapsing
/// many sequential small reads into a single larger chunk read.
/// It uses a Completer lock to be safely callable concurrently.
class SafRandomAccessSource implements RandomAccessSource {
  final String uri;
  final int bufferSize;
  final _safStream = SafStream();

  int _bufferOffset = -1;
  Uint8List? _buffer;
  Completer<void>? _readLock;

  SafRandomAccessSource(this.uri, {this.bufferSize = 65536});

  @override
  Future<void> open() async {
    // No-op
  }

  @override
  Future<int> get length async {
    final docFile = await DocumentFile.fromUri(uri);
    if (docFile == null) throw Exception('File not found: $uri');
    return docFile.size ?? 0;
  }

  @override
  Future<Uint8List> read(int offset, int length) async {
    while (_readLock != null) {
      await _readLock!.future;
    }
    _readLock = Completer<void>();

    try {
      // For reads larger than the buffer size, skip buffering entirely
      if (length > bufferSize) {
        return await _safStream.readFileBytes(uri, start: offset, count: length);
      }

      // Check if requested range is fully inside the current buffer
      if (_buffer == null || offset < _bufferOffset || (offset + length) > (_bufferOffset + _buffer!.length)) {
        // Buffer Miss: fetch a new block of `bufferSize` bytes
        _bufferOffset = offset;
        _buffer = await _safStream.readFileBytes(uri, start: _bufferOffset, count: bufferSize);
      }

      // Buffer Hit: return sliced copy
      final start = offset - _bufferOffset;
      final end = min(start + length, _buffer!.length);
      if (start >= _buffer!.length) {
        return Uint8List(0); // EOF
      }

      return Uint8List.fromList(_buffer!.sublist(start, end));
    } finally {
      final lock = _readLock!;
      _readLock = null;
      lock.complete();
    }
  }

  @override
  Future<void> close() async {
    _buffer = null;
  }
}
