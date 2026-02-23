import 'package:flutter_test/flutter_test.dart';
import 'package:hdict/features/home/home_screen.dart';

void main() {
  group('consolidateDefinitions', () {
    const sep = '<hr style="border: 0; border-top: 1px solid #eee; margin: 16px 0;">';

    test('keeps separate entries for each headword', () {
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

      // we expect three consolidated entries: (1,alpha), (1,beta), (2,alpha)
      expect(consolidated.length, 3);
      expect(
        consolidated.any((e) => e['dict_id'] == 1 && e['word'] == 'alpha'),
        isTrue,
      );
      expect(
        consolidated.any((e) => e['dict_id'] == 1 && e['word'] == 'beta'),
        isTrue,
      );
      expect(
        consolidated.any((e) => e['dict_id'] == 2 && e['word'] == 'alpha'),
        isTrue,
      );

      final fooDef = consolidated.firstWhere((e) => e['dict_id'] == 1 && e['word'] == 'alpha');
      expect(fooDef['definition'], equals('first$sep' 'second'));
    });
  });
}
