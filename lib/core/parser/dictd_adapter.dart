import 'dart:typed_data';
import 'package:dictd_reader/dictd_reader.dart' as dd;
import 'package:dictzip_reader/dictzip_reader.dart' as dz;

/// Adapts a [dz.RandomAccessSource] to be used where a [dd.RandomAccessSource] is expected.
/// This is necessary because both dictd_reader and dictzip_reader define their own 
/// RandomAccessSource interfaces which, while identical, are not type-compatible in Dart.
class DictdSourceAdapter implements dd.RandomAccessSource, dz.RandomAccessSource {
  final dz.RandomAccessSource source;

  DictdSourceAdapter(this.source);

  @override
  Future<int> get length => source.length;

  @override
  Future<Uint8List> read(int offset, int length) => source.read(offset, length);

  @override
  Future<void> open() => source.open();

  @override
  Future<void> close() => source.close();
}
