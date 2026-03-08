import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'dart:collection';

/// Parses and reads from a dictzip (`.dict.dz`) file without fully decompressing it.
///
/// Dictzip is a gzip variant that stores a Random Access (RA) chunk index in
/// the gzip Extra Field. The uncompressed data is divided into fixed-size
/// chunks (CHLEN bytes each), each chunk independently deflated. This allows
/// efficient random access: only the chunk(s) covering the requested byte
/// range need to be decompressed.
///
/// Usage:
/// ```dart
/// final reader = DictzipLocalReader('/path/to/file.dict.dz');
/// await reader.open();
/// final text = await reader.read(offset, length);
/// await reader.close();
/// ```
class DictzipLocalReader {
  final String path;

  RandomAccessFile? _raf;

  /// Uncompressed size of each chunk (CHLEN from RA header).
  int _chunkLen = 0;

  /// Compressed size of each chunk (from RA header).
  late List<int> _chunkCompressedSizes;

  /// Cumulative byte offsets into the file for each chunk's compressed data.
  late List<int> _chunkFileOffsets;

  /// File position where the first compressed chunk begins (after gzip header).
  int _dataOffset = 0;

  bool _opened = false;

  /// LRU Cache for decompressed chunks to prevent redundant CPU cycles.
  final int _maxCacheSize = 4;
  final LinkedHashMap<int, List<int>> _chunkCache = LinkedHashMap<int, List<int>>();

  DictzipLocalReader(this.path);

  // ---------------------------------------------------------------------------
  // Open / Close
  // ---------------------------------------------------------------------------

  /// Opens the file and parses the dictzip header.
  ///
  /// Must be called before [read].
  Future<void> open() async {
    _raf = await File(path).open(mode: FileMode.read);
    await _parseHeader();
    _opened = true;
  }

  /// Closes the file and clears the chunk cache.
  Future<void> close() async {
    await _raf?.close();
    _raf = null;
    _opened = false;
    _chunkCache.clear();
  }

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Reads [length] bytes starting at uncompressed [offset], returning UTF-8 text.
  ///
  /// Decompresses only the chunks that overlap the requested range.
  Future<String> read(int offset, int length) async {
    final bytes = await readBytes(offset, length);
    return utf8.decode(bytes, allowMalformed: true);
  }

  /// Reads [length] bytes starting at uncompressed [offset], returning the raw bytes.
  ///
  /// Decompresses only the chunks that overlap the requested range.
  Future<List<int>> readBytes(int offset, int length) async {
    if (!_opened) throw StateError('DictzipLocalReader not opened. Call open() first.');
    return _readBytes(offset, length);
  }

  // ---------------------------------------------------------------------------
  // Header Parsing
  // ---------------------------------------------------------------------------

  Future<void> _parseHeader() async {
    final raf = _raf!;

    // Read the first 10 bytes (fixed gzip header).
    final header = await raf.read(10);
    if (header.length < 10) throw FormatException('File too short to be a valid gzip/dictzip file.');
    if (header[0] != 0x1f || header[1] != 0x8b) {
      throw FormatException('Not a gzip file (bad magic bytes): $path');
    }
    final flags = header[3];

    const flagFHCRC    = 0x02;
    const flagFEXTRA   = 0x04;
    const flagFNAME    = 0x08;
    const flagFCOMMENT = 0x10;

    // ── FEXTRA ────────────────────────────────────────────────────────────────
    if (flags & flagFEXTRA != 0) {
      final xlenBytes = await raf.read(2);
      final xlen = ByteData.sublistView(Uint8List.fromList(xlenBytes)).getUint16(0, Endian.little);
      final extraBytes = await raf.read(xlen);
      _parseExtraField(Uint8List.fromList(extraBytes));
    }

    if (flags & flagFNAME != 0) await _skipNullTerminated(raf);
    if (flags & flagFCOMMENT != 0) await _skipNullTerminated(raf);
    if (flags & flagFHCRC != 0) await raf.read(2); // skip CRC16

    _dataOffset = await raf.position();

    if (_chunkLen == 0) {
      throw FormatException('Not a dictzip file: missing RA extra subfield in $path');
    }

    // Build cumulative file offsets for each chunk.
    _chunkFileOffsets = List<int>.filled(_chunkCompressedSizes.length + 1, 0);
    int pos = _dataOffset;
    for (int i = 0; i < _chunkCompressedSizes.length; i++) {
      _chunkFileOffsets[i] = pos;
      pos += _chunkCompressedSizes[i];
    }
    _chunkFileOffsets[_chunkCompressedSizes.length] = pos;
  }

  void _parseExtraField(Uint8List extra) {
    int i = 0;
    while (i + 4 <= extra.length) {
      final si1 = extra[i];
      final si2 = extra[i + 1];
      final subLen = ByteData.sublistView(extra, i + 2, i + 4).getUint16(0, Endian.little);
      i += 4;

      if (si1 == 0x52 && si2 == 0x41) {
        if (i + 6 > extra.length) break;
        final bd = ByteData.sublistView(extra, i, i + subLen);
        _chunkLen  = bd.getUint16(2, Endian.little);
        final chcnt = bd.getUint16(4, Endian.little);
        _chunkCompressedSizes = List<int>.filled(chcnt, 0);
        for (int c = 0; c < chcnt; c++) {
          _chunkCompressedSizes[c] = bd.getUint16(6 + c * 2, Endian.little);
        }
        return;
      }

      i += subLen;
    }
  }

  Future<void> _skipNullTerminated(RandomAccessFile raf) async {
    while (true) {
      final b = await raf.read(64);
      if (b.isEmpty) break;
      final zeroIndex = b.indexOf(0);
      if (zeroIndex != -1) {
        // We found the null terminator. Seek back to right after it.
        await raf.setPosition(await raf.position() - (b.length - 1 - zeroIndex));
        break;
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Chunk-based reading with LRU Cache
  // ---------------------------------------------------------------------------

  Future<List<int>> _readBytes(int offset, int length) async {
    if (length <= 0) return [];

    final firstChunk = offset ~/ _chunkLen;
    final lastChunk  = (offset + length - 1) ~/ _chunkLen;

    // Decompress all needed chunks into a contiguous buffer.
    final buffer = <int>[];
    for (int ci = firstChunk; ci <= lastChunk; ci++) {
      buffer.addAll(await _decompressChunk(ci));
    }

    // Slice out the requested range.
    final startInBuffer = offset - firstChunk * _chunkLen;
    final end = startInBuffer + length;
    if (end > buffer.length) {
      // Clamp gracefully if the file is shorter than expected.
      return buffer.sublist(startInBuffer, buffer.length);
    }
    return buffer.sublist(startInBuffer, end);
  }

  Future<List<int>> _decompressChunk(int chunkIndex) async {
    if (chunkIndex >= _chunkCompressedSizes.length) return [];

    // Cache Hit: Move to MRU position and return immediately
    if (_chunkCache.containsKey(chunkIndex)) {
      final cachedValue = _chunkCache.remove(chunkIndex)!;
      _chunkCache[chunkIndex] = cachedValue;
      return cachedValue;
    }

    // Cache Miss: Read from disk and inflate
    final fileOffset  = _chunkFileOffsets[chunkIndex];
    final compressed  = _chunkCompressedSizes[chunkIndex];

    await _raf!.setPosition(fileOffset);
    final raw = await _raf!.read(compressed);

    // Raw inflate — no gzip / zlib header, just deflate stream.
    final decompressed = ZLibDecoder(raw: true).convert(raw);

    // Store in cache
    _chunkCache[chunkIndex] = decompressed;
    // Evict oldest if exceeding limit
    if (_chunkCache.length > _maxCacheSize) {
      _chunkCache.remove(_chunkCache.keys.first);
    }

    return decompressed;
  }
}
