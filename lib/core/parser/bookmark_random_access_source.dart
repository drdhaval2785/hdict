import 'dart:typed_data';
import 'dart:io';
import 'package:hdict/core/parser/random_access_source.dart';
import 'package:hdict/core/parser/bookmark_manager.dart';
import 'package:path/path.dart' as p;

/// Implementation of [RandomAccessSource] for iOS/macOS security-scoped bookmarks.
class BookmarkRandomAccessSource implements RandomAccessSource {
  final String bookmark;
  final String? targetPath;
  RandomAccessFile? _file;
  String? _resolvedPath;
  int? _length;

  BookmarkRandomAccessSource(this.bookmark, {this.targetPath});

  Future<void> _ensureOpened() async {
    if (_file != null) return;

    _resolvedPath = await BookmarkManager.resolveBookmark(bookmark);
    if (_resolvedPath == null) {
      throw FileSystemException('Could not resolve bookmark', bookmark);
    }

    final String fullPath = targetPath != null 
        ? p.join(_resolvedPath!, targetPath!) 
        : _resolvedPath!;

    final file = File(fullPath);
    if (!await file.exists()) {
      throw FileSystemException('Resolved path does not exist', fullPath);
    }

    _file = await file.open();
    _length = await _file!.length();
  }

  @override
  Future<int> get length async {
    await _ensureOpened();
    return _length!;
  }

  @override
  Future<Uint8List> read(int offset, int length) async {
    await _ensureOpened();
    await _file!.setPosition(offset);
    return await _file!.read(length);
  }

  @override
  Future<void> close() async {
    if (_file != null) {
      await _file!.close();
      _file = null;
      await BookmarkManager.stopAccess(bookmark);
    }
  }
}
