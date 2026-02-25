import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;

/// Pure Dart reader for the Slob (.slob) dictionary format.
///
/// Slob (Sorted List Of Blobs) is an open, compressed, read-only dictionary
/// format. Spec: https://github.com/itkach/slob
///
/// File layout:
///   - Fixed MAGIC + UUID + encoding + compression + tags + content_types
///   - block_count (4 bytes) + ref_count (8 bytes, though spec says 4)
///   - Ref table: sorted list of (key_len: u16, key: UTF-8, bin_index: u32, item_index: u16)
///   - Store section:
///     - data_offset: absolute position of store data
///     - bin_count (4 bytes)
///     - Bin offsets: bin_count * 8-byte absolute positions
///     - Bin data: each bin is (compressed_size: 4 bytes, content: zlib-compressed)
///       where content is N items: (item_length: 4 bytes, content_type_index: u8, data: bytes)
class SlobReader {
  static const String _magic = 'aard2.slob\x00';

  final String path;
  RandomAccessFile? _raf;

  // Parsed header fields
  String _encoding = 'utf-8';
  String _compression = 'zlib';
  late int _refCount;
  late int _refOffset; // file position where refs start
  late int _storeOffset; // file position of store section header
  late int _binCount;
  late List<int> _binAbsoluteOffsets; // absolute file offsets for each bin
  List<String> _contentTypes = [];

  SlobReader(this.path);

  /// Opens and parses the Slob file header.
  Future<void> open() async {
    if (kIsWeb) throw UnsupportedError('SlobReader is not supported on Web.');
    _raf = await File(path).open(mode: FileMode.read);
    await _parseHeader();
  }

  Future<void> close() async {
    await _raf?.close();
    _raf = null;
  }

  // ── Header parsing ────────────────────────────────────────────────────────

  Future<void> _parseHeader() async {
    final raf = _raf!;

    // 1. Magic bytes (11 bytes)
    final magicBytes = await raf.read(11);
    final magic = latin1.decode(magicBytes);
    if (magic != _magic) {
      throw Exception('Invalid Slob file: wrong magic bytes');
    }

    // 2. UUID (16 bytes) — skip
    await raf.read(16);

    // 3. Encoding (u8 length-prefixed UTF-8 string)
    _encoding = await _readSmallString(raf);

    // 4. Compression (u8 length-prefixed UTF-8 string)
    _compression = await _readSmallString(raf);

    // 5. Tags (u8 count, then key-value pairs of u8-prefixed strings)
    final tagCount = (await raf.read(1))[0];
    for (int i = 0; i < tagCount; i++) {
      await _readSmallString(raf); // key
      await _readSmallString(raf); // value
    }

    // 6. Content types (u8 count, then u8-prefixed strings)
    final ctCount = (await raf.read(1))[0];
    _contentTypes = [];
    for (int i = 0; i < ctCount; i++) {
      _contentTypes.add(await _readSmallString(raf));
    }

    // 7. blob_count (u32 big-endian) — total number of bins in store
    _binCount = await _readUint32BE(raf);

    // 8. store_offset (u64 big-endian) — absolute file position of store section
    _storeOffset = await _readUint64BE(raf);

    // 9. size (u64 big-endian) — total file size (we can ignore)
    await raf.read(8);

    // 10. ref_count (u32 big-endian)
    _refCount = await _readUint32BE(raf);

    // Current position is the start of the ref table
    _refOffset = await raf.position();

    // ── Parse store section header ──────────────────────────────────────────
    await raf.setPosition(_storeOffset);

    // Compression type for store (u8-prefixed string) — should match _compression
    await _readSmallString(raf); // store compression tag (can reuse)

    // bin_count in store (u32)
    final storeBinCount = await _readUint32BE(raf);
    // This should equal _binCount; use it for building offsets list.

    // Read bin offsets: storeBinCount * u64 absolute offsets
    _binAbsoluteOffsets = [];
    for (int i = 0; i < storeBinCount; i++) {
      _binAbsoluteOffsets.add(await _readUint64BE(raf));
    }
  }

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Streams all headword keys from the ref table.
  Stream<String> getAllKeys() async* {
    if (kIsWeb) throw UnsupportedError('SlobReader is not supported on Web.');
    final raf = _raf!;
    await raf.setPosition(_refOffset);

    for (int i = 0; i < _refCount; i++) {
      // Each ref: key (u16-prefixed UTF-8), bin_index (u32), item_index (u16), fragment (u8-prefixed)
      final keyLen = await _readUint16BE(raf);
      final keyBytes = await raf.read(keyLen);
      final key = utf8.decode(keyBytes, allowMalformed: true);
      await raf.read(4); // bin_index
      await raf.read(2); // item_index
      await _readSmallString(raf); // fragment
      yield key;
    }
  }

  /// Returns ref entries as maps with `word`, `bin_index`, `item_index`.
  /// Used during import to build the word index.
  Stream<Map<String, dynamic>> getAllRefs() async* {
    if (kIsWeb) throw UnsupportedError('SlobReader is not supported on Web.');
    final raf = _raf!;
    await raf.setPosition(_refOffset);

    for (int i = 0; i < _refCount; i++) {
      final keyLen = await _readUint16BE(raf);
      final keyBytes = await raf.read(keyLen);
      final key = utf8.decode(keyBytes, allowMalformed: true);
      final binIndex = await _readUint32BE(raf);
      final itemIndex = await _readUint16BE(raf);
      await _readSmallString(raf); // fragment (usually empty)
      yield {
        'word': key,
        'bin_index': binIndex,
        'item_index': itemIndex,
      };
    }
  }

  /// Looks up the definition for the given [binIndex] and [itemIndex].
  ///
  /// Returns the definition as a String (HTML or plain text depending on
  /// the content type stored in the Slob file).
  Future<String?> readItem(int binIndex, int itemIndex) async {
    if (kIsWeb) throw UnsupportedError('SlobReader is not supported on Web.');
    if (binIndex >= _binAbsoluteOffsets.length) return null;

    final raf = _raf!;
    final binAbsoluteOffset = _binAbsoluteOffsets[binIndex];
    await raf.setPosition(binAbsoluteOffset);

    // Read item count (u32) and compressed content size (u32)
    final itemCount = await _readUint32BE(raf);
    if (itemIndex >= itemCount) return null;
    final compressedSize = await _readUint32BE(raf);
    final compressedBytes = await raf.read(compressedSize);

    // Decompress the bin
    late List<int> binData;
    if (_compression == 'zlib' || _compression == '') {
      binData = _decompressZlib(compressedBytes);
    } else if (_compression == 'lzma2' || _compression == 'xz') {
      // LZMA2/XZ is not supported in dart:convert or archive (without native libs).
      // Return a meaningful error message so the user sees it in-app.
      return '<p><i>Definition unavailable: LZMA2 compression not supported.</i></p>';
    } else {
      // No compression or unknown — treat as raw
      binData = compressedBytes;
    }

    // Parse items from decompressed bin
    // Each item: content_type_index (u8), length (u32), data (bytes)
    int pos = 0;
    for (int idx = 0; idx < itemCount; idx++) {
      if (pos >= binData.length) break;
      final contentTypeIndex = binData[pos];
      pos++;
      if (pos + 4 > binData.length) break;
      final itemLen = ByteData.sublistView(
        Uint8List.fromList(binData),
        pos,
        pos + 4,
      ).getUint32(0, Endian.big);
      pos += 4;
      if (pos + itemLen > binData.length) break;
      final itemData = binData.sublist(pos, pos + itemLen);
      pos += itemLen;

      if (idx == itemIndex) {
        // Determine encoding from content type
        final contentType = contentTypeIndex < _contentTypes.length
            ? _contentTypes[contentTypeIndex]
            : '';
        if (contentType.contains('html') || contentType.contains('text')) {
          return utf8.decode(itemData, allowMalformed: true);
        } else {
          // Binary content (e.g. images) — not renderable as text
          return null;
        }
      }
    }

    return null;
  }

  // ── Private helpers ────────────────────────────────────────────────────────

  List<int> _decompressZlib(List<int> bytes) {
    try {
      // dart:io's `zlib` codec can decode both raw deflate and zlib-wrapped data
      return zlib.decode(bytes);
    } catch (_) {
      // Some slobs use raw deflate without the zlib wrapper; fall back to identity
      return bytes;
    }
  }

  /// Reads a u8-length-prefixed UTF-8 string.
  Future<String> _readSmallString(RandomAccessFile raf) async {
    final lenBytes = await raf.read(1);
    if (lenBytes.isEmpty) return '';
    final len = lenBytes[0];
    if (len == 0) return '';
    final bytes = await raf.read(len);
    return utf8.decode(bytes, allowMalformed: true);
  }

  Future<int> _readUint16BE(RandomAccessFile raf) async {
    final bytes = await raf.read(2);
    return ByteData.sublistView(Uint8List.fromList(bytes)).getUint16(0, Endian.big);
  }

  Future<int> _readUint32BE(RandomAccessFile raf) async {
    final bytes = await raf.read(4);
    return ByteData.sublistView(Uint8List.fromList(bytes)).getUint32(0, Endian.big);
  }

  Future<int> _readUint64BE(RandomAccessFile raf) async {
    final bytes = await raf.read(8);
    final bd = ByteData.sublistView(Uint8List.fromList(bytes));
    // Dart ints are 64-bit on VM; handle as two 32-bit halves
    final hi = bd.getUint32(0, Endian.big);
    final lo = bd.getUint32(4, Endian.big);
    return (hi * 0x100000000) + lo;
  }
}
