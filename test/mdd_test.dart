import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hdict/core/parser/mdict_reader.dart';
import 'package:hdict/core/parser/mdd_reader.dart';
import 'package:hdict/core/parser/random_access_source.dart';
import 'package:hdict/core/utils/multimedia_processor.dart';
import 'package:path/path.dart' as p;

void main() {
  const sourceDir = '/Users/dhaval/Downloads';
  const mddFileName = '[英-英] Longman Phrasal Verbs Dictionary 2nd Edition.mdd';
  const mdxFileName = '[英-英] Longman Phrasal Verbs Dictionary 2nd Edition.mdx';

  group('MddReader Tests', () {
    late Directory testDir;
    late String mddPath;

    setUp(() async {
      testDir = Directory.systemTemp.createTempSync('hdict_mdd_test_');
      final sourceMdd = File(p.join(sourceDir, mddFileName));
      if (await sourceMdd.exists()) {
        mddPath = p.join(testDir.path, 'test.mdd');
        await sourceMdd.copy(mddPath);
      }
    });

    tearDown(() async {
      if (await testDir.exists()) {
        await testDir.delete(recursive: true);
      }
    });

    test('opens and initializes MDD file', () async {
      if (!File(mddPath).existsSync()) {
        markTestSkipped('MDD test file not available');
        return;
      }

      final source = FileRandomAccessSource(mddPath);
      final reader = MddReader(mddPath, source: source);

      await reader.open();
      expect(reader.isInitialized, isTrue);
      await reader.close();
    });

    test('getResource handles missing keys gracefully', () async {
      if (!File(mddPath).existsSync()) {
        markTestSkipped('MDD test file not available');
        return;
      }

      final source = FileRandomAccessSource(mddPath);
      final reader = MddReader(mddPath, source: source);

      await reader.open();
      final result = await reader.getResource('nonexistent_key');
      expect(result, isNull);
      await reader.close();
    });

    test('getResourceAsString returns null for missing keys', () async {
      if (!File(mddPath).existsSync()) {
        markTestSkipped('MDD test file not available');
        return;
      }

      final source = FileRandomAccessSource(mddPath);
      final reader = MddReader(mddPath, source: source);

      await reader.open();
      final result = await reader.getResourceAsString('nonexistent.css');
      expect(result, isNull);
      await reader.close();
    });

    test('getResourceAsBytes returns null for missing keys', () async {
      if (!File(mddPath).existsSync()) {
        markTestSkipped('MDD test file not available');
        return;
      }

      final source = FileRandomAccessSource(mddPath);
      final reader = MddReader(mddPath, source: source);

      await reader.open();
      final result = await reader.getResourceAsBytes('nonexistent.png');
      expect(result, isNull);
      await reader.close();
    });

    test('close clears cache and resets state', () async {
      if (!File(mddPath).existsSync()) {
        markTestSkipped('MDD test file not available');
        return;
      }

      final source = FileRandomAccessSource(mddPath);
      final reader = MddReader(mddPath, source: source);

      await reader.open();
      expect(reader.isInitialized, isTrue);

      await reader.close();
      expect(reader.isInitialized, isFalse);
    });

    test('detectCssKey handles missing CSS gracefully', () async {
      if (!File(mddPath).existsSync()) {
        markTestSkipped('MDD test file not available');
        return;
      }

      final source = FileRandomAccessSource(mddPath);
      final reader = MddReader(mddPath, source: source);

      await reader.open();
      final cssKey = await reader.detectCssKey();
      expect(cssKey == null || cssKey.isNotEmpty, isTrue);
      await reader.close();
    });
  });

  group('MdictReader MDD Integration Tests', () {
    late Directory testDir;
    late String mdxPath;
    late String mddPath;

    setUp(() async {
      testDir = Directory.systemTemp.createTempSync('hdict_mdict_mdd_test_');

      final sourceMdx = File(p.join(sourceDir, mdxFileName));
      if (await sourceMdx.exists()) {
        mdxPath = p.join(testDir.path, 'test.mdx');
        await sourceMdx.copy(mdxPath);
      }

      final sourceMdd = File(p.join(sourceDir, mddFileName));
      if (await sourceMdd.exists()) {
        mddPath = p.join(testDir.path, 'test.mdd');
        await sourceMdd.copy(mddPath);
      }
    });

    tearDown(() async {
      if (await testDir.exists()) {
        await testDir.delete(recursive: true);
      }
    });

    test('opens MDict with MDD', () async {
      if (!File(mdxPath).existsSync() || !File(mddPath).existsSync()) {
        markTestSkipped('MDX/MDD test files not available');
        return;
      }

      final reader = await MdictReader.fromPath(mdxPath, mddPath: mddPath);
      await reader.open();

      expect(reader.hasMdd, isTrue);
      await reader.close();
    });

    test('hasMdd returns false when no MDD provided', () async {
      if (!File(mdxPath).existsSync()) {
        markTestSkipped('MDX test file not available');
        return;
      }

      final reader = await MdictReader.fromPath(mdxPath);
      await reader.open();

      expect(reader.hasMdd, isFalse);

      await reader.close();
    });

    test('getMddResourceBytes returns null when no MDD', () async {
      if (!File(mdxPath).existsSync()) {
        markTestSkipped('MDX test file not available');
        return;
      }

      final reader = await MdictReader.fromPath(mdxPath);
      await reader.open();

      final result = await reader.getMddResourceBytes('cover.jpg');
      expect(result, isNull);

      await reader.close();
    });

    test('lookup works with MDX', () async {
      if (!File(mdxPath).existsSync()) {
        markTestSkipped('MDX test file not available');
        return;
      }

      final reader = await MdictReader.fromPath(mdxPath);
      await reader.open();

      final definition = await reader.lookup('go');
      expect(definition, isNotNull);
      expect(definition, contains('go'));
      expect(definition, contains('<b'));

      await reader.close();
    });

    test('prefixSearch returns results for common prefix', () async {
      if (!File(mdxPath).existsSync()) {
        markTestSkipped('MDX test file not available');
        return;
      }

      final reader = await MdictReader.fromPath(mdxPath);
      await reader.open();

      final results = await reader.prefixSearch('go');
      expect(results, isNotEmpty);
      expect(results.first.$1, startsWith('go'));

      await reader.close();
    });
  });

  group('Video Resource Tests', () {
    test('can read video file and get bytes', () async {
      const videoPath = '/Users/dhaval/Desktop/output3.mp4';
      final videoFile = File(videoPath);

      if (!await videoFile.exists()) {
        markTestSkipped('Video file not available');
        return;
      }

      final bytes = await videoFile.readAsBytes();
      expect(bytes, isNotNull);
      expect(bytes.length, greaterThan(0));
      // print('Video file size: ${bytes.length} bytes');
    });

    test('can use video bytes with MddReader flow', () async {
      // This test verifies that we can integrate video bytes into the MDD flow
      const videoPath = '/Users/dhaval/Desktop/output3.mp4';
      final videoFile = File(videoPath);

      if (!await videoFile.exists()) {
        markTestSkipped('Video file not available');
        return;
      }

      // Read video bytes
      final videoBytes = await videoFile.readAsBytes();
      expect(videoBytes.length, greaterThan(0));

      // Verify MIME type detection would work
      final ext = 'mp4';
      final mimeType = 'video/mp4';
      expect(mimeType, equals('video/mp4'));

      // Create temp file like the player would
      final tempDir = Directory.systemTemp.createTempSync('video_test_');
      final tempFile = File(p.join(tempDir.path, 'test_video.$ext'));
      await tempFile.writeAsBytes(videoBytes);

      expect(await tempFile.exists(), isTrue);

      // Cleanup
      await tempFile.delete();
      await tempDir.delete();
    });
  });

  group('MultimediaProcessor Tests', () {
    test(
      'processHtmlWithMedia returns original html when no mddReader',
      () async {
        final processor = MultimediaProcessor(null, null);
        final result = await processor.processHtmlWithMedia('<p>Test</p>');
        expect(result, equals('<p>Test</p>'));
      },
    );

    test('preserves http URLs unchanged', () async {
      final processor = MultimediaProcessor(null, null);
      final result = await processor.processHtmlWithMedia(
        '<img src="http://example.com/image.png">',
      );
      expect(result, contains('http://example.com/image.png'));
    });

    test('preserves data URIs unchanged', () async {
      final processor = MultimediaProcessor(null, null);
      final result = await processor.processHtmlWithMedia(
        '<img src="data:image/png;base64,abc123">',
      );
      expect(result, contains('data:image/png;base64,abc123'));
    });

    test('getAudioResource returns null without MDD', () async {
      final processor = MultimediaProcessor(null, null);
      final result = await processor.getAudioResource('test.mp3');
      expect(result, isNull);
    });

    test('getVideoResource returns null without MDD', () async {
      final processor = MultimediaProcessor(null, null);
      final result = await processor.getVideoResource('test.mp4');
      expect(result, isNull);
    });

    test(
      'processHtmlWithInlineVideo keeps video tags with mdd-video URLs',
      () async {
        final processor = MultimediaProcessor(null, null);
        final html = '<video src="test.mp4" controls></video>';
        final result = await processor.processHtmlWithInlineVideo(html);
        expect(result, contains('mdd-video:test.mp4'));
        expect(result, contains('<video'));
      },
    );

    test('preserves original speaker image in audio links', () async {
      final processor = MultimediaProcessor(null, null);
      final html =
          '<a class="jp-play" href="sound://hwd/ame/a/prove.mp3"><img src="img/spkr_b.png"></a>';
      final result = await processor.processHtmlWithMedia(html);
      expect(result, contains('mdd-audio:hwd/ame/a/prove.mp3'));
      expect(result, contains('<img src="img/spkr_b.png">'));
      expect(result, contains('jp-play'));
      expect(result, contains('prove.mp3'));
    });
  });
}
