import 'dart:typed_data';
import 'package:saf_stream/saf_stream.dart';
import 'package:docman/docman.dart';
import 'random_access_source.dart';

/// Android SAF implementation of [RandomAccessSource] using [SafStream].
/// Enables high-performance random-access (seekable) reading of large files
/// directly from content:// URIs without copying them to local storage.
///
/// Note: We deliberately do NOT call [DocumentFile.fromUri] here.
/// That is a docman MethodChannel call that must be globally serialized to
/// avoid the "AlreadyRunning" crash. saf_stream.readFileBytes handles
/// offset+length reads without any prior open/metadata call, so this class
/// is completely stateless and safe to call concurrently.
class SafRandomAccessSource implements RandomAccessSource {
  final String uri;
  final _safStream = SafStream();

  SafRandomAccessSource(this.uri);

  @override
  Future<void> open() async {
    // No-op: saf_stream.readFileBytes handles partially-ranged reads without
    // a prior open. DocumentFile.fromUri would require global SAF serialization.
  }

  @override
  Future<int> get length async {
    // This is only called by format parsers (like IfoParser, IdxParser, DictdParser)
    // during the sequential dictionary import process, NEVER during concurrent search
    // (since dictzip uses its own header parsing and never calls source.length).
    // Therefore, making a docman call here is safe and won't trigger the AlreadyRunning crash.
    final docFile = await DocumentFile.fromUri(uri);
    if (docFile == null) throw Exception('File not found: $uri');
    return docFile.size ?? 0;
  }

  @override
  Future<Uint8List> read(int offset, int length) async {
    return await _safStream.readFileBytes(uri, start: offset, count: length);
  }

  @override
  Future<void> close() async {
    // No explicit session state to clean up.
  }
}
