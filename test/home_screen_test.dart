import 'package:flutter_test/flutter_test.dart';

void main() {
  group('consolidateDefinitions', () {
    // Separator used by helper; the top-level test no longer declares it explicitly.

    test('merges headwords sharing identical definition and lists all words', () {
      final grouped = <int, Map<String, List<Map<String, dynamic>>>>{
        1: {
          'alpha': [
            {'word': 'alpha', 'dict_name': 'A', 'definition': 'same'},
          ],
          'beta': [
            {'word': 'beta', 'dict_name': 'A', 'definition': 'same'},
          ],
          'gamma': [
            {'word': 'gamma', 'dict_name': 'A', 'definition': 'different'},
          ],
        },
      };

      final consolidated = consolidateDefinitions(grouped);

      expect(consolidated.length, 1);
      final dict1 = consolidated.first;
      // word field should list all headwords
      expect(dict1['word'], 'alpha | beta | gamma');
      expect(dict1['dict_name'], 'A');
      final defHtml = dict1['definition'] as String;
      // first group heading should include both alpha and beta
      expect(defHtml, contains('alpha | beta')); 
      // second group heading for gamma
      expect(defHtml, contains('gamma</div>'));
      // the shared definition should appear only once
      expect(defHtml, contains('same')); 
      // and the different definition
      expect(defHtml, contains('different'));
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
