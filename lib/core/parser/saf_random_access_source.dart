import 'dart:typed_data';
import 'package:saf_stream/saf_stream.dart';
import 'package:docman/docman.dart';
import 'random_access_source.dart';

/// Android SAF implementation of [RandomAccessSource] using [SafStream].
/// Enables high-performance random-access (seekable) reading of large files
/// directly from content:// URIs without copying them to local storage.
class SafRandomAccessSource implements RandomAccessSource {
  final String uri;
  final _safStream = SafStream();
  int? _cachedLength;

  SafRandomAccessSource(this.uri);

  Future<void> _ensureOpen() async {
    if (_cachedLength == null) {
      final docFile = await DocumentFile.fromUri(uri);
      if (docFile == null) throw Exception('File not found: $uri');
      _cachedLength = docFile.size;
    }
  }

  @override
  Future<int> get length async {
    await _ensureOpen();
    return _cachedLength!;
  }

  @override
  Future<Uint8List> read(int offset, int length) async {
    // readFileBytes in saf_stream 2.0.0 acts as a random-access read chunking operation
    return await _safStream.readFileBytes(uri, start: offset, count: length);
  }

  @override
  Future<void> close() async {
    // No explicit session state to clean up for this approach
  }
}

