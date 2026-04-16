import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:hdict/core/parser/mdict_reader.dart';
import 'package:hdict/core/parser/random_access_source.dart';

class MockMdxSource extends RandomAccessSource {
  final Uint8List data;
  MockMdxSource(this.data);

  @override
  Future<Uint8List> read(int pos, int len) async {
    if (pos >= data.length) return Uint8List(0);
    int actualLen = (pos + len > data.length) ? data.length - pos : len;
    return data.sublist(pos, pos + actualLen);
  }

  @override
  Future<int> get length async => data.length;

  @override
  Future<void> open() async {}

  @override
  Future<void> close() async {}
}

void main() {
  group('MdictReader Tests', () {
    test('MdictReader initialization with mock header', () async {
      // Create a minimal MDX header
      // 4 bytes size + content
      const headerContent =
          '<root Encoding="UTF-8" GeneratedByEngineVersion="2.0" Encrypted="No"/>\u0000\u0000';
      final headerBytes = Uint8List.fromList(headerContent.codeUnits);
      final sizeBytes = ByteData(4)
        ..setUint32(0, headerBytes.length, Endian.big);

      final mockData = Uint8List.fromList([
        ...sizeBytes.buffer.asUint8List(),
        ...headerBytes,
      ]);
      final source = MockMdxSource(mockData);

      final reader = MdictReader('test.mdx', source: source);

      // We can't fully initialize because it tries to read key blocks next,
      // but we can at least verify it parses the header if we call a method that triggers it.
      // Since it's a wrapper, we might need to mock MdxParser instead for deeper logic,
      // but this confirms the wrapper accepts the source.

      expect(reader.mdxPath, 'test.mdx');
      expect(reader.source, source);
    });

    test('MdictReader fromPath uses FileRandomAccessSource', () async {
      // This test just verifies the factory doesn't crash on construction (it doesn't open the file)
      final reader = await MdictReader.fromPath('dummy.mdx');
      expect(reader.mdxPath, 'dummy.mdx');
      expect(reader.source, isA<FileRandomAccessSource>());
    });

    test('MdictReader hasMdd and mddReady properties', () async {
      // Test that hasMdd and mddReady return false when no MDD is provided
      final reader = await MdictReader.fromPath('dummy.mdx');
      expect(reader.hasMdd, isFalse);
      expect(reader.mddReady, isFalse);
    });

    test('MdictReader cssContent returns null when no MDD', () async {
      final reader = await MdictReader.fromPath('dummy.mdx');
      expect(reader.cssContent, isNull);
    });
  });
}
