import 'dart:async';
import 'package:hdict/core/database/database_helper.dart';
import 'package:hdict/core/manager/dictionary_manager.dart';
import 'package:hdict/core/utils/logger.dart';

/// Utility for measuring and reporting dictionary lookup performance.
class HBenchmark {
  static final _dbHelper = DatabaseHelper();
  static final _dictManager = DictionaryManager();

  /// Runs a comprehensive benchmark of dictionary lookups.
  /// 
  /// 1. Finds the first 3 enabled dictionaries.
  /// 2. Fetches 20 random words from each.
  /// 3. Performs lookups and reports timings via [HPerf].
  static Future<String> runLookupBenchmark({int wordsPerDict = 20}) async {
    final dicts = await _dbHelper.getDictionaries();
    final enabledDicts = dicts.where((d) => d['is_enabled'] == 1).toList();

    if (enabledDicts.isEmpty) {
      return 'No enabled dictionaries found for benchmarking.';
    }

    final report = StringBuffer('--- BENCHMARK REPORT ---\n');
    report.writeln('Testing ${enabledDicts.length} dictionaries, $wordsPerDict lookups each.');

    HPerf.reset();
    final totalWatch = Stopwatch()..start();

    for (final dict in enabledDicts) {
      final dictId = dict['id'] as int;
      final name = dict['name'] as String;
      
      // Get some words to lookup
      final wordResults = await _dbHelper.getSampleWords(dictId, limit: wordsPerDict);
      if (wordResults.isEmpty) continue;

      report.writeln('  Dictionary: $name (${wordResults.length} words)');

      for (final row in wordResults) {
        final word = row['word'] as String;
        final offset = row['offset'] as int;
        final length = row['length'] as int;

        final watch = HPerf.start('Benchmark_Lookup');
        await _dictManager.fetchDefinition(dict, word, offset, length);
        HPerf.end(watch, 'Benchmark_Lookup');
      }
    }

    totalWatch.stop();
    report.writeln('\nSummary:');
    
    // Extract stats from HPerf
    // Note: This matches the 'Benchmark_Lookup' key used above
    HPerf.dump(prefix: 'BENCHMARK_DUMP');
    
    report.writeln('Total time: ${totalWatch.elapsedMilliseconds}ms');
    return report.toString();
  }
}
