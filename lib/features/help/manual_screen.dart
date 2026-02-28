import 'package:flutter/material.dart';
import 'package:hdict/features/home/widgets/app_drawer.dart';

class ManualScreen extends StatelessWidget {
  const ManualScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: const Text(
          'User Manual',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24.0),
        children: [
          _buildSection(
            theme,
            '🔍 Searching',
            'Type any word in the search bar. Suggestions appear as you type. By default, "Search in Definitions" is enabled, searching through meanings as well as headwords.',
          ),
          _buildSection(
            theme,
            '✨ Advanced Search',
            'Use * to match any number of characters (e.g., "app*") and ? to match exactly one character (e.g., "a?ple").',
          ),
          _buildSection(
            theme,
            '📚 Managing Dictionaries',
            'Import StarDict, MDict, or DICTD files. New dictionaries are automatically indexed for full-meaning search during import.',
          ),
          _buildSection(
            theme,
            '↕️ Reordering',
            'Drag dictionaries to set priority. Results from higher-priority dictionaries appear first, even if lower ones have exact matches.',
          ),
          _buildSection(
            theme,
            '⚙️ Settings',
            'Customize fonts, colors, and search history retention. You can also adjust the number of words for your flash card sessions.',
          ),
          _buildSection(
            theme,
            '⚡ Flash Cards',
            'Test your knowledge with 5-50 random words. Flash Card session details, including used dictionaries and scores, are saved in your Score History.',
          ),
          _buildSection(
            theme,
            '📜 Search History',
            'Access your previous searches from the Search History menu. Tap any term to look it up again.',
          ),
          _buildSection(
            theme,
            '🌐 Links',
            'Definition text may contain clickable links. Tap on them to open the resource in your web browser.',
          ),
        ],
      ),
    );
  }

  Widget _buildSection(ThemeData theme, String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: const Color(0xFFFFAB40),
            ),
          ),
          const SizedBox(height: 8),
          Text(content, style: const TextStyle(fontSize: 16, height: 1.5)),
        ],
      ),
    );
  }
}
