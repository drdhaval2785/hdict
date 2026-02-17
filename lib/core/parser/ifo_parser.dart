import 'dart:io';

/// A parser for StarDict .ifo files (metadata/information).
///
/// The .ifo file contains key-value pairs (e.g., version=2.4.2) that describe
/// the dictionary's properties, such as word count and index file offset bits.
class IfoParser {
  final Map<String, String> _metadata = {};

  Future<void> parse(String path) async {
    final file = File(path);
    if (!await file.exists()) {
      throw Exception('IFO file not found: $path');
    }

    final lines = await file.readAsLines();
    for (var line in lines) {
      final index = line.indexOf('=');
      if (index > 0) {
        final key = line.substring(0, index).trim();
        final value = line.substring(index + 1).trim();
        _metadata[key] = value;
      }
    }

    // Validate required fields (optional but good for robustness)
    if (!_metadata.containsKey('version')) {
      // warning or error?
    }
  }

  String? get version => _metadata['version'];
  String? get bookName => _metadata['bookname'];
  int get wordCount => int.tryParse(_metadata['wordcount'] ?? '0') ?? 0;
  int get idxFileSize => int.tryParse(_metadata['idxfilesize'] ?? '0') ?? 0;
  String? get author => _metadata['author'];
  String? get email => _metadata['email'];
  String? get website => _metadata['website'];
  String? get description => _metadata['description'];
  String? get date => _metadata['date'];
  String? get sameTypeSequence => _metadata['sametypesequence'];

  // Expose metadata for extensions or debugging
  Map<String, String> get metadata => _metadata;

  int get idxOffsetBits =>
      int.tryParse(_metadata['idxoffsetbits'] ?? '32') ?? 32;

  int get synWordCount => int.tryParse(_metadata['synwordcount'] ?? '0') ?? 0;
}
