import 'package:flutter/foundation.dart';

/// Global flag to control debug logging across the application.
/// Set to true to enable debug logs, false to disable them.
bool enableDebugLogs = true;

/// Flag to control verbose HTML processing logs.
bool showHtmlProcessing = true;

/// Flag to control multimedia processing debug logs (images, audio, video).
bool showMultimediaProcessing = false;

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
  /// Map from operation name → list of individual durations (ms).
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
    _samples.putIfAbsent(name, () => []).add(sw.elapsedMilliseconds);
  }

  /// One-liner shortcut: records a known [ms] value under [name].
  static void record(String name, int ms) {
    if (!enableDebugLogs) return;
    _samples.putIfAbsent(name, () => []).add(ms);
  }

  /// Dumps a formatted summary of all recorded operations to the debug log.
  static void dump({String prefix = '--- PERF'}) {
    if (!enableDebugLogs || _samples.isEmpty) return;
    final buf = StringBuffer('$prefix ---\n');
    for (final entry in _samples.entries) {
      final list = entry.value;
      final count = list.length;
      final total = list.fold(0, (a, b) => a + b);
      final avg = (total / count).toStringAsFixed(1);
      final min = list.reduce((a, b) => a < b ? a : b);
      final max = list.reduce((a, b) => a > b ? a : b);
      buf.writeln(
        '  ${entry.key.padRight(32)} calls=$count  '
        'total=${total}ms  avg=${avg}ms  min=${min}ms  max=${max}ms',
      );
    }
    buf.write('---');
    hDebugPrint(buf.toString());
  }

  /// Clears all accumulated samples.
  static void reset() => _samples.clear();
}
