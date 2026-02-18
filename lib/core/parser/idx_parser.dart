import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'package:hdict/core/parser/ifo_parser.dart';

/// A parser for StarDict .idx files.
///
/// The .idx file contains a list of headwords, each followed by:
/// - A null-terminated UTF-8 string (the word).
/// - An offset in the .dict file (32-bit or 64-bit).
/// - A length of the data in the .dict file (32-bit).
class IdxParser {
  final IfoParser ifo;

  IdxParser(this.ifo);

  /// Parses the .idx file at [path] and yields a stream of word entries.
  /// Each entry is a map containing: 'word', 'offset', and 'length'.
  Stream<Map<String, dynamic>> parse(String path) async* {
    final file = File(path);
    if (!await file.exists()) {
      throw Exception('IDX file not found: $path');
    }

    final bytes = await file.readAsBytes();
    int offsetBits = 32;
    if (ifo.idxOffsetBits == 64) {
      offsetBits = 64;
    }

    int i = 0;
    final len = bytes.length;

    // Helper to read C-string
    // Optimization: scanning for 0 byte directly
    while (i < len) {
      int start = i;
      while (i < len && bytes[i] != 0) {
        i++;
      }

      if (i >= len) break;

      String word = utf8.decode(bytes.sublist(start, i), allowMalformed: true);
      i++; // skip null terminator

      if (i + (offsetBits ~/ 8) + 4 > len) break; // formatting error check

      int dataOffset;
      int dataSize;

      // Read Offset
      final bd = ByteData.sublistView(bytes, i, i + (offsetBits ~/ 8) + 4);
      if (offsetBits == 64) {
        dataOffset = bd.getUint64(0, Endian.big);
        i += 8;
      } else {
        dataOffset = bd.getUint32(0, Endian.big);
        i += 4;
      }

      // Read Size
      dataSize = bd.getUint32(offsetBits == 64 ? 8 : 4, Endian.big);
      // Wait, if I read sublist, index is 0-based relative to sublist.
      // Correct logic:
      // if 64-bit: offset at 0 (8 bytes), size at 8 (4 bytes) -> total 12 bytes
      // if 32-bit: offset at 0 (4 bytes), size at 4 (4 bytes) -> total 8 bytes

      // But verify Endianness. StarDict is usually Big Endian (Network byte order).

      if (offsetBits == 64) {
        i += 4; // consumed size
      } else {
        i += 4; // consumed size
      }

      yield {'word': word, 'offset': dataOffset, 'length': dataSize};
    }
  }
}
