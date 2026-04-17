import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hdict/features/settings/settings_provider.dart';
import 'package:url_launcher/url_launcher.dart';

/// Store URLs for hdict on each platform.
class _StoreUrls {
  static const playStore =
      'https://play.google.com/store/apps/details?id=in.sanskritworld.hdict';
  static const snapStore = 'https://snapcraft.io/hdict';
  static const microsoftStore =
      'https://apps.microsoft.com/detail/hdict';
  static const appStore =
      'https://apps.apple.com/in/app/hdict/id6759493062';
}

class ReviewHelper {
  /// Shows a friendly dialog asking the user to rate hdict in their store.
  /// Respects the same throttling logic as before (max 5 prompts, 30-day gaps).
  static Future<void> maybeRequestReview(
    BuildContext context,
    SettingsProvider settings,
  ) async {
    if (!kDebugMode) {
      if (settings.hasGivenReview || settings.reviewPromptCount >= 5) return;
    }

    await settings.initAppFirstLaunchDateIfNeeded();

    final now = DateTime.now().millisecondsSinceEpoch;
    if (!kDebugMode && now < settings.nextReviewPromptDate) return;

    settings.setReviewPromptedThisSession(true);
    await settings.incrementReviewPromptCountAndSetNextDate();

    if (!context.mounted) return;
    _showReviewDialog(context, settings);
  }

  static void _showReviewDialog(
    BuildContext context,
    SettingsProvider settings,
  ) {
    final storeInfo = _resolveStore();
    if (storeInfo == null) return; // unsupported platform — stay silent

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Enjoying hdict?'),
        content: Text(
          'If you find hdict useful, please consider giving it a rating on '
          '${storeInfo.name}. Your feedback helps improve the app!',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Maybe Later'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final url = Uri.parse(storeInfo.url);
              if (await canLaunchUrl(url)) {
                await launchUrl(url, mode: LaunchMode.externalApplication);
                await settings.setHasGivenReview(true);
              }
            },
            child: const Text('Rate Now'),
          ),
        ],
      ),
    );
  }

  /// Returns the store name + URL for the current platform, or null if unknown.
  static _StoreInfo? _resolveStore() {
    if (kIsWeb) return null;
    if (Platform.isAndroid) {
      return _StoreInfo('Google Play', _StoreUrls.playStore);
    } else if (Platform.isIOS) {
      return _StoreInfo('App Store', _StoreUrls.appStore);
    } else if (Platform.isLinux) {
      return _StoreInfo('Snap Store', _StoreUrls.snapStore);
    } else if (Platform.isWindows) {
      return _StoreInfo('Microsoft Store', _StoreUrls.microsoftStore);
    } else if (Platform.isMacOS) {
      return _StoreInfo('App Store', _StoreUrls.appStore);
    }
    return null;
  }
}

class _StoreInfo {
  final String name;
  final String url;
  const _StoreInfo(this.name, this.url);
}
