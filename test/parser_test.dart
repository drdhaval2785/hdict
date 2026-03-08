import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:hdict/core/parser/ifo_parser.dart';
import 'package:hdict/core/parser/idx_parser.dart';
import 'package:hdict/core/parser/syn_parser.dart';
import 'package:hdict/core/parser/dict_reader.dart';
import 'package:dictd_reader/dictd_reader.dart';
import 'package:hdict/core/utils/html_lookup_wrapper.dart';
import 'package:dictzip_reader/dictzip_reader.dart';
import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;

void main() {
  group('Dictionary Parser Tests', () {
    late Directory tempDir;
    late String ifoPath;
    late String idxPath;
    late String dictPath;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('hdict_test_');
      ifoPath = p.join(tempDir.path, 'test.ifo');
      idxPath = p.join(tempDir.path, 'test.idx');
      dictPath = p.join(tempDir.path, 'test.dict');

      // Create .ifo
      await File(ifoPath).writeAsString('''
StarDict's dict ifo file
version=2.4.2
wordcount=2
idxfilesize=100
bookname=Test Dictionary
idxoffsetbits=32
author=Tester
''');

      // Create .dict (Data)
      final dictFile = File(dictPath);
      await dictFile.writeAsString('hello worlddefinition of test');
      // "hello world" (11 bytes), "definition of test" (18 bytes)

      // Create .idx (Index)
      // Entry 1: word="hello", offset=0, size=11
      // Entry 2: word="test", offset=11, size=18
      final idxFile = File(idxPath);
      final bytes = BytesBuilder();

      // Entry 1
      bytes.add('hello'.codeUnits);
      bytes.addByte(0); // null terminator
      // Offset (32-bit big endian) = 0
      bytes.add([0, 0, 0, 0]);
      // Size (32-bit big endian) = 11
      bytes.add([0, 0, 0, 11]);

      // Entry 2
      bytes.add('test'.codeUnits);
      bytes.addByte(0);
      // Offset = 11
      bytes.add([0, 0, 0, 11]);
      // Size = 18
      bytes.add([0, 0, 0, 18]);

      await idxFile.writeAsBytes(bytes.toBytes());
    });

    tearDown(() async {
      await tempDir.delete(recursive: true);
    });

    test('IfoParser parses metadata correctly', () async {
      final parser = IfoParser();
      await parser.parse(ifoPath);

      expect(parser.version, '2.4.2');
      expect(parser.bookName, 'Test Dictionary');
      expect(parser.wordCount, 2);
      expect(parser.author, 'Tester');
      expect(parser.idxOffsetBits, 32);
    });

    test('IdxParser parses entries correctly', () async {
      final ifo = IfoParser();
      await ifo.parse(ifoPath);

      final idx = IdxParser(ifo);
      final entries = await idx.parse(idxPath).toList();

      expect(entries.length, 2);

      expect(entries[0]['word'], 'hello');
      expect(entries[0]['offset'], 0);
      expect(entries[0]['length'], 11);

      expect(entries[1]['word'], 'test');
      expect(entries[1]['offset'], 11);
      expect(entries[1]['length'], 18);
    });

    test('DictReader reads data correctly', () async {
      final reader = DictReader(dictPath);

      // Read Entry 1
      final def1 = await reader.readEntry(0, 11);
      expect(def1, 'hello world');

      // Read Entry 2
      final def2 = await reader.readEntry(11, 18);
      expect(def2, 'definition of test');
    });

    test('SynParser parses synonyms correctly', () async {
      final synPath = p.join(tempDir.path, 'test.syn');
      final bytes = BytesBuilder();

      // Synonym: "hi", Original Word Index: 0
      bytes.add('hi'.codeUnits);
      bytes.addByte(0);
      bytes.add([0, 0, 0, 0]);

      // Synonym: "exam", Original Word Index: 1
      bytes.add('exam'.codeUnits);
      bytes.addByte(0);
      bytes.add([0, 0, 0, 1]);

      await File(synPath).writeAsBytes(bytes.toBytes());

      final parser = SynParser();
      final synonyms = await parser.parse(synPath).toList();

      expect(synonyms.length, 2);
      expect(synonyms[0]['word'], 'hi');
      expect(synonyms[0]['original_word_index'], 0);
      expect(synonyms[1]['word'], 'exam');
      expect(synonyms[1]['original_word_index'], 1);
    });
  });

  // ── DICTD Parser Tests ──────────────────────────────────────────────────────

  group('DictdParser Tests', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('hdict_dictd_test_');
    });

    tearDown(() async {
      await tempDir.delete(recursive: true);
    });

    test('DictdParser decodes base64 integers from byte stream', () async {
      // DICTD base64 alphabet: ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/
      // 'A'=0, 'L'=11, 'S'=18
      final parser = DictdParser();
      final indexContent = 'hello\tA\tL\ntest\tL\tS\n';
      final bytes = Uint8List.fromList(indexContent.codeUnits);
      final entries = await parser.parseIndexFromBytes(bytes).toList();

      expect(entries.length, 2);
      expect(entries[0]['word'], 'hello');
      expect(entries[0]['offset'], 0);
      expect(entries[0]['length'], 11);
      expect(entries[1]['word'], 'test');
      expect(entries[1]['offset'], 11);
      expect(entries[1]['length'], 18);
    });

    test('DictdParser parseIndex reads .index file from disk', () async {
      final indexPath = p.join(tempDir.path, 'test.index');
      // 'A'=0, 'L'=11, 'S'=18
      await File(indexPath).writeAsString('hello\tA\tL\ntest\tL\tS\n');

      final parser = DictdParser();
      final entries = await parser.parseIndex(indexPath).toList();

      expect(entries.length, 2);
      expect(entries[0]['word'], 'hello');
      expect(entries[0]['offset'], 0);
      expect(entries[0]['length'], 11);
    });

    test('DictdReader reads definition from .dict file', () async {
      final dictFilePath = p.join(tempDir.path, 'test.dict');
      await File(dictFilePath).writeAsString('hello worlddefinition of test');

      final reader = DictdReader(dictFilePath);
      final def1 = await reader.readEntry(0, 11);
      expect(def1, 'hello world');

      final def2 = await reader.readEntry(11, 18);
      expect(def2, 'definition of test');
    });

  });


  // ── HtmlLookupWrapper Tests ─────────────────────────────────────────────────

  group('HtmlLookupWrapper Tests', () {
    test('wrapWords handles Devanagari with marks correctly', () {
      const input = 'शतपत्त्र कमल';
      final output = HtmlLookupWrapper.wrapWords(input);

      // शतपत्त्र should be wrapped as one word including marks
      expect(
        output,
        contains(
          '<a href="look_up:शतपत्त्र" class="dict-word">शतपत्त्र</a>',
        ),
      );
      expect(
        output,
        contains('<a href="look_up:कमल" class="dict-word">कमल</a>'),
      );
    });

    test('wrapWords preserves line breaks as <br>', () {
      const input = 'line1\nline2';
      final output = HtmlLookupWrapper.wrapWords(input);

      expect(output, contains('line1</a><br>'));
      expect(output, contains('line2</a>'));
    });

    test('wrapWords handles URI encoding for special characters', () {
      const input = 'word#1';
      final output = HtmlLookupWrapper.wrapWords(input);

      // # is not \p{L}\p{N}\p{M}, so it should be a boundary
      expect(
        output,
        contains('<a href="look_up:word" class="dict-word">word</a>#<a href="look_up:1" class="dict-word">1</a>'),
      );
    });
  });

  // ── DictzipReader Tests ───────────────────────────────────────────────────

  group('DictzipReader Tests', () {
    late Directory tempDir;
    late String dzPath;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('hdict_dz_test_');
      dzPath = p.join(tempDir.path, 'test.dict.dz');
    });

    tearDown(() async {
      await tempDir.delete(recursive: true);
    });

    Future<void> createDictZip(String path, String data, int chunkLen) async {
      final content = utf8.encode(data);
      final List<Uint8List> chunks = [];
      final List<int> compressedSizes = [];

      for (int i = 0; i < content.length; i += chunkLen) {
        int end = (i + chunkLen < content.length) ? i + chunkLen : content.length;
        final chunkData = content.sublist(i, end);
        // Create raw deflate data by stripping ZLib header (2 bytes) and trailer (4 bytes)
        final zlib = ZLibEncoder().encode(chunkData);
        final rawCompressed = zlib.sublist(2, zlib.length - 4);
        chunks.add(Uint8List.fromList(rawCompressed));
        compressedSizes.add(rawCompressed.length);
      }

      final builder = BytesBuilder(copy: false);
      // GZIP Header: ID1, ID2, CM (8), FLG (FEXTRA=4), MTIME(4), XFL, OS
      builder.add([0x1f, 0x8b, 0x08, 0x04, 0, 0, 0, 0, 0, 0]);

      // Extra Field
      final raSubfield = BytesBuilder(copy: false);
      raSubfield.add([0x52, 0x41]); // 'R', 'A'
      final raLen = 6 + compressedSizes.length * 2;
      final bdRaLen = ByteData(2)..setUint16(0, raLen, Endian.little);
      raSubfield.add(Uint8List.view(bdRaLen.buffer));
      raSubfield.add([0x01, 0x00]); // version 1
      final bdChLen = ByteData(2)..setUint16(0, chunkLen, Endian.little);
      raSubfield.add(Uint8List.view(bdChLen.buffer));
      final bdChCnt = ByteData(2)..setUint16(0, compressedSizes.length, Endian.little);
      raSubfield.add(Uint8List.view(bdChCnt.buffer));
      for (final size in compressedSizes) {
        final bdSize = ByteData(2)..setUint16(0, size, Endian.little);
        raSubfield.add(Uint8List.view(bdSize.buffer));
      }

      final raBytes = raSubfield.toBytes();
      final bdExtraLen = ByteData(2)..setUint16(0, raBytes.length, Endian.little);
      builder.add(Uint8List.view(bdExtraLen.buffer));
      builder.add(raBytes);

      // Compressed Data
      for (final chunk in chunks) {
        builder.add(chunk);
      }

      await File(path).writeAsBytes(builder.toBytes());
    }

    test('DictzipReader reads single chunk correctly', () async {
      const data = 'hello world';
      await createDictZip(dzPath, data, 100);

      final reader = DictzipReader(dzPath);
      await reader.open();
      final result = await reader.read(0, 5);
      expect(result, 'hello');
      final result2 = await reader.read(6, 5);
      expect(result2, 'world');
      await reader.close();
    });

    test('DictzipReader reads across multiple chunks correctly', () async {
      // Create data that spans 3 chunks (chunk size 5)
      // "01234" "56789" "abcde"
      const data = '0123456789abcde';
      await createDictZip(dzPath, data, 5);

      final reader = DictzipReader(dzPath);
      await reader.open();

      // Read middle of chunk 1 to middle of chunk 2
      // skip 2 bytes ("01"), read 8 bytes -> "23456789"
      final result = await reader.read(2, 8);
      expect(result, '23456789');

      // Read from chunk 1 to end
      final result2 = await reader.read(7, 8);
      expect(result2, '789abcde');

      await reader.close();
    });

    test('DictReader delegates to DictzipReader for .dz files', () async {
      const data = 'delegation test';
      await createDictZip(dzPath, data, 100);

      final reader = DictReader(dzPath);
      await reader.open();
      final result = await reader.readAtIndex(0, 10);
      expect(result, 'delegation');
      await reader.close();
    });
  });
}
