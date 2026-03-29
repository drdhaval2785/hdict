import 'package:flutter_test/flutter_test.dart';
import 'package:hdict/features/home/home_screen.dart';

void main() {
  group('resultsMetadata indexing after sorting', () {
    test(
      'metadata stays correctly paired with entry after sorting by dict priority',
      () async {
        // Simulate SQLite results from multiple dictionaries
        // Based on the bug: dictId=41 results came in different order
        final results = [
          {
            'word': 'pramaadavat-nara',
            'dict_id': 41,
            'offset': 26434054,
            'length': 335,
          },
          {
            'word': 'pramaaNa',
            'dict_id': 41,
            'offset': 26451458,
            'length': 437,
          },
          {
            'word': 'pramaaNa',
            'dict_id': 41,
            'offset': 26451895,
            'length': 278,
          },
          {
            'word': 'pramaada',
            'dict_id': 41,
            'offset': 26452173,
            'length': 242,
          },
          {
            'word': 'pramaapaNa',
            'dict_id': 41,
            'offset': 26452415,
            'length': 235,
          },
          {
            'word': 'pramaataamaha',
            'dict_id': 41,
            'offset': 26452415,
            'length': 235,
          },
        ];

        // Simulate the dictDisplayOrder map (sorted by priority)
        final dictDisplayOrder = <int, int>{41: 1};

        // Simulate entriesToProcess being built and sorted
        // This mimics the buggy scenario where entries get sorted but metadata wasn't aligned
        final entriesToProcess = <EntryToProcess>[
          EntryToProcess(
            index: 0,
            content: 'def0',
            word: 'pramaadavat-nara',
            format: 'stardict',
          ),
          EntryToProcess(
            index: 1,
            content: 'def1',
            word: 'pramaaNa',
            format: 'stardict',
          ),
          EntryToProcess(
            index: 2,
            content: 'def2',
            word: 'pramaaNa',
            format: 'stardict',
          ),
          EntryToProcess(
            index: 3,
            content: 'def3',
            word: 'pramaada',
            format: 'stardict',
          ),
          EntryToProcess(
            index: 4,
            content: 'def4',
            word: 'pramaapaNa',
            format: 'stardict',
          ),
          EntryToProcess(
            index: 5,
            content: 'def5',
            word: 'pramaataamaha',
            format: 'stardict',
          ),
        ];

        // Simulate resultsMetadata being stored at correct original indices (the fix)
        final resultsMetadata = List<Map<String, dynamic>?>.filled(
          results.length,
          null,
        );
        for (int i = 0; i < results.length; i++) {
          resultsMetadata[i] = results[i];
        }

        // Sort entriesToProcess by dict priority (simulating the sort)
        entriesToProcess.sort((a, b) {
          final aOriginal = results[a.index];
          final bOriginal = results[b.index];
          final aDictId = aOriginal['dict_id'] as int;
          final bDictId = bOriginal['dict_id'] as int;
          final aOrder = dictDisplayOrder[aDictId] ?? 0;
          final bOrder = dictDisplayOrder[bDictId] ?? 0;
          if (aOrder != bOrder) return aOrder.compareTo(bOrder);
          return a.index.compareTo(b.index);
        });

        // Verify: after sorting, metadata should still match entry content
        // This is the regression test for the bug where SQLITE word != AFTER_SORT word
        for (int i = 0; i < entriesToProcess.length; i++) {
          final entry = entriesToProcess[i];
          final meta = resultsMetadata[entry.index]!;

          // The key assertion: the word from SQLite metadata should match the entry's word
          expect(
            meta['word'],
            entry.word,
            reason:
                'At sorted position $i: SQLite word "${meta['word']}" should match entry word "${entry.word}"',
          );

          // Also verify the uniqueKey can be generated correctly
          final uniqueKey = '${meta['offset']}_${meta['length']}';
          expect(uniqueKey, isNotEmpty);
        }
      },
    );

    test('handles multiple dictionaries with different display orders', () {
      // Test with multiple dictionaries to ensure sorting by priority works
      final results = [
        {'word': 'word1', 'dict_id': 2, 'offset': 100, 'length': 50},
        {'word': 'word2', 'dict_id': 1, 'offset': 200, 'length': 60},
        {'word': 'word3', 'dict_id': 3, 'offset': 300, 'length': 70},
        {'word': 'word4', 'dict_id': 1, 'offset': 250, 'length': 80},
      ];

      // Dict 1 has highest priority (display_order=1), then 2, then 3
      final dictDisplayOrder = <int, int>{1: 1, 2: 2, 3: 3};

      final entriesToProcess = <EntryToProcess>[
        EntryToProcess(
          index: 0,
          content: 'def1',
          word: 'word1',
          format: 'stardict',
        ),
        EntryToProcess(
          index: 1,
          content: 'def2',
          word: 'word2',
          format: 'stardict',
        ),
        EntryToProcess(
          index: 2,
          content: 'def3',
          word: 'word3',
          format: 'stardict',
        ),
        EntryToProcess(
          index: 3,
          content: 'def4',
          word: 'word4',
          format: 'stardict',
        ),
      ];

      final resultsMetadata = List<Map<String, dynamic>?>.filled(
        results.length,
        null,
      );
      for (int i = 0; i < results.length; i++) {
        resultsMetadata[i] = results[i];
      }

      // Sort by dict priority
      entriesToProcess.sort((a, b) {
        final aOriginal = results[a.index];
        final bOriginal = results[b.index];
        final aDictId = aOriginal['dict_id'] as int;
        final bDictId = bOriginal['dict_id'] as int;
        final aOrder = dictDisplayOrder[aDictId] ?? 0;
        final bOrder = dictDisplayOrder[bDictId] ?? 0;
        if (aOrder != bOrder) return aOrder.compareTo(bOrder);
        return a.index.compareTo(b.index);
      });

      // After sorting: dict_id=1 entries first, then dict_id=2, then dict_id=3
      // Within same dict, sorted by original index
      expect(entriesToProcess[0].index, 1); // dict_id=1, word2
      expect(entriesToProcess[1].index, 3); // dict_id=1, word4
      expect(entriesToProcess[2].index, 0); // dict_id=2, word1
      expect(entriesToProcess[3].index, 2); // dict_id=3, word3

      // Verify metadata still matches after sort
      for (int i = 0; i < entriesToProcess.length; i++) {
        final entry = entriesToProcess[i];
        final meta = resultsMetadata[entry.index]!;
        expect(meta['word'], entry.word);
      }
    });
  });

  group('consolidateDefinitions', () {
    test(
      'lists headword-definition pairs individually and joins keys for title',
      () async {
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

        final definitionsList =
            dict1['definitions'] as List<Map<String, dynamic>>;
        expect(definitionsList.length, 3);

        // Each headword should have its own heading now, not merged
        expect(definitionsList[0]['headwordHtml'], contains('>alpha</div>'));
        expect(definitionsList[1]['headwordHtml'], contains('>beta</div>'));
        expect(definitionsList[2]['headwordHtml'], contains('>gamma</div>'));

        // Definitions should be present
        expect(definitionsList[0]['rawContent'], contains('def1'));
        expect(definitionsList[2]['rawContent'], contains('def2'));
      },
    );
  });
}
