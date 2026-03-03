import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'package:archive/archive.dart';

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
/// final reader = DictzipReader('/path/to/file.dict.dz');
/// await reader.open();
/// final text = await reader.read(offset, length);
/// await reader.close();
/// ```
class DictzipReader {
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

  DictzipReader(this.path);

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

  /// Closes the file.
  Future<void> close() async {
    await _raf?.close();
    _raf = null;
    _opened = false;
  }

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Reads [length] bytes starting at uncompressed [offset], returning UTF-8 text.
  ///
  /// Decompresses only the chunks that overlap the requested range.
  Future<String> read(int offset, int length) async {
    if (!_opened) throw StateError('DictzipReader not opened. Call open() first.');
    final bytes = await _readBytes(offset, length);
    return utf8.decode(bytes, allowMalformed: true);
  }

  // ---------------------------------------------------------------------------
  // Header Parsing
  // ---------------------------------------------------------------------------

  /// Reads the gzip header from the file and extracts dictzip RA metadata.
  ///
  /// Gzip header layout (RFC 1952):
  ///   0-1   ID magic   (0x1f, 0x8b)
  ///   2     CM         (must be 8 = deflate)
  ///   3     FLG        (flags)
  ///   4-7   MTIME
  ///   8     XFL
  ///   9     OS
  ///   if FLG.FEXTRA (bit 2):
  ///     10-11  XLEN (LE uint16)
  ///     12..   extra field (contains RA subfield)
  ///   if FLG.FNAME  (bit 3): null-terminated string
  ///   if FLG.FCOMMENT (bit 4): null-terminated string
  ///   if FLG.FHCRC (bit 1): 2-byte CRC
  /// → data starts here
  Future<void> _parseHeader() async {
    final raf = _raf!;

    // Read the first 10 bytes (fixed gzip header).
    final header = await raf.read(10);
    if (header.length < 10) throw FormatException('File too short to be a valid gzip/dictzip file.');
    if (header[0] != 0x1f || header[1] != 0x8b) {
      throw FormatException('Not a gzip file (bad magic bytes): $path');
    }
    // header[2] = CM (8 = deflate) — we don't enforce this to be lenient.
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

    // ── FNAME ─────────────────────────────────────────────────────────────────
    if (flags & flagFNAME != 0) {
      await _skipNullTerminated(raf);
    }

    // ── FCOMMENT ──────────────────────────────────────────────────────────────
    if (flags & flagFCOMMENT != 0) {
      await _skipNullTerminated(raf);
    }

    // ── FHCRC ─────────────────────────────────────────────────────────────────
    if (flags & flagFHCRC != 0) {
      await raf.read(2); // skip CRC16
    }

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

  /// Parses the gzip Extra Field, looking for the 'RA' (Random Access) subfield.
  ///
  /// Extra field consists of variable-length subfields:
  ///   2 bytes  SI1, SI2  (subfield ID)
  ///   2 bytes  LEN (LE uint16)
  ///   LEN bytes data
  ///
  /// The RA subfield data:
  ///   2 bytes  version   (must be 1)
  ///   2 bytes  CHLEN     (uncompressed chunk size, LE uint16)
  ///   2 bytes  CHCNT     (number of chunks, LE uint16)
  ///   CHCNT × 2 bytes  compressed size of each chunk (LE uint16)
  void _parseExtraField(Uint8List extra) {
    int i = 0;
    while (i + 4 <= extra.length) {
      final si1 = extra[i];
      final si2 = extra[i + 1];
      final subLen = ByteData.sublistView(extra, i + 2, i + 4).getUint16(0, Endian.little);
      i += 4;

      if (si1 == 0x52 && si2 == 0x41) {
        // 'R' = 0x52, 'A' = 0x41 — this is the RA subfield.
        if (i + 6 > extra.length) break;
        final bd = ByteData.sublistView(extra, i, i + subLen);
        // version = bd.getUint16(0, Endian.little); // typically 1
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
    // RA subfield not found — _chunkLen remains 0, caller will throw.
  }

  /// Skips bytes until a null byte (0x00) is consumed.
  Future<void> _skipNullTerminated(RandomAccessFile raf) async {
    while (true) {
      final b = await raf.read(1);
      if (b.isEmpty || b[0] == 0) break;
    }
  }

  // ---------------------------------------------------------------------------
  // Chunk-based reading
  // ---------------------------------------------------------------------------

  Future<List<int>> _readBytes(int offset, int length) async {
    if (length <= 0) return [];

    final firstChunk = offset ~/ _chunkLen;
    final lastChunk  = (offset + length - 1) ~/ _chunkLen;
    final totalChunks = lastChunk - firstChunk + 1;

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

    final fileOffset  = _chunkFileOffsets[chunkIndex];
    final compressed  = _chunkCompressedSizes[chunkIndex];

    await _raf!.setPosition(fileOffset);
    final raw = await _raf!.read(compressed);

    // Raw inflate — no gzip / zlib header, just deflate stream.
    return ZLibDecoder().decodeBytes(raw, raw: true);
  }
}
