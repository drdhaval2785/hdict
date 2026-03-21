import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'dart:io';

/// Manages platform-specific persistent file access.
/// 
/// On iOS and macOS, it handles "security-scoped bookmarks" to maintain access
/// to files picked by the user after the app restarts.
class BookmarkManager {
  static const _channel = MethodChannel('com.drdhaval2785.hdict/bookmarks');

  /// Resolves a security-scoped bookmark to a physical path.
  /// 
  /// On iOS/macOS, this also starts a security-scoped access session.
  /// On other platforms, it returns the bookmark as is (assuming it's a path).
  static Future<String?> resolveBookmark(String bookmark) async {
    if (Platform.isIOS || Platform.isMacOS) {
      try {
        final String? path = await _channel.invokeMethod('resolveBookmark', {
          'bookmark': bookmark,
        });
        return path;
      } on PlatformException catch (e) {
        debugPrint('Error resolving bookmark: $e');
        return null;
      }
    }
    return bookmark;
  }

  /// Stops security-scoped access for a previously resolved bookmark.
  static Future<void> stopAccess(String bookmark) async {
    if (Platform.isIOS || Platform.isMacOS) {
      try {
        await _channel.invokeMethod('stopAccess', {
          'bookmark': bookmark,
        });
      } on PlatformException catch (e) {
        debugPrint('Error stopping access: $e');
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
    }
    return path;
  }
}
