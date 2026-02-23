import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:hdict/core/parser/ifo_parser.dart';
import 'package:hdict/core/parser/idx_parser.dart';
import 'package:hdict/core/parser/syn_parser.dart';
import 'package:hdict/core/parser/dict_reader.dart';
import 'package:hdict/core/utils/html_lookup_wrapper.dart';
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

  group('HtmlLookupWrapper Tests', () {
    test('wrapWords handles Devanagari with marks correctly', () {
      const input = 'शतपत्त्र कमल';
      final output = HtmlLookupWrapper.wrapWords(input);

      // शतपत्त्र should be wrapped as one word including marks
      expect(
        output,
        contains(
          '<a href="look_up:%E0%A4%B6%E0%A4%A4%E0%A4%AA%E0%A4%A4%E0%A5%8D%E0%A4%A4%E0%A5%8D%E0%A4%B0" class="dict-word">शतपत्त्र</a>',
        ),
      );
      expect(
        output,
        contains('<a href="look_up:%E0%A4%95%E0%A4%AE%E0%A4%B2" class="dict-word">कमल</a>'),
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
}
