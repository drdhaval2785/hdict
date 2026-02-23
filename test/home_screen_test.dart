import 'package:flutter_test/flutter_test.dart';

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
      expect(defHtml, contains('<div class="headword"'));
      expect(defHtml, contains('alpha</div>'));
      expect(defHtml, contains('beta</div>'));
      // alpha's definitions are joined
      expect(defHtml, contains('first$sep' 'second'));

      final dict2 = consolidated.firstWhere((e) => e['dict_id'] == 2);
      expect(dict2['dict_name'], 'B');
      expect(dict2['definition'], contains('other'));
    });
  });
}

// Helper for test
List<Map<String, dynamic>> consolidateDefinitions(
    Map<int, Map<String, List<Map<String, dynamic>>>> groupedResults) {
  final List<Map<String, dynamic>> consolidated = [];
  const sep = '<hr style="border: 0; border-top: 1px solid #eee; margin: 16px 0;">';
  groupedResults.forEach((dictId, wordMap) {
    final buffer = StringBuffer();
    String? dictName;
    bool first = true;
    wordMap.forEach((headword, entries) {
      if (dictName == null && entries.isNotEmpty) {
        dictName = entries.first['dict_name'] as String;
      }
      if (!first) {
        buffer.writeln('<hr style="border: 0; border-top: 2px solid #bbb; margin: 24px 0;">');
      }
      first = false;
      buffer.writeln('<div class="headword" style="font-size:1.3em;font-weight:bold;margin-bottom:8px;">$headword</div>');
      buffer.write(entries.map((r) => r['definition'] as String).join(sep));
    });
    consolidated.add({
      'word': wordMap.keys.first,
      'dict_id': dictId,
      'dict_name': dictName ?? '',
      'definition': buffer.toString(),
    });
  });
  return consolidated;
}
