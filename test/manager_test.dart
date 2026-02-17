import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hdict/core/manager/dictionary_manager.dart';
import 'package:hdict/core/database/database_helper.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class FakePathProviderPlatform extends Fake
    with MockPlatformInterfaceMixin
    implements PathProviderPlatform {
  final Directory tempDir;

  FakePathProviderPlatform(this.tempDir);

  @override
  Future<String?> getApplicationDocumentsPath() async {
    return tempDir.path;
  }

  @override
  Future<String?> getTemporaryPath() async {
    return tempDir.path;
  }
}

void main() {
  late DatabaseHelper dbHelper;
  late DictionaryManager manager;
  late Directory tempDir;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('dict_mgr_test');
    PathProviderPlatform.instance = FakePathProviderPlatform(tempDir);

    dbHelper = DatabaseHelper();
    // Initialize in-memory database for testing
    // Note: DatabaseHelper is a singleton, so we need to be careful.
    // Ideally we'd set the database factory to ffi, which we did.
    // And maybe close it?

    // For this test, we can use a fresh instance logic if possible or just use the singleton.
    // But DatabaseHelper.setDatabase is a visible-for-testing method we can use if we want to mock it.
    // Or we just let it use the file system (tmp).

    manager = DictionaryManager(dbHelper: dbHelper);
  });

  tearDown(() async {
    await tempDir.delete(recursive: true);
  });

  test('importDictionaryStream flows correctly for a valid zip', () async {
    // 1. Create a dummy zip file
    final archive = Archive();
    final ifoContent =
        'StarDict'
        'version=2.4.2\n'
        'bookname=Test Dictionary\n'
        'wordcount=1\n'
        'idxfilesize=10\n'
        'sametypesequence=m\n';

    final idxContent = [0, 0, 0, 0, 0, 0, 0, 0]; // dummy idx
    final dictContent = 'definition';

    archive.addFile(
      ArchiveFile('test.ifo', ifoContent.length, ifoContent.codeUnits),
    );
    archive.addFile(ArchiveFile('test.idx', idxContent.length, idxContent));
    archive.addFile(
      ArchiveFile('test.dict', dictContent.length, dictContent.codeUnits),
    );

    final zipData = ZipEncoder().encode(archive);
    final zipFile = File(p.join(tempDir.path, 'test.zip'));
    await zipFile.writeAsBytes(zipData!);

    // 2. Run import
    final stream = manager.importDictionaryStream(zipFile.path);

    final events = <ImportProgress>[];
    await for (final event in stream) {
      events.add(event);
      debugPrint('Progress: ${event.message} (${event.value})');
    }

    // 3. Verify
    expect(events.last.isCompleted, true);
    expect(events.last.error, null);

    // Check DB
    final dicts = await dbHelper.getDictionaries();
    expect(dicts.length, greaterThanOrEqualTo(1));
    final dict = dicts.last;
    expect(dict['name'], 'Test Dictionary');
  });
}
