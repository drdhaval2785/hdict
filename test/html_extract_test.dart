import 'package:flutter_test/flutter_test.dart';

void main() {
  group('_extractTextFromHtml logic', () {
    String extractTextFromHtml(String html) {
      return html.replaceAll(RegExp(r'<[^>]*>'), '').trim();
    }

    test('strips HTML tags', () {
      expect(extractTextFromHtml('<b>hello</b> world'), 'hello world');
    });

    test('handles nested tags', () {
      expect(
        extractTextFromHtml('<div class="headword"><span>test</span></div>'),
        'test',
      );
    });

    test('returns plain text unchanged', () {
      expect(extractTextFromHtml('plain text'), 'plain text');
    });

    test('trims whitespace', () {
      expect(extractTextFromHtml('  <b>hello</b>  '), 'hello');
    });

    test('handles empty string', () {
      expect(extractTextFromHtml(''), '');
    });

    test('handles text with multiple spaces', () {
      expect(extractTextFromHtml('hello   world'), 'hello   world');
    });

    test('strips headword HTML structure', () {
      expect(extractTextFromHtml('<div class="headword">word</div>'), 'word');
    });

    test('handles complex HTML definitions', () {
      final html =
          '<div class="headword">test</div><p>This is a <b>definition</b> with <i>italic</i> text.</p>';
      expect(
        extractTextFromHtml(html),
        'testThis is a definition with italic text.',
      );
    });
  });
}
