import 'package:hdict/core/utils/logger.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:hdict/core/database/database_helper.dart';
import 'package:hdict/core/manager/dictionary_manager.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:flutter/services.dart';
import 'package:hdict/core/utils/html_lookup_wrapper.dart';
import 'package:provider/provider.dart';
import 'package:hdict/features/settings/settings_provider.dart';
import 'package:hdict/features/home/widgets/app_drawer.dart';
import 'package:hdict/features/settings/dictionary_management_screen.dart';
import 'dart:async';
import 'dart:io';
import 'package:hdict/core/utils/word_boundary.dart' as util;
import 'package:flutter/rendering.dart';
import 'package:flutter/foundation.dart';
import 'package:in_app_review/in_app_review.dart';

/// Arguments for HTML processing in a separate isolate.

class _EntryToProcess {
  final int index;
  final String content;
  final String word;
  final String format;
  final String? typeSequence;

  _EntryToProcess({
    required this.index,
    required this.content,
    required this.word,
    required this.format,
    this.typeSequence,
  });
}

/// Isolate processing completely removed in favor of Lazy processing directly in the ListView!

/// The main search screen of the hdict app.
class HomeScreen extends StatefulWidget {
  final String? initialWord;
  const HomeScreen({super.key, this.initialWord});

  // Helpers ------------------------------------------------------------------
  /// Takes results that have already been enriched with `dict_name` and
  /// `definition` and groups them first by dictionary id and then by the
  /// specific headword before producing a list suitable for the UI.
  static Future<List<Map<String, dynamic>>> consolidateDefinitions(
    List<MapEntry<int, Map<String, List<Map<String, dynamic>>>>> groupedResults, {
    Map<int, Map<String, dynamic>>? dictMap,
  }) async {
    final List<Map<String, dynamic>> consolidated = [];
    for (final dictEntry in groupedResults) {
      final dictId = dictEntry.key;
      final uniqueKeyMap = dictEntry.value;

      final dictMeta = dictMap != null
          ? dictMap[dictId]
          : await DatabaseHelper().getDictionaryById(dictId);
      final String dictName = dictMeta?['name'] ?? '';
      final String? format = dictMeta?['format'];
      final String? typeSequence = dictMeta?['type_sequence'];

      final List<String> allHeadwords = [];
      final List<Map<String, dynamic>> definitionsList = [];

      uniqueKeyMap.forEach((uniqueKey, entries) {
        if (entries.isEmpty) return;

        final headwords = entries.map((e) => e['word'] as String).toSet().toList();
        final headwordStr = headwords.join(' | ');
        allHeadwords.add(headwordStr);

        definitionsList.add({
          'word': entries.first['word'] as String,
          'headwordHtml':
              '<div class="headword" style="font-weight:bold;margin-bottom:8px;">$headwordStr</div>',
          'rawContent': entries.first['raw_content'] as String,
          'processedHtml': null,
        });
      });

      consolidated.add({
        'dict_id': dictId,
        'dict_name': dictName,
        'format': format,
        'type_sequence': typeSequence,
        'word': allHeadwords.join(' | '),
        'definitions': definitionsList,
      });
    }
    return consolidated;
  }

  /// Normalizes whitespace. If content is HTML, it's more aggressive.
  /// If it's plain text, it preserves newlines as <br>.
  static String normalizeWhitespace(
    String text, {
    String? format,
    String? typeSequence,
  }) {
    if (showHtmlProcessing) {
      hDebugPrint('normalizeWhitespace: Input: [$text]');
    }
    bool isHtml = false;
    if (format == 'mdict' || format == 'dictd') {
      isHtml = true;
    } else if (format == 'stardict') {
      if (typeSequence != null &&
          (typeSequence.contains('h') ||
              typeSequence.contains('x') ||
              typeSequence.contains('g'))) {
        isHtml = true;
      }
    }

    // Heuristic: if it looks like it has tags, treat as HTML regardless of format
    if (!isHtml && text.contains('<') && text.contains('>')) {
      isHtml = true;
    }

    if (isHtml) {
      // List of common HTML tags to KEEP.
      const allowedTags =
          'html|head|body|div|span|p|br|hr|b|i|u|blockquote|a|ul|ol|li|h[1-6]|table|tr|td|th|thead|tbody|tfoot|img|font|big|small|em|strong|sub|sup|mark|link|script|style|meta|title|head|center|font|dfn|code|samp|kbd|var|cite|abbr|acronym|q|sub|sup|ins|del|pre';

      // regex to match any tag <tag ...> or </tag>
      final genericTagRegex = RegExp(
        r'<(/?[a-z0-9]+)([^>]*)>',
        caseSensitive: false,
      );

      String processed;
      if (format == 'mdict') {
        // Mdict usually contains standard HTML.
        processed = text;
      } else {
        processed = text.replaceAllMapped(genericTagRegex, (match) {
          String fullTag = match.group(1)!;
          bool isClosing = fullTag.startsWith('/');
          String tagName = isClosing
              ? fullTag.substring(1).toLowerCase()
              : fullTag.toLowerCase();

          // If it's in the whitelist, keep it as is
          if (RegExp('^(?:$allowedTags)\$').hasMatch(tagName)) {
            return match.group(0)!;
          }

          // Convert non-standard tags to semantic span (stardict) or escape (dictd/slob)
          if (format == 'stardict') {
            if (isClosing) {
              return '</span>';
            } else {
              return '<span class="hdict-$tagName">';
            }
          } else {
            // Escape pseudo-tags in dictd, slob, etc. to prevent renderer truncation
            return match.group(0)!.replaceAll('<', '&lt;').replaceAll('>', '&gt;');
          }
        });
      }

      // Preserve newlines for non-mdict formats by converting to <br>
      // while collapsing other multiple spaces.
      if (format != 'mdict' && format != 'stardict') {
        processed = processed.replaceAll('\r\n', '\n').replaceAllMapped(
          RegExp(r'\s+'),
          (match) {
            String matchStr = match.group(0)!;
            if (matchStr.contains('\n')) {
              int n = matchStr.split('\n').length - 1;
              return '<br>' * n;
            }
            return ' ';
          },
        );
      } else {
        processed = processed.replaceAll(RegExp(r'\s+'), ' ');
      }

      final result = processed.trim();
      if (showHtmlProcessing) {
        hDebugPrint('normalizeWhitespace (HTML): Result: [$result]');
      }
      return result;
    } else {
      // Plain text dictionary: Preserve newlines by converting them to <br>
      // then collapsing other multiple spaces.
      final result = text.replaceAll('\r\n', '\n').trim().replaceAllMapped(
        RegExp(r'\s+'),
        (match) {
          if (match.group(0)!.contains('\n')) {
            // Count newlines and return appropriate number of <br>
            int n = match.group(0)!.split('\n').length - 1;
            return '<br>' * n;
          }
          return ' ';
        },
      );
      if (showHtmlProcessing) {
        hDebugPrint('normalizeWhitespace (Plain): Result: [$result]');
      }
      return result;
    }
  }

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final TextEditingController _headwordController = TextEditingController();
  final TextEditingController _definitionController = TextEditingController();
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final DictionaryManager _dictManager = DictionaryManager();

  List<Map<String, dynamic>> _currentDefinitions = [];
  bool _isLoading = false;
  String? _selectedWord;
  String _lastHeadwordQuery = '';
  String _lastDefinitionQuery = '';
  TabController? _tabController;

  int _searchSqliteMs = 0;
  int _searchOtherMs = 0;
  int _searchTotalMs = 0;
  int _searchResultCount = 0;

  bool _hasDictionaries = false;
  bool _checkingDicts = true;

  // Fix #5: Cache the dictionaries future so FutureBuilder doesn't fire a new
  // SQL query on every widget rebuild (keyboard, theme, settings changes, etc.).
  late Future<List<Map<String, dynamic>>> _dictionariesFuture;

  @override
  void dispose() {
    _headwordController.dispose();
    _definitionController.dispose();
    _tabController?.dispose();
    super.dispose();
  }

  Future<void> _performSearch({bool isRobust = false}) async {
    final headword = _headwordController.text.trim();
    final definition = _definitionController.text.trim();

    if (headword.isEmpty && definition.isEmpty) return;

    if (headword.isNotEmpty) {
      await _dbHelper.addSearchHistory(headword, searchType: 'Headword Search');
    } else if (definition.isNotEmpty) {
      await _dbHelper.addSearchHistory(
        definition,
        searchType: 'Definition Search',
      );
    }

    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _selectedWord = headword.isNotEmpty ? headword : definition;
      _lastHeadwordQuery = headword;
      _lastDefinitionQuery = definition;
      _currentDefinitions = [];
      _searchSqliteMs = 0;
      _searchOtherMs = 0;
      _searchTotalMs = 0;
      _searchResultCount = 0;
    });

    try {
      HPerf.reset();
      final settings = context.read<SettingsProvider>();
      final totalWatch = HPerf.start('Search_Total');
      final sqliteWatch = HPerf.start('Search_SQLite');

      List<Map<String, dynamic>> results = [];

      if (headword.isNotEmpty) {
        // First try with user's preferred mode
        results = await _dbHelper.searchWords(
          headwordQuery: headword,
          headwordMode: settings.headwordSearchMode,
          limit: settings.searchResultLimit,
        );

        // If robust mode is on and we found nothing, try fallbacks
        if (isRobust && results.isEmpty) {
          // 1. Try exact match if preferred mode wasn't already exact
          if (settings.headwordSearchMode != SearchMode.exact) {
            results = await _dbHelper.searchWords(
              headwordQuery: headword,
              headwordMode: SearchMode.exact,
            );
          }

          // 2. Try longest prefix match (like popup logic)
          if (results.isEmpty) {
            String prefix = headword;
            while (prefix.length > 2) {
              prefix = prefix.substring(0, prefix.length - 1);
              results = await _dbHelper.searchWords(
                headwordQuery: prefix,
                headwordMode: SearchMode.prefix,
                limit: settings.searchResultLimit,
              );
              if (results.isNotEmpty) break;
            }
          }
        }
      } else if (definition.isNotEmpty) {
        results = await _dbHelper.searchWords(
          definitionQuery: definition,
          definitionMode: settings.definitionSearchMode,
          limit: settings.searchResultLimit,
        );
      }

      HPerf.end(sqliteWatch, 'Search_SQLite');
      final sqliteMs = sqliteWatch?.elapsedMilliseconds ?? 0;

      final List<_EntryToProcess> entriesToProcess = [];
      final List<Map<String, dynamic>> resultsMetadata = [];

      final enrichmentWatch = HPerf.start('Search_Enrichment');

      // The database helper now internally caches dictionary metadata, 
      // so we can rely on it and avoid manual pre-fetching logic here.

      // Group results by dictionary for batch fetching. 
      // This is critical for performance on stateful readers (.dz, .mdx).
      final Map<int, List<Map<String, dynamic>>> resultsByDict = {};
      final Map<int, List<int>> originalIndicesByDict = {};

      for (int i = 0; i < results.length; i++) {
        final r = results[i];
        final dictId = r['dict_id'] as int;
        // dictMap lookup is now a memory-based lookup inside _dbHelper.getDictionaryById
        final dict = await _dbHelper.getDictionaryById(dictId);
        if (dict != null && dict['is_enabled'] == 1) {
          resultsByDict.putIfAbsent(dictId, () => []).add(r);
          originalIndicesByDict.putIfAbsent(dictId, () => []).add(i);
        }
      }

      // Phase 1: Parallel definition fetching across dictionaries (IO bound)
      final fetchAllDictsWatch = HPerf.start('fetchAllDicts_Wall');
      await Future.wait(
        resultsByDict.entries.map((entry) async {
          final dictId = entry.key;
          final requests = entry.value;
          final originalIndices = originalIndicesByDict[dictId]!;
          final dict = (await _dbHelper.getDictionaryById(dictId))!;

          final batchContents = await _dictManager.fetchDefinitionsBatch(
            dict,
            requests,
          );

          for (int i = 0; i < requests.length; i++) {
            final content = batchContents[i] ?? '';
            final req = requests[i];
            final ogIndex = originalIndices[i];

            entriesToProcess.add(
              _EntryToProcess(
                index: ogIndex,
                content: content,
                word: req['word'] as String,
                format: dict['format'],
                typeSequence: dict['type_sequence'],
              ),
            );

            // We store ONLY the original result reference and the dictId.
            // Dictionary metadata like name/format will be looked up during 
            // consolidation from the shared dictMap, avoiding 50k Map instances.
            resultsMetadata.add(req);
          }
        }),
      );
      HPerf.end(fetchAllDictsWatch, 'fetchAllDicts_Wall');

      // Phase 2: HTML Processing is now done LAZILY during ListView scrolling!
      if (entriesToProcess.isNotEmpty) {
        final Map<int, Map<String, List<Map<String, dynamic>>>> finalGrouped =
            {};
        int finalResultCount = 0;

        for (int i = 0; i < entriesToProcess.length; i++) {
          final entry = entriesToProcess[i];
          final original = results[entry.index];
          final dictId = original['dict_id'] as int;
          final String uniqueKey =
              '${original['offset']}_${original['length']}';

          final meta = resultsMetadata[i];

          finalResultCount++;
          finalGrouped.putIfAbsent(dictId, () => {});
          finalGrouped[dictId]!.putIfAbsent(uniqueKey, () => []);
          finalGrouped[dictId]![uniqueKey]!.add({
            ...meta,
            'raw_content': entry.content,
          });
        }

        HPerf.end(enrichmentWatch, 'Search_Enrichment');

        // Sort finalGrouped by display_order so results respect user-configured priority.
        final sortedGroupedList = finalGrouped.entries.toList();
        
        // Sorting is now asynchronous because it looks up metadata via the DB helper (cached).
        // Since we know the internal cache is likely populated by now (due to previous fetches), 
        // we can either await each or use a helper. 
        // Let's use a Future.wait approach for maximum safety and concurrency.
        final List<({int dictId, int displayOrder, MapEntry<int, Map<String, List<Map<String, dynamic>>>> entry})> sortData = await Future.wait(
          sortedGroupedList.map((entry) async {
            final dict = await _dbHelper.getDictionaryById(entry.key);
            return (
              dictId: entry.key,
              displayOrder: (dict?['display_order'] as int?) ?? 999,
              entry: entry
            );
          }),
        );
        
        sortData.sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
        final finalizedEntries = sortData.map((d) => d.entry).toList();

        final consolidatedDefs = await HomeScreen.consolidateDefinitions(
          finalizedEntries,
        );

        HPerf.end(totalWatch, 'Search_Total');
        HPerf.dump(prefix: '--- SEARCH RESULTS PERF ---');

        setState(() {
          _currentDefinitions = consolidatedDefs;
          _searchResultCount = finalResultCount;
          _searchSqliteMs = sqliteMs;
          _searchTotalMs = totalWatch?.elapsedMilliseconds ?? 0;
          _searchOtherMs = _searchTotalMs - _searchSqliteMs;
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
      } else {
        HPerf.end(enrichmentWatch, 'Search_Enrichment');
        HPerf.end(totalWatch, 'Search_Total');
        HPerf.dump(prefix: '--- SEARCH RESULTS EMPTY ---');
        setState(() {
          _currentDefinitions = [];
          _searchResultCount = 0;
          _isLoading = false;
        });
      }
      hDebugPrint(
        '--- SEARCH_TOTAL: ${_searchTotalMs}ms (SQLite: ${sqliteMs}ms, Other: ${_searchOtherMs}ms) ---',
      );
    } catch (e) {
      hDebugPrint('Error fetching definitions: $e');
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

  @override
  void initState() {
    super.initState();
    enableDebugLogs = true; // Enable logging for performance investigation

    if (widget.initialWord != null) {
      _headwordController.text = widget.initialWord!;
      _selectedWord = widget.initialWord!;
      _isLoading = true;
    }

    _dictionariesFuture = _dbHelper.getDictionaries();
    _checkDictionaries();
    _cleanHistory();
    _cleanOrphanedFiles();

    // Check for migration alert from version 16
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (DatabaseHelper.needsMigrationAlert) {
        DatabaseHelper.needsMigrationAlert = false;
        _showMigrationNotice();
      }

      _checkAndPromptReview();

      if (widget.initialWord != null) {
        // Double check text if it somehow got cleared
        if (_headwordController.text.isEmpty) {
          _headwordController.text = widget.initialWord!;
        }
        _definitionController.clear();

        // Ensure _hasDictionaries is checked at least once before searching
        // if it's still false, we wait a bit or just proceed as searchWords
        // will return empty anyway if no dicts exist in DB.
        _performSearch(isRobust: true);
      }
    });
  }

  Future<void> _checkAndPromptReview() async {
    // Give the app some time to settle and for the user to see the home screen
    await Future.delayed(const Duration(seconds: 5));
    if (!mounted) return;

    final settings = context.read<SettingsProvider>();
    
    // Check if we already prompted in this session
    if (settings.reviewPromptedThisSession) {
      return;
    }

    // In Debug Mode, we always bypass most checks so you can test the UI,
    // but we still respect the session flag and we don't spam if already given.
    if (!kDebugMode) {
      if (settings.hasGivenReview || settings.reviewPromptCount >= 5) {
        return;
      }
    } else {
      // In debug, if they already manually said they gave review, maybe stop? 
      // But user said "for the session if the user avoids giving feedback in debug app mode"
    }

    await settings.initAppFirstLaunchDateIfNeeded();

    final now = DateTime.now().millisecondsSinceEpoch;
    // Date check is also bypassed in Debug Mode
    if (kDebugMode || now >= settings.nextReviewPromptDate) {
      if (!mounted) return;

      final InAppReview inAppReview = InAppReview.instance;
      if (await inAppReview.isAvailable()) {
        // Mark as prompted for this session BEFORE showing, so returning to home doesn't trigger it again
        settings.setReviewPromptedThisSession(true);
        
        await settings.incrementReviewPromptCountAndSetNextDate();
        await inAppReview.requestReview();
      } else if (Platform.isLinux) {
        // Fallback for platforms where in-app review is not available natively e.g Linux (Snap Store)
        if (!mounted) return;
        settings.setReviewPromptedThisSession(true);
        showDialog(
          context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Enjoying hdict?'),
              content: const Text(
                  'If you find this app useful, please consider giving it a rating or review on the Snap Store.'),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    settings.incrementReviewPromptCountAndSetNextDate();
                  },
                  child: const Text('Later'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    if (!kDebugMode) {
                      settings.setHasGivenReview(true);
                    }
                    launchUrl(Uri.parse('https://snapcraft.io/hdict')); 
                  },
                  child: const Text('Rate on Snap Store'),
                ),
              ],
            ),
          );
      }
    }
  }

  void _showMigrationNotice() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Database Update'),
        content: const Text(
          'Because of a newer version of database to reduce your storage space, '
          'you may see your dictionaries having 0 words. '
          'Just reindex the dictionaries again from Manage Dictionaries.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _cleanOrphanedFiles() async {
    try {
      // Small delay to let app settle
      await Future.delayed(const Duration(seconds: 2));
      if (!mounted) return;

      final orphanedFolders = await _dictManager.getOrphanedDictionaryFolders();
      if (orphanedFolders.isNotEmpty && mounted) {
        _showOrphanCleanupDialog(orphanedFolders);
      }
    } catch (e) {
      hDebugPrint('Clean orphaned files error: $e');
    }
  }

  void _showOrphanCleanupDialog(List<String> folders) {
    List<String> selectedFolders = List.from(folders);

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Orphaned Data Found'),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Your App Data has dictionaries which you have deleted. '
                  'Would you like to delete the following dictionary data to free up space?',
                ),
                const SizedBox(height: 16),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: folders.length,
                    itemBuilder: (context, index) {
                      final folder = folders[index];
                      return CheckboxListTile(
                        title: Text(folder),
                        value: selectedFolders.contains(folder),
                        onChanged: (val) {
                          setDialogState(() {
                            if (val == true) {
                              selectedFolders.add(folder);
                            } else {
                              selectedFolders.remove(folder);
                            }
                          });
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Later'),
            ),
            ElevatedButton(
              onPressed: selectedFolders.isEmpty
                  ? null
                  : () async {
                      final messenger = ScaffoldMessenger.of(context);
                      await _dictManager.deleteOrphanedFolders(selectedFolders);
                      if (!context.mounted) return;
                      Navigator.pop(context);
                      messenger.showSnackBar(
                        const SnackBar(content: Text('Cleanup complete.')),
                      );
                    },
              child: const Text('Delete Selected'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _cleanHistory() async {
    try {
      final settings = context.read<SettingsProvider>();
      await _dbHelper.deleteOldSearchHistory(settings.historyRetentionDays);
    } catch (e) {
      hDebugPrint('Clean history error: $e');
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
        title: const Text(
          'hdict',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
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
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.library_books_outlined,
                size: 80,
                color: theme.colorScheme.primary.withValues(alpha: 0.3),
              ),
              const SizedBox(height: 24),
              Text(
                'No dictionaries found',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'To start searching, you need to install at least one dictionary.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 32),
              _buildGuidanceCard(theme),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGuidanceCard(ThemeData theme) {
    return Card(
      elevation: 0,
      color: theme.colorScheme.primaryContainer.withValues(alpha: 0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: theme.colorScheme.primary.withValues(alpha: 0.1),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.language,
                color: theme.colorScheme.primary,
                size: 32,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Select Dictionaries by selecting your desired languages',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Quickly download high-quality dictionaries for dozens of languages directly within the app.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const DictionaryManagementScreen(
                      triggerSelectByLanguage: true,
                    ),
                  ),
                ).then((_) => _checkDictionaries());
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: theme.colorScheme.onPrimary,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
              ),
              child: const Text(
                'Select by Language',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: Divider(color: Colors.grey.withValues(alpha: 0.2)),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    'OR',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.withValues(alpha: 0.5),
                    ),
                  ),
                ),
                Expanded(
                  child: Divider(color: Colors.grey.withValues(alpha: 0.2)),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'You can also use "Import File", "Import Folder" or "Download from Web" if you have a specific file or URL.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.withValues(alpha: 0.6),
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
      future: _dictionariesFuture, // Fix #5: use cached future
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty)
          return const SizedBox.shrink();
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
    if (_isLoading) return const SizedBox.shrink();
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

    if (_tabController == null ||
        _tabController!.length != _currentDefinitions.length)
      return const SizedBox.shrink();
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
                          _tabController = TabController(
                            length: _currentDefinitions.length,
                            vsync: this,
                          );
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
                .map(
                  (def) => _buildDefinitionContent(
                    theme,
                    def,
                    highlightHeadword: _lastHeadwordQuery,
                    highlightDefinition: _lastDefinitionQuery,
                  ),
                )
                .toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildDefinitionContent(
    ThemeData theme,
    Map<String, dynamic> defMap, {
    String? highlightHeadword,
    String? highlightDefinition,
    int? searchSqliteMs,
    int? searchOtherMs,
    int? searchTotalMs,
    int? searchResultCount,
  }) {
    final settings = context.watch<SettingsProvider>();
    final List<Map<String, dynamic>> rawDefinitions =
        List<Map<String, dynamic>>.from(defMap['definitions']);

    final highlightCol =
        ThemeData.estimateBrightnessForColor(settings.backgroundColor) ==
            Brightness.dark
        ? '#ff9900'
        : '#ffeb3b';

    return Container(
      color: settings.getEffectiveBackgroundColor(context),
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              icon: const Icon(Icons.copy_all, size: 18),
              label: const Text('Copy All'),
              onPressed: () {
                final allText = rawDefinitions
                    .map((d) {
                      final String html =
                          d['processedHtml'] ??
                          '${d['headwordHtml']}\n${d['rawContent']}';
                      return html.replaceAll(
                        RegExp(
                          r'<[^>]*>',
                          multiLine: true,
                          caseSensitive: true,
                        ),
                        '',
                      );
                    })
                    .join('\n\n');
                Clipboard.setData(ClipboardData(text: allText));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Copied all definitions to clipboard'),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
            ),
          ),
          Expanded(
            child: SafeArea(
              top: false,
              child: ListView.separated(
                padding: const EdgeInsets.only(left: 20, right: 20, bottom: 20),
                itemCount: rawDefinitions.length + 1,
                separatorBuilder: (context, index) {
                  if (index == rawDefinitions.length - 1) {
                    return const Divider(
                      height: 48,
                      thickness: 1,
                      color: Colors.transparent,
                    );
                  }
                  return const Divider(height: 32, thickness: 2);
                },
                itemBuilder: (context, index) {
                  if (index == rawDefinitions.length) {
                    final sqliteMs = searchSqliteMs ?? _searchSqliteMs;
                    final totalMs = searchTotalMs ?? _searchTotalMs;
                    final otherMs = searchOtherMs ?? _searchOtherMs;
                    final resultCount = searchResultCount ?? _searchResultCount;
                    final dictName = defMap['dict_name'] ?? 'Unknown Dictionary';

                    return Text(
                      'Dictionary: $dictName\n'
                      'Showed $resultCount results in $totalMs ms.\n'
                      'Sqlite query took $sqliteMs ms.\n'
                      'Other work took $otherMs ms.',
                      style: TextStyle(
                        fontSize: 11,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    );
                  }

                  // HTML Processing is done LAZILY right as the item scrolls onto the screen!
                  final Map<String, dynamic> defData = rawDefinitions[index];
                  String? definitionHtml = defData['processedHtml'];

                  if (definitionHtml == null) {
                    final String rawContent = defData['rawContent'] as String;
                    final String format =
                        defMap['format'] as String? ?? 'stardict';
                    final String? typeSequence =
                        defMap['type_sequence'] as String?;

                    // Wrap and Highlight (Word wrapping removed in favor of tap-position detection)
                    final processed = HtmlLookupWrapper.processRecord(
                      html: HomeScreen.normalizeWhitespace(
                        rawContent,
                        format: format,
                        typeSequence: typeSequence,
                      ),
                      format: format,
                      typeSequence: typeSequence,
                      underlineQuery: _lastDefinitionQuery,
                    );

                    definitionHtml = '${defData['headwordHtml']}\n$processed';
                    if (showHtmlProcessing) {
                      hDebugPrint('HomeScreen: Final definitionHtml: [$definitionHtml]');
                    }
                    defData['processedHtml'] =
                        definitionHtml; // Cache for subsequent scrolls
                  }

                  return Stack(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          MouseRegion(
                            cursor: settings.isTapOnMeaningEnabled
                              ? SystemMouseCursors.click
                              : MouseCursor.defer,
                            child: Builder(
                              builder: (ctx) => GestureDetector(
                                behavior: HitTestBehavior.translucent,
                                onTapUp: (details) {
                                  if (!settings.isTapOnMeaningEnabled) {
                                    hDebugPrint(
                                      'Tap ignored: isTapOnMeaningEnabled is false',
                                    );
                                    return;
                                  }

                                  final RenderBox? renderBox =
                                      ctx.findRenderObject() as RenderBox?;
                                  if (renderBox == null) {
                                    hDebugPrint('Tap ignored: renderBox is null');
                                    return;
                                  }

                                  final BoxHitTestResult result =
                                      BoxHitTestResult();
                                  renderBox.hitTest(
                                    result,
                                    position: renderBox.globalToLocal(
                                      details.globalPosition,
                                    ),
                                  );

                                  for (final HitTestEntry entry in result.path) {
                                    final target = entry.target;
                                    if (target is RenderParagraph) {
                                      final String text = target.text
                                          .toPlainText();
                                      // Ignore \uFFFC which is the Object Replacement Character representing inline widgets
                                      if (text
                                          .replaceAll('\uFFFC', '')
                                          .trim()
                                          .isEmpty)
                                        continue;

                                      final Offset localOffset = target
                                          .globalToLocal(details.globalPosition);
                                      final TextPosition pos = target
                                          .getPositionForOffset(localOffset);
                                      final String charAtOffset =
                                          (pos.offset >= 0 &&
                                              pos.offset < text.length)
                                          ? text[pos.offset]
                                          : 'EOF';

                                      hDebugPrint(
                                        'HitTest detected on Paragraph text: "$text"',
                                      );
                                      hDebugPrint(
                                        'Calculated TextOffset: ${pos.offset}, Char: "$charAtOffset"',
                                      );

                                      final String? word = util
                                          .WordBoundary.wordAt(text, pos.offset);
                                      hDebugPrint(
                                        'Word tapped for search: $word',
                                      );

                                      if (word != null &&
                                          word.trim().isNotEmpty) {
                                        _showWordPopup(word);
                                        return; // Stop looking after the first valid text paragraph is found
                                      }
                                    }
                                  }
                                  hDebugPrint(
                                    'HitTest found no valid text paragraph.',
                                  );
                                },
                                child: Html(
                                  data: definitionHtml,
                                  style: {
                                    "body": Style(
                                      fontSize: FontSize(settings.fontSize),
                                      lineHeight: LineHeight.em(1.5),
                                      margin: Margins.zero,
                                      padding: HtmlPaddings.zero,
                                      color: settings.getEffectiveTextColor(context),
                                      fontFamily: settings.fontFamily,
                                    ),
                                    "a": Style(
                                      color: theme.colorScheme.primary,
                                      textDecoration: TextDecoration.underline,
                                    ),
                                    "mark": Style(
                                      backgroundColor: Color(
                                        int.parse(
                                          highlightCol.replaceFirst('#', '0xFF'),
                                        ),
                                      ),
                                      color: Colors.black,
                                    ),
                                    ".dict-word": Style(
                                      color: settings.textColor,
                                      textDecoration: TextDecoration.none,
                                    ),
                                    ".headword": Style(
                                      color: settings.getEffectiveHeadwordColor(context),
                                      fontWeight: FontWeight.bold,
                                    ),
                                    ".headword a": Style(
                                      color: settings.getEffectiveHeadwordColor(context),
                                      textDecoration: TextDecoration.none,
                                    ),
                                    ".headword .dict-word": Style(
                                      color: settings.headwordColor,
                                      textDecoration: TextDecoration.none,
                                    ),
                                  },
                                  onLinkTap: (url, attributes, element) async {
                                    hDebugPrint(
                                      'onLinkTap triggered with url: $url',
                                    );
                                    if (url != null) {
                                      if (url.startsWith('http://') ||
                                          url.startsWith('https://')) {
                                        hDebugPrint(
                                          'Launching external URL: $url',
                                        );
                                        final uri = Uri.parse(url);
                                        if (await canLaunchUrl(uri)) {
                                          await launchUrl(
                                            uri,
                                            mode: LaunchMode.externalApplication,
                                          );
                                        }
                                      } else {
                                        String wordToLookup = url;
                                        if (wordToLookup.startsWith('look_up:')) {
                                          wordToLookup = wordToLookup.substring(
                                            8,
                                          );
                                        } else if (wordToLookup.startsWith(
                                          'bword://',
                                        )) {
                                          wordToLookup = wordToLookup.substring(
                                            8,
                                          );
                                        }
                                        try {
                                          final word = wordToLookup.contains('%')
                                              ? Uri.decodeComponent(wordToLookup)
                                              : wordToLookup;
                                          _showWordPopup(word);
                                        } catch (e) {
                                          _showWordPopup(wordToLookup);
                                        }
                                      }
                                    }
                                  },
                                ),
                              ),
                            ),
                          ),
                          if (index == rawDefinitions.length - 1 &&
                              settings.isTapOnMeaningEnabled)
                            Padding(
                              padding: const EdgeInsets.only(top: 24.0),
                              child: Text(
                                'Tap on words/links to look them up.',
                                style: TextStyle(
                                  fontStyle: FontStyle.italic,
                                  color: theme.colorScheme.onSurfaceVariant,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                        ],
                      ),
                      Positioned(
                        top: 0,
                        right: 0,
                        child: IconButton(
                          icon: const Icon(Icons.copy, size: 20),
                          color: theme.colorScheme.onSurfaceVariant,
                          tooltip: 'Copy this definition',
                          onPressed: () {
                            final String copyHtml =
                                rawDefinitions[index]['processedHtml'] ??
                                '${rawDefinitions[index]['headwordHtml']}\n${rawDefinitions[index]['rawContent']}';
                            final plainText = copyHtml.replaceAll(
                              RegExp(
                                r'<[^>]*>',
                                multiLine: true,
                                caseSensitive: true,
                              ),
                              '',
                            );
                            Clipboard.setData(ClipboardData(text: plainText));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Copied definition to clipboard'),
                                duration: Duration(seconds: 2),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showWordPopup(String word) async {
    final settings = context.read<SettingsProvider>();
    await _dbHelper.addSearchHistory(word, searchType: 'Pop-up Search');
    if (!mounted) return;
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
          decoration: BoxDecoration(
            color: settings.getEffectiveBackgroundColor(context),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(20),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.info_outline,
                      size: 20,
                      color: Colors.orange,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        word,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.keyboard_arrow_down),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: FutureBuilder<Map<String, dynamic>>(
                  future: () async {
                    HPerf.reset();
                    final totalWatch = HPerf.start('Pop-up_Total');
                    final sqliteWatch = HPerf.start('Pop-up_SQLite');

                    // 1. Try exact match first for popups
                    List<Map<String, dynamic>> candidates = await _dbHelper
                        .searchWords(
                          headwordQuery: word,
                          headwordMode: SearchMode.exact,
                        );

                    // 2. Fallback to user setting or prefix if exact fails
                    if (candidates.isEmpty) {
                      candidates = await _dbHelper.searchWords(
                        headwordQuery: word,
                        headwordMode: settings.headwordSearchMode,
                      );
                    }

                    // 3. Last fallback: longest prefix match
                    if (candidates.isEmpty) {
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

                    HPerf.end(sqliteWatch, 'Pop-up_SQLite');

                    final enrichmentWatch = HPerf.start('Pop-up_Enrichment');

                    // Parallelize definition fetching and HTML pre-processing

                    // The database helper now internally caches dictionary metadata.

                    // fetchAllDefs_Wall = true wall-clock time of all parallel
                    // fetchDefinition calls. fetchDef_IO "total" is a misleading
                    // sum; use "max" per-call or this wall timer instead.
                    final fetchAllDefsWatch = HPerf.start('fetchAllDefs_Wall');
                    final results = await Future.wait(
                      candidates.map((res) async {
                        final dictId = res['dict_id'] as int;
                        final wordValue = res['word'] as String;
                        final dict = await _dbHelper.getDictionaryById(dictId);
                        if (dict == null || dict['is_enabled'] != 1)
                          return null;

                        String content =
                            await _dictManager.fetchDefinition(
                              dict,
                              wordValue,
                              res['offset'] as int,
                              res['length'] as int,
                            ) ??
                            '';

                        return {
                          'id': dictId,
                          'word': wordValue,
                          'dict_name': dict['name'],
                          'raw_content': content,
                          'format': dict['format'],
                          'type_sequence': dict['type_sequence'],
                        };
                      }),
                    );
                    HPerf.end(fetchAllDefsWatch, 'fetchAllDefs_Wall');

                    final Map<int, Map<String, List<Map<String, dynamic>>>>
                    groupedResults = {};
                    int resultCount = 0;
                    for (final res in results) {
                      if (res == null) continue;
                      resultCount++;
                      final dictId = res['id'] as int;
                      final wordValue = res['word'] as String;
                      groupedResults.putIfAbsent(dictId, () => {});
                      groupedResults[dictId]!.putIfAbsent(wordValue, () => []);
                      groupedResults[dictId]![wordValue]!.add(res);
                    }

                    // Sort by display order
                    final List<({int dictId, int displayOrder, MapEntry<int, Map<String, List<Map<String, dynamic>>>> entry})> sortData = await Future.wait(
                      groupedResults.entries.map((entry) async {
                        final dict = await _dbHelper.getDictionaryById(entry.key);
                        return (
                          dictId: entry.key,
                          displayOrder: (dict?['display_order'] as int?) ?? 999,
                          entry: entry
                        );
                      }),
                    );
                    
                    sortData.sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
                    final sortedEntries = sortData.map((d) => d.entry).toList();

                    final consolidated = await HomeScreen.consolidateDefinitions(
                      sortedEntries,
                    );

                    HPerf.end(enrichmentWatch, 'Pop-up_Enrichment');
                    HPerf.end(totalWatch, 'Pop-up_Total');
                    HPerf.dump(prefix: '--- POP-UP SEARCH PERF ---');

                    final timing = {
                      'sqliteMs': sqliteWatch?.elapsedMilliseconds ?? 0,
                      'totalMs': totalWatch?.elapsedMilliseconds ?? 0,
                      'otherMs':
                          (totalWatch?.elapsedMilliseconds ?? 0) -
                          (sqliteWatch?.elapsedMilliseconds ?? 0),
                      'resultCount': resultCount,
                    };

                    return {'definitions': consolidated, 'timing': timing};
                  }(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (!snapshot.hasData ||
                        (snapshot.data!['definitions'] as List).isEmpty) {
                      return const Center(child: Text('No definition found.'));
                    }
                    final Map<String, dynamic> data = snapshot.data!;
                    final List<Map<String, dynamic>> defs = data['definitions'];
                    final Map<String, int> timing = data['timing'];

                    return DefaultTabController(
                      length: defs.length,
                      child: Column(
                        children: [
                          TabBar(
                            isScrollable: true,
                            labelColor: theme.colorScheme.primary,
                            unselectedLabelColor: Colors.grey,
                            tabs: defs.map((def) {
                              String name = def['dict_name'];
                              if (name.length > 13) {
                                name = '${name.substring(0, 10)}...';
                              }
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
                            }).toList(),
                          ),
                          Expanded(
                            child: TabBarView(
                              children: defs
                                  .map(
                                    (def) => _buildDefinitionContent(
                                      theme,
                                      def,
                                      highlightHeadword: word,
                                      searchSqliteMs: timing['sqliteMs'],
                                      searchOtherMs: timing['otherMs'],
                                      searchTotalMs: timing['totalMs'],
                                      searchResultCount: timing['resultCount'],
                                    ),
                                  )
                                  .toList(),
                            ),
                          ),
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
