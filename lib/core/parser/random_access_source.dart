import 'package:slob_reader/slob_reader.dart' as slob;

import 'package:dictzip_reader/dictzip_reader.dart' as dictzip;
import 'package:dictd_reader/dictd_reader.dart' as dictd;
import 'dart:typed_data';
import 'dart:io';

/// Abstract source that provides random-access read capability.
/// This matches the interface expected by slob_reader, dictd_reader, and dictzip_reader.
abstract class RandomAccessSource
    implements
        slob.RandomAccessSource,
        dictzip.RandomAccessSource,
        dictd.RandomAccessSource {
  /// Reads [length] bytes starting at [offset].
  @override
  Future<Uint8List> read(int offset, int length);

  /// Returns the total size of the data source in bytes.
  @override
  Future<int> get length;

  /// Releases any system resources.
  @override
  Future<void> close();
}

/// Default implementation for local files using dart:io.
class FileRandomAccessSource implements RandomAccessSource {
  final String path;
  RandomAccessFile? _file;
  int? _cachedLength;

  FileRandomAccessSource(this.path);

  Future<void> _ensureOpen() async {
    if (_file == null) {
      final f = File(path);
      if (!await f.exists()) {
        throw FileSystemException('File not found', path);
      }
      _file = await f.open(mode: FileMode.read);
      _cachedLength = await _file!.length();
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
    await _file!.setPosition(offset);
    return await _file!.read(length);
  }

  @override
  Future<void> close() async {
    await _file?.close();
    _file = null;
  }
}
