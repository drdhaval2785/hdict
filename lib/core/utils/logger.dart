import 'package:flutter/foundation.dart';

/// Global flag to control debug logging across the application.
/// Set to true to enable debug logs, false to disable them.
bool enableDebugLogs = true;

/// A wrapper around [debugPrint] that checks the [enableDebugLogs] flag.
void hDebugPrint(String? message, {int? wrapWidth}) {
  if (enableDebugLogs) {
    debugPrint(message, wrapWidth: wrapWidth);
  }
}
