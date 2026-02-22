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
            'Type any word in the search bar on the home screen. Suggestions will appear as you type.',
          ),
          _buildSection(
            theme,
            '✨ Advanced Search',
            'Use * to match any number of characters (e.g., "app*") and ? to match exactly one character (e.g., "a?ple").',
          ),
          _buildSection(
            theme,
            '📚 Managing Dictionaries',
            'Go to "Manage Dictionaries" from the menu. You can import StarDict files (.zip, .tar.gz, .tar.xz, etc.) or download them directly from the web.',
          ),
          _buildSection(
            theme,
            '↕️ Reordering',
            'In the management screen, use the handle on the left to drag dictionaries up or down. This sets their priority in search results.',
          ),
          _buildSection(
            theme,
            '⚙️ Settings',
            'Customize fonts and colors in the Settings menu. You can also adjust search history retention.',
          ),
          _buildSection(
            theme,
            '⚡ Flash Cards',
            'Test your knowledge! Select dictionaries and guess meanings for 10 random words. Review meanings after the session.',
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
