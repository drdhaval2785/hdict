import 'package:flutter/material.dart';
import 'package:hdict/core/database/database_helper.dart';
import 'package:hdict/core/manager/dictionary_manager.dart';
import 'package:hdict/core/utils/html_lookup_wrapper.dart';
import 'package:hdict/features/settings/settings_provider.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:provider/provider.dart';
import 'dart:math';
import 'package:hdict/features/home/widgets/app_drawer.dart';
import 'package:hdict/features/flash_cards/result_screen.dart';
import 'package:hdict/core/utils/word_boundary.dart' as util;
import 'package:flutter/rendering.dart';
import 'package:hdict/core/utils/logger.dart';

class FlashCardsScreen extends StatefulWidget {
  const FlashCardsScreen({super.key});

  @override
  State<FlashCardsScreen> createState() => _FlashCardsScreenState();
}

class _FlashCardsScreenState extends State<FlashCardsScreen>
    with SingleTickerProviderStateMixin {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  List<Map<String, dynamic>> _allDictionaries = [];
  final Set<int> _selectedDictIds = {};
  bool _isLoading = true;
  bool _isQuizStarted = false;
  List<Map<String, dynamic>> _quizWords = [];
  int _currentIndex = 0;
  int _score = 0;
  bool _showMeaning = false;
  List<bool> _results = [];
  bool _isPeeking = false;
  int _peekCount = 0;

  // Animation controller for slide transition between cards
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(1.0, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic));
    _loadDictionaries();
  }

  @override
  void dispose() {
    _slideController.dispose();
    super.dispose();
  }

  Future<void> _loadDictionaries() async {
    final dicts = await _dbHelper.getDictionaries();
    if (mounted) {
      setState(() {
        _allDictionaries = dicts.where((d) => d['is_enabled'] == 1).toList();
        for (var d in _allDictionaries) {
          _selectedDictIds.add(d['id']);
        }
        _isLoading = false;
      });
    }
  }

  Future<void> _startQuiz() async {
    if (_selectedDictIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one dictionary.')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final settings = context.read<SettingsProvider>();
    final targetCount = settings.flashCardWordCount;

    try {
      hDebugPrint('FlashCards: _startQuiz started. targetCount: $targetCount');
      final stopwatch = Stopwatch()..start();

      final List<Map<String, dynamic>> allAvailableWordMetas = [];
      final List<int> selectedDictIdsList = _selectedDictIds.toList();
      
      // If too many dictionaries selected, pick a reasonable subset to avoid massive query storms
      if (selectedDictIdsList.length > 50) {
        selectedDictIdsList.shuffle();
        selectedDictIdsList.removeRange(50, selectedDictIdsList.length);
      }

      // Calculate how many words to fetch from each dictionary to reach target
      int fetchPerDict = (targetCount * 2 / selectedDictIdsList.length).ceil();
      if (fetchPerDict < 5) fetchPerDict = 5;
      if (fetchPerDict > 100) fetchPerDict = 100;

      hDebugPrint('FlashCards: Fetching word metas from ${selectedDictIdsList.length} dicts, $fetchPerDict each');

      for (var dictId in selectedDictIdsList) {
        final metas = await _dbHelper.getSampleWords(dictId, limit: fetchPerDict);
        for (var meta in metas) {
          allAvailableWordMetas.add({
            'word': meta['word'],
            'dict_id': dictId,
            'offset': meta['offset'],
            'length': meta['length'],
          });
        }
      }

      hDebugPrint('FlashCards: Meta fetch complete. Found ${allAvailableWordMetas.length} words in ${stopwatch.elapsedMilliseconds}ms');
      final metaTime = stopwatch.elapsedMilliseconds;

      if (allAvailableWordMetas.length < targetCount) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Not enough words in selected dictionaries (need $targetCount).'),
            ),
          );
        }
        return;
      }

      final random = Random();
      final List<Map<String, dynamic>> selectedWordMetas = [];
      final Set<int> usedIndices = {};

      while (selectedWordMetas.length < targetCount) {
        int index = random.nextInt(allAvailableWordMetas.length);
        if (!usedIndices.contains(index)) {
          usedIndices.add(index);
          selectedWordMetas.add(allAvailableWordMetas[index]);
        }
      }

      hDebugPrint('FlashCards: Random selection complete. Fetching meanings for ${selectedWordMetas.length} words.');

      final List<Map<String, dynamic>> selectedWords = await Future.wait(
        selectedWordMetas.map((meta) async {
          try {
            final dict = await _dbHelper.getDictionaryById(meta['dict_id']);
            if (dict != null) {
              final meaning = await DictionaryManager.instance.fetchDefinition(
                dict,
                meta['word'],
                meta['offset'],
                meta['length'],
              );
              if (meaning != null) {
                return {
                  'word': meta['word'],
                  'meaning': meaning,
                  'dict_name': dict['name'],
                };
              }
            }
          } catch (e) {
            hDebugPrint('FlashCards: Error fetching meaning for ${meta['word']}: $e');
          }
          return {};
        }),
      );

      hDebugPrint('FlashCards: Meaning fetch complete in ${stopwatch.elapsedMilliseconds - metaTime}ms');
      hDebugPrint('FlashCards: _startQuiz total time: ${stopwatch.elapsedMilliseconds}ms');

      final filteredWords = selectedWords
          .where((w) => w.isNotEmpty)
          .toList()
          .cast<Map<String, dynamic>>();

      if (filteredWords.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not fetch any word meanings.')),
          );
        }
        return;
      }

      if (mounted) {
        setState(() {
          _quizWords = filteredWords;
          _isQuizStarted = true;
          _currentIndex = 0;
          _score = 0;
          _showMeaning = false;
          _isPeeking = false;
          _peekCount = 0;
          _results = List.filled(filteredWords.length, false);
        });
        _slideController.forward(from: 0);
      }
    } catch (e, s) {
      hDebugPrint('FlashCards: Global error in _startQuiz: $e\n$s');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error starting quiz: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _animateToNextCard(VoidCallback onComplete) {
    _slideController.reverse(from: 1.0).then((_) {
      if (mounted) {
        onComplete();
        _slideController.forward(from: 0);
      }
    });
  }

  void _answer(bool correct) {
    _results[_currentIndex] = correct;
    if (correct) _score++;

    if (_currentIndex < _quizWords.length - 1) {
      _animateToNextCard(() {
        setState(() {
          _currentIndex++;
          _isPeeking = false;
        });
      });
    } else {
      _finishQuiz();
    }
  }

  Future<void> _finishQuiz() async {
    if (!mounted) return;
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => ResultScreen(
          score: _score,
          total: _quizWords.length,
          peekCount: _peekCount,
        ),
      ),
    );
    if (!mounted) return;
    if (result == 'review') {
      setState(() {
        _showMeaning = true;
        _currentIndex = 0;
      });
    } else {
      setState(() {
        _isQuizStarted = false;
      });
    }
  }

  void _peekMeaning() {
    setState(() {
      _isPeeking = !_isPeeking;
      if (_isPeeking) {
        _peekCount++;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (!_isQuizStarted) {
      return _buildSetupUI();
    }

    if (_showMeaning) {
      return _buildReviewUI();
    }

    return _buildQuizUI();
  }

  Widget _buildSetupUI() {
    final settings = context.watch<SettingsProvider>();
    return Scaffold(
      drawer: const AppDrawer(),
      appBar: AppBar(title: const Text('Flash Cards')),
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'Select dictionaries for your flash cards session:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _allDictionaries.length,
              itemBuilder: (context, index) {
                final dict = _allDictionaries[index];
                return CheckboxListTile(
                  title: Text(dict['name']),
                  subtitle: Text('${dict['word_count']} words'),
                  value: _selectedDictIds.contains(dict['id']),
                  onChanged: (val) {
                    setState(() {
                      if (val == true) {
                        _selectedDictIds.add(dict['id']);
                      } else {
                        _selectedDictIds.remove(dict['id']);
                      }
                    });
                  },
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: ElevatedButton(
                onPressed: _startQuiz,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                ),
                child: Text('Start Random Session (${settings.flashCardWordCount} words)'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuizUI() {
    final currentWord = _quizWords[_currentIndex];
    final settings = context.read<SettingsProvider>();

    return Scaffold(
      drawer: const AppDrawer(),
      appBar: AppBar(title: Text('Word ${_currentIndex + 1} of ${_quizWords.length}')),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 32),
            child: Column(
              children: [
                Text(
                  currentWord['word'],
                  style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildActionButton(
                      Icons.close,
                      Colors.red,
                      () => _answer(false),
                    ),
                    const SizedBox(width: 48),
                    _buildActionButton(
                      Icons.check,
                      Colors.green,
                      () => _answer(true),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextButton.icon(
                  onPressed: _peekMeaning,
                  icon: Icon(_isPeeking ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                  label: Text(_isPeeking ? 'Hide Meaning' : 'Check Meaning'),
                  style: TextButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: SlideTransition(
              position: _slideAnimation,
              child: _isPeeking
                  ? Container(
                      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      decoration: BoxDecoration(
                        color: settings.getEffectiveBackgroundColor(context),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Theme.of(context).dividerColor),
                      ),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.secondaryContainer.withValues(alpha: 0.5),
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.menu_book_outlined, size: 16),
                                SizedBox(width: 8),
                                Text('Meaning Snippet', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                              ],
                            ),
                          ),
                          Expanded(
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.all(12),
                               child: MouseRegion(
                                 cursor: settings.isTapOnMeaningEnabled
                                     ? SystemMouseCursors.click
                                     : MouseCursor.defer,
                                 child: Builder(
                                   builder: (ctx) => GestureDetector(
                                  behavior: HitTestBehavior.translucent,
                                  onTapUp: (details) {
                                  if (!settings.isTapOnMeaningEnabled) {
                                      hDebugPrint('FlashCards (meaning header): Tap ignored: isTapOnMeaningEnabled is false');
                                      return;
                                  }
                                  final RenderBox? renderBox = ctx.findRenderObject() as RenderBox?;
                                  if (renderBox == null) {
                                      hDebugPrint('FlashCards (meaning header): Tap ignored: renderBox is null');
                                      return;
                                  }
                                  final BoxHitTestResult result = BoxHitTestResult();
                                  renderBox.hitTest(result, position: renderBox.globalToLocal(details.globalPosition));
                                  for (final HitTestEntry entry in result.path) {
                                    final target = entry.target;
                                    if (target is RenderParagraph) {
                                      final String text = target.text.toPlainText();
                                      if (text.replaceAll('\uFFFC', '').trim().isEmpty) continue;
                                      final Offset localOffset = target.globalToLocal(details.globalPosition);
                                      final TextPosition pos = target.getPositionForOffset(localOffset);
                                      final String? word = util.WordBoundary.wordAt(text, pos.offset);
                                      hDebugPrint('FlashCards (meaning header): Word tapped for search: $word');
                                      if (word != null && word.trim().isNotEmpty) {
                                        _showWordPopup(word);
                                        return;
                                      }
                                    }
                                  }
                                  hDebugPrint('FlashCards (meaning header): HitTest found no valid text paragraph.');
                                },
                                child: Html(
                                  data: currentWord['meaning'],
                                  style: {
                                    "body": Style(
                                      fontSize: FontSize(settings.fontSize - 2),
                                      lineHeight: LineHeight.em(1.4),
                                      margin: Margins.zero,
                                      padding: HtmlPaddings.zero,
                                      color: settings.getEffectiveTextColor(context),
                                      fontFamily: settings.fontFamily,
                                    ),
                                    "a": Style(
                                      color: settings.getEffectiveTextColor(context),
                                      textDecoration: TextDecoration.none,
                                    ),
                                  },
                                ),
                              ),
                             ),
                            ),
                           ),
                          ),
                        ],
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewUI() {
    final settings = context.watch<SettingsProvider>();

    return Scaffold(
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: const Text('Review Session'),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Center(
              child: Text(
                'Score: $_score/${_quizWords.length}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: _quizWords.length,
              itemBuilder: (context, index) {
                final wordData = _quizWords[index];
                final wasCorrect = _results[index];

                return ExpansionTile(
                  title: Text(
                    wordData['word'],
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: wasCorrect ? Colors.green : Colors.red,
                    ),
                  ),
                  subtitle: Text(
                    wasCorrect ? 'Correct Guess' : 'Incorrect Guess',
                    style: TextStyle(
                      fontSize: 12,
                      color: wasCorrect ? Colors.green.withValues(alpha: 0.8) : Colors.red.withValues(alpha: 0.8),
                    ),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(
                          wasCorrect ? Icons.check_circle : Icons.check_circle_outline,
                          color: wasCorrect ? Colors.green : Colors.grey,
                        ),
                        onPressed: () {
                          if (!wasCorrect) {
                            setState(() {
                              _results[index] = true;
                              _score++;
                            });
                          }
                        },
                      ),
                      IconButton(
                        icon: Icon(
                          !wasCorrect ? Icons.cancel : Icons.cancel_outlined,
                          color: !wasCorrect ? Colors.red : Colors.grey,
                        ),
                        onPressed: () {
                          if (wasCorrect) {
                            setState(() {
                              _results[index] = false;
                              _score--;
                            });
                          }
                        },
                      ),
                    ],
                  ),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      child: MouseRegion(
                        cursor: settings.isTapOnMeaningEnabled
                            ? SystemMouseCursors.click
                            : MouseCursor.defer,
                        child: Builder(
                          builder: (ctx) => GestureDetector(
                          behavior: HitTestBehavior.translucent,
                          onTapUp: (details) {
                            if (!settings.isTapOnMeaningEnabled) {
                              hDebugPrint('FlashCards (review): Tap ignored: isTapOnMeaningEnabled is false');
                              return;
                            }
                            final RenderBox? renderBox = ctx.findRenderObject() as RenderBox?;
                            if (renderBox == null) {
                              hDebugPrint('FlashCards (review): Tap ignored: renderBox is null');
                              return;
                            }
                            final BoxHitTestResult result = BoxHitTestResult();
                            renderBox.hitTest(result, position: renderBox.globalToLocal(details.globalPosition));
                            for (final HitTestEntry entry in result.path) {
                              final target = entry.target;
                              if (target is RenderParagraph) {
                                final String text = target.text.toPlainText();
                                if (text.replaceAll('\uFFFC', '').trim().isEmpty) continue;
                                final Offset localOffset = target.globalToLocal(details.globalPosition);
                                final TextPosition pos = target.getPositionForOffset(localOffset);
                                final String? word = util.WordBoundary.wordAt(text, pos.offset);
                                hDebugPrint('FlashCards (review): Word tapped for search: $word');
                                if (word != null && word.trim().isNotEmpty) {
                                  _showWordPopup(word);
                                  return;
                                }
                              }
                            }
                            hDebugPrint('FlashCards (review): HitTest found no valid text paragraph.');
                          },
                          child: Html(
                            data: wordData['meaning'],
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
                              color: settings.getEffectiveTextColor(context),
                              textDecoration: TextDecoration.none,
                            ),
                          },
                          onLinkTap: (url, attributes, element) {
                            if (url != null && url.startsWith('look_up:')) {
                              final encodedWord = url.substring(8);
                              try {
                                final word = encodedWord.contains('%')
                                    ? Uri.decodeComponent(encodedWord)
                                    : encodedWord;
                                _showWordPopup(word);
                              } catch (e) {
                                _showWordPopup(encodedWord);
                              }
                            }
                          },
                        ),
                      ),
                    ),
                    ),
                    ),
                  ],
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: ElevatedButton(
                onPressed: () {
                  _dbHelper.addFlashCardScore(
                    _score,
                    _quizWords.length,
                    _selectedDictIds.join(','),
                  );
                  setState(() => _isQuizStarted = false);
                },
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                ),
                child: const Text('Finish Review'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showWordPopup(String word) async {
    final settings = context.read<SettingsProvider>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.transparent,
      useSafeArea: true,
      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width),
      builder: (context) => Container(
        width: double.infinity,
        height: MediaQuery.of(context).size.height * 0.5,
        decoration: BoxDecoration(
          color: settings.getEffectiveBackgroundColor(context),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, size: 20, color: Colors.orange),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      word,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
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
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: () async {

                  // 1. Try exact match first

                  List<Map<String, dynamic>> candidates =
                      await _dbHelper.searchWords(
                    headwordQuery: word,
                    headwordMode: SearchMode.exact,
                  );

                  // 2. Fallback to prefix if exact fails
                  if (candidates.isEmpty) {
                    candidates = await _dbHelper.searchWords(
                      headwordQuery: word,
                      headwordMode: SearchMode.prefix,
                    );
                  }
                  // 3. Parallel fetch & pre-process

                  // 3. Parallel fetch & pre-process
                  final results = await Future.wait(candidates.map((res) async {
                    final dict =
                        await _dbHelper.getDictionaryById(res['dict_id']);
                    if (dict == null || dict['is_enabled'] != 1) return null;

                    String content =
                        await DictionaryManager.instance.fetchDefinition(
                              dict,
                              res['word'],
                              res['offset'],
                              res['length'],
                            ) ??
                            '';

                    content = HtmlLookupWrapper.processRecord(
                      html: content,
                      format: dict['format'] ?? 'stardict',
                      underlineQuery: word, // Performance: highlight is same as underline in this wrapper now
                    );

                    return {
                      'word': res['word'],
                      'dict_name': dict['name'],
                      'definition': content,
                    };
                  }));
                  return results.whereType<Map<String, dynamic>>().toList();
                }(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                  if (!snapshot.hasData || snapshot.data!.isEmpty) return const Center(child: Text('No definition found.'));
                  final defs = snapshot.data!;
                  if (defs.length == 1) return _buildDefinitionContentInPopup(Theme.of(context), defs.first);
                  return DefaultTabController(
                    length: defs.length,
                    child: Column(
                      children: [
                        TabBar(
                          isScrollable: true,
                          labelColor: Theme.of(context).colorScheme.primary,
                          unselectedLabelColor: Colors.grey,
                          tabs: defs.map((d) => Tab(text: d['dict_name'])).toList(),
                        ),
                        Expanded(
                          child: TabBarView(
                            children: defs.map((d) => _buildDefinitionContentInPopup(Theme.of(context), d)).toList(),
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
      ),
    );
  }

  Widget _buildDefinitionContentInPopup(ThemeData theme, Map<String, dynamic> def) {
    final settings = context.watch<SettingsProvider>();
    // HTML is now pre-processed and cached in the Future result
    final String definitionHtml = def['definition'];

    return Container(
            color: settings.getEffectiveBackgroundColor(context),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(def['word'], style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold, color: settings.getEffectiveHeadwordColor(context), fontFamily: settings.fontFamily, fontSize: settings.fontSize + 8)),
            const Divider(height: 32),
            MouseRegion(
              cursor: settings.isTapOnMeaningEnabled
                  ? SystemMouseCursors.click
                  : MouseCursor.defer,
              child: Builder(
                builder: (ctx) => GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTapUp: (details) {
                  if (!settings.isTapOnMeaningEnabled) {
                    hDebugPrint('FlashCards (popup): Tap ignored: isTapOnMeaningEnabled is false');
                    return;
                  }
                  final RenderBox? renderBox = ctx.findRenderObject() as RenderBox?;
                  if (renderBox == null) {
                    hDebugPrint('FlashCards (popup): Tap ignored: renderBox is null');
                    return;
                  }
                  final BoxHitTestResult result = BoxHitTestResult();
                  renderBox.hitTest(result, position: renderBox.globalToLocal(details.globalPosition));
                  for (final HitTestEntry entry in result.path) {
                    final target = entry.target;
                    if (target is RenderParagraph) {
                      final String text = target.text.toPlainText();
                      if (text.replaceAll('\uFFFC', '').trim().isEmpty) continue;
                      final Offset localOffset = target.globalToLocal(details.globalPosition);
                      final TextPosition pos = target.getPositionForOffset(localOffset);
                      final String? tappedWord = util.WordBoundary.wordAt(text, pos.offset);
                      hDebugPrint('FlashCards (popup): Word tapped for search: $tappedWord');
                      if (tappedWord != null && tappedWord.trim().isNotEmpty) {
                        Navigator.pop(context);
                        _showWordPopup(tappedWord);
                        return;
                      }
                    }
                  }
                  hDebugPrint('FlashCards (popup): HitTest found no valid text paragraph.');
                },
                child: Html(
                  data: definitionHtml,
                  style: {
                    "body": Style(fontSize: FontSize(settings.fontSize), lineHeight: LineHeight.em(1.5), margin: Margins.zero, padding: HtmlPaddings.zero, color: settings.textColor, fontFamily: settings.fontFamily),
                    "a": Style(color: settings.textColor, textDecoration: TextDecoration.none),
                  },
                ),
              ),
            ),
          ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(IconData icon, Color color, VoidCallback onPressed) {
    return Material(
      color: color,
      shape: const CircleBorder(),
      elevation: 4,
      shadowColor: color.withValues(alpha: 0.4),
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        splashColor: Colors.white.withValues(alpha: 0.35),
        highlightColor: Colors.white.withValues(alpha: 0.15),
        child: SizedBox(
          width: 80,
          height: 80,
          child: Icon(icon, color: Colors.white, size: 40),
        ),
      ),
    );
  }
}
