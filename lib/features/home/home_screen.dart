import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:hdict/core/database/database_helper.dart';
import 'package:hdict/core/parser/dict_reader.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:hdict/core/utils/html_lookup_wrapper.dart';
import 'package:provider/provider.dart';
import 'package:hdict/features/settings/settings_provider.dart';
import 'package:hdict/features/home/widgets/app_drawer.dart';
import 'package:hdict/features/settings/dictionary_management_screen.dart';
import 'dart:async';


/// The main search screen of the hdict app.
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
  String _lastSearchQuery = '';
  TabController? _tabController;

  @override
  void dispose() {
    _searchController.dispose();
    _tabController?.dispose();
    super.dispose();
  }

  Future<void> _onWordSelected(String word) async {
    // Save to history
    await _dbHelper.addSearchHistory(word);

    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _selectedWord = word;
      _lastSearchQuery = word;
      _currentDefinitions = [];
    });

    try {
      final settings = context.read<SettingsProvider>();
      // 1. Search for all occurrences of this word
      final results = await _dbHelper.searchWords(
        word,
        fuzzy: settings.isFuzzySearchEnabled,
        searchDefinitions: settings.isSearchWithinDefinitionsEnabled,
      );

      // 2. Fetch definitions
      // group first by dictionary and then by the actual headword so multiple
      // headwords in the same dictionary don't get merged together.
      final Map<int, Map<String, List<Map<String, dynamic>>>> groupedResults = {};
      for (final result in results) {
        final dictId = result['dict_id'] as int;
        final wordValue = result['word'] as String;
        final dict = await _dbHelper.getDictionaryById(dictId);
        if (dict != null && dict['is_enabled'] == 1) {
          String dictPath = await _dbHelper.resolvePath(dict['path']);
          if (dictPath.endsWith('.ifo')) {
            dictPath = dictPath.replaceAll('.ifo', '.dict');
          }

          final reader = DictReader(dictPath, dictId: dictId);
          final content = await reader.readEntry(
            result['offset'],
            result['length'],
          );

          groupedResults.putIfAbsent(dictId, () => {});
          groupedResults[dictId]!.putIfAbsent(wordValue, () => []);

          groupedResults[dictId]![wordValue]!.add({
            ...result,
            'dict_name': dict['name'],
            'definition': content,
          });
        }
      }

      // once all definitions have been read we can consolidate them
      // (group by dictionary and headword). delegate to a helper so we can
      // unit test the behaviour in isolation.
      final consolidatedDefs = consolidateDefinitions(groupedResults);


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
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error fetching definitions: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error retrieving definition: $e')),
        );
      }
    }
  }

  // Helpers ------------------------------------------------------------------
  /// Takes results that have already been enriched with `dict_name` and
  /// `definition` and groups them first by dictionary id and then by the
  /// specific headword before producing a list suitable for the UI.
  /// Public utility for grouping lookup results by dictionary and headword.
  ///
  /// Used by [_onWordSelected] and covered by unit tests.
  static List<Map<String, dynamic>> consolidateDefinitions(
      Map<int, Map<String, List<Map<String, dynamic>>>> groupedResults) {
    final List<Map<String, dynamic>> consolidated = [];
    const sep = '<hr style="border: 0; border-top: 1px solid #eee; margin: 16px 0;">';
    groupedResults.forEach((dictId, wordMap) {
      final buffer = StringBuffer();
      String? dictName;
      bool first = true;
      wordMap.forEach((headword, entries) {
        if (dictName == null && entries.isNotEmpty) {
          dictName = entries.first['dict_name'] as String;
        }
        if (!first) {
          buffer.writeln('<hr style="border: 0; border-top: 2px solid #bbb; margin: 24px 0;">');
        }
        first = false;
        buffer.writeln('<div class="headword" style="font-size:1.3em;font-weight:bold;margin-bottom:8px;">$headword</div>');
        buffer.write(entries.map((r) => r['definition'] as String).join(sep));
      });
      consolidated.add({
        'word': wordMap.keys.first,
        'dict_id': dictId,
        'dict_name': dictName ?? '',
        'definition': buffer.toString(),
      });
    });
    return consolidated;
  }

  bool _hasDictionaries = false;
  bool _checkingDicts = true;

  @override
  void initState() {
    super.initState();
    _checkDictionaries();
    _cleanHistory();
  }

  Future<void> _cleanHistory() async {
    try {
      final settings = context.read<SettingsProvider>();
      await _dbHelper.deleteOldSearchHistory(settings.historyRetentionDays);
    } catch (e) {
      debugPrint('Clean history error: $e');
    }
  }

  Future<void> _checkDictionaries() async {
    try {
      final dicts = await _dbHelper.getDictionaries();
      if (mounted) {
        setState(() {
          _hasDictionaries = dicts.isNotEmpty;
          _checkingDicts = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasDictionaries = false;
          _checkingDicts = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('hdict', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      drawer: const AppDrawer(),
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
            Icon(Icons.library_books_outlined, size: 80, color: theme.colorScheme.primary.withValues(alpha: 0.3)),
            const SizedBox(height: 16),
            Text('No dictionaries found', style: theme.textTheme.headlineSmall?.copyWith(color: Colors.grey)),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const DictionaryManagementScreen()),
                ).then((_) => _checkDictionaries());
              },
              icon: const Icon(Icons.download),
              label: const Text('Manage Dictionaries'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar(ThemeData theme) {
    final settings = context.watch<SettingsProvider>();
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4)),
          ],
        ),
        child: Autocomplete<String>(
          optionsBuilder: (TextEditingValue textEditingValue) async {
            if (textEditingValue.text.isEmpty) return const Iterable<String>.empty();
            // always fetch a larger bucket of suggestions for the dropdown
            return await _dbHelper.getPrefixSuggestions(
              textEditingValue.text,
              fuzzy: settings.isFuzzySearchEnabled,
              limit: 100,
            );
          },
          onSelected: (String selection) => _onWordSelected(selection),
          fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
            final isDark = ThemeData.estimateBrightnessForColor(settings.searchBarColor) == Brightness.dark;
            final textColor = isDark ? Colors.white : Colors.black;
            return TextField(
              controller: controller,
              focusNode: focusNode,
              style: TextStyle(color: textColor),
              decoration: InputDecoration(
                hintText: 'Search or use * and ? for wildcards...',
                hintStyle: TextStyle(color: textColor.withValues(alpha: 0.6)),
                prefixIcon: Icon(Icons.search, color: textColor.withValues(alpha: 0.6)),
                filled: true,
                fillColor: settings.searchBarColor,
                suffixIcon: IconButton(
                  icon: Icon(Icons.clear, color: textColor.withValues(alpha: 0.6)),
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
                  focusNode.unfocus();
                  _onWordSelected(value);
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
                  constraints: const BoxConstraints(maxHeight: 300, maxWidth: 350),
                  child: ListView.builder(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    itemCount: options.length,
                    itemBuilder: (BuildContext context, int index) {
                      final String option = options.elementAt(index);
                      final settings = context.read<SettingsProvider>();

                      return FutureBuilder<List<Map<String, dynamic>>>(
                        future: _dbHelper.searchWords(option, limit: 1, fuzzy: false),
                        builder: (context, snapshot) {
                          String preview = '';
                          if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                            final def = snapshot.data!.first['definition'] ?? '';
                            preview = def.replaceAll(RegExp(r'<[^>]*>'), '');
                            final lines = preview.split('\n');
                            preview = lines.take(settings.previewLines).join(' ').trim();
                            if (preview.length > 100) preview = '${preview.substring(0, 97)}...';
                          }

                          return ListTile(
                            title: Text(option),
                            subtitle: preview.isNotEmpty
                                ? Text(preview, maxLines: settings.previewLines, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodySmall)
                                : null,
                            onTap: () => onSelected(option),
                          );
                        },
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
        if (!snapshot.hasData || snapshot.data!.isEmpty) return const SizedBox.shrink();
        return ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          children: [
            const SizedBox(height: 20),
            Text('Your Dictionaries', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ...snapshot.data!.map((dict) {
              if (dict['is_enabled'] != 1) return const SizedBox.shrink();
              return Card(
                elevation: 0,
                color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
                margin: const EdgeInsets.only(bottom: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  leading: const Icon(Icons.book_outlined),
                  title: Text(dict['name'], style: const TextStyle(fontWeight: FontWeight.w500)),
                  trailing: Text('${dict['word_count'] ?? 0} words', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.primary)),
                ),
              );
            }),
          ],
        );
      },
    );
  }

  Widget _buildResultsView(ThemeData theme) {
    if (_isLoading) return const SizedBox.shrink();
    if (_currentDefinitions.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 64, color: Colors.grey),
            SizedBox(height: 12),
            Text('No results found for this word', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    if (_currentDefinitions.length == 1) {
      return _buildDefinitionContent(theme, _currentDefinitions.first, highlightQuery: _lastSearchQuery);
    }

    if (_tabController == null || _tabController!.length != _currentDefinitions.length) return const SizedBox.shrink();

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
            return Tab(
              child: Text(name),
            );
          }).toList(),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: _currentDefinitions.map((def) => _buildDefinitionContent(theme, def, highlightQuery: _lastSearchQuery)).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildDefinitionContent(ThemeData theme, Map<String, dynamic> def, {String? highlightQuery}) {
    final settings = context.watch<SettingsProvider>();
    String definitionHtml = def['definition'];
    if (settings.isTapOnMeaningEnabled) {
      definitionHtml = HtmlLookupWrapper.wrapWords(definitionHtml);
    }
    if (highlightQuery != null && highlightQuery.isNotEmpty) {
      final isDark = ThemeData.estimateBrightnessForColor(settings.backgroundColor) == Brightness.dark;
      definitionHtml = HtmlLookupWrapper.highlightText(definitionHtml, highlightQuery, highlightColor: isDark ? '#ff9800' : '#ffeb3b', textColor: 'black');
    }

    return Container(
      color: settings.backgroundColor,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(def['word'], style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold, color: settings.headwordColor, fontFamily: settings.fontFamily, fontSize: settings.fontSize + 8)),
            const Divider(height: 32),
            Html(
              data: definitionHtml,
              style: {
                "body": Style(fontSize: FontSize(settings.fontSize), lineHeight: LineHeight.em(1.5), margin: Margins.zero, padding: HtmlPaddings.zero, color: settings.textColor, fontFamily: settings.fontFamily),
                "a": Style(color: Colors.blue, textDecoration: TextDecoration.underline),
                ".dict-word": Style(color: settings.textColor, textDecoration: TextDecoration.none),
                ".headword": Style(color: settings.headwordColor, fontWeight: FontWeight.bold),
              },
              onLinkTap: (url, attributes, element) async {
                if (url != null) {
                  if (url.startsWith('http://') || url.startsWith('https://')) {
                    final uri = Uri.parse(url);
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                    }
                  } else {
                    String wordToLookup = url;
                    if (wordToLookup.startsWith('look_up:')) {
                      wordToLookup = wordToLookup.substring(8);
                    } else if (wordToLookup.startsWith('bword://')) {
                      wordToLookup = wordToLookup.substring(8);
                    }
                    try {
                      final word = wordToLookup.contains('%') ? Uri.decodeComponent(wordToLookup) : wordToLookup;
                      _showWordPopup(word);
                    } catch (e) {
                      _showWordPopup(wordToLookup);
                    }
                  }
                }
              },
            ),
            if (settings.isTapOnMeaningEnabled)
              const Padding(
                padding: EdgeInsets.only(top: 24.0),
                child: Text('Tap on words/links to look them up.', style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey, fontSize: 12)),
              ),
          ],
        ),
      ),
    );

  }

  void _showWordPopup(String word) async {
    final settings = context.read<SettingsProvider>();
    if (!settings.isOpenPopupOnTap) {
      _onWordSelected(word);
      _searchController.text = word;
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.transparent,
      useSafeArea: true,
      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width),
      builder: (context) {
        final theme = Theme.of(context);
        return Container(
          width: double.infinity,
          height: MediaQuery.of(context).size.height * 0.5,
          decoration: BoxDecoration(color: settings.backgroundColor, borderRadius: const BorderRadius.vertical(top: Radius.circular(20))),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(color: theme.colorScheme.primaryContainer, borderRadius: const BorderRadius.vertical(top: Radius.circular(20))),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, size: 20, color: Colors.orange),
                    const SizedBox(width: 12),
                    Expanded(child: Text(word, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.onPrimaryContainer))),
                    IconButton(icon: const Icon(Icons.keyboard_arrow_down), onPressed: () => Navigator.pop(context)),
                  ],
                ),
              ),
              Expanded(
                child: FutureBuilder<List<Map<String, dynamic>>>(
                  future: () async {
                    final candidates = await _dbHelper.searchWords(word);
                    final List<Map<String, dynamic>> defs = [];
                    for (final res in candidates) {
                      final dict = await _dbHelper.getDictionaryById(res['dict_id']);
                      if (dict == null || dict['is_enabled'] != 1) continue;
                      String dictPath = await _dbHelper.resolvePath(dict['path']);
                      if (dictPath.endsWith('.ifo')) dictPath = dictPath.replaceAll('.ifo', '.dict');
                      final reader = DictReader(dictPath, dictId: res['dict_id']);
                      final content = await reader.readEntry(res['offset'], res['length']);
                      defs.add({'word': res['word'], 'dict_name': dict['name'], 'definition': content});
                    }
                    return defs;
                  }(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                    if (!snapshot.hasData || snapshot.data!.isEmpty) return const Center(child: Text('No definition found.'));
                    final defs = snapshot.data!;
                    if (defs.length == 1) return _buildDefinitionContent(theme, defs.first);
                    return DefaultTabController(
                      length: defs.length,
                      child: Column(
                        children: [
                          TabBar(isScrollable: true, labelColor: theme.colorScheme.primary, unselectedLabelColor: Colors.grey, tabs: defs.map((d) => Tab(text: d['dict_name'])).toList()),
                          Expanded(child: TabBarView(children: defs.map((d) => _buildDefinitionContent(theme, d)).toList())),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
