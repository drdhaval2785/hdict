import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:hdict/features/home/widgets/app_drawer.dart';

class ManualScreen extends StatelessWidget {
  const ManualScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: const Text(
          'User Manual',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: FutureBuilder<String>(
        future: rootBundle.loadString('assets/user_manual.md'),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Text('Error loading manual: ${snapshot.error}'),
              ),
            );
          }

          final String data = snapshot.data ?? 'No content found.';
          final theme = Theme.of(context);

          return SafeArea(
            top: false,
            child: Markdown(
              data: data,
              selectable: true,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
                h1: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 24,
                  color: theme.colorScheme.primary,
                ),
                h2: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                  color: theme.colorScheme.primary,
                  height: 2.0,
                ),
                h3: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: theme.colorScheme.onSurface,
                  height: 1.5,
                ),
                h4: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 17,
                  color: theme.colorScheme.secondary,
                  height: 1.4,
                ),
                h5: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                  color: theme.colorScheme.onSurface,
                  height: 1.4,
                ),
                h6: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.4,
                ),
                p: const TextStyle(fontSize: 16, height: 1.6),
                listBullet: const TextStyle(fontSize: 16, height: 1.6),
                listIndent: 24,
                code: TextStyle(
                  color: theme.colorScheme.onSurfaceVariant,
                  backgroundColor: theme.colorScheme.onSurface.withValues(
                    alpha: 0.1,
                  ),
                  fontFamily: 'monospace',
                ),
                codeblockDecoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                horizontalRuleDecoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(color: theme.dividerColor, width: 1),
                  ),
                ),
                blockquoteDecoration: BoxDecoration(
                  border: Border(
                    left: BorderSide(
                      color: theme.colorScheme.primary,
                      width: 4,
                    ),
                  ),
                ),
                blockquotePadding: const EdgeInsets.only(
                  left: 16,
                  top: 8,
                  bottom: 8,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
