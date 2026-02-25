import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:hdict/core/database/database_helper.dart';
import 'package:hdict/core/parser/dict_reader.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:flutter/services.dart';
import 'package:hdict/core/utils/html_lookup_wrapper.dart';
import 'package:provider/provider.dart';
import 'package:hdict/features/settings/settings_provider.dart';
import 'package:hdict/features/home/widgets/app_drawer.dart';
import 'package:hdict/features/settings/dictionary_management_screen.dart';
import 'dart:async';


/// The main search screen of the hdict app.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  // Helpers ------------------------------------------------------------------
  /// Takes results that have already been enriched with `dict_name` and
  /// `definition` and groups them first by dictionary id and then by the
  /// specific headword before producing a list suitable for the UI.
  static List<Map<String, dynamic>> consolidateDefinitions(
      Map<int, Map<String, List<Map<String, dynamic>>>> groupedResults) {
    final List<Map<String, dynamic>> consolidated = [];
    groupedResults.forEach((dictId, uniqueKeyMap) {
      String? dictName;
      final List<String> definitionsList = [];

      uniqueKeyMap.forEach((uniqueKey, entries) {
        if (entries.isEmpty) return;
        dictName ??= entries.first['dict_name'] as String;
        
        final headwords = entries.map((e) => e['word'] as String).toSet().toList();
        final headwordStr = headwords.join(' | ');

        final buffer = StringBuffer();
        buffer.writeln('<div class="headword" style="font-size:1.3em;font-weight:bold;margin-bottom:8px;">$headwordStr</div>');
        buffer.writeln(normalizeWhitespace(entries.first['definition'] as String));
        definitionsList.add(buffer.toString());
      });

      consolidated.add({
        'dict_id': dictId,
        'dict_name': dictName ?? '',
        'definitions': definitionsList,
      });
    });
    return consolidated;
  }

  /// Normalizes whitespace in HTML by replacing multiple spaces/newlines with single space.
  static String normalizeWhitespace(String html) {
    return html
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'>\s+<'), '><')
        .trim();
  }

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final TextEditingController _headwordController = TextEditingController();
  final TextEditingController _definitionController = TextEditingController();
  final DatabaseHelper _dbHelper = DatabaseHelper();

  List<Map<String, dynamic>> _currentDefinitions = [];
  bool _isLoading = false;
  String? _selectedWord;
  String _lastHeadwordQuery = '';
  String _lastDefinitionQuery = '';
  TabController? _tabController;

  @override
  void dispose() {
    _headwordController.dispose();
    _definitionController.dispose();
    _tabController?.dispose();
    super.dispose();
  }

  Future<void> _performSearch() async {
    final headword = _headwordController.text.trim();
    final definition = _definitionController.text.trim();

    if (headword.isEmpty && definition.isEmpty) return;

    if (headword.isNotEmpty) {
      await _dbHelper.addSearchHistory(headword);
    }

    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _selectedWord = headword.isNotEmpty ? headword : definition;
      _lastHeadwordQuery = headword;
      _lastDefinitionQuery = definition;
      _currentDefinitions = [];
    });

    try {
      final settings = context.read<SettingsProvider>();
      
      List<Map<String, dynamic>> results = await _dbHelper.searchWords(
        headwordQuery: headword.isNotEmpty ? headword : null,
        headwordMode: settings.headwordSearchMode,
        definitionQuery: definition.isNotEmpty ? definition : null,
        definitionMode: settings.definitionSearchMode,
        limit: settings.searchResultLimit,
      );

      final Map<int, Map<String, List<Map<String, dynamic>>>> groupedResults = {};
      for (final result in results) {
        final dictId = result['dict_id'] as int;
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

          final String uniqueKey = '${result['offset']}_${result['length']}';

          groupedResults.putIfAbsent(dictId, () => {});
          groupedResults[dictId]!.putIfAbsent(uniqueKey, () => []);

          groupedResults[dictId]![uniqueKey]!.add({
            ...result,
            'dict_name': dict['name'],
            'definition': content,
          });
        }
      }

      final consolidatedDefs = HomeScreen.consolidateDefinitions(groupedResults);

      setState(() {
        _currentDefinitions = consolidatedDefs;
        _tabController?.dispose();
        if (consolidatedDefs.isNotEmpty) {
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

  Future<void> _onWordSelected(String word) async {
    _headwordController.text = word;
    _definitionController.clear();
    await _performSearch();
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
                _buildSearchBars(theme),
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

  Widget _buildSearchBars(ThemeData theme) {
    final settings = context.watch<SettingsProvider>();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      child: Column(
        children: [
          if (settings.isSearchInHeadwordsEnabled)
            TextField(
              controller: _headwordController,
              decoration: InputDecoration(
                hintText: 'Type headword to search',
                border: InputBorder.none,
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () => _headwordController.clear(),
                ),
              ),
              onSubmitted: (_) => _performSearch(),
            ),
          if (settings.isSearchInDefinitionsEnabled)
            TextField(
              controller: _definitionController,
              decoration: InputDecoration(
                hintText: 'Type word to search in definition',
                border: InputBorder.none,
                prefixIcon: const Icon(Icons.manage_search),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () => _definitionController.clear(),
                ),
              ),
              onSubmitted: (_) => _performSearch(),
            ),
        ],
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
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(name),
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _currentDefinitions.remove(def);
                        if (_currentDefinitions.isEmpty) {
                          _selectedWord = null;
                        } else {
                          _tabController = TabController(length: _currentDefinitions.length, vsync: this);
                        }
                      });
                    },
                    child: const Icon(Icons.close, size: 14),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: _currentDefinitions
                .map((def) => _buildDefinitionContent(theme, def,
                    highlightHeadword: _lastHeadwordQuery,
                    highlightDefinition: _lastDefinitionQuery))
                .toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildDefinitionContent(ThemeData theme, Map<String, dynamic> defMap,
      {String? highlightHeadword, String? highlightDefinition}) {
    final settings = context.watch<SettingsProvider>();
    final List<String> rawDefinitions = defMap['definitions'];
    
    final isDark =
        ThemeData.estimateBrightnessForColor(settings.backgroundColor) ==
            Brightness.dark;
    final highlightCol = isDark ? '#ff9900' : '#ffeb3b';

    return Container(
      color: settings.backgroundColor,
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              icon: const Icon(Icons.copy_all, size: 18),
              label: const Text('Copy All'),
              onPressed: () {
                final allText = rawDefinitions.map((d) => d.replaceAll(RegExp(r'<[^>]*>', multiLine: true, caseSensitive: true), '')).join('\n\n');
                Clipboard.setData(ClipboardData(text: allText));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Copied all definitions to clipboard'), duration: Duration(seconds: 2)),
                );
              },
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.only(left: 20, right: 20, bottom: 20),
              itemCount: rawDefinitions.length,
              separatorBuilder: (context, index) => const Divider(height: 32, thickness: 2),
              itemBuilder: (context, index) {
                String definitionHtml = rawDefinitions[index];
                definitionHtml = HomeScreen.normalizeWhitespace(definitionHtml);
                if (settings.isTapOnMeaningEnabled) {
                  definitionHtml = HtmlLookupWrapper.wrapWords(definitionHtml);
                }

                if (highlightHeadword != null && highlightHeadword.isNotEmpty) {
                  definitionHtml = HtmlLookupWrapper.highlightText(
                    definitionHtml,
                    highlightHeadword,
                    highlightColor: highlightCol,
                    textColor: 'black',
                  );
                }

                if (highlightDefinition != null && highlightDefinition.isNotEmpty) {
                  definitionHtml = HtmlLookupWrapper.underlineText(
                    definitionHtml,
                    highlightDefinition,
                    underlineColor: highlightCol,
                  );
                }

                return Stack(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Html(
                          data: definitionHtml,
                          style: {
                            "body": Style(fontSize: FontSize(settings.fontSize), lineHeight: LineHeight.em(1.5), margin: Margins.zero, padding: HtmlPaddings.zero, color: settings.textColor, fontFamily: settings.fontFamily),
                            "a": Style(color: theme.colorScheme.primary, textDecoration: TextDecoration.underline),
                            "mark": Style(backgroundColor: Color(int.parse(highlightCol.replaceFirst('#', '0xFF'))), color: Colors.black),
                            ".dict-word": Style(color: settings.textColor, textDecoration: TextDecoration.none),
                            ".headword": Style(color: settings.headwordColor, fontWeight: FontWeight.bold),
                            ".headword a": Style(color: settings.headwordColor, textDecoration: TextDecoration.none),
                            ".headword .dict-word": Style(color: settings.headwordColor, textDecoration: TextDecoration.none),
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
                        if (index == rawDefinitions.length - 1 && settings.isTapOnMeaningEnabled)
                          const Padding(
                            padding: EdgeInsets.only(top: 24.0),
                            child: Text('Tap on words/links to look them up.', style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey, fontSize: 12)),
                          ),
                      ],
                    ),
                    Positioned(
                      top: 0,
                      right: 0,
                      child: IconButton(
                        icon: const Icon(Icons.copy, size: 20),
                        color: Colors.grey,
                        tooltip: 'Copy this definition',
                        onPressed: () {
                          final plainText = rawDefinitions[index].replaceAll(RegExp(r'<[^>]*>', multiLine: true, caseSensitive: true), '');
                          Clipboard.setData(ClipboardData(text: plainText));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Copied definition to clipboard'), duration: Duration(seconds: 2)),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showWordPopup(String word) async {
    final settings = context.read<SettingsProvider>();
    if (!settings.isOpenPopupOnTap) {
      _onWordSelected(word);
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
                    List<Map<String, dynamic>> candidates =
                        await _dbHelper.searchWords(
                      headwordQuery: word,
                      headwordMode: settings.headwordSearchMode,
                    );
                    if (candidates.isEmpty) {
                      // fallback: longest prefix match
                      String prefix = word;
                      while (prefix.length > 2) {
                        prefix = prefix.substring(0, prefix.length - 1);
                        candidates = await _dbHelper.searchWords(
                          headwordQuery: prefix,
                          headwordMode: SearchMode.prefix,
                        );
                        if (candidates.isNotEmpty) break;
                      }
                    }
                    // Group by dictionary, consolidate headwords
                    final Map<int, Map<String, List<Map<String, dynamic>>>> groupedResults = {};
                    for (final res in candidates) {
                      final dictId = res['dict_id'] as int;
                      final wordValue = res['word'] as String;
                      final dict = await _dbHelper.getDictionaryById(dictId);
                      if (dict == null || dict['is_enabled'] != 1) continue;
                      String dictPath = await _dbHelper.resolvePath(dict['path']);
                      if (dictPath.endsWith('.ifo')) dictPath = dictPath.replaceAll('.ifo', '.dict');
                      final reader = DictReader(dictPath, dictId: dictId);
                      final content = await reader.readEntry(res['offset'], res['length']);
                      groupedResults.putIfAbsent(dictId, () => {});
                      groupedResults[dictId]!.putIfAbsent(wordValue, () => []);
                      groupedResults[dictId]![wordValue]!.add({
                        ...res,
                        'dict_name': dict['name'],
                        'definition': content,
                      });
                    }
                    return HomeScreen.consolidateDefinitions(groupedResults);
                  }(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                    if (!snapshot.hasData || snapshot.data!.isEmpty) return const Center(child: Text('No definition found.'));
                    final defs = snapshot.data!;

                    return DefaultTabController(
                      length: defs.length,
                      child: Column(
                        children: [
                          TabBar(isScrollable: true, labelColor: theme.colorScheme.primary, unselectedLabelColor: Colors.grey, tabs: defs.map((def) {
                            String name = def['dict_name'];
                            if (name.length > 13) name = '${name.substring(0, 10)}...';
                            return Tab(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(name),
                                  const SizedBox(width: 4),
                                  GestureDetector(
                                    onTap: () {
                                      defs.remove(def);
                                      (context as Element).markNeedsBuild();
                                    },
                                    child: const Icon(Icons.close, size: 14),
                                  ),
                                ],
                              ),
                            );
                          }).toList()),
                          Expanded(child: TabBarView(children: defs.map((def) => _buildDefinitionContent(theme, def)).toList())),
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
