import 'package:flutter_test/flutter_test.dart';
import 'package:hdict/core/utils/html_lookup_wrapper.dart';

void main() {
  group('HtmlLookupWrapper Tests', () {
    test('processRecord preserves HTML entities while highlighting', () {
      const input = 'doctor&apos;s bill &amp; AT&T';
      final output = HtmlLookupWrapper.processRecord(
        html: input,
        format: 'html',
        underlineQuery: 'doctor',
      );
      
      expect(output, contains('&apos;'));
      expect(output, contains('&amp;'));
      expect(output, contains('<mark>doctor</mark>'));
    });

    test('highlightText utility preserves HTML entities', () {
      const input = 'doctor&apos;s';
      final output = HtmlLookupWrapper.highlightText(input, 'doctor');
      expect(output, contains('<mark>doctor</mark>&apos;s'));
    });
  });
}
