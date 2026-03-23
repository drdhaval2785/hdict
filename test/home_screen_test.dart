import 'package:flutter_test/flutter_test.dart';
import 'package:hdict/features/home/home_screen.dart';

void main() {
  group('consolidateDefinitions', () {
    test('lists headword-definition pairs individually and joins keys for title', () async {
      final grouped = <int, Map<String, List<Map<String, dynamic>>>>{
        1: {
          'alpha': [
            {'word': 'alpha', 'raw_content': 'def1'},
          ],
          'beta': [
            {'word': 'beta', 'raw_content': 'def1'},
          ],
          'gamma': [
            {'word': 'gamma', 'raw_content': 'def2'},
          ],
        },
      };

      final dictMap = <int, Map<String, dynamic>>{
        1: {'id': 1, 'name': 'A', 'format': 'stardict'},
      };

      final consolidated = await HomeScreen.consolidateDefinitions(
        grouped.entries.toList(),
        dictMap: dictMap,
      );

      expect(consolidated.length, 1);
      final dict1 = consolidated.first;
      
      // The overall 'word' field (used for the tab title) should contain all keys
      expect(dict1['word'], 'alpha | beta | gamma');
      expect(dict1['dict_name'], 'A');
      
      final definitionsList = dict1['definitions'] as List<Map<String, dynamic>>;
      expect(definitionsList.length, 3);
      
      // Each headword should have its own heading now, not merged
      expect(definitionsList[0]['headwordHtml'], contains('>alpha</div>'));
      expect(definitionsList[1]['headwordHtml'], contains('>beta</div>'));
      expect(definitionsList[2]['headwordHtml'], contains('>gamma</div>'));
      
      // Definitions should be present
      expect(definitionsList[0]['rawContent'], contains('def1'));
      expect(definitionsList[2]['rawContent'], contains('def2'));
    });
  });
}
