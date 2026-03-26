import 'package:hdict/core/utils/logger.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:hdict/core/database/database_helper.dart';
import 'package:hdict/core/manager/dictionary_manager.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:flutter/services.dart';
import 'package:hdict/core/utils/html_lookup_wrapper.dart';
import 'package:hdict/core/utils/multimedia_processor.dart';
import 'package:hdict/core/utils/anchor_id_extension.dart';
import 'package:provider/provider.dart';
import 'package:hdict/features/settings/settings_provider.dart';
import 'package:hdict/features/home/widgets/app_drawer.dart';
import 'package:hdict/features/settings/dictionary_management_screen.dart';
import 'dart:async';
import 'dart:io';
import 'package:hdict/core/utils/word_boundary.dart' as util;
import 'package:just_audio/just_audio.dart';
import 'package:video_player/video_player.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/foundation.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:chewie/chewie.dart';

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
    List<MapEntry<int, Map<String, List<Map<String, dynamic>>>>>
    groupedResults, {
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

      if (format == 'mdict') {
        for (final entries in uniqueKeyMap.values) {
          for (final entry in entries) {
            final word = entry['word'] as String;
            final rawContent = entry['raw_content'] as String;
            allHeadwords.add(word);
            definitionsList.add({
              'word': word,
              'headwordHtml':
                  '<div class="headword" style="font-weight:bold;margin-bottom:8px;">$word</div>',
              'rawContent': rawContent,
              'processedHtml': null,
            });
          }
        }
      } else {
        uniqueKeyMap.forEach((uniqueKey, entries) {
          if (entries.isEmpty) return;

          final headwords = entries
              .map((e) => e['word'] as String)
              .toSet()
              .toList();
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
      }

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
            return match
                .group(0)!
                .replaceAll('<', '&lt;')
                .replaceAll('>', '&gt;');
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
  final AudioPlayer _pronunciationPlayer = AudioPlayer();

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

  // Search generation counter to prevent stale results from overwriting newer searches
  int _searchGeneration = 0;

  // Track if a popup is currently open to prevent duplicate popups
  bool _isPopupOpen = false;

  bool _hasDictionaries = false;
  bool _checkingDicts = true;

  // Fix #5: Cache the dictionaries future so FutureBuilder doesn't fire a new
  // SQL query on every widget rebuild (keyboard, theme, settings changes, etc.).
  late Future<List<Map<String, dynamic>>> _dictionariesFuture;

  void _playPronunciation(String url, int dictId) async {
    if (!url.startsWith('mdd-audio:')) return;

    final resourceKey = url.substring('mdd-audio:'.length);
    final mdictReader = DictionaryManager.instance.getMdictReader(dictId);
    if (mdictReader == null) return;

    final data = await mdictReader.getMddResourceBytes(resourceKey);
    if (data == null) return;

    try {
      final tempDir = await getTemporaryDirectory();
      final ext = resourceKey.split('.').last.toLowerCase();

      // Formats that just_audio supports natively: mp3, wav, m4a, aac, ogg, flac, wma, aiff
      // Convert unsupported formats (spx, amr, etc.) to m4a using ffmpeg
      final supportedExts = [
        'mp3',
        'wav',
        'm4a',
        'aac',
        'ogg',
        'flac',
        'wma',
        'aiff',
        '3gp',
      ];
      final needsConversion = !supportedExts.contains(ext);

      final inputFile = File(
        '${tempDir.path}/pron_${DateTime.now().millisecondsSinceEpoch}_input.$ext',
      );
      await inputFile.writeAsBytes(data);

      String audioPath;
      if (needsConversion) {
        hDebugPrint(
          '_playPronunciation: .$ext format not supported, skipping audio',
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Audio format .$ext is not supported on this device',
              ),
              duration: const Duration(seconds: 2),
            ),
          );
        }
        await inputFile.delete().catchError((_) => File(''));
        return;
      } else {
        audioPath = inputFile.path;
      }

      await _pronunciationPlayer.setFilePath(audioPath);
      hDebugPrint('_playPronunciation: Playing audio...');
      await _pronunciationPlayer.play();
      hDebugPrint('_playPronunciation: Play called');

      File(audioPath).delete().catchError((_) => File(''));
    } catch (e, stack) {
      hDebugPrint('_playPronunciation: EXCEPTION: $e');
      hDebugPrint('_playPronunciation: Stack: $stack');
    }
  }

  void _showMediaPlayer(String url, int dictId) async {
    final parts = url.split(':');
    if (parts.length != 2) return;

    final mediaType = parts[0];
    final resourceKey = parts[1];

    final mdictReader = DictionaryManager.instance.getMdictReader(dictId);
    if (mdictReader == null) return;

    Uint8List? data;
    if (mediaType == 'mdd-audio') {
      data = await mdictReader.getMddResourceBytes(resourceKey);
    } else if (mediaType == 'mdd-video') {
      data = await mdictReader.getMddResourceBytes(resourceKey);
    }

    if (data == null) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Media not found')));
      }
      return;
    }

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => _MediaPlayerDialog(
        data: data!,
        mediaType: mediaType == 'mdd-audio' ? 'audio' : 'video',
        filename: resourceKey,
      ),
    );
  }

  @override
  void dispose() {
    _headwordController.dispose();
    _definitionController.dispose();
    _tabController?.dispose();
    _pronunciationPlayer.dispose();
    super.dispose();
  }

  Future<void> _performSearch({bool isRobust = false}) async {
    final headword = _headwordController.text.trim();
    final definition = _definitionController.text.trim();

    if (headword.isEmpty && definition.isEmpty) return;

    // Increment search generation to invalidate any in-flight older searches
    final searchGen = ++_searchGeneration;
    hDebugPrint(
      'HomeScreen._performSearch: START gen=$searchGen for "$headword"',
    );

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
        // First, ensure dictionary cache is loaded for fast synchronous lookups.
        await _dbHelper.getDictionaries();

        final sortedGroupedList = finalGrouped.entries.toList();
        final List<
          ({
            int displayOrder,
            int dictId,
            MapEntry<int, Map<String, List<Map<String, dynamic>>>> entry,
          })
        >
        sortData = sortedGroupedList.map((entry) {
          final dict = _dbHelper.getDictionaryByIdSync(entry.key);
          return (
            displayOrder: (dict?['display_order'] as int?) ?? 999,
            dictId: entry.key,
            entry: entry,
          );
        }).toList();

        sortData.sort((a, b) {
          final orderCompare = a.displayOrder.compareTo(b.displayOrder);
          if (orderCompare != 0) return orderCompare;
          return a.dictId.compareTo(b.dictId);
        });
        final finalizedEntries = sortData.map((d) => d.entry).toList();

        final consolidatedDefs = await HomeScreen.consolidateDefinitions(
          finalizedEntries,
        );

        HPerf.end(totalWatch, 'Search_Total');
        HPerf.dump(prefix: '--- SEARCH RESULTS PERF ---');

        // Check if this search is still the latest (not superseded by a newer search)
        if (searchGen != _searchGeneration) {
          hDebugPrint(
            'HomeScreen._performSearch: gen=$searchGen is stale (current gen=$_searchGeneration), discarding results',
          );
          return;
        }
        hDebugPrint(
          'HomeScreen._performSearch: gen=$searchGen updating UI with ${consolidatedDefs.length} results',
        );

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
        // Check if this search is still the latest
        if (searchGen != _searchGeneration) {
          hDebugPrint(
            'HomeScreen._performSearch: gen=$searchGen is stale (empty results), discarding',
          );
          return;
        }
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
      // Check if this search is still the latest
      if (searchGen != _searchGeneration) {
        hDebugPrint(
          'HomeScreen._performSearch: gen=$searchGen is stale (error), discarding',
        );
        return;
      }
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
              'If you find this app useful, please consider giving it a rating or review on the Snap Store.',
            ),
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
        crossAxisAlignment: CrossAxisAlignment.start,
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
            const SizedBox(height: 4),
            Text(
              '${snapshot.data!.where((d) => d['is_enabled'] == 1).length} active',
              style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
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
                    searchSqliteMs: _searchSqliteMs,
                    searchOtherMs: _searchOtherMs,
                    searchTotalMs: _searchTotalMs,
                    searchResultCount: _searchResultCount,
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
    final int dictId = defMap['dict_id'] as int;
    final String format = defMap['format'] as String? ?? 'stardict';

    if (format == 'mdict') {
      return _MdictDefinitionContent(
        key: ValueKey('mdict_${dictId}_${defMap['word'] ?? ''}'),
        defMap: defMap,
        dictId: dictId,
        theme: theme,
        highlightHeadword: highlightHeadword,
        highlightDefinition: highlightDefinition,
        searchSqliteMs: searchSqliteMs,
        searchOtherMs: searchOtherMs,
        searchTotalMs: searchTotalMs,
        searchResultCount: searchResultCount,
        onEntryTap: (word) {
          _headwordController.text = word;
          _performSearch();
        },
      );
    }

    return _buildDefinitionContentSync(
      theme,
      defMap,
      highlightHeadword: highlightHeadword,
      highlightDefinition: highlightDefinition,
      searchSqliteMs: searchSqliteMs,
      searchOtherMs: searchOtherMs,
      searchTotalMs: searchTotalMs,
      searchResultCount: searchResultCount,
    );
  }

  Widget _buildDefinitionContentSync(
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
    // Deep copy to prevent cached processedHtml from persisting across searches
    final List<Map<String, dynamic>> rawDefinitions =
        (defMap['definitions'] as List)
            .map((e) => Map<String, dynamic>.from(e))
            .toList();

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
                    final dictName =
                        defMap['dict_name'] ?? 'Unknown Dictionary';

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
                    String processed = HtmlLookupWrapper.processRecord(
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
                      hDebugPrint(
                        'HomeScreen: Final definitionHtml: [$definitionHtml]',
                      );
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
                                    hDebugPrint(
                                      'Tap ignored: renderBox is null',
                                    );
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

                                  for (final HitTestEntry entry
                                      in result.path) {
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
                                          .globalToLocal(
                                            details.globalPosition,
                                          );
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

                                      final String? word =
                                          util.WordBoundary.wordAt(
                                            text,
                                            pos.offset,
                                          );
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
                                      color: settings.getEffectiveTextColor(
                                        context,
                                      ),
                                      fontFamily: settings.fontFamily,
                                    ),
                                    "a": Style(
                                      color: theme.colorScheme.primary,
                                      textDecoration: TextDecoration.underline,
                                    ),
                                    "mark": Style(
                                      backgroundColor: Color(
                                        int.parse(
                                          highlightCol.replaceFirst(
                                            '#',
                                            '0xFF',
                                          ),
                                        ),
                                      ),
                                      color: Colors.black,
                                    ),
                                    ".dict-word": Style(
                                      color: settings.textColor,
                                      textDecoration: TextDecoration.none,
                                    ),
                                    ".headword": Style(
                                      color: settings.getEffectiveHeadwordColor(
                                        context,
                                      ),
                                      fontWeight: FontWeight.bold,
                                    ),
                                    ".headword a": Style(
                                      color: settings.getEffectiveHeadwordColor(
                                        context,
                                      ),
                                      textDecoration: TextDecoration.none,
                                    ),
                                    ".headword .dict-word": Style(
                                      color: settings.headwordColor,
                                      textDecoration: TextDecoration.none,
                                    ),
                                    "hr": Style(
                                      margin: Margins.zero,
                                      padding: HtmlPaddings.zero,
                                      border: Border(
                                        bottom: BorderSide(
                                          color: theme.colorScheme.outline,
                                          width: 1,
                                        ),
                                      ),
                                    ),
                                  },
                                  extensions: [
                                    MddVideoHtmlExtension(
                                      dictId: defMap['dict_id'] as int? ?? 0,
                                    ),
                                    const AnchorIdExtension(),
                                  ],
                                  onLinkTap: (url, attributes, element) async {
                                    hDebugPrint(
                                      'onLinkTap #1 triggered with url: "$url"',
                                    );
                                    if (url != null) {
                                      hDebugPrint(
                                        'onLinkTap #1: url is not null, checking prefixes...',
                                      );
                                      if (url.startsWith('http://') ||
                                          url.startsWith('https://')) {
                                        hDebugPrint(
                                          'onLinkTap #1: HTTP URL: $url',
                                        );
                                        final uri = Uri.parse(url);
                                        if (await canLaunchUrl(uri)) {
                                          await launchUrl(
                                            uri,
                                            mode:
                                                LaunchMode.externalApplication,
                                          );
                                        }
                                      } else if (url.startsWith('mdd-audio:')) {
                                        hDebugPrint(
                                          'onLinkTap #1: MDD audio detected: $url',
                                        );
                                        if (showMultimediaProcessing) {
                                          hDebugPrint(
                                            'MDD audio link tapped: $url',
                                          );
                                        }
                                        final defId = defMap['dict_id'] as int?;
                                        hDebugPrint(
                                          'onLinkTap #1: defId = $defId',
                                        );
                                        if (defId != null) {
                                          hDebugPrint(
                                            'onLinkTap #1: Calling _playPronunciation',
                                          );
                                          _playPronunciation(url, defId);
                                        }
                                      } else if (url.startsWith('mdd-video:')) {
                                        if (showMultimediaProcessing) {
                                          hDebugPrint(
                                            'MDD video link tapped: $url',
                                          );
                                        }
                                        final defId = defMap['dict_id'] as int?;
                                        if (defId != null) {
                                          _showMediaPlayer(url, defId);
                                        }
                                      } else if (url.startsWith('entry://')) {
                                        hDebugPrint(
                                          'onLinkTap #1: ENTRY link detected: $url',
                                        );
                                        String wordToLookup = url.substring(
                                          8,
                                        ); // Remove 'entry://' prefix
                                        try {
                                          wordToLookup = Uri.decodeComponent(
                                            wordToLookup,
                                          );
                                        } catch (_) {
                                          // Keep original if decode fails
                                        }
                                        hDebugPrint(
                                          'onLinkTap #1: Looking up entry: "$wordToLookup"',
                                        );
                                        _showWordPopup(wordToLookup);
                                      } else {
                                        String wordToLookup = url;
                                        if (wordToLookup.startsWith(
                                          'look_up:',
                                        )) {
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
                                          final word =
                                              wordToLookup.contains('%')
                                              ? Uri.decodeComponent(
                                                  wordToLookup,
                                                )
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
    hDebugPrint('HomeScreen._showWordPopup: START for word="$word"');
    final settings = context.read<SettingsProvider>();
    await _dbHelper.addSearchHistory(word, searchType: 'Pop-up Search');
    if (!mounted) {
      hDebugPrint('HomeScreen._showWordPopup: NOT mounted, returning');
      return;
    }
    if (!settings.isOpenPopupOnTap) {
      hDebugPrint(
        'HomeScreen._showWordPopup: isOpenPopupOnTap=false, calling _onWordSelected',
      );
      _onWordSelected(word);
      return;
    }
    // Prevent opening multiple popups
    if (_isPopupOpen) {
      hDebugPrint(
        'HomeScreen._showWordPopup: Popup already open, closing and reopening',
      );
      Navigator.of(context).pop();
    }
    _isPopupOpen = true;

    hDebugPrint(
      'HomeScreen._showWordPopup: Opening modal bottom sheet for "$word"',
    );
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

                        hDebugPrint(
                          'HomeScreen: Fetching definition for "$wordValue" from dictId=$dictId (offset=${res['offset']}, length=${res['length']})',
                        );
                        String content =
                            await _dictManager.fetchDefinition(
                              dict,
                              wordValue,
                              res['offset'] as int,
                              res['length'] as int,
                            ) ??
                            '';
                        hDebugPrint(
                          'HomeScreen: fetchDefinition for "$wordValue" returned: ${content.isEmpty ? "EMPTY" : "${content.length} chars"}',
                        );

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

                    // Sort by display order - first warm cache then use sync lookup
                    await _dbHelper.getDictionaries();

                    final List<
                      ({
                        int displayOrder,
                        int dictId,
                        MapEntry<int, Map<String, List<Map<String, dynamic>>>>
                        entry,
                      })
                    >
                    sortData = groupedResults.entries.map((entry) {
                      final dict = _dbHelper.getDictionaryByIdSync(entry.key);
                      return (
                        displayOrder: (dict?['display_order'] as int?) ?? 999,
                        dictId: entry.key,
                        entry: entry,
                      );
                    }).toList();

                    sortData.sort((a, b) {
                      final orderCompare = a.displayOrder.compareTo(
                        b.displayOrder,
                      );
                      if (orderCompare != 0) return orderCompare;
                      return a.dictId.compareTo(b.dictId);
                    });
                    final sortedEntries = sortData.map((d) => d.entry).toList();

                    final consolidated =
                        await HomeScreen.consolidateDefinitions(sortedEntries);

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
    ).whenComplete(() {
      hDebugPrint('HomeScreen._showWordPopup: Popup closed, resetting flag');
      _isPopupOpen = false;
    });
  }
}

class _MdictDefinitionContent extends StatefulWidget {
  final Map<String, dynamic> defMap;
  final int dictId;
  final ThemeData theme;
  final String? highlightHeadword;
  final String? highlightDefinition;
  final int? searchSqliteMs;
  final int? searchOtherMs;
  final int? searchTotalMs;
  final int? searchResultCount;
  final void Function(String word)? onEntryTap;

  const _MdictDefinitionContent({
    super.key,
    required this.defMap,
    required this.dictId,
    required this.theme,
    this.highlightHeadword,
    this.highlightDefinition,
    this.searchSqliteMs,
    this.searchOtherMs,
    this.searchTotalMs,
    this.searchResultCount,
    this.onEntryTap,
  });

  @override
  State<_MdictDefinitionContent> createState() =>
      _MdictDefinitionContentState();
}

class _MdictDefinitionContentState extends State<_MdictDefinitionContent> {
  bool _isProcessing = false;
  late List<Map<String, dynamic>> _rawDefinitions;

  @override
  void initState() {
    super.initState();
    // Deep copy to prevent cached processedHtml from persisting across searches
    _rawDefinitions = (widget.defMap['definitions'] as List)
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    _processMultimedia();
  }

  Future<void> _processMultimedia() async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    final mdictReader = DictionaryManager.instance.getMdictReader(
      widget.dictId,
    );
    if (mdictReader == null || !mdictReader.hasMdd) {
      setState(() => _isProcessing = false);
      return;
    }

    final mp = MultimediaProcessor(mdictReader, mdictReader.cssContent);
    final format = widget.defMap['format'] as String? ?? 'mdict';
    final typeSequence = widget.defMap['type_sequence'] as String?;

    for (final defData in _rawDefinitions) {
      if (defData['processedHtml'] != null) continue;

      final rawContent = defData['rawContent'] as String;

      String processed = HtmlLookupWrapper.processRecord(
        html: HomeScreen.normalizeWhitespace(
          rawContent,
          format: format,
          typeSequence: typeSequence,
        ),
        format: format,
        typeSequence: typeSequence,
        underlineQuery: widget.highlightDefinition,
      );

      processed = await mp.processHtmlWithInlineVideo(processed);

      final headwordHtml = defData['headwordHtml'] as String;
      defData['processedHtml'] = '$headwordHtml\n$processed';
    }

    if (mounted) {
      setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isProcessing) {
      return const Center(child: CircularProgressIndicator());
    }

    return _buildDefinitionContentSync(
      widget.theme,
      widget.defMap,
      highlightHeadword: widget.highlightHeadword,
      highlightDefinition: widget.highlightDefinition,
      searchSqliteMs: widget.searchSqliteMs,
      searchOtherMs: widget.searchOtherMs,
      searchTotalMs: widget.searchTotalMs,
      searchResultCount: widget.searchResultCount,
    );
  }

  Widget _buildDefinitionContentSync(
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
                final allText = _rawDefinitions
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
                itemCount: _rawDefinitions.length + 1,
                separatorBuilder: (context, index) {
                  if (index == _rawDefinitions.length - 1) {
                    return const Divider(
                      height: 48,
                      thickness: 1,
                      color: Colors.transparent,
                    );
                  }
                  return const Divider(height: 32, thickness: 2);
                },
                itemBuilder: (context, index) {
                  if (index == _rawDefinitions.length) {
                    final sqliteMs = searchSqliteMs ?? 0;
                    final totalMs = searchTotalMs ?? 0;
                    final otherMs = searchOtherMs ?? 0;
                    final resultCount = searchResultCount ?? 0;
                    final dictName =
                        defMap['dict_name'] ?? 'Unknown Dictionary';

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

                  final Map<String, dynamic> defData = _rawDefinitions[index];
                  String? definitionHtml = defData['processedHtml'];

                  if (definitionHtml == null) {
                    final String rawContent = defData['rawContent'] as String;
                    final String format =
                        defMap['format'] as String? ?? 'stardict';
                    final String? typeSequence =
                        defMap['type_sequence'] as String?;

                    String processed = HtmlLookupWrapper.processRecord(
                      html: HomeScreen.normalizeWhitespace(
                        rawContent,
                        format: format,
                        typeSequence: typeSequence,
                      ),
                      format: format,
                      typeSequence: typeSequence,
                      underlineQuery: highlightDefinition,
                    );

                    definitionHtml = '${defData['headwordHtml']}\n$processed';
                    defData['processedHtml'] = definitionHtml;
                  }

                  return Stack(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          GestureDetector(
                            behavior: HitTestBehavior.translucent,
                            child: Html(
                              data: definitionHtml,
                              style: {
                                "body": Style(
                                  fontSize: FontSize(settings.fontSize),
                                  lineHeight: LineHeight.em(1.5),
                                  margin: Margins.zero,
                                  padding: HtmlPaddings.zero,
                                  color: settings.getEffectiveTextColor(
                                    context,
                                  ),
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
                                  color: settings.getEffectiveHeadwordColor(
                                    context,
                                  ),
                                  fontWeight: FontWeight.bold,
                                ),
                                "hr": Style(
                                  margin: Margins.zero,
                                  padding: HtmlPaddings.zero,
                                  border: Border(
                                    bottom: BorderSide(
                                      color: theme.colorScheme.outline,
                                      width: 1,
                                    ),
                                  ),
                                ),
                              },
                              extensions: [
                                MddVideoHtmlExtension(
                                  dictId: defMap['dict_id'] as int? ?? 0,
                                ),
                                const AnchorIdExtension(),
                              ],
                              onLinkTap: (url, attributes, element) async {
                                hDebugPrint(
                                  'onLinkTap #2 triggered with url: "$url"',
                                );
                                if (url != null &&
                                    url.startsWith('mdd-audio:')) {
                                  hDebugPrint(
                                    'onLinkTap #2: MDD audio detected: $url',
                                  );
                                  if (showMultimediaProcessing) {
                                    hDebugPrint('MDD audio link tapped: $url');
                                  }
                                  final defId = defMap['dict_id'] as int?;
                                  hDebugPrint('onLinkTap #2: defId = $defId');
                                  if (defId != null) {
                                    final resourceKey = url.substring(
                                      'mdd-audio:'.length,
                                    );
                                    hDebugPrint(
                                      'onLinkTap #2: resourceKey = $resourceKey',
                                    );
                                    final mdictReader = DictionaryManager
                                        .instance
                                        .getMdictReader(defId);
                                    hDebugPrint(
                                      'onLinkTap #2: mdictReader = $mdictReader',
                                    );
                                    if (mdictReader == null) {
                                      hDebugPrint(
                                        'onLinkTap #2: mdictReader is NULL!',
                                      );
                                      return;
                                    }
                                    hDebugPrint(
                                      'onLinkTap #2: Fetching resource bytes for $resourceKey...',
                                    );
                                    final data = await mdictReader
                                        .getMddResourceBytes(resourceKey);
                                    hDebugPrint(
                                      'onLinkTap #2: data = ${data != null ? "${data.length} bytes" : "NULL"}',
                                    );
                                    if (data == null) {
                                      hDebugPrint(
                                        'onLinkTap #2: Resource not found in MDD!',
                                      );
                                      return;
                                    }
                                    hDebugPrint(
                                      'onLinkTap #2: Creating temp file for audio...',
                                    );
                                    try {
                                      final tempDir =
                                          await getTemporaryDirectory();
                                      final ext = resourceKey
                                          .split('.')
                                          .last
                                          .toLowerCase();

                                      // Formats that just_audio supports natively
                                      final supportedExts = [
                                        'mp3',
                                        'wav',
                                        'm4a',
                                        'aac',
                                        'ogg',
                                        'flac',
                                        'wma',
                                        'aiff',
                                        '3gp',
                                      ];
                                      final needsConversion = !supportedExts
                                          .contains(ext);

                                      final inputFile = File(
                                        '${tempDir.path}/pron_${DateTime.now().millisecondsSinceEpoch}_input.$ext',
                                      );
                                      await inputFile.writeAsBytes(data);

                                      String audioPath;
                                      if (needsConversion) {
                                        hDebugPrint(
                                          'onLinkTap #2: .$ext format not supported, skipping audio',
                                        );
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                'Audio format .$ext is not supported on this device',
                                              ),
                                              duration: const Duration(
                                                seconds: 2,
                                              ),
                                            ),
                                          );
                                        }
                                        await inputFile.delete().catchError(
                                          (_) => File(''),
                                        );
                                        return;
                                      } else {
                                        audioPath = inputFile.path;
                                      }

                                      final player = AudioPlayer();
                                      hDebugPrint(
                                        'onLinkTap #2: Setting audio source: $audioPath',
                                      );
                                      await player.setFilePath(audioPath);
                                      hDebugPrint(
                                        'onLinkTap #2: Playing audio...',
                                      );
                                      await player.play();
                                      hDebugPrint(
                                        'onLinkTap #2: Audio play() called successfully',
                                      );
                                      File(
                                        audioPath,
                                      ).delete().catchError((_) => File(''));
                                    } catch (e, stack) {
                                      hDebugPrint(
                                        'onLinkTap #2: EXCEPTION playing audio: $e',
                                      );
                                      hDebugPrint(
                                        'onLinkTap #2: Stack: $stack',
                                      );
                                      if (showMultimediaProcessing) {
                                        hDebugPrint(
                                          'Error playing pronunciation: $e',
                                        );
                                      }
                                    }
                                  }
                                } else if (url != null &&
                                    url.startsWith('mdd-video:')) {
                                  if (showMultimediaProcessing) {
                                    hDebugPrint('MDD video link tapped: $url');
                                  }
                                  final defId = defMap['dict_id'] as int?;
                                  if (defId != null) {
                                    final resourceKey = url.substring(
                                      'mdd-video:'.length,
                                    );
                                    final mdictReader = DictionaryManager
                                        .instance
                                        .getMdictReader(defId);
                                    if (mdictReader == null) return;
                                    final data = await mdictReader
                                        .getMddResourceBytes(resourceKey);
                                    if (data == null) return;
                                    if (!context.mounted) return;
                                    showDialog(
                                      context: context,
                                      builder: (ctx) => _MediaPlayerDialog(
                                        data: data,
                                        mediaType: 'video',
                                        filename: resourceKey,
                                      ),
                                    );
                                  }
                                } else if (url != null &&
                                    (url.startsWith('http://') ||
                                        url.startsWith('https://'))) {
                                  launchUrl(
                                    Uri.parse(url),
                                    mode: LaunchMode.externalApplication,
                                  );
                                } else if (url != null &&
                                    url.startsWith('entry://')) {
                                  hDebugPrint(
                                    'onLinkTap #2: ENTRY link detected: $url',
                                  );
                                  String wordToLookup = url.substring(
                                    8,
                                  ); // Remove 'entry://' prefix
                                  try {
                                    wordToLookup = Uri.decodeComponent(
                                      wordToLookup,
                                    );
                                  } catch (_) {
                                    // Keep original if decode fails
                                  }
                                  hDebugPrint(
                                    'onLinkTap #2: Looking up entry: "$wordToLookup"',
                                  );
                                  // Perform actual search via callback
                                  widget.onEntryTap?.call(wordToLookup);
                                } else if (url != null) {
                                  String wordToLookup = url;
                                  if (wordToLookup.startsWith('look_up:')) {
                                    wordToLookup = wordToLookup.substring(8);
                                  } else if (wordToLookup.startsWith(
                                    'bword://',
                                  )) {
                                    wordToLookup = wordToLookup.substring(8);
                                  }
                                  final decoded = wordToLookup.contains('%')
                                      ? Uri.decodeComponent(wordToLookup)
                                      : wordToLookup;
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Search for: $decoded'),
                                      ),
                                    );
                                  }
                                }
                              },
                            ),
                          ),
                        ],
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
}

class _MediaPlayerDialog extends StatefulWidget {
  final Uint8List data;
  final String mediaType;
  final String filename;

  const _MediaPlayerDialog({
    required this.data,
    required this.mediaType,
    required this.filename,
  });

  @override
  State<_MediaPlayerDialog> createState() => _MediaPlayerDialogState();
}

class _MediaPlayerDialogState extends State<_MediaPlayerDialog> {
  AudioPlayer? _audioPlayer;
  VideoPlayerController? _videoController;
  bool _isLoading = true;
  String? _error;
  String? _tempFilePath;

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    try {
      final tempDir = await getTemporaryDirectory();
      final ext = widget.filename.split('.').last;
      final tempFile = File(
        '${tempDir.path}/mdd_media_${DateTime.now().millisecondsSinceEpoch}.$ext',
      );
      await tempFile.writeAsBytes(widget.data);
      _tempFilePath = tempFile.path;
      if (showMultimediaProcessing) {
        hDebugPrint(
          'MediaPlayer: temp file: $_tempFilePath, size: ${widget.data.length}, type: ${widget.mediaType}',
        );
      }

      if (widget.mediaType == 'audio') {
        _audioPlayer = AudioPlayer();
        if (showMultimediaProcessing) {
          hDebugPrint('MediaPlayer: setting file path...');
        }
        await _audioPlayer!.setFilePath(_tempFilePath!);
        if (showMultimediaProcessing) {
          hDebugPrint(
            'MediaPlayer: audio player ready, duration: ${_audioPlayer!.duration}',
          );
        }
      } else {
        _videoController = VideoPlayerController.file(File(_tempFilePath!));
        await _videoController!.initialize();
      }

      if (mounted) {
        setState(() => _isLoading = false);
      }
      // Auto-play after loading
      if (widget.mediaType == 'audio' && _audioPlayer != null) {
        if (showMultimediaProcessing) {
          hDebugPrint('MediaPlayer: auto-playing...');
        }
        await _audioPlayer!.play();
        if (showMultimediaProcessing) {
          hDebugPrint('MediaPlayer: play() called');
        }
      }
    } catch (e) {
      if (showMultimediaProcessing) {
        hDebugPrint('MediaPlayer error: $e');
      }
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = e.toString();
        });
      }
    }
  }

  @override
  void dispose() {
    _audioPlayer?.dispose();
    _videoController?.dispose();
    if (_tempFilePath != null) {
      File(_tempFilePath!).delete().catchError((_) => File(''));
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.filename),
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.85,
        height: widget.mediaType == 'video' ? 350 : 150,
        child: _buildContent(context),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }

  Widget _buildContent(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              'Error loading media',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    if (widget.mediaType == 'audio') {
      return _buildAudioPlayer(context);
    } else {
      return _buildVideoPlayer(context);
    }
  }

  Widget _buildAudioPlayer(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.audiotrack,
          size: 64,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(height: 16),
        Text(
          '${(widget.data.length / 1024).toStringAsFixed(1)} KB',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 24),
        StreamBuilder<Duration>(
          stream: _audioPlayer!.positionStream,
          builder: (context, snapshot) {
            final position = snapshot.data ?? Duration.zero;
            final duration = _audioPlayer!.duration ?? Duration.zero;
            if (showMultimediaProcessing) {
              hDebugPrint(
                'MediaPlayer: position: $position, duration: $duration',
              );
            }
            return Column(
              children: [
                Slider(
                  value: position.inMilliseconds.toDouble(),
                  max: duration.inMilliseconds.toDouble(),
                  onChanged: (value) {
                    _audioPlayer!.seek(Duration(milliseconds: value.toInt()));
                  },
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(_formatDuration(position)),
                    Text(_formatDuration(duration)),
                  ],
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.replay_10),
              onPressed: () {
                final pos = _audioPlayer!.position;
                _audioPlayer!.seek(pos - const Duration(seconds: 10));
              },
            ),
            StreamBuilder<PlayerState>(
              stream: _audioPlayer!.playerStateStream,
              builder: (context, snapshot) {
                final playerState = snapshot.data;
                final playing = playerState?.playing ?? false;
                if (showMultimediaProcessing) {
                  hDebugPrint(
                    'MediaPlayer: play state changed - playing: $playing',
                  );
                }
                return IconButton(
                  iconSize: 48,
                  icon: Icon(
                    playing
                        ? Icons.pause_circle_filled
                        : Icons.play_circle_filled,
                  ),
                  onPressed: () {
                    if (showMultimediaProcessing) {
                      hDebugPrint(
                        'MediaPlayer: play button pressed, currently playing: $playing',
                      );
                    }
                    if (playing) {
                      _audioPlayer!.pause();
                    } else {
                      _audioPlayer!.play();
                    }
                  },
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.forward_10),
              onPressed: () {
                final pos = _audioPlayer!.position;
                _audioPlayer!.seek(pos + const Duration(seconds: 10));
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildVideoPlayer(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: AspectRatio(
              aspectRatio: _videoController!.value.aspectRatio,
              child: VideoPlayer(_videoController!),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.replay_10),
              onPressed: () {
                final pos = _videoController!.value.position;
                _videoController!.seekTo(pos - const Duration(seconds: 10));
              },
            ),
            ValueListenableBuilder<VideoPlayerValue>(
              valueListenable: _videoController!,
              builder: (context, value, child) {
                final playing = value.isPlaying;
                return IconButton(
                  iconSize: 48,
                  icon: Icon(
                    playing
                        ? Icons.pause_circle_filled
                        : Icons.play_circle_filled,
                  ),
                  onPressed: () {
                    if (playing) {
                      _videoController!.pause();
                    } else {
                      _videoController!.play();
                    }
                  },
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.forward_10),
              onPressed: () {
                final pos = _videoController!.value.position;
                _videoController!.seekTo(pos + const Duration(seconds: 10));
              },
            ),
          ],
        ),
        ValueListenableBuilder<VideoPlayerValue>(
          valueListenable: _videoController!,
          builder: (context, value, child) {
            final position = value.position;
            final duration = value.duration;
            if (duration == Duration.zero) return const SizedBox.shrink();
            return Column(
              children: [
                Slider(
                  value: position.inMilliseconds.toDouble(),
                  max: duration.inMilliseconds.toDouble(),
                  onChanged: (val) {
                    _videoController!.seekTo(
                      Duration(milliseconds: val.toInt()),
                    );
                  },
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(_formatDuration(position)),
                    Text(_formatDuration(duration)),
                  ],
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}

class MddVideoHtmlExtension extends HtmlExtension {
  final int dictId;

  MddVideoHtmlExtension({required this.dictId});

  @override
  Set<String> get supportedTags => {'video'};

  @override
  InlineSpan build(ExtensionContext context) {
    final attributes = context.attributes;
    final src = attributes['src'];

    if (src != null && src.startsWith('mdd-video:')) {
      final resourceKey = src.substring('mdd-video:'.length);
      return WidgetSpan(
        child: _MddVideoWidget(
          resourceKey: resourceKey,
          dictId: dictId,
          width: double.tryParse(attributes['width'] ?? ''),
          height: double.tryParse(attributes['height'] ?? ''),
          controls: attributes['controls'] != null,
          autoplay: attributes['autoplay'] != null,
          loop: attributes['loop'] != null,
        ),
      );
    }

    return WidgetSpan(child: Container());
  }
}

class _MddVideoWidget extends StatefulWidget {
  final String resourceKey;
  final int dictId;
  final double? width;
  final double? height;
  final bool controls;
  final bool autoplay;
  final bool loop;

  const _MddVideoWidget({
    required this.resourceKey,
    required this.dictId,
    this.width,
    this.height,
    this.controls = true,
    this.autoplay = false,
    this.loop = false,
  });

  @override
  State<_MddVideoWidget> createState() => _MddVideoWidgetState();
}

class _MddVideoWidgetState extends State<_MddVideoWidget> {
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;
  bool _isLoading = true;
  String? _error;
  String? _tempFilePath;

  @override
  void initState() {
    super.initState();
    _loadVideo();
  }

  Future<void> _loadVideo() async {
    try {
      final mdictReader = DictionaryManager.instance.getMdictReader(
        widget.dictId,
      );
      if (mdictReader == null) {
        setState(() {
          _error = 'Dictionary reader not found';
          _isLoading = false;
        });
        return;
      }

      final bytes = await mdictReader.getMddResourceBytes(widget.resourceKey);
      if (bytes == null) {
        setState(() {
          _error = 'Video not found: ${widget.resourceKey}';
          _isLoading = false;
        });
        return;
      }

      if (showMultimediaProcessing) {
        hDebugPrint('MddVideoWidget: Got bytes: ${bytes.length}');
      }

      final tempDir = await getTemporaryDirectory();
      final ext = widget.resourceKey.split('.').last;
      final tempFile = File(
        '${tempDir.path}/mdd_video_${DateTime.now().millisecondsSinceEpoch}.$ext',
      );
      await tempFile.writeAsBytes(bytes);
      _tempFilePath = tempFile.path;

      _videoController = VideoPlayerController.file(File(_tempFilePath!));
      await _videoController!.initialize();

      _chewieController = ChewieController(
        videoPlayerController: _videoController!,
        autoPlay: widget.autoplay,
        looping: widget.loop,
        showControls: widget.controls,
        autoInitialize: true,
        aspectRatio: _videoController!.value.aspectRatio,
        errorBuilder: (context, errorMessage) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error, color: Colors.red),
                const SizedBox(height: 8),
                Text(errorMessage),
              ],
            ),
          );
        },
      );

      if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (showMultimediaProcessing) {
        hDebugPrint('MddVideoWidget error: $e');
      }
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _chewieController?.dispose();
    _videoController?.dispose();
    if (_tempFilePath != null) {
      File(_tempFilePath!).delete().catchError((_) => File(''));
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        height: widget.height ?? 200,
        alignment: Alignment.center,
        child: const CircularProgressIndicator(),
      );
    }

    if (_error != null) {
      return Container(
        height: widget.height ?? 200,
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 8),
            Text('Video error', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              _error!,
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    final aspectRatio = _videoController!.value.aspectRatio;
    return AspectRatio(
      aspectRatio: aspectRatio > 0 ? aspectRatio : 16 / 9,
      child: Chewie(controller: _chewieController!),
    );
  }
}

class _InlineVideoWidget extends StatefulWidget {
  final String resourceKey;
  final int dictId;

  const _InlineVideoWidget({required this.resourceKey, required this.dictId});

  @override
  State<_InlineVideoWidget> createState() => _InlineVideoWidgetState();
}

class _InlineVideoWidgetState extends State<_InlineVideoWidget> {
  VideoPlayerController? _controller;
  bool _isLoading = true;
  String? _error;
  String? _tempFilePath;

  @override
  void initState() {
    super.initState();
    _loadVideo();
  }

  Future<void> _loadVideo() async {
    try {
      final mdictReader = DictionaryManager.instance.getMdictReader(
        widget.dictId,
      );
      if (mdictReader == null) {
        setState(() {
          _error = 'Dictionary reader not found';
          _isLoading = false;
        });
        return;
      }

      final bytes = await mdictReader.getMddResourceBytes(widget.resourceKey);
      if (bytes == null) {
        setState(() {
          _error = 'Video not found: ${widget.resourceKey}';
          _isLoading = false;
        });
        return;
      }

      if (showMultimediaProcessing) {
        hDebugPrint('InlineVideo: Got bytes: ${bytes.length}');
      }

      final tempDir = await getTemporaryDirectory();
      final ext = widget.resourceKey.split('.').last;
      final tempFile = File(
        '${tempDir.path}/inline_video_${DateTime.now().millisecondsSinceEpoch}.$ext',
      );
      await tempFile.writeAsBytes(bytes);
      _tempFilePath = tempFile.path;

      _controller = VideoPlayerController.file(File(_tempFilePath!));
      await _controller!.initialize();

      if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (showMultimediaProcessing) {
        hDebugPrint('InlineVideo error: $e');
      }
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    if (_tempFilePath != null) {
      File(_tempFilePath!).delete().catchError((_) => File(''));
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        height: 200,
        alignment: Alignment.center,
        child: const CircularProgressIndicator(),
      );
    }

    if (_error != null) {
      return Container(
        height: 200,
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 8),
            Text('Video error', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              _error!,
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    final aspectRatio = _controller!.value.aspectRatio;
    return AspectRatio(
      aspectRatio: aspectRatio > 0 ? aspectRatio : 16 / 9,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          VideoPlayer(_controller!),
          _VideoControls(controller: _controller!),
        ],
      ),
    );
  }
}

class _VideoControls extends StatelessWidget {
  final VideoPlayerController controller;

  const _VideoControls({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black54,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          ValueListenableBuilder<VideoPlayerValue>(
            valueListenable: controller,
            builder: (context, value, child) {
              return IconButton(
                icon: Icon(
                  value.isPlaying ? Icons.pause : Icons.play_arrow,
                  color: Colors.white,
                ),
                onPressed: () {
                  if (value.isPlaying) {
                    controller.pause();
                  } else {
                    controller.play();
                  }
                },
              );
            },
          ),
          Expanded(
            child: ValueListenableBuilder<VideoPlayerValue>(
              valueListenable: controller,
              builder: (context, value, child) {
                final position = value.position;
                final duration = value.duration;
                return Row(
                  children: [
                    Text(
                      _formatDuration(position),
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                    Expanded(
                      child: Slider(
                        value: position.inMilliseconds.toDouble(),
                        max: duration.inMilliseconds.toDouble().clamp(
                          1,
                          double.infinity,
                        ),
                        onChanged: (value) {
                          controller.seekTo(
                            Duration(milliseconds: value.toInt()),
                          );
                        },
                      ),
                    ),
                    Text(
                      _formatDuration(duration),
                      style: const TextStyle(color: Colors.white, fontSize: 12),
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

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}
