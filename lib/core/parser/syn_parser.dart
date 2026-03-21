import 'package:hdict/core/parser/random_access_source.dart';
import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;

/// A parser for StarDict .syn files.
///
/// The .syn file handles synonyms. It contains:
/// - A null-terminated UTF-8 string (the synonym).
/// - A 32-bit Big Endian index pointing to the original word in the .idx file.
class SynParser {
  /// Parses a StarDict .syn file.
  /// Yields pairs of {'word': synonym, 'original_word_index': index}.
  Stream<Map<String, dynamic>> parse(RandomAccessSource source) async* {
    if (kIsWeb) {
      throw UnsupportedError('Use parseFromBytes on Web');
    }
    
    final length = await source.length;
    final bytes = await source.read(0, length);
    yield* parseFromBytes(bytes);
  }

  /// Parses a StarDict .syn file from bytes.
  Stream<Map<String, dynamic>> parseFromBytes(Uint8List bytes) async* {
    int i = 0;
    final len = bytes.length;

    while (i < len) {
      int start = i;
      while (i < len && bytes[i] != 0) {
        i++;
      }

      if (i >= len) break;

      String word = utf8.decode(bytes.sublist(start, i), allowMalformed: true);
      i++; // skip null terminator

      if (i + 4 > len) break; // formatting error check

      final bd = ByteData.sublistView(bytes, i, i + 4);
      int originalIndex = bd.getUint32(0, Endian.big);
      i += 4;

      yield {'word': word, 'original_word_index': originalIndex};
    }
  }
}
