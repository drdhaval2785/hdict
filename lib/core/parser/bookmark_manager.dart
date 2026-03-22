import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'dart:io';

/// Manages platform-specific persistent file access.
/// 
/// On iOS and macOS, it handles "security-scoped bookmarks" to maintain access
/// to files picked by the user after the app restarts.
class BookmarkManager {
  static const _channel = MethodChannel('com.drdhaval2785.hdict/bookmarks');

  /// Keeps track of active access sessions for each bookmark.
  static final Map<String, int> _sessionCounts = {};

  /// Resolves a security-scoped bookmark to a physical path.
  /// 
  /// On iOS/macOS, this also starts a security-scoped access session.
  /// On other platforms, it returns the bookmark as is (assuming it's a path).
  static Future<String?> resolveBookmark(String bookmark) async {
    if (Platform.isIOS || Platform.isMacOS) {
      try {
        // Increment session count
        _sessionCounts[bookmark] = (_sessionCounts[bookmark] ?? 0) + 1;
        
        // If this is the first session, it will trigger startAccessing on native side
        final String? path = await _channel.invokeMethod('resolveBookmark', {
          'bookmark': bookmark,
        });
        return path;
      } on PlatformException catch (e) {
        debugPrint('Error resolving bookmark: $e');
        _sessionCounts[bookmark] = (_sessionCounts[bookmark] ?? 0) - 1;
        return null;
      }
    }
    return bookmark;
  }

  /// Picks a directory using native SAF picker on Android with persistable grants.
  /// The native intent is launched with FLAG_GRANT_PERSISTABLE_URI_PERMISSION
  /// so the returned URI already has a persisted grant.
  static Future<String?> pickDirectory() async {
    if (Platform.isAndroid) {
      try {
        final String? uri = await _channel.invokeMethod('pickDirectory');
        return uri;
      } on PlatformException catch (e) {
        debugPrint('Error picking directory natively: $e');
        return null;
      }
    }
    return null;
  }

  /// Picks one or more files using native SAF picker on Android with persistable grants.
  /// Returns a list of content:// URI strings, or null if cancelled.
  static Future<List<String>?> pickFiles() async {
    if (Platform.isAndroid) {
      try {
        final List<dynamic>? uris = await _channel.invokeMethod('pickFiles');
        return uris?.cast<String>();
      } on PlatformException catch (e) {
        debugPrint('Error picking files natively: $e');
        return null;
      }
    }
    return null;
  }

  /// Stops security-scoped access for a previously resolved bookmark.
  static Future<void> stopAccess(String bookmark) async {
    if (Platform.isIOS || Platform.isMacOS) {
      final current = _sessionCounts[bookmark] ?? 0;
      if (current <= 0) return;

      final next = current - 1;
      _sessionCounts[bookmark] = next;

      if (next == 0) {
        try {
          await _channel.invokeMethod('stopAccess', {
            'bookmark': bookmark,
          });
          _sessionCounts.remove(bookmark);
        } on PlatformException catch (e) {
          debugPrint('Error stopping access: $e');
        }
      }
    }
  }

  /// Creates a security-scoped bookmark for a file path.
  /// 
  /// This is used when a file is first picked to store its permanent reference.
  static Future<String?> createBookmark(String path) async {
    if (Platform.isIOS || Platform.isMacOS) {
      try {
        final String? bookmark = await _channel.invokeMethod('createBookmark', {
          'path': path,
        });
        return bookmark;
      } on PlatformException catch (e) {
        debugPrint('Error creating bookmark: $e');
        return null;
      }
    } else if (Platform.isAndroid && path.startsWith('content://')) {
      // Try to take persistable permission. This will succeed only if the URI
      // was offered with FLAG_GRANT_PERSISTABLE_URI_PERMISSION (e.g. via our
      // native pickDirectory / pickFiles methods). If it fails, just log it —
      // the session-level grant from the picker is still valid for this run.
      try {
        await _channel.invokeMethod('takePersistablePermission', {
          'path': path,
        });
      } on PlatformException catch (e) {
        debugPrint('Note: could not make SAF grant persistent for $path: ${e.message}');
      }
    }
    return path;
  }

  /// Starts security-scoped access for a physical path.
  static Future<bool> startAccessingPath(String path) async {
    if (Platform.isIOS || Platform.isMacOS) {
      try {
        final bool success = await _channel.invokeMethod('startAccessingPath', {
          'path': path,
        });
        return success;
      } on PlatformException catch (e) {
        debugPrint('Error starting access to path: $e');
        return false;
      }
    }
    return true;
  }

  /// Stops security-scoped access for a physical path.
  static Future<void> stopAccessingPath(String path) async {
    if (Platform.isIOS || Platform.isMacOS) {
      try {
        await _channel.invokeMethod('stopAccessingPath', {
          'path': path,
        });
      } on PlatformException catch (e) {
        debugPrint('Error stopping access to path: $e');
      }
    }
  }
}
