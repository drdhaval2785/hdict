import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:hdict/features/settings/settings_provider.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class ReviewHelper {
  static Future<void> maybeRequestReview(BuildContext context, SettingsProvider settings) async {
    // Current logic from HomeScreen
    if (!kDebugMode) {
      if (settings.hasGivenReview || settings.reviewPromptCount >= 5) {
        return;
      }
    }

    await settings.initAppFirstLaunchDateIfNeeded();

    final now = DateTime.now().millisecondsSinceEpoch;
    if (kDebugMode || now >= settings.nextReviewPromptDate) {
      final InAppReview inAppReview = InAppReview.instance;
      if (await inAppReview.isAvailable()) {
        settings.setReviewPromptedThisSession(true);
        await settings.incrementReviewPromptCountAndSetNextDate();
        await inAppReview.requestReview();
      } else if (Platform.isLinux) {
        settings.setReviewPromptedThisSession(true);
        // Show the existing dialog logic
        if (context.mounted) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Enjoying hdict?'),
              content: const Text(
                'If you find hdict useful, please consider giving it a rating or review on the Snap Store. Your feedback helps me improve the app!',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Maybe Later'),
                ),
                TextButton(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    final url = Uri.parse('https://snapcraft.io/hdict');
                    if (await canLaunchUrl(url)) {
                      await launchUrl(url);
                      await settings.setHasGivenReview(true);
                    }
                  },
                  child: const Text('Rate Now'),
                ),
              ],
            ),
          );
        }
      }
    }
  }

  // Dummy helper for imports in other files if needed
  static Future<bool> canLaunchUrl(Uri url) async {
    // This is just a proxy for url_launcher to keep dependencies in this file if possible
    // But since we use it in HomeScreen anyway, we'll just keep it simple.
    return true; 
  }
}
