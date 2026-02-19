import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;

/// A parser for StarDict .ifo files (metadata/information).
class IfoParser {
  final Map<String, String> _metadata = {};

  Future<void> parse(String path) async {
    if (kIsWeb) {
      throw UnsupportedError('Use parseContent on Web');
    }
    final file = File(path);
    if (!await file.exists()) {
      throw Exception('IFO file not found: $path');
    }

    final lines = await file.readAsLines();
    _parseLines(lines);
  }

  void parseContent(String content) {
    final lines = content.split(RegExp(r'\r?\n'));
    _parseLines(lines);
  }

  void _parseLines(List<String> lines) {
    _metadata.clear();
    for (var line in lines) {
      final index = line.indexOf('=');
      if (index > 0) {
        final key = line.substring(0, index).trim();
        final value = line.substring(index + 1).trim();
        _metadata[key] = value;
      }
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

  Map<String, String> get metadata => _metadata;

  int get idxOffsetBits =>
      int.tryParse(_metadata['idxoffsetbits'] ?? '32') ?? 32;

  int get synWordCount => int.tryParse(_metadata['synwordcount'] ?? '0') ?? 0;
}
