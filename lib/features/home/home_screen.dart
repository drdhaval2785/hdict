import 'package:flutter/material.dart';
import 'package:hdict/core/database/database_helper.dart';
import 'package:hdict/core/parser/dict_reader.dart';
import 'package:hdict/features/settings/dictionary_management_screen.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:hdict/features/about/about_screen.dart';
import 'package:hdict/features/help/manual_screen.dart';
import 'dart:async';

/// The main search screen of the hdict app.
///
/// Provides a search bar with autocomplete suggestions and displays dictionary
/// definitions in a tabbed view when results are available from multiple dictionaries.
/// Also includes a navigation drawer for settings and help pages.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  final DatabaseHelper _dbHelper = DatabaseHelper();

  List<Map<String, dynamic>> _currentDefinitions = [];
  bool _isLoading = false;
  String? _selectedWord;
  TabController? _tabController;

  @override
  void dispose() {
    _searchController.dispose();
    _tabController?.dispose();
    super.dispose();
  }

  Future<void> _onWordSelected(String word) async {
    setState(() {
      _isLoading = true;
      _selectedWord = word;
      _currentDefinitions = [];
    });

    try {
      // 1. Search for all occurrences of this word in different dictionaries
      final results = await _dbHelper.searchWords(word);

      // 2. Fetch definitions for each occurrence
      final Map<int, List<Map<String, dynamic>>> groupedResults = {};
      for (final result in results) {
        final dictId = result['dict_id'] as int;
        final dict = await _dbHelper.getDictionaryById(dictId);
        if (dict != null && dict['is_enabled'] == 1) {
          String dictPath = dict['path'];
          if (dictPath.endsWith('.ifo')) {
            dictPath = dictPath.replaceAll('.ifo', '.dict');
          }
          final reader = DictReader(dictPath);
          final content = await reader.readEntry(
            result['offset'],
            result['length'],
          );

          if (!groupedResults.containsKey(dictId)) {
            groupedResults[dictId] = [];
          }

          groupedResults[dictId]!.add({
            ...result,
            'dict_name': dict['name'],
            'definition': content,
          });
        }
      }

      final List<Map<String, dynamic>> consolidatedDefs = [];
      groupedResults.forEach((dictId, results) {
        // Concatenate multiple definitions with a separator
        final combinedContent = results
            .map((r) => r['definition'])
            .join(
              '<hr style="border: 0; border-top: 1px solid #eee; margin: 16px 0;">',
            );

        consolidatedDefs.add({
          'word': word,
          'dict_id': dictId,
          'dict_name': results.first['dict_name'],
          'definition': combinedContent,
        });
      });

      setState(() {
        _currentDefinitions = consolidatedDefs;
        _tabController?.dispose();
        if (consolidatedDefs.length > 1) {
          _tabController = TabController(
            length: consolidatedDefs.length,
            vsync: this,
          );
        } else {
          _tabController = null;
        }
        _isLoading = false; // Set loading to false in the same frame
      });
    } catch (e) {
      debugPrint('Error fetching definitions: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  bool _hasDictionaries = false;
  bool _checkingDicts = true;

  @override
  void initState() {
    super.initState();
    _checkDictionaries();
  }

  Future<void> _checkDictionaries() async {
    final dicts = await _dbHelper.getDictionaries();
    setState(() {
      _hasDictionaries = dicts.isNotEmpty;
      _checkingDicts = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'hdict',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      drawer: Drawer(
        child: Column(
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.book, size: 48, color: Color(0xFFFFAB40)),
                    const SizedBox(height: 8),
                    Text(
                      'hdict',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.search),
              title: const Text('Search'),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Icon(Icons.settings_outlined),
              title: const Text('Manage Dictionaries'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const DictionaryManagementScreen(),
                  ),
                ).then((_) => _checkDictionaries());
              },
            ),
            ListTile(
              leading: const Icon(Icons.help_outline),
              title: const Text('User Manual'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ManualScreen()),
                );
              },
            ),
            const Spacer(),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('About Us'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const AboutScreen()),
                );
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
      body: _checkingDicts
          ? const Center(child: CircularProgressIndicator())
          : !_hasDictionaries
          ? _buildEmptyState(theme)
          : Column(
              children: [
                _buildSearchBar(theme),
                if (_isLoading) const LinearProgressIndicator(),
                Expanded(
                  child: _selectedWord == null
                      ? _buildDefaultContent(theme)
                      : _buildResultsView(theme),
                ),
              ],
            ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.library_books_outlined,
              size: 80,
              color: theme.colorScheme.primary.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'No dictionaries found',
              style: theme.textTheme.headlineSmall?.copyWith(
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const DictionaryManagementScreen(),
                  ),
                ).then((_) => _checkDictionaries());
              },
              icon: const Icon(Icons.download),
              label: const Text('Manage Dictionaries'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Autocomplete<String>(
          optionsBuilder: (TextEditingValue textEditingValue) async {
            if (textEditingValue.text.isEmpty) {
              return const Iterable<String>.empty();
            }
            return await _dbHelper.getPrefixSuggestions(textEditingValue.text);
          },
          onSelected: (String selection) {
            _onWordSelected(selection);
          },
          fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
            return TextField(
              controller: controller,
              focusNode: focusNode,
              decoration: InputDecoration(
                hintText: 'Search or use * and ? for wildcards...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    controller.clear();
                    setState(() {
                      _selectedWord = null;
                      _currentDefinitions = [];
                    });
                  },
                ),
              ),
              onSubmitted: (value) {
                if (value.isNotEmpty) {
                  _onWordSelected(value);
                  onFieldSubmitted();
                }
              },
            );
          },
          optionsViewBuilder: (context, onSelected, options) {
            return Align(
              alignment: Alignment.topLeft,
              child: Material(
                elevation: 4.0,
                borderRadius: BorderRadius.circular(12),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxHeight: 300,
                    maxWidth: 350,
                  ),
                  child: ListView.builder(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    itemCount: options.length,
                    itemBuilder: (BuildContext context, int index) {
                      final String option = options.elementAt(index);
                      return ListTile(
                        title: Text(option),
                        onTap: () => onSelected(option),
                      );
                    },
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildDefaultContent(ThemeData theme) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _dbHelper.getDictionaries(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const SizedBox.shrink();
        }
        return ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          children: [
            const SizedBox(height: 20),
            Text(
              'Your Dictionaries',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            ...snapshot.data!.map((dict) {
              if (dict['is_enabled'] != 1) return const SizedBox.shrink();
              return Card(
                elevation: 0,
                color: theme.colorScheme.primaryContainer.withValues(
                  alpha: 0.3,
                ),
                margin: const EdgeInsets.only(bottom: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  leading: const Icon(Icons.book_outlined),
                  title: Text(
                    dict['name'],
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  trailing: Text(
                    '${dict['word_count'] ?? 0} words',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
              );
            }),
          ],
        );
      },
    );
  }

  Widget _buildResultsView(ThemeData theme) {
    if (_isLoading) {
      return const SizedBox.shrink(); // Hide old results while loading new ones
    }

    if (_currentDefinitions.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 64, color: Colors.grey),
            SizedBox(height: 12),
            Text(
              'No results found for this word',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    if (_currentDefinitions.length == 1) {
      return _buildDefinitionContent(theme, _currentDefinitions.first);
    }

    // Double check TabController consistency
    if (_tabController == null ||
        _tabController!.length != _currentDefinitions.length) {
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: theme.colorScheme.primary,
          unselectedLabelColor: Colors.grey,
          indicatorColor: theme.colorScheme.primary,
          tabs: _currentDefinitions.map((def) {
            String name = def['dict_name'];
            if (name.length > 13) name = '${name.substring(0, 10)}...';
            return Tab(text: name);
          }).toList(),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: _currentDefinitions
                .map((def) => _buildDefinitionContent(theme, def))
                .toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildDefinitionContent(ThemeData theme, Map<String, dynamic> def) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  def['word'],
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 32),
          Html(
            data: def['definition'],
            style: {
              "body": Style(
                fontSize: FontSize(16.0),
                lineHeight: LineHeight.em(1.5),
                margin: Margins.zero,
                padding: HtmlPaddings.zero,
              ),
            },
            onLinkTap: (url, attributes, element) async {
              if (url != null) {
                final uri = Uri.tryParse(url);
                if (uri != null && await canLaunchUrl(uri)) {
                  await launchUrl(uri);
                }
              }
            },
          ),
        ],
      ),
    );
  }
}
