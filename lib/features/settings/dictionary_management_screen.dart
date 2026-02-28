import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:file_selector/file_selector.dart';

import 'package:hdict/core/manager/dictionary_manager.dart';
import 'package:hdict/features/home/widgets/app_drawer.dart';

/// A screen for managing installed dictionaries.
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
    final TextEditingController urlController = TextEditingController();
    final dynamic urlString = await showDialog<dynamic>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
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
                    'index': true,
                  }),
                  child: const Text('Download'),
                ),
              ],
            );
          },
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

  Future<void> _importDictionary() async {
    const XTypeGroup typeGroup = XTypeGroup(
      label: 'Dictionaries',
      extensions: [
        'zip',
        'tar',
        'gz',
        'bz2',
        'xz',
        'tgz',
        'tbz2',
        'txz',
        'ifo',
        'idx',
        'dict',
        'dz',
        'syn',
        // New formats
        'mdx',
        'mdd',
        'index',
      ],
      uniformTypeIdentifiers: [
        'public.item',
        'public.archive',
        'com.pkware.zip-archive',
        'public.tar-archive',
        'public.gzip',
        'public.bzip2-archive',
        'public.data',
      ],
    );
    final List<XFile> files = await openFiles(acceptedTypeGroups: <XTypeGroup>[
      typeGroup,
    ]);

    if (files.isNotEmpty) {
      if (!mounted) return;

      final dynamic importConfig = await showDialog<dynamic>(
        context: context,
        builder: (context) {
          return StatefulBuilder(
            builder: (context, setDialogState) {
              return AlertDialog(
                title: const Text('Import Dictionary'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Importing ${files.length} file(s).'),
                    const SizedBox(height: 8),
                    const Text('Dictionaries will be automatically indexed for meaning search.'),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Proceed'),
                  ),
                ],
              );
            },
          );
        },
      );

      if (importConfig == null) return;
      final bool indexDefinitions = importConfig as bool;

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

        if (files.length > 1 ||
            files.any(
              (f) => f.name.endsWith('.ifo') || f.name.endsWith('.idx') ||
                     f.name.endsWith('.index') || f.name.endsWith('.mdd'),
            )) {
          if (kIsWeb) {
            final fileData = await Future.wait(files.map((f) async => (name: f.name, bytes: await f.readAsBytes())));
            stream = _dictionaryManager.importMultipleFilesWebStream(
              fileData,
              indexDefinitions: indexDefinitions,
            );
          } else {
            final paths = files.map((f) => f.path).toList();
            stream = _dictionaryManager.importMultipleFilesStream(
              paths,
              indexDefinitions: indexDefinitions,
            );
          }
        } else {
          // Single file — detect format
          final singleFile = files.single;
          final lowerName = singleFile.name.toLowerCase();

          if (lowerName.endsWith('.mdx')) {
            // These are self-contained — use multi-file stream which handles detection
            if (kIsWeb) {
              stream = _dictionaryManager.importMultipleFilesWebStream(
                [(name: singleFile.name, bytes: await singleFile.readAsBytes())],
                indexDefinitions: indexDefinitions,
              );
            } else {
              stream = _dictionaryManager.importMultipleFilesStream(
                [singleFile.path],
                indexDefinitions: indexDefinitions,
              );
            }
          } else if (kIsWeb) {
            stream = _dictionaryManager.importDictionaryWebStream(
              singleFile.name,
              await singleFile.readAsBytes(),
              indexDefinitions: indexDefinitions,
            );
          } else {
            stream = _dictionaryManager.importDictionaryStream(
              singleFile.path,
              indexDefinitions: indexDefinitions,
            );
          }
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
      ),
      drawer: const AppDrawer(),
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
                          contentPadding: const EdgeInsets.only(
                            left: 0,
                            right: 8,
                            top: 4,
                            bottom: 4,
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
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            '${dict['word_count']} words',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Switch(
                                value: dict['is_enabled'] == 1,
                                activeThumbColor: Theme.of(
                                  context,
                                ).colorScheme.primary,
                                onChanged: (bool? value) async {
                                  await _dictionaryManager
                                      .toggleDictionaryEnabled(
                                        dict['id'],
                                        value ?? false,
                                      );
                                  _loadDictionaries();
                                },
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.refresh,
                                  color: Colors.blueAccent,
                                ),
                                onPressed: () => _showReindexDialog(dict),
                                tooltip: 'Re-index dictionary',
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
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.library_books_outlined,
                  size: 64, color: Colors.grey.withValues(alpha: 0.5)),
              const SizedBox(height: 16),
              const Text(
                'No dictionaries installed.',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Add dictionaries to start using hdict.',
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 32),
              _buildGuidanceCard(theme),
              const SizedBox(height: 32),
              const Text(
                'Use the buttons below to add your own dictionary files.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGuidanceCard(ThemeData theme) {
    return Card(
      elevation: 0,
      color: theme.colorScheme.primaryContainer.withValues(alpha: 0.2),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.colorScheme.primary.withValues(alpha: 0.1)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Text(
              'Looking for a dictionary?',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Copy the URL below and paste it into "Download Web" below:',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: theme.colorScheme.primary.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(width: 8),
                  Expanded(
                    child: SelectableText(
                      'http://tovotu.de/data/stardict/gcide.zip',
                      style: TextStyle(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'monospace',
                        fontSize: 13,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy, size: 18),
                    onPressed: () {
                      Clipboard.setData(const ClipboardData(
                          text: 'http://tovotu.de/data/stardict/gcide.zip'));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('URL copied to clipboard'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                    tooltip: 'Copy URL',
                  ),
                ],
              ),
            ),
          ],
        ),
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

  Future<void> _showReindexDialog(Map<String, dynamic> dict) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(dict['index_definitions'] == 1 ? 'Re-index Dictionary?' : 'Enable Meaning Search?'),
        content: Text(
          dict['index_definitions'] == 1
              ? 'Are you sure you want to re-index "${dict['name']}"? This might take a while.'
              : 'Index definitions for "${dict['name']}"? This will enable searching inside meanings but will take some time.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Start'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          return PopScope(
            canPop: false,
            child: AlertDialog(
              title: const Text('Re-indexing'),
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
        final stream = _dictionaryManager.reindexDictionaryStream(dict['id']);
        await for (final progress in stream) {
          _progressNotifier.value = progress;
          if (progress.isCompleted && progress.error != null) {
            throw Exception(progress.error);
          }
        }
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Re-indexing of "${dict['name']}" complete.')),
          );
          _loadDictionaries();
        }
      } catch (e) {
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Re-indexing failed: $e')),
          );
        }
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
      ],
    );
  }
}
