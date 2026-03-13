import 'package:flutter_test/flutter_test.dart';
import 'package:hdict/core/utils/word_boundary.dart';

void main() {
  group('WordBoundary Tests', () {
    test('detects basic ASCII words', () {
      const text = 'hello world';
      expect(WordBoundary.wordAt(text, 0), 'hello');
      expect(WordBoundary.wordAt(text, 2), 'hello');
      expect(WordBoundary.wordAt(text, 4), 'hello');
      expect(WordBoundary.wordAt(text, 5), null); // space
      expect(WordBoundary.wordAt(text, 6), 'world');
      expect(WordBoundary.wordAt(text, 10), 'world');
    });

    test('detects words with diacritics', () {
      const text = 'résumé café namaḥ svāhā';
      expect(WordBoundary.wordAt(text, 0), 'résumé');
      expect(WordBoundary.wordAt(text, 1), 'résumé');
      expect(WordBoundary.wordAt(text, 6), null); // space
      expect(WordBoundary.wordAt(text, 7), 'café');
      expect(WordBoundary.wordAt(text, 12), 'namaḥ');
      expect(WordBoundary.wordAt(text, 18), 'svāhā');
    });

    test('detects Devanagari words', () {
      const text = 'नमस्ते दुनिया';
      expect(WordBoundary.wordAt(text, 0), 'नमस्ते');
      expect(WordBoundary.wordAt(text, 3), 'नमस्ते');
      expect(WordBoundary.wordAt(text, 6), null); // space
      expect(WordBoundary.wordAt(text, 7), 'दुनिया');
    });

    test('respects punctuation boundaries', () {
      const text = 'word, punctuation. "quote" - dash — emdash';
      expect(WordBoundary.wordAt(text, 0), 'word');
      expect(WordBoundary.wordAt(text, 4), null); // comma
      expect(WordBoundary.wordAt(text, 6), 'punctuation');
      expect(WordBoundary.wordAt(text, 17), null); // dot
      expect(WordBoundary.wordAt(text, 20), 'quote');
      expect(WordBoundary.wordAt(text, 27), null); // dash
      expect(WordBoundary.wordAt(text, 34), null); // emdash
    });

    test('handles edge offsets', () {
      const text = 'abc';
      expect(WordBoundary.wordAt(text, -1), null);
      expect(WordBoundary.wordAt(text, 3), null);
      expect(WordBoundary.wordAt(text, 0), 'abc');
      expect(WordBoundary.wordAt(text, 2), 'abc');
    });

    test('handles empty string', () {
      expect(WordBoundary.wordAt('', 0), null);
    });
  });
}
