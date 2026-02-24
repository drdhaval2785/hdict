import 'package:flutter_test/flutter_test.dart';
import 'package:hdict/features/home/home_screen.dart';

void main() {
  group('consolidateDefinitions', () {
    test('lists headword-definition pairs individually and joins keys for title', () {
      final grouped = <int, Map<String, List<Map<String, dynamic>>>>{
        1: {
          'alpha': [
            {'word': 'alpha', 'dict_name': 'A', 'definition': 'def1'},
          ],
          'beta': [
            {'word': 'beta', 'dict_name': 'A', 'definition': 'def1'},
          ],
          'gamma': [
            {'word': 'gamma', 'dict_name': 'A', 'definition': 'def2'},
          ],
        },
      };

      final consolidated = HomeScreen.consolidateDefinitions(grouped);

      expect(consolidated.length, 1);
      final dict1 = consolidated.first;
      
      // The overall 'word' field (used for the tab title) should contain all keys
      expect(dict1['word'], 'alpha | beta | gamma');
      expect(dict1['dict_name'], 'A');
      
      final defHtml = dict1['definition'] as String;
      
      // Each headword should have its own heading now, not merged
      expect(defHtml, contains('<div class="headword" style="font-size:1.3em;font-weight:bold;margin-bottom:8px;">alpha</div>'));
      expect(defHtml, contains('<div class="headword" style="font-size:1.3em;font-weight:bold;margin-bottom:8px;">beta</div>'));
      expect(defHtml, contains('<div class="headword" style="font-size:1.3em;font-weight:bold;margin-bottom:8px;">gamma</div>'));
      
      // Definitions should be present
      expect(defHtml, contains('def1'));
      expect(defHtml, contains('def2'));
      
      // Separators should exist between the 3 entries
      final hrCount = RegExp('<hr').allMatches(defHtml).length;
      expect(hrCount, 2);
    });
  });
}
