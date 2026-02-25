import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:archive/archive.dart';

/// Parser for the DICTD dictionary format.
///
/// A DICTD dictionary consists of:
///   - A `.index` file: a sorted tab-delimited text file, one line per entry:
///       `word\tbase64_offset\tbase64_length`
///     where offset/length are base64-encoded big-endian 32-bit integers
///     pointing into the `.dict` (or `.dict.dz`) file.
///   - A `.dict` file: plain UTF-8 text containing definitions.
///   - An optional `.dict.dz` file: the dict file compressed with dictzip
///     (a gzip variant with a seek table), which can be fully decompressed
///     up front using the `archive` package's GZipDecoder.
///
/// This parser fully decompresses `.dict.dz` at import time into a `.dict`
/// file for efficient random-access reads via [DictdReader].
class DictdParser {
  /// Parses a DICTD `.index` file and yields map entries with:
  ///   - `word`: the headword string
  ///   - `offset`: byte offset in the `.dict` file (int)
  ///   - `length`: byte length of the definition (int)
  ///
  /// Web is not supported.
  Stream<Map<String, dynamic>> parseIndex(String indexPath) async* {
    if (kIsWeb) throw UnsupportedError('DictdParser is not supported on Web.');
    final file = File(indexPath);
    if (!await file.exists()) throw Exception('DICTD .index file not found: $indexPath');

    final lines = await file.readAsLines(encoding: utf8);
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      final parts = trimmed.split('\t');
      if (parts.length < 3) continue;

      final word = parts[0];
      final offsetB64 = parts[1];
      final lengthB64 = parts[2];

      try {
        final offset = _decodeBase64Int(offsetB64);
        final length = _decodeBase64Int(lengthB64);
        yield {'word': word, 'offset': offset, 'length': length};
      } catch (e) {
        // Skip malformed entries
        continue;
      }
    }
  }

  /// Parses a DICTD `.index` file from raw [bytes].
  Stream<Map<String, dynamic>> parseIndexFromBytes(Uint8List bytes) async* {
    final content = utf8.decode(bytes, allowMalformed: true);
    final lines = content.split('\n');
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      final parts = trimmed.split('\t');
      if (parts.length < 3) continue;

      final word = parts[0];
      final offsetB64 = parts[1];
      final lengthB64 = parts[2];

      try {
        final offset = _decodeBase64Int(offsetB64);
        final length = _decodeBase64Int(lengthB64);
        yield {'word': word, 'offset': offset, 'length': length};
      } catch (_) {
        continue;
      }
    }
  }

  /// Decodes a DICTD base64-encoded integer.
  ///
  /// DICTD uses a custom base64 alphabet:
  ///   ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/
  /// This is the standard RFC 4648 base64 — each character represents 6 bits
  /// of a big-endian integer. The integer is then the numeric offset/size.
  int _decodeBase64Int(String s) {
    const alphabet =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
    int result = 0;
    for (final char in s.split('')) {
      final idx = alphabet.indexOf(char);
      if (idx < 0) throw FormatException('Invalid base64 char: $char');
      result = result * 64 + idx;
    }
    return result;
  }

  /// Fully decompresses a `.dict.dz` (dictzip / gzip) file to a `.dict` file.
  ///
  /// Returns the path to the decompressed `.dict` file.
  /// If [dictPath] already ends in `.dict` (not `.dz`), returns it unchanged.
  Future<String> maybeDecompressDictZ(String dictPath) async {
    if (kIsWeb) throw UnsupportedError('DictdParser is not supported on Web.');
    if (!dictPath.endsWith('.dz') && !dictPath.endsWith('.gz')) return dictPath;

    // Strip the compression extension to get the target path
    final target = dictPath.endsWith('.dz')
        ? dictPath.substring(0, dictPath.length - 3) // .dict.dz → .dict
        : dictPath.substring(0, dictPath.length - 3); // .dict.gz → .dict

    if (await File(target).exists()) return target;

    final bytes = await File(dictPath).readAsBytes();
    final decompressed = GZipDecoder().decodeBytes(bytes);
    await File(target).writeAsBytes(decompressed);
    return target;
  }
}

/// Reads definitions from a DICTD `.dict` file using stored offsets/lengths.
class DictdReader {
  final String dictPath;
  RandomAccessFile? _raf;

  DictdReader(this.dictPath);

  /// Opens the `.dict` file for repeated random-access reads.
  Future<void> open() async {
    if (kIsWeb) throw UnsupportedError('DictdReader is not supported on Web.');
    _raf = await File(dictPath).open(mode: FileMode.read);
  }

  /// Reads the definition at [offset] with [length] bytes.
  Future<String> readAtOffset(int offset, int length) async {
    if (kIsWeb) throw UnsupportedError('DictdReader is not supported on Web.');
    if (_raf == null) throw StateError('DictdReader not opened.');
    await _raf!.setPosition(offset);
    final bytes = await _raf!.read(length);
    return utf8.decode(bytes, allowMalformed: true);
  }

  /// One-shot read without keeping the file open.
  Future<String> readEntry(int offset, int length) async {
    if (kIsWeb) throw UnsupportedError('DictdReader is not supported on Web.');
    final raf = await File(dictPath).open(mode: FileMode.read);
    try {
      await raf.setPosition(offset);
      final bytes = await raf.read(length);
      return utf8.decode(bytes, allowMalformed: true);
    } finally {
      await raf.close();
    }
  }

  Future<void> close() async {
    await _raf?.close();
    _raf = null;
  }
}
