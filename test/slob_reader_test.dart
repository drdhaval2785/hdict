import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hdict/core/parser/slob_reader.dart';


void main() {
  group('SlobReader Tests', () {
    // We use a real slob file from the dependency override project for integration testing
    final slobPath = '/Users/dhaval/Documents/FlutterProjects/slob_test/abc.slob';

    test('SlobReader opens and reads content correctly', () async {
      if (!File(slobPath).existsSync()) {
        markTestSkipped('abc.slob not found at $slobPath');
        return;
      }

      final reader = await SlobReader.fromPath(slobPath);
      try {
        await reader.open();
        expect(reader.blobCount, greaterThan(0));
        expect(reader.bookName, isNotEmpty);

        // Test O(1) lookup if we know an index (e.g. 0)
        final content = await reader.getBlobContent(0);
        expect(content, isNotNull);
        expect(content, isNotEmpty);

        // Test lookup (O(N) but should work for small files or first entries)
        final firstBlob = await reader.getBlob(0);
        if (firstBlob != null) {
          final lookupContent = await reader.lookup(firstBlob.key);
          expect(lookupContent, equals(content));
        }
      } finally {
        await reader.close();
      }
    });

    test('SlobReader getBlobsByRange reads multiple blobs', () async {
      if (!File(slobPath).existsSync()) return;

      final reader = await SlobReader.fromPath(slobPath);
      try {
        await reader.open();
        final count = reader.blobCount > 5 ? 5 : reader.blobCount;
        final blobs = await reader.getBlobsByRange(0, count);
        expect(blobs.length, equals(count));
      } finally {
        await reader.close();
      }
    });
  });
}
