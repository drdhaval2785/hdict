import 'package:flutter_test/flutter_test.dart';
import 'package:hdict/features/home/home_screen.dart';

void main() {
  group('HomeScreen.normalizeWhitespace Tests', () {
    test('HTML dictionary normalization (mdict)', () {
      const input = '  <div>  Hello  \n  World  </div>  ';
      final output = HomeScreen.normalizeWhitespace(input, format: 'mdict');
      expect(output, '<div> Hello World </div>');
    });

    test('HTML dictionary normalization (stardict with h/x)', () {
      const input = '  <p>  Test  \n  </p>  ';
      final output = HomeScreen.normalizeWhitespace(input, format: 'stardict', typeSequence: 'h');
      expect(output, '<p> Test </p>');
    });

    test('Plain text dictionary normalization (stardict with m/t)', () {
      const input = 'line1\nline2\n\nline4  extra  spaces';
      final output = HomeScreen.normalizeWhitespace(input, format: 'stardict', typeSequence: 'm');
      // Should preserve newlines as <br> and collapse other spaces
      expect(output, 'line1<br>line2<br><br>line4 extra spaces');
    });

    test('Mixed newlines normalization', () {
      const input = 'A\r\nB\n\r\nC';
      final output = HomeScreen.normalizeWhitespace(input, format: 'stardict', typeSequence: 't');
      expect(output, 'A<br>B<br><br>C');
    });

    test('StarDict tag conversion to spans', () {
      const input = '<k>head</k> <custom>text</custom> <b>bold</b>';
      final output = HomeScreen.normalizeWhitespace(input, format: 'stardict', typeSequence: 'h');
      // <b> should stay, others should be converted
      expect(output, '<span class="hdict-k">head</span> <span class="hdict-custom">text</span> <b>bold</b>');
    });
  });
}
