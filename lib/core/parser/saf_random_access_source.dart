import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'package:saf_stream/saf_stream.dart';
import 'package:docman/docman.dart';
import 'package:hdict/core/utils/logger.dart';
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

  SafRandomAccessSource(this.uri, {this.bufferSize = 262144});

  @override
  Future<void> open() async {
    // No-op
  }

  @override
  Future<int> get length async {
    final stopwatch = Stopwatch()..start();
    final docFile = await DocumentFile.fromUri(uri);
    stopwatch.stop();
    if (docFile == null) throw Exception('File not found: $uri');
    hDebugPrint(
      '[SAF] SafRandomAccessSource.length: size=${docFile.size} time=${stopwatch.elapsedMilliseconds}ms',
    );
    return docFile.size;
  }

  @override
  Future<Uint8List> read(int offset, int length) async {
    while (_readLock != null) {
      await _readLock!.future;
    }
    _readLock = Completer<void>();

    final stopwatch = Stopwatch()..start();
    try {
      // For reads larger than the buffer size, skip buffering entirely
      if (length > bufferSize) {
        final result = await _safStream.readFileBytes(
          uri,
          start: offset,
          count: length,
        );
        stopwatch.stop();
        hDebugPrint(
          '[SAF] SafRandomAccessSource.read: offset=$offset length=$length bufferSkip=true time=${stopwatch.elapsedMilliseconds}ms',
        );
        return result;
      }

      // Check if requested range is fully inside the current buffer
      final bool bufferHit =
          _buffer != null &&
          offset >= _bufferOffset &&
          (offset + length) <= (_bufferOffset + _buffer!.length);
      if (!bufferHit) {
        // Buffer Miss: fetch a new block of `bufferSize` bytes
        _bufferOffset = offset;
        _buffer = await _safStream.readFileBytes(
          uri,
          start: _bufferOffset,
          count: bufferSize,
        );
      }

      // Buffer Hit: return sliced copy
      final start = offset - _bufferOffset;
      final end = min(start + length, _buffer!.length);
      if (start >= _buffer!.length) {
        stopwatch.stop();
        hDebugPrint(
          '[SAF] SafRandomAccessSource.read: offset=$offset length=$length bufferHit=$bufferHit time=${stopwatch.elapsedMilliseconds}ms (EOF)',
        );
        return Uint8List(0); // EOF
      }

      final result = Uint8List.fromList(_buffer!.sublist(start, end));
      stopwatch.stop();
      hDebugPrint(
        '[SAF] SafRandomAccessSource.read: offset=$offset length=$length bufferHit=$bufferHit time=${stopwatch.elapsedMilliseconds}ms',
      );
      return result;
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
