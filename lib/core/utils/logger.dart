import 'package:flutter/foundation.dart';

/// Global flag to control debug logging across the application.
/// Set to true to enable debug logs, false to disable them.
bool enableDebugLogs = true;

/// Flag to control verbose HTML processing logs.
bool showHtmlProcessing = true;

/// Flag to control multimedia processing debug logs (images, audio, video).
bool showMultimediaProcessing = false;

/// Flag to control sorting debug logs (SQLite vs Dart sort verification).
bool showSorting = false;

/// A wrapper around [debugPrint] that checks the [enableDebugLogs] flag.
void hDebugPrint(String? message, {int? wrapWidth}) {
  if (enableDebugLogs) {
    final timestamp = DateTime.now().toIso8601String().substring(11, 23);
    debugPrint('[$timestamp] $message', wrapWidth: wrapWidth);
  }
}

/// Lightweight call-count + timing profiler, active only in debug mode.
///
/// Usage:
/// ```dart
/// final t = HPerf.start('fetchDef[stardict]');
/// // ... do work ...
/// HPerf.end(t, 'fetchDef[stardict]');
///
/// // At end of request:
/// HPerf.dump();
/// HPerf.reset();
/// ```
class HPerf {
  /// Map from operation name → list of individual durations (microseconds).
  static final Map<String, List<int>> _samples = {};

  /// Returns a started [Stopwatch] — call [end] with the same [name] when done.
  /// Returns null (no-op) in release mode.
  static Stopwatch? start(String name) {
    if (!enableDebugLogs) return null;
    return Stopwatch()..start();
  }

  /// Records the elapsed time from [sw] under [name]. Safe to call with a
  /// null [sw] (produced by [start] in release mode).
  static void end(Stopwatch? sw, String name) {
    if (sw == null || !enableDebugLogs) return;
    sw.stop();
    _samples.putIfAbsent(name, () => []).add(sw.elapsedMicroseconds);
  }

  /// One-liner shortcut: records a known [ms] value under [name].
  static void record(String name, int ms) {
    if (!enableDebugLogs) return;
    _samples.putIfAbsent(name, () => []).add(ms * 1000);
  }

  /// Records a known [us] value under [name].
  static void recordUs(String name, int us) {
    if (!enableDebugLogs) return;
    _samples.putIfAbsent(name, () => []).add(us);
  }

  /// Dumps a formatted summary of all recorded operations to the debug log.
  static void dump({String prefix = '--- PERF'}) {
    if (!enableDebugLogs || _samples.isEmpty) return;
    final buf = StringBuffer('$prefix ---\n');
    for (final entry in _samples.entries) {
      final list = entry.value;
      final count = list.length;
      final totalUs = list.fold(0, (a, b) => a + b);
      final avgUs = totalUs / count;
      final minUs = list.reduce((a, b) => a < b ? a : b);
      final maxUs = list.reduce((a, b) => a > b ? a : b);

      final totalMs = (totalUs / 1000.0).toStringAsFixed(2);
      final avgMs = (avgUs / 1000.0).toStringAsFixed(3);
      final minMs = (minUs / 1000.0).toStringAsFixed(3);
      final maxMs = (maxUs / 1000.0).toStringAsFixed(3);

      buf.writeln(
        '  ${entry.key.padRight(32)} calls=$count  '
        'total=${totalMs}ms  avg=${avgMs}ms  min=${minMs}ms  max=${maxMs}ms',
      );
    }
    buf.write('---');
    hDebugPrint(buf.toString());
  }

  /// Clears all accumulated samples.
  static void reset() => _samples.clear();
}
