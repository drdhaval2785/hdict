import 'package:flutter/material.dart';
import 'package:hdict/core/database/database_helper.dart';
import 'package:hdict/core/parser/dict_reader.dart';
import 'package:flutter_html/flutter_html.dart';
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

    final List<Map<String, dynamic>> allAvailableWords = [];
    for (var dictId in _selectedDictIds) {
      final words = await _dbHelper.getSampleWords(dictId, limit: 100);
      for (var word in words) {
        allAvailableWords.add({'word': word, 'dict_id': dictId});
      }
    }

    if (allAvailableWords.length < 10) {
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
    final List<Map<String, dynamic>> selectedWords = [];
    final Set<int> usedIndices = {};

    while (selectedWords.length < 10) {
      int index = random.nextInt(allAvailableWords.length);
      if (!usedIndices.contains(index)) {
        usedIndices.add(index);
        final wordData = allAvailableWords[index];

        // Fetch full meaning for later verification
        final dictResults = await _dbHelper.searchWords(
          wordData['word'],
          limit: 1,
        );
        if (dictResults.isNotEmpty) {
          final result = dictResults.first;
          final dict = await _dbHelper.getDictionaryById(wordData['dict_id']);
          if (dict != null) {
            String dictPath = dict['path'];
            if (dictPath.endsWith('.ifo')) {
              dictPath = dictPath.replaceAll('.ifo', '.dict');
            }
            final reader = DictReader(dictPath);
            final meaning = await reader.readEntry(
              result['offset'],
              result['length'],
            );
            selectedWords.add({
              'word': wordData['word'],
              'meaning': meaning,
              'dict_name': dict['name'],
            });
          }
        }
      }
    }

    setState(() {
      _quizWords = selectedWords;
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
    await _dbHelper.addFlashCardScore(_score, 10);
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
                Text(
                  wasCorrect
                      ? 'You marked this Correct'
                      : 'You marked this Incorrect',
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Html(data: currentWord['meaning']),
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
