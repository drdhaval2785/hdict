import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

import 'package:hdict/core/manager/dictionary_manager.dart';

/// A screen for managing installed dictionaries.
///
/// Users can:
/// - Import new dictionaries from local files (.zip, .tar.gz, etc.)
/// - Download dictionaries from a provided URL.
/// - Enable or disable dictionaries.
/// - Delete dictionaries.
/// - Reorder dictionaries via drag-and-drop to set search priority.
class DictionaryManagementScreen extends StatefulWidget {
  const DictionaryManagementScreen({super.key});

  @override
  State<DictionaryManagementScreen> createState() =>
      _DictionaryManagementScreenState();
}

class _DictionaryManagementScreenState
    extends State<DictionaryManagementScreen> {
  final DictionaryManager _dictionaryManager = DictionaryManager();
  List<Map<String, dynamic>> _dictionaries = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDictionaries();
  }

  Future<void> _loadDictionaries() async {
    setState(() => _isLoading = true);
    try {
      final dicts = await _dictionaryManager.getDictionaries();
      setState(() {
        _dictionaries = dicts;
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _downloadDictionary() async {
    bool indexDefinitions = false;
    final TextEditingController urlController = TextEditingController(
      text: 'http://download.huzheng.org',
    );

    final dynamic urlString = await showDialog<dynamic>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Download Dictionary'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Enter the URL of the dictionary file (.zip, .tar.gz):',
              ),
              const SizedBox(height: 16),
              TextField(
                controller: urlController,
                decoration: const InputDecoration(
                  labelText: 'URL',
                  border: OutlineInputBorder(),
                  hintText: 'http://example.com/dict.zip',
                ),
                keyboardType: TextInputType.url,
              ),
              const SizedBox(height: 8),
              StatefulBuilder(
                builder: (context, setState) {
                  return CheckboxListTile(
                    title: const Text('Index definitions for search'),
                    subtitle: const Text(
                      'Makes "Search within definitions" possible',
                    ),
                    value: indexDefinitions,
                    contentPadding: EdgeInsets.zero,
                    onChanged: (val) {
                      setState(() => indexDefinitions = val ?? false);
                    },
                  );
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, {
                'url': urlController.text,
                'index': indexDefinitions,
              }),
              child: const Text('Download'),
            ),
          ],
        );
      },
    );

    if (urlString != null &&
        urlString is Map &&
        urlString['url'] != null &&
        (urlString['url'] as String).isNotEmpty) {
      final String url = urlString['url'];
      final bool index = urlString['index'] ?? false;
      if (!mounted) return;

      // Reuse the import progress dialog logic
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          return PopScope(
            canPop: false,
            child: AlertDialog(
              title: const Text('Downloading & Importing'),
              content: ValueListenableBuilder<ImportProgress>(
                valueListenable: _progressNotifier,
                builder: (context, progress, child) {
                  return _buildProgressContent(progress);
                },
              ),
            ),
          );
        },
      );

      try {
        final stream = _dictionaryManager.downloadAndImportDictionaryStream(
          url,
          indexDefinitions: index,
        );
        await for (final progress in stream) {
          _progressNotifier.value = progress;
          if (progress.isCompleted) {
            if (progress.error != null) {
              throw Exception(progress.error);
            }
          }
        }

        if (mounted) {
          Navigator.pop(context); // Close progress dialog
          final lastProgress = _progressNotifier.value;
          final String sampleWordsText = lastProgress.sampleWords != null
              ? '\n\nSample words: ${lastProgress.sampleWords!.join(', ')}'
              : '';

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Dictionary downloaded and imported successfully$sampleWordsText',
              ),
              duration: const Duration(seconds: 5),
            ),
          );
          await _loadDictionaries();
        }
      } catch (e) {
        if (mounted) {
          Navigator.pop(context); // Close progress dialog
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Download/Import failed: $e')));
        }
      }
    }
  }

  Future<void> _reIndexAll() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Re-index All Dictionaries?'),
        content: const Text(
          'This will populate the search index with definition content, enabling "Search within definitions". It may take a while depending on your dictionary sizes.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Re-index'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return PopScope(
          canPop: false,
          child: AlertDialog(
            title: const Text('Re-indexing Dictionaries'),
            content: ValueListenableBuilder<ImportProgress>(
              valueListenable: _progressNotifier,
              builder: (context, progress, child) {
                return _buildProgressContent(progress);
              },
            ),
          ),
        );
      },
    );

    try {
      final stream = _dictionaryManager.reIndexDictionariesStream();
      await for (final progress in stream) {
        _progressNotifier.value = progress;
        if (progress.isCompleted && progress.error != null) {
          throw Exception(progress.error);
        }
      }

      if (mounted) {
        Navigator.pop(context); // Close progress dialog
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Re-indexing completed successfully!')),
        );
        await _loadDictionaries();
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close progress dialog
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Re-indexing failed: $e')));
      }
    }
  }

  Future<void> _importDictionary() async {
    bool indexDefinitions = false;
    // Pick file(s)
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: [
        'zip',
        'tar',
        'gz',
        'bz2',
        'ifo',
        'idx',
        'dict',
        'dz',
        'syn',
      ],
      allowMultiple: true,
    );

    if (result != null && result.files.isNotEmpty) {
      if (!mounted) return;

      // Optional: Ask for indexing preference if it's not a tiny dictionary
      final bool? proceed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Import Options'),
          content: StatefulBuilder(
            builder: (context, setState) {
              return CheckboxListTile(
                title: const Text('Index definitions for search'),
                subtitle: const Text(
                  'Allows searching inside meanings. Uses more disk space.',
                ),
                value: indexDefinitions,
                onChanged: (val) =>
                    setState(() => indexDefinitions = val ?? false),
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Import'),
            ),
          ],
        ),
      );

      if (proceed != true) return;

      if (!mounted) return;

      // Show progress dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          return PopScope(
            canPop: false,
            child: AlertDialog(
              title: const Text('Importing Dictionary'),
              content: ValueListenableBuilder<ImportProgress>(
                valueListenable: _progressNotifier,
                builder: (context, progress, child) {
                  return _buildProgressContent(progress);
                },
              ),
            ),
          );
        },
      );

      try {
        Stream<ImportProgress> stream;

        // If multiple files were picked, or if it looks like individual dictionary components
        if (result.files.length > 1 ||
            result.files.any(
              (f) => f.extension == 'ifo' || f.extension == 'idx',
            )) {
          final paths = result.files.map((f) => f.path!).toList();
          stream = _dictionaryManager.importMultipleFilesStream(
            paths,
            indexDefinitions: indexDefinitions,
          );
        } else {
          // Single file picked - assume it's an archive
          stream = _dictionaryManager.importDictionaryStream(
            result.files.single.path!,
            indexDefinitions: indexDefinitions,
          );
        }

        await for (final progress in stream) {
          _progressNotifier.value = progress;
          if (progress.isCompleted && progress.error != null) {
            throw Exception(progress.error);
          }
        }

        if (mounted) {
          Navigator.pop(context); // Close dialog
          final lastProgress = _progressNotifier.value;
          final String sampleWordsText = lastProgress.sampleWords != null
              ? '\n\nSample words: ${lastProgress.sampleWords!.join(', ')}'
              : '';

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Dictionary imported successfully$sampleWordsText'),
              duration: const Duration(seconds: 5),
            ),
          );
          await _loadDictionaries();
        }
      } catch (e) {
        if (mounted) {
          Navigator.pop(context); // Close dialog
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Import failed: $e')));
        }
      }
    }
  }

  // Need to define ValueNotifier
  final ValueNotifier<ImportProgress> _progressNotifier = ValueNotifier(
    ImportProgress(message: 'Starting...', value: 0.0),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Manage Dictionaries',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            tooltip: 'Re-index for Definition Search',
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _reIndexAll,
          ),
        ],
      ),
      persistentFooterButtons: [
        Row(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                child: OutlinedButton.icon(
                  onPressed: _isLoading ? null : _importDictionary,
                  icon: const Icon(Icons.file_open_outlined),
                  label: const Text('Import File'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                child: FilledButton.icon(
                  onPressed: _isLoading ? null : _downloadDictionary,
                  icon: const Icon(Icons.public),
                  label: const Text('Download Web'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _dictionaries.isEmpty
          ? _buildEmptyState()
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text(
                    'Drag to reorder (favorite first)',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
                Expanded(
                  child: ReorderableListView.builder(
                    buildDefaultDragHandles: false,
                    itemCount: _dictionaries.length,
                    onReorder: (oldIndex, newIndex) async {
                      if (newIndex > oldIndex) newIndex -= 1;

                      final List<Map<String, dynamic>> updatedList = List.from(
                        _dictionaries,
                      );
                      final item = updatedList.removeAt(oldIndex);
                      updatedList.insert(newIndex, item);

                      setState(() {
                        _dictionaries = updatedList;
                      });

                      // Persist new order
                      final sortedIds = updatedList
                          .map((d) => d['id'] as int)
                          .toList();
                      await _dictionaryManager.reorderDictionaries(sortedIds);
                    },
                    itemBuilder: (context, index) {
                      final dict = _dictionaries[index];
                      return Card(
                        key: ValueKey(dict['id']),
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        elevation: 0,
                        color: Theme.of(context).colorScheme.surface,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: Colors.grey.withValues(alpha: 0.2),
                          ),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 0,
                            vertical: 4,
                          ),
                          leading: ReorderableDragStartListener(
                            index: index,
                            child: const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 16.0),
                              child: Icon(
                                Icons.drag_handle,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                          title: Text(
                            dict['name'],
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${dict['word_count']} words',
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(
                                    dict['index_definitions'] == 1
                                        ? Icons.manage_search
                                        : Icons.search_off,
                                    size: 14,
                                    color: Colors.grey,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    dict['index_definitions'] == 1
                                        ? 'Definitions indexed'
                                        : 'Headwords only',
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(fontSize: 10),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Switch(
                                value: dict['is_enabled'] == 1,
                                activeThumbColor: Theme.of(
                                  context,
                                ).colorScheme.primary,
                                onChanged: (bool value) async {
                                  await _dictionaryManager
                                      .toggleDictionaryEnabled(
                                        dict['id'],
                                        value,
                                      );
                                  _loadDictionaries();
                                },
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.settings_outlined,
                                  size: 20,
                                ),
                                tooltip: 'Indexing settings',
                                onPressed: () => _showIndexingDialog(dict),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.delete_outline,
                                  color: Colors.redAccent,
                                ),
                                onPressed: () => _showDeleteDialog(dict),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.library_books_outlined, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'No dictionaries installed.',
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
          SizedBox(height: 8),
          Text(
            'Use the buttons below to add one.',
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Future<void> _showDeleteDialog(Map<String, dynamic> dict) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Dictionary?'),
        content: Text('Are you sure you want to delete "${dict['name']}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _dictionaryManager.deleteDictionary(dict['id']);
      _loadDictionaries();
    }
  }

  void _showIndexingDialog(Map<String, dynamic> dict) async {
    bool indexDefinitions = dict['index_definitions'] == 1;
    final int dictId = dict['id'];

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Indexing Settings: ${dict['name']}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            StatefulBuilder(
              builder: (context, setState) {
                return CheckboxListTile(
                  title: const Text('Index definitions for search'),
                  subtitle: const Text(
                    'Allows searching inside meanings for this dictionary.',
                  ),
                  value: indexDefinitions,
                  onChanged: (val) async {
                    final newValue = val ?? false;
                    setState(() => indexDefinitions = newValue);
                    await _dictionaryManager.updateDictionaryIndexDefinitions(
                      dictId,
                      newValue,
                    );
                    _loadDictionaries();
                  },
                );
              },
            ),
            const SizedBox(height: 16),
            const Text(
              'If you change this setting, you must re-index this dictionary for it to take effect.',
              style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _reIndexSpecific(dict);
            },
            icon: const Icon(Icons.refresh),
            label: const Text('Re-index Now'),
          ),
        ],
      ),
    );
  }

  Future<void> _reIndexSpecific(Map<String, dynamic> dict) async {
    final dictId = dict['id'] as int;
    final dictName = dict['name'] as String;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return PopScope(
          canPop: false,
          child: AlertDialog(
            title: Text('Re-indexing $dictName'),
            content: ValueListenableBuilder<ImportProgress>(
              valueListenable: _progressNotifier,
              builder: (context, progress, child) {
                return _buildProgressContent(progress);
              },
            ),
          ),
        );
      },
    );

    try {
      final stream = _dictionaryManager.reIndexDictionaryStream(dictId);
      await for (final progress in stream) {
        _progressNotifier.value = progress;
        if (progress.isCompleted && progress.error != null) {
          throw Exception(progress.error);
        }
      }

      if (mounted) {
        Navigator.pop(context); // Close progress dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$dictName re-indexed successfully!')),
        );
        await _loadDictionaries();
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close progress dialog
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Re-indexing failed: $e')));
      }
    }
  }

  Widget _buildProgressContent(ImportProgress progress) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        LinearProgressIndicator(value: progress.value),
        const SizedBox(height: 16),
        Text(progress.message, textAlign: TextAlign.center),
        if (progress.headwordCount > 0) ...[
          const SizedBox(height: 8),
          Text(
            '${progress.headwordCount} headwords indexed',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ],
        if (progress.definitionWordCount > 0)
          Text(
            '${progress.definitionWordCount} definition words indexed',
            style: const TextStyle(fontSize: 11, color: Colors.grey),
          ),
      ],
    );
  }
}
