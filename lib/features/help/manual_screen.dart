import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
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

          return Markdown(
            data: data,
            selectable: true,
            styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
              h1: const TextStyle(fontWeight: FontWeight.bold, fontSize: 24, color: Color(0xFFFFAB40)),
              h2: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Color(0xFFFFAB40), height: 2.0),
              h3: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, height: 1.5),
              p: const TextStyle(fontSize: 16, height: 1.6),
              listBullet: const TextStyle(fontSize: 16, height: 1.6),
              code: TextStyle(
                backgroundColor: theme.colorScheme.onSurface.withValues(alpha: 0.1),
                fontFamily: 'monospace',
                color: theme.colorScheme.primary,
              ),
              horizontalRuleDecoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: theme.dividerColor, width: 1),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
