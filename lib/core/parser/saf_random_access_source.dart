import 'dart:typed_data';
import 'package:saf_stream/saf_stream.dart';
import 'random_access_source.dart';

/// Android SAF implementation of [RandomAccessSource] using [SafStream].
/// Enables high-performance random-access (seekable) reading of large files
/// directly from content:// URIs without copying them to local storage.
class SafRandomAccessSource implements RandomAccessSource {
  final String uri;
  final _safStream = SafStream();
  String? _sessionId;
  int? _cachedLength;

  SafRandomAccessSource(this.uri);

  Future<void> _ensureOpen() async {
    if (_sessionId == null) {
      // Note: In saf_stream, startFileStream returns a unique session ID
      // that manages the native-side file descriptor.
      _sessionId = await _safStream.startFileStream(uri);
      _cachedLength = await _safStream.getFileStreamLength(_sessionId!);
    }
  }

  @override
  Future<int> get length async {
    await _ensureOpen();
    return _cachedLength!;
  }

  @override
  Future<Uint8List> read(int offset, int length) async {
    await _ensureOpen();
    // readFileStreamChunk performs native-side seek + read.
    return await _safStream.readFileStreamChunk(_sessionId!, offset, length);
  }

  @override
  Future<void> close() async {
    if (_sessionId != null) {
      await _safStream.stopFileStream(_sessionId!);
      _sessionId = null;
    }
  }
}
