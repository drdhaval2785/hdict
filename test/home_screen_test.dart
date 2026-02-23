import 'package:flutter_test/flutter_test.dart';
import 'package:hdict/features/home/home_screen.dart';

void main() {
  group('consolidateDefinitions', () {
    const sep = '<hr style="border: 0; border-top: 1px solid #eee; margin: 16px 0;">';

    test('produces one entry per dictionary with all headwords', () {
      final grouped = <int, Map<String, List<Map<String, dynamic>>>>{
        1: {
          'alpha': [
            {'word': 'alpha', 'dict_name': 'A', 'definition': 'first'},
            {'word': 'alpha', 'dict_name': 'A', 'definition': 'second'},
          ],
          'beta': [
            {'word': 'beta', 'dict_name': 'A', 'definition': 'only'},
          ],
        },
        2: {
          'alpha': [
            {'word': 'alpha', 'dict_name': 'B', 'definition': 'other'},
          ],
        },
      };

      final consolidated = consolidateDefinitions(grouped);

      // expect two entries: one per dict id
      expect(consolidated.length, 2);

      final dict1 = consolidated.firstWhere((e) => e['dict_id'] == 1);
      expect(dict1['word'], 'alpha');
      expect(dict1['dict_name'], 'A');
      final defHtml = dict1['definition'] as String;
      // should contain both headwords with separators and the proper class
      expect(defHtml, contains('<p class="headword"><b>alpha</b></p>'));
      expect(defHtml, contains('<p class="headword"><b>beta</b></p>'));
      // alpha's definitions are joined
      expect(defHtml, contains('first$sep' 'second'));

      final dict2 = consolidated.firstWhere((e) => e['dict_id'] == 2);
      expect(dict2['dict_name'], 'B');
      expect(dict2['definition'], contains('other'));
    });
  });
}
