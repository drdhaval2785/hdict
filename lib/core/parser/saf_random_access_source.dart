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
  final String? name;
  final int bufferSize;
  final _safStream = SafStream();

  // Global memory tracking for all SAF sources
  static int _totalMemoryUsed = 0;
  static const int _maxTotalMemory = 500 * 1024 * 1024; // 500 MB limit
  static const int _maxPerFileMemory = 50 * 1024 * 1024; // 50 MB per file limit

  int _bufferOffset = -1;
  Uint8List? _buffer;
  bool _isFullFileInMemory = false;
  Completer<void>? _readLock;

  /// Whether the entire file is currently cached in memory.
  bool get isFullFileInMemory => _isFullFileInMemory;

  SafRandomAccessSource(
    this.uri, {
    this.name,
    this.bufferSize = 5242880,
  }); // 5MB buffer for better prefetch

  @override
  Future<void> open() async {
    final stopwatch = Stopwatch()..start();
    final docFile = await DocumentFile.fromUri(uri);
    final size = docFile?.size ?? 0;

    // Check if we can fit the whole file in memory
    if (size > 0 &&
        size <= _maxPerFileMemory &&
        (_totalMemoryUsed + size) <= _maxTotalMemory) {
      _bufferOffset = 0;
      _buffer = await _safStream.readFileBytes(uri, start: 0, count: size);
      _isFullFileInMemory = true;
      _totalMemoryUsed += size;

      stopwatch.stop();
      hDebugPrint(
        '[SAF${name != null ? ": $name" : ""}] Loaded FULL FILE into memory: size=$size totalMemoryUsed=${(_totalMemoryUsed / 1024 / 1024).toStringAsFixed(1)}MB time=${stopwatch.elapsedMilliseconds}ms',
      );
    } else {
      // Fallback to existing 5MB pre-fetch logic
      _bufferOffset = 0;
      _buffer = await _safStream.readFileBytes(
        uri,
        start: 0,
        count: bufferSize,
      );
      _isFullFileInMemory = false;

      stopwatch.stop();
      hDebugPrint(
        '[SAF${name != null ? ": $name" : ""}] Pre-filled 5MB buffer: size=$size isLarge=${size > _maxPerFileMemory} time=${stopwatch.elapsedMilliseconds}ms',
      );
    }
  }

  @override
  Future<int> get length async {
    final stopwatch = Stopwatch()..start();
    final docFile = await DocumentFile.fromUri(uri);
    stopwatch.stop();
    if (docFile == null) throw Exception('File not found: $uri');
    hDebugPrint(
      '[SAF${name != null ? ": $name" : ""}] SafRandomAccessSource.length: size=${docFile.size} time=${stopwatch.elapsedMilliseconds}ms',
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
      // If full file is in memory, always a hit
      if (_isFullFileInMemory && _buffer != null) {
        final start = max(0, offset);
        final end = min(start + length, _buffer!.length);
        final result = Uint8List.fromList(_buffer!.sublist(start, end));
        stopwatch.stop();
        hDebugPrint(
          '[SAF${name != null ? ": $name" : ""}] SafRandomAccessSource.read (FULL): offset=$offset length=$length time=${stopwatch.elapsedMilliseconds}ms',
        );
        return result;
      }

      // For reads larger than the buffer size, skip buffering entirely
      if (length > bufferSize) {
        final result = await _safStream.readFileBytes(
          uri,
          start: offset,
          count: length,
        );
        stopwatch.stop();
        hDebugPrint(
          '[SAF${name != null ? ": $name" : ""}] SafRandomAccessSource.read: offset=$offset length=$length bufferSkip=true time=${stopwatch.elapsedMilliseconds}ms',
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
          '[SAF${name != null ? ": $name" : ""}] SafRandomAccessSource.read: offset=$offset length=$length bufferHit=$bufferHit time=${stopwatch.elapsedMilliseconds}ms (EOF)',
        );
        return Uint8List(0); // EOF
      }

      final result = Uint8List.fromList(_buffer!.sublist(start, end));
      stopwatch.stop();
      hDebugPrint(
        '[SAF${name != null ? ": $name" : ""}] SafRandomAccessSource.read: offset=$offset length=$length bufferHit=$bufferHit time=${stopwatch.elapsedMilliseconds}ms',
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
    if (_isFullFileInMemory && _buffer != null) {
      _totalMemoryUsed = max(0, _totalMemoryUsed - _buffer!.length);
    }
    _buffer = null;
    _isFullFileInMemory = false;
  }
}
