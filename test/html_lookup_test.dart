import 'package:flutter_test/flutter_test.dart';
import 'package:hdict/core/utils/html_lookup_wrapper.dart';

void main() {
  group('HtmlLookupWrapper Tests', () {
    test('wrapWords preserves HTML entities', () {
      const input = 'doctor&apos;s bill &amp; AT&T';
      final output = HtmlLookupWrapper.wrapWords(input);
      
      // It should NOT wrap 'apos' as a word.
      // It should wrap 'doctor', 's', 'bill', 'AT', 'T'
      expect(output, contains('&apos;'));
      expect(output, contains('&amp;'));
      expect(output, isNot(contains('>apos<')));
      expect(output, isNot(contains('>amp<')));
    });

    test('highlightText preserves HTML entities', () {
      const input = 'doctor&apos;s';
      final output = HtmlLookupWrapper.highlightText(input, 'doctor');
      expect(output, contains('<mark>doctor</mark>&apos;s'));
    });
  });
}
