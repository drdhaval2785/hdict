import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:hdict/core/utils/folder_scanner.dart';

void main() {
  group('FolderScanner — StarDict', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('hdict_folder_scan_');
    });

    tearDown(() async {
      await tempDir.delete(recursive: true);
    });

    test('detects complete StarDict (ifo + idx + dict)', () async {
      final base = p.join(tempDir.path, 'en-de');
      await File('$base.ifo').create();
      await File('$base.idx').create();
      await File('$base.dict').create();

      final result = await scanFolderForDictionaries(
        tempDir.path,
        extractArchives: false,
      );

      expect(result.discovered.length, 1);
      expect(result.discovered.first.format, 'stardict');
      expect(result.discovered.first.path, endsWith('.ifo'));
      expect(result.incomplete, isEmpty);
    });

    test('detects complete StarDict with .dict.dz instead of .dict', () async {
      final base = p.join(tempDir.path, 'wordnet');
      await File('$base.ifo').create();
      await File('$base.idx').create();
      await File('$base.dict.dz').create();

      final result = await scanFolderForDictionaries(
        tempDir.path,
        extractArchives: false,
      );

      expect(result.discovered.length, 1);
      expect(result.incomplete, isEmpty);
    });

    test('detects complete StarDict with optional .syn file', () async {
      final base = p.join(tempDir.path, 'de-en');
      await File('$base.ifo').create();
      await File('$base.idx').create();
      await File('$base.dict').create();
      await File('$base.syn').create();

      final result = await scanFolderForDictionaries(
        tempDir.path,
        extractArchives: false,
      );

      expect(result.discovered.length, 1);
      expect(result.incomplete, isEmpty);
    });

    test('marks StarDict as incomplete when .idx is missing', () async {
      final base = p.join(tempDir.path, 'broken-dict');
      await File('$base.ifo').create();
      // no .idx
      await File('$base.dict').create();

      final result = await scanFolderForDictionaries(
        tempDir.path,
        extractArchives: false,
      );

      expect(result.discovered, isEmpty);
      expect(result.incomplete.length, 1);
      expect(result.incomplete.first.format, 'stardict');
      expect(result.incomplete.first.missingFiles, contains('.idx'));
    });

    test('marks StarDict as incomplete when .dict is missing', () async {
      final base = p.join(tempDir.path, 'broken-dict2');
      await File('$base.ifo').create();
      await File('$base.idx').create();
      // no .dict

      final result = await scanFolderForDictionaries(
        tempDir.path,
        extractArchives: false,
      );

      expect(result.discovered, isEmpty);
      expect(result.incomplete.length, 1);
      expect(result.incomplete.first.missingFiles, contains('.dict / .dict.dz'));
    });

    test('marks StarDict as incomplete when both .idx and .dict are missing', () async {
      final base = p.join(tempDir.path, 'orphan');
      await File('$base.ifo').create();
      // no .idx, no .dict

      final result = await scanFolderForDictionaries(
        tempDir.path,
        extractArchives: false,
      );

      expect(result.incomplete.first.missingFiles.length, 2);
    });
  });

  group('FolderScanner — MDict', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('hdict_mdict_scan_');
    });

    tearDown(() async => await tempDir.delete(recursive: true));

    test('detects .mdx as complete MDict', () async {
      await File(p.join(tempDir.path, 'oxford.mdx')).create();

      final result = await scanFolderForDictionaries(
        tempDir.path,
        extractArchives: false,
      );

      expect(result.discovered.length, 1);
      expect(result.discovered.first.format, 'mdict');
      expect(result.incomplete, isEmpty);
    });

    test('companion .mdd does not generate a separate discovered entry', () async {
      await File(p.join(tempDir.path, 'oxford.mdx')).create();
      await File(p.join(tempDir.path, 'oxford.mdd')).create();

      final result = await scanFolderForDictionaries(
        tempDir.path,
        extractArchives: false,
      );

      // Only the .mdx should appear; .mdd is a companion, not its own entry
      expect(result.discovered.length, 1);
      expect(result.discovered.first.format, 'mdict');
    });
  });

  group('FolderScanner — Slob', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('hdict_slob_scan_');
    });

    tearDown(() async => await tempDir.delete(recursive: true));

    test('detects .slob as complete Slob dictionary', () async {
      await File(p.join(tempDir.path, 'wikipedia.slob')).create();

      final result = await scanFolderForDictionaries(
        tempDir.path,
        extractArchives: false,
      );

      expect(result.discovered.length, 1);
      expect(result.discovered.first.format, 'slob');
      expect(result.incomplete, isEmpty);
    });
  });

  group('FolderScanner — DICTD', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('hdict_dictd_scan_');
    });

    tearDown(() async => await tempDir.delete(recursive: true));

    test('detects complete DICTD (.index + .dict)', () async {
      final base = p.join(tempDir.path, 'gcide');
      await File('$base.index').create();
      await File('$base.dict').create();

      final result = await scanFolderForDictionaries(
        tempDir.path,
        extractArchives: false,
      );

      expect(result.discovered.length, 1);
      expect(result.discovered.first.format, 'dictd');
      expect(result.discovered.first.companionPath, endsWith('.dict'));
      expect(result.incomplete, isEmpty);
    });

    test('detects complete DICTD with .dict.dz companion', () async {
      final base = p.join(tempDir.path, 'gcide');
      await File('$base.index').create();
      await File('$base.dict.dz').create();

      final result = await scanFolderForDictionaries(
        tempDir.path,
        extractArchives: false,
      );

      expect(result.discovered.length, 1);
      expect(result.discovered.first.companionPath, endsWith('.dict.dz'));
    });

    test('marks DICTD as incomplete when .dict is missing', () async {
      final base = p.join(tempDir.path, 'gcide');
      await File('$base.index').create();
      // no .dict or .dict.dz

      final result = await scanFolderForDictionaries(
        tempDir.path,
        extractArchives: false,
      );

      expect(result.discovered, isEmpty);
      expect(result.incomplete.length, 1);
      expect(result.incomplete.first.format, 'dictd');
      expect(result.incomplete.first.missingFiles, contains('.dict / .dict.dz'));
    });
  });

  group('FolderScanner — Nested directories', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('hdict_nested_scan_');
    });

    tearDown(() async => await tempDir.delete(recursive: true));

    test('finds StarDict inside a subdirectory', () async {
      final subDir = Directory(p.join(tempDir.path, 'subdir', 'inner'));
      await subDir.create(recursive: true);
      final base = p.join(subDir.path, 'mydict');
      await File('$base.ifo').create();
      await File('$base.idx').create();
      await File('$base.dict').create();

      final result = await scanFolderForDictionaries(
        tempDir.path,
        extractArchives: false,
      );

      expect(result.discovered.length, 1);
      expect(result.discovered.first.format, 'stardict');
    });

    test('finds MDict and Slob inside subdirectories', () async {
      final subA = Directory(p.join(tempDir.path, 'mdict_dir'));
      final subB = Directory(p.join(tempDir.path, 'slob_dir'));
      await subA.create();
      await subB.create();
      await File(p.join(subA.path, 'oxford.mdx')).create();
      await File(p.join(subB.path, 'wiki.slob')).create();

      final result = await scanFolderForDictionaries(
        tempDir.path,
        extractArchives: false,
      );

      expect(result.discovered.length, 2);
      final formats = result.discovered.map((d) => d.format).toList();
      expect(formats, containsAll(['mdict', 'slob']));
    });
  });

  group('FolderScanner — Mixed valid and incomplete', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('hdict_mixed_scan_');
    });

    tearDown(() async => await tempDir.delete(recursive: true));

    test('correctly splits complete and incomplete entries', () async {
      // Complete StarDict
      final base1 = p.join(tempDir.path, 'complete');
      await File('$base1.ifo').create();
      await File('$base1.idx').create();
      await File('$base1.dict').create();

      // Complete MDict
      await File(p.join(tempDir.path, 'oxford.mdx')).create();

      // Incomplete StarDict (missing .idx)
      final base2 = p.join(tempDir.path, 'incomplete');
      await File('$base2.ifo').create();
      await File('$base2.dict').create();

      // Complete Slob
      await File(p.join(tempDir.path, 'wiki.slob')).create();

      // Incomplete DICTD (no .dict)
      await File(p.join(tempDir.path, 'gcide.index')).create();

      final result = await scanFolderForDictionaries(
        tempDir.path,
        extractArchives: false,
      );

      // 3 complete: StarDict, MDict, Slob
      expect(result.discovered.length, 3);
      // 2 incomplete: StarDict (missing .idx) and DICTD (missing .dict)
      expect(result.incomplete.length, 2);
    });
  });

  group('FolderScanner — Multiple dictionaries in same folder', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('hdict_multi_scan_');
    });

    tearDown(() async => await tempDir.delete(recursive: true));

    test('discovers multiple StarDicts with distinct stems', () async {
      for (final name in ['en-de', 'de-en', 'en-fr']) {
        final base = p.join(tempDir.path, name);
        await File('$base.ifo').create();
        await File('$base.idx').create();
        await File('$base.dict').create();
      }

      final result = await scanFolderForDictionaries(
        tempDir.path,
        extractArchives: false,
      );

      expect(result.discovered.length, 3);
      expect(result.incomplete, isEmpty);
    });
  });

  group('FolderScanner — IncompleteDict human-readable details', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('hdict_details_scan_');
    });

    tearDown(() async => await tempDir.delete(recursive: true));

    test('IncompleteDict has correct name and format', () async {
      await File(p.join(tempDir.path, 'mydict.ifo')).create();
      // missing .idx and .dict

      final result = await scanFolderForDictionaries(
        tempDir.path,
        extractArchives: false,
      );

      expect(result.incomplete.length, 1);
      expect(result.incomplete.first.name, 'mydict');
      expect(result.incomplete.first.format, 'stardict');
      expect(result.incomplete.first.missingFiles.length, 2);
    });
  });
}
