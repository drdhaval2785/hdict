import 'package:flutter/material.dart';
import 'package:hdict/core/database/database_helper.dart';
import 'package:hdict/core/parser/dict_reader.dart';
import 'package:hdict/core/utils/html_lookup_wrapper.dart';
import 'package:hdict/features/flash_cards/score_history_screen.dart';
import 'package:hdict/features/settings/settings_provider.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:provider/provider.dart';
import 'dart:math';

class FlashCardsScreen extends StatefulWidget {
  const FlashCardsScreen({super.key});

  @override
  State<FlashCardsScreen> createState() => _FlashCardsScreenState();
}

class _FlashCardsScreenState extends State<FlashCardsScreen> {
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

  @override
  void initState() {
    super.initState();
    _loadDictionaries();
  }

  Future<void> _loadDictionaries() async {
    final dicts = await _dbHelper.getDictionaries();
    setState(() {
      _allDictionaries = dicts.where((d) => d['is_enabled'] == 1).toList();
      for (var d in _allDictionaries) {
        _selectedDictIds.add(d['id']);
      }
      _isLoading = false;
    });
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

    final List<Map<String, dynamic>> allAvailableWordMetas = [];
    for (var dictId in _selectedDictIds) {
      final metas = await _dbHelper.getSampleWords(dictId, limit: 100);
      for (var meta in metas) {
        allAvailableWordMetas.add({
          'word': meta['word'],
          'dict_id': dictId,
          'offset': meta['offset'],
          'length': meta['length'],
        });
      }
    }

    if (allAvailableWordMetas.length < 10) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Not enough words in selected dictionaries.'),
          ),
        );
      }
      return;
    }

    final random = Random();
    final List<Map<String, dynamic>> selectedWordMetas = [];
    final Set<int> usedIndices = {};

    while (selectedWordMetas.length < 10) {
      int index = random.nextInt(allAvailableWordMetas.length);
      if (!usedIndices.contains(index)) {
        usedIndices.add(index);
        selectedWordMetas.add(allAvailableWordMetas[index]);
      }
    }

    // Fetch full meanings in parallel for faster loading
    final List<Map<String, dynamic>> selectedWords = await Future.wait(
      selectedWordMetas.map((meta) async {
        final dict = await _dbHelper.getDictionaryById(meta['dict_id']);
        if (dict != null) {
          String dictPath = await _dbHelper.resolvePath(dict['path']);
          if (dictPath.endsWith('.ifo')) {
            dictPath = dictPath.replaceAll('.ifo', '.dict');
          }
          final reader = DictReader(dictPath);
          final meaning = await reader.readEntry(
            meta['offset'],
            meta['length'],
          );
          return {
            'word': meta['word'],
            'meaning': meaning,
            'dict_name': dict['name'],
          };
        }
        return {};
      }),
    );

    // Filter out any potential empty results
    final filteredWords = selectedWords
        .where((w) => w.isNotEmpty)
        .toList()
        .cast<Map<String, dynamic>>();

    setState(() {
      _quizWords = filteredWords;
      _isQuizStarted = true;
      _currentIndex = 0;
      _score = 0;
      _showMeaning = false;
      _isLoading = false;
      _results = [];
    });
  }

  void _answer(bool correct) {
    _results.add(correct);
    if (correct) _score++;

    if (_currentIndex < 9) {
      setState(() {
        _currentIndex++;
      });
    } else {
      _finishQuiz();
    }
  }

  Future<void> _finishQuiz() async {
    // We will save to DB after review mode instead of here,
    // to allow user to change their guess based on the results.
    if (mounted) {
      _showResultsDialog();
    }
  }

  void _showResultsDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Quiz Finished!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Your score: $_score / 10',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text('Now verify your guesses by looking at the meanings.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _isQuizStarted = true;
                _showMeaning = true;
                _currentIndex = 0; // Reset index to let user review
              });
            },
            child: const Text('Review Meanings'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _isQuizStarted = false;
              });
            },
            child: const Text('Done'),
          ),
        ],
      ),
    );
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
    return Scaffold(
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
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 24.0,
              vertical: 8.0,
            ),
            child: OutlinedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ScoreHistoryScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.history),
              label: const Text('View Score History'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: ElevatedButton(
              onPressed: _startQuiz,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
              ),
              child: const Text('Start Random Session (10 words)'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuizUI() {
    final currentWord = _quizWords[_currentIndex];
    return Scaffold(
      appBar: AppBar(title: Text('Word ${_currentIndex + 1} of 10')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              currentWord['word'],
              style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'from ${currentWord['dict_name']}',
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 64),
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
            const SizedBox(height: 32),
            const Text('Did you guess it right?'),
          ],
        ),
      ),
    );
  }

  Widget _buildReviewUI() {
    final currentWord = _quizWords[_currentIndex];
    final wasCorrect = _results[_currentIndex];
    final settings = context.watch<SettingsProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text('Review: ${currentWord['word']}'),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Text(
                'Score: $_score/10',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: wasCorrect
                ? Colors.green.withValues(alpha: 0.1)
                : Colors.red.withValues(alpha: 0.1),
            child: Row(
              children: [
                Icon(
                  wasCorrect ? Icons.check_circle : Icons.cancel,
                  color: wasCorrect ? Colors.green : Colors.red,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    wasCorrect ? 'Correct Guess' : 'Incorrect Guess',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: wasCorrect ? Colors.green : Colors.red,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _results[_currentIndex] = !wasCorrect;
                      if (!wasCorrect) {
                        _score++;
                      } else {
                        _score--;
                      }
                    });
                  },
                  icon: Icon(
                    wasCorrect ? Icons.undo : Icons.check_circle_outline,
                    size: 18,
                  ),
                  label: Text(
                    wasCorrect ? 'Mark Incorrect' : 'Mark Correct',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () {
                Navigator.of(context).popUntil((route) => route.isFirst);
              },
              behavior: HitTestBehavior.translucent,
              child: Container(
                color: settings.backgroundColor,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: SelectionArea(
                    child: Html(
                      data: settings.isTapOnMeaningEnabled
                          ? HtmlLookupWrapper.wrapWords(currentWord['meaning'])
                          : currentWord['meaning'],
                      style: {
                        "body": Style(
                          fontSize: FontSize(settings.fontSize),
                          lineHeight: LineHeight.em(1.5),
                          margin: Margins.zero,
                          padding: HtmlPaddings.zero,
                          color: settings.textColor,
                          fontFamily: settings.fontFamily,
                        ),
                        "a": Style(
                          color: settings.textColor,
                          textDecoration: TextDecoration.none,
                        ),
                      },
                      onLinkTap: (url, attributes, element) {
                        debugPrint("FlashCard Link tapped: $url");
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
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                if (_currentIndex > 0)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => setState(() => _currentIndex--),
                      child: const Text('Previous'),
                    ),
                  ),
                if (_currentIndex > 0) const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      if (_currentIndex < 9) {
                        setState(() => _currentIndex++);
                      } else {
                        // Save score to database at the very end
                        _dbHelper.addFlashCardScore(_score, 10);
                        setState(() => _isQuizStarted = false);
                      }
                    },
                    child: Text(_currentIndex < 9 ? 'Next' : 'Finish Review'),
                  ),
                ),
              ],
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
          color: settings.backgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
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
                  // Get all exact matches for this word across all dictionaries
                  final candidates = await _dbHelper.searchWords(word);
                  final List<Map<String, dynamic>> defs = [];

                  for (final res in candidates) {
                    if (res['word'].toLowerCase() != word.toLowerCase()) {
                      continue;
                    }

                    final dict = await _dbHelper.getDictionaryById(
                      res['dict_id'],
                    );
                    if (dict == null) continue;

                    String dictPath = await _dbHelper.resolvePath(dict['path']);
                    if (dictPath.endsWith('.ifo')) {
                      dictPath = dictPath.replaceAll('.ifo', '.dict');
                    }
                    final reader = DictReader(dictPath);
                    final content = await reader.readEntry(
                      res['offset'],
                      res['length'],
                    );

                    defs.add({
                      'word': res['word'],
                      'dict_name': dict['name'],
                      'definition': content,
                    });
                  }
                  return defs;
                }(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const Center(child: Text('No definition found.'));
                  }

                  final defs = snapshot.data!;
                  if (defs.length == 1) {
                    return _buildDefinitionContentInPopup(
                      Theme.of(context),
                      defs.first,
                    );
                  }

                  return DefaultTabController(
                    length: defs.length,
                    child: Column(
                      children: [
                        TabBar(
                          isScrollable: true,
                          labelColor: Theme.of(context).colorScheme.primary,
                          unselectedLabelColor: Colors.grey,
                          tabs: defs
                              .map((d) => Tab(text: d['dict_name']))
                              .toList(),
                        ),
                        Expanded(
                          child: TabBarView(
                            children: defs
                                .map(
                                  (d) => _buildDefinitionContentInPopup(
                                    Theme.of(context),
                                    d,
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
      ),
    );
  }

  Widget _buildDefinitionContentInPopup(
    ThemeData theme,
    Map<String, dynamic> def, {
    String? highlightQuery,
  }) {
    final settings = context.watch<SettingsProvider>();

    String definitionHtml = def['definition'];
    if (settings.isTapOnMeaningEnabled) {
      definitionHtml = HtmlLookupWrapper.wrapWords(definitionHtml);
    }
    if (highlightQuery != null && highlightQuery.isNotEmpty) {
      final isDark =
          ThemeData.estimateBrightnessForColor(settings.backgroundColor) ==
          Brightness.dark;
      definitionHtml = HtmlLookupWrapper.highlightText(
        definitionHtml,
        highlightQuery,
        highlightColor: isDark ? '#ff9800' : '#ffeb3b',
        textColor: 'black',
      );
    }

    return GestureDetector(
      onTap: () {
        Navigator.of(context).popUntil((route) => route.isFirst);
      },
      behavior: HitTestBehavior.translucent,
      child: Container(
        color: settings.backgroundColor,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                def['word'],
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: settings.fontColor,
                  fontFamily: settings.fontFamily,
                  fontSize: settings.fontSize + 8,
                ),
              ),
              const Divider(height: 32),
              SelectionArea(
                child: Html(
                  data: definitionHtml,
                  style: {
                    "body": Style(
                      fontSize: FontSize(settings.fontSize),
                      lineHeight: LineHeight.em(1.5),
                      margin: Margins.zero,
                      padding: HtmlPaddings.zero,
                      color: settings.textColor,
                      fontFamily: settings.fontFamily,
                    ),
                    "a": Style(
                      color: settings.textColor,
                      textDecoration: TextDecoration.none,
                    ),
                  },
                  onLinkTap: (url, attributes, element) {
                    debugPrint("FlashCard Popup Link tapped: $url");
                    if (url != null && url.startsWith('look_up:')) {
                      final encodedWord = url.substring(8);
                      Navigator.pop(this.context);
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
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton(
    IconData icon,
    Color color,
    VoidCallback onPressed,
  ) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(40),
      child: Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.3),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Icon(icon, color: Colors.white, size: 40),
      ),
    );
  }
}
