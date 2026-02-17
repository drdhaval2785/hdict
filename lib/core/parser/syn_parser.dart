import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';

/// A parser for StarDict .syn files.
///
/// The .syn file handles synonyms. It contains:
/// - A null-terminated UTF-8 string (the synonym).
/// - A 32-bit Big Endian index pointing to the original word in the .idx file.
class SynParser {
  /// Parses a StarDict .syn file at [path].
  /// Yields pairs of {'word': synonym, 'original_word_index': index}.
  Stream<Map<String, dynamic>> parse(String path) async* {
    final file = File(path);
    if (!await file.exists()) {
      throw Exception('SYN file not found: $path');
    }

    final bytes = await file.readAsBytes();
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
