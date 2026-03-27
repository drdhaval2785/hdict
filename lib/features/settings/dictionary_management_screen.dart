import 'package:flutter/material.dart';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:file_selector/file_selector.dart';
import 'package:file_picker/file_picker.dart';

import 'package:hdict/core/manager/dictionary_manager.dart';
import 'package:hdict/core/manager/dictionary_group_manager.dart';
import 'package:hdict/core/parser/bookmark_manager.dart';
import 'package:hdict/features/home/widgets/app_drawer.dart';
import 'package:hdict/features/settings/widgets/stardict_download_dialog.dart';

/// A screen for managing installed dictionaries.
class DictionaryManagementScreen extends StatefulWidget {
  final bool triggerSelectByLanguage;
  const DictionaryManagementScreen({
    super.key,
    this.triggerSelectByLanguage = false,
  });

  @override
  State<DictionaryManagementScreen> createState() =>
      _DictionaryManagementScreenState();
}

class _DictionaryManagementScreenState
    extends State<DictionaryManagementScreen> {
  final DictionaryManager _dictionaryManager = DictionaryManager();
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _dictionaries = [];
  List<Map<String, dynamic>> _filteredDictionaries = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDictionaries();
    _searchController.addListener(_onSearchChanged);
    if (widget.triggerSelectByLanguage) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _downloadFreedictDictionary();
      });
    }
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _filterDictionaries();
  }

  void _filterDictionaries() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredDictionaries = List.from(_dictionaries);
      } else {
        _filteredDictionaries = _dictionaries.where((dict) {
          final name = (dict['name'] as String).toLowerCase();
          return name.contains(query);
        }).toList();
      }
    });
  }

  Future<void> _loadDictionaries() async {
    setState(() => _isLoading = true);
    try {
      final dicts = await _dictionaryManager.getDictionaries();
      setState(() {
        _dictionaries = dicts;
        _filterDictionaries();
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _downloadDictionary() async {
    final TextEditingController urlController = TextEditingController();
    bool indexDefinitions = false;
    final dynamic urlString = await showDialog<dynamic>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Download Dictionary'),
              content: SingleChildScrollView(
                child: Column(
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
                    const SizedBox(height: 16),
                    CheckboxListTile(
                      title: const Text('Index words in definitions'),
                      subtitle: const Text(
                        'Enables searching inside meanings (takes more time/space)',
                      ),
                      value: indexDefinitions,
                      onChanged: (val) {
                        setDialogState(() {
                          indexDefinitions = val ?? false;
                        });
                      },
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ],
                ),
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
      },
    );

    if (urlString != null &&
        urlString is Map &&
        urlString['url'] != null &&
        (urlString['url'] as String).isNotEmpty) {
      final String url = urlString['url'];
      final bool index = urlString['index'] ?? false;
      if (!mounted) return;

      bool cancelled = false;
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
                  return _buildProgressContent(
                    progress,
                    onCancel: () {
                      cancelled = true;
                      Navigator.pop(context);
                    },
                  );
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
          if (cancelled) break;
          _progressNotifier.value = progress;
        }

        if (mounted) {
          Navigator.pop(context); // Close progress dialog
          final lastProgress = _progressNotifier.value;

          if (lastProgress.error != null &&
              lastProgress.error != 'ALREADY_EXISTS') {
            throw Exception(lastProgress.error);
          }

          if (lastProgress.alreadyExistsEntries != null &&
              lastProgress.alreadyExistsEntries!.isNotEmpty) {
            _showImportReport(lastProgress, title: 'Download Result');
          } else if (lastProgress.error == 'ALREADY_EXISTS') {
            final name =
                lastProgress.dictionaryName ??
                (lastProgress.message.contains(':')
                    ? lastProgress.message.split(':').last.trim()
                    : lastProgress.message);
            _showImportReport(
              ImportProgress(
                message: lastProgress.message,
                value: 1.0,
                isCompleted: true,
                alreadyExistsEntries: [name],
              ),
              title: 'Download Result',
            );
          } else {
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
          }
          await _loadDictionaries();
        }
      } catch (e) {
        if (mounted) {
          Navigator.pop(context); // Close progress dialog
          final String errorStr = e.toString();
          String message;
          if (errorStr.contains('ALREADY_EXISTS:')) {
            message = errorStr.split('ALREADY_EXISTS:').last.trim();
          } else if (errorStr.contains('already in your library')) {
            message = errorStr.replaceAll('Exception: ', '').trim();
          } else {
            message = 'Download/Import failed: $e';
          }
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(message)));
        }
      }
    }
  }

  Future<void> _downloadFreedictDictionary() async {
    final dynamic result = await showDialog<dynamic>(
      context: context,
      builder: (context) => const StardictDownloadDialog(),
    );

    if (result != null && result is Map && result['urls'] != null) {
      final List<String> urls = (result['urls'] as List).cast<String>();
      final bool index = result['index'] ?? false;
      final String? groupName = result['groupName'] as String?;
      if (urls.isEmpty || !mounted) return;

      bool cancelled = false;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          return PopScope(
            canPop: false,
            child: AlertDialog(
              title: Text(
                urls.length == 1
                    ? 'Downloading Dictionary'
                    : 'Downloading ${urls.length} Dictionaries',
              ),
              content: ValueListenableBuilder<ImportProgress>(
                valueListenable: _progressNotifier,
                builder: (context, progress, child) {
                  return _buildProgressContent(
                    progress,
                    onCancel: () {
                      cancelled = true;
                      Navigator.pop(context);
                    },
                  );
                },
              ),
            ),
          );
        },
      );

      int successCount = 0;
      int failureCount = 0;
      final List<String> allAlreadyExists = [];
      final List<String> allIncomplete = [];
      final List<String> allImported = [];

      for (int i = 0; i < urls.length; i++) {
        if (cancelled) break;
        final url = urls[i];
        try {
          final stream = _dictionaryManager.downloadAndImportDictionaryStream(
            url,
            indexDefinitions: index,
            sourceUrl: url,
          );
          await for (final progress in stream) {
            if (cancelled) break;
            _progressNotifier.value = ImportProgress(
              message: urls.length > 1
                  ? '(${i + 1}/${urls.length}) ${progress.message}'
                  : progress.message,
              value: progress.value,
              isCompleted: progress.isCompleted,
              error: progress.error,
              sampleWords: progress.sampleWords,
              incompleteEntries: progress.incompleteEntries,
              alreadyExistsEntries: progress.alreadyExistsEntries,
            );
            if (progress.dictId != null && groupName != null) {
              await DictionaryGroupManager.addDictionaryToGroup(
                groupName,
                progress.dictId!,
              );
            }
            if (progress.isCompleted) {
              if (progress.error != null &&
                  progress.error != 'ALREADY_EXISTS') {
                throw Exception(progress.error);
              }
              if (progress.alreadyExistsEntries != null) {
                allAlreadyExists.addAll(progress.alreadyExistsEntries!);
              } else if (progress.error == 'ALREADY_EXISTS') {
                allAlreadyExists.add(progress.dictionaryName ?? url);
              } else if (progress.error == null) {
                allImported.add(progress.dictionaryName ?? url);
                successCount++;
              }
            }
          }
        } catch (e) {
          failureCount++;
          allIncomplete.add('(${i + 1}/${urls.length}) $e');
        }
      }

      if (mounted) {
        Navigator.pop(context); // Close progress dialog

        if (allAlreadyExists.isNotEmpty || allIncomplete.isNotEmpty) {
          _showImportReport(
            ImportProgress(
              message: 'Bulk download complete',
              value: 1.0,
              isCompleted: true,
              alreadyExistsEntries: allAlreadyExists,
              incompleteEntries: allIncomplete,
              importedEntries: allImported,
            ),
            title: 'Bulk Download Result',
          );
        } else {
          String msg;
          if (urls.length == 1) {
            msg = successCount == 1
                ? 'Dictionary downloaded and imported successfully'
                : 'Failed to import dictionary';
          } else {
            msg = '$successCount successfully imported.';
            if (failureCount > 0) {
              msg += ' $failureCount failed.';
            }
          }

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(msg), duration: const Duration(seconds: 5)),
          );
        }
        await _loadDictionaries();
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
    final List<XFile> files = await openFiles(
      acceptedTypeGroups: <XTypeGroup>[typeGroup],
    );

    if (files.isNotEmpty) {
      if (!mounted) return;

      bool indexDefinitions = false;
      final dynamic importConfig = await showDialog<dynamic>(
        context: context,
        builder: (context) {
          return StatefulBuilder(
            builder: (context, setDialogState) {
              return AlertDialog(
                title: const Text('Import Dictionary'),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Importing ${files.length} file(s).'),
                      const SizedBox(height: 16),
                      CheckboxListTile(
                        title: const Text('Index words in definitions'),
                        subtitle: const Text(
                          'Enables searching inside meanings (takes more time/space)',
                        ),
                        value: indexDefinitions,
                        onChanged: (val) {
                          setDialogState(() {
                            indexDefinitions = val ?? false;
                          });
                        },
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context, indexDefinitions),
                    child: const Text('Proceed'),
                  ),
                ],
              );
            },
          );
        },
      );

      if (importConfig == null) return;
      indexDefinitions = importConfig as bool;

      if (!mounted) return;

      bool cancelled = false;
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
                  return _buildProgressContent(
                    progress,
                    onCancel: () {
                      cancelled = true;
                      Navigator.pop(context);
                    },
                  );
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
              (f) =>
                  f.name.endsWith('.ifo') ||
                  f.name.endsWith('.idx') ||
                  f.name.endsWith('.index') ||
                  f.name.endsWith('.mdd'),
            )) {
          if (kIsWeb) {
            final fileData = await Future.wait(
              files.map(
                (f) async => (name: f.name, bytes: await f.readAsBytes()),
              ),
            );
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
              stream = _dictionaryManager.importMultipleFilesWebStream([
                (name: singleFile.name, bytes: await singleFile.readAsBytes()),
              ], indexDefinitions: indexDefinitions);
            } else {
              stream = _dictionaryManager.importMultipleFilesStream([
                singleFile.path,
              ], indexDefinitions: indexDefinitions);
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
          if (cancelled) break;
          _progressNotifier.value = progress;
          if (progress.isCompleted && progress.error != null) {
            throw Exception(progress.error);
          }
        }

        if (mounted) {
          Navigator.pop(context); // Close dialog
          final lastProgress = _progressNotifier.value;

          if ((lastProgress.alreadyExistsEntries != null &&
                  lastProgress.alreadyExistsEntries!.isNotEmpty) ||
              (lastProgress.incompleteEntries != null &&
                  lastProgress.incompleteEntries!.isNotEmpty)) {
            _showImportReport(lastProgress, title: 'Import Result');
          } else {
            final String sampleWordsText = lastProgress.sampleWords != null
                ? '\n\nSample words: ${lastProgress.sampleWords!.join(', ')}'
                : '';

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Dictionary imported successfully$sampleWordsText',
                ),
                duration: const Duration(seconds: 5),
              ),
            );
          }
          await _loadDictionaries();
        }
      } catch (e) {
        if (mounted) {
          Navigator.pop(context); // Close dialog
          final String errorStr = e.toString();
          String message;
          if (errorStr.contains('ALREADY_EXISTS:')) {
            message = errorStr.split('ALREADY_EXISTS:').last.trim();
          } else if (errorStr.contains('already in your library')) {
            message = errorStr.replaceAll('Exception: ', '').trim();
          } else {
            message = 'Import failed: $e';
          }
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(message)));
        }
      }
    }
  }

  Future<void> _addFolder() async {
    String? folderPath;
    try {
      if (Platform.isAndroid) {
        folderPath = await BookmarkManager.pickDirectory();
      } else {
        folderPath = await FilePicker.platform.getDirectoryPath();
      }
    } catch (e) {
      debugPrint('Error picking folder: $e');
      return;
    }
    if (folderPath == null) return;
    if (!mounted) return;

    bool indexDefinitions = false;
    final dynamic importConfig = await showDialog<dynamic>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Add Folder'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Adding from "$folderPath".\n\nDirect dictionaries will be linked (zero-copy), and archives will be decompressed and imported.',
                      style: const TextStyle(fontSize: 13),
                    ),
                    const SizedBox(height: 16),
                    CheckboxListTile(
                      title: const Text('Index words in definitions'),
                      subtitle: const Text(
                        'Enables searching inside meanings (takes more time/space)',
                      ),
                      value: indexDefinitions,
                      onChanged: (val) {
                        setDialogState(() {
                          indexDefinitions = val ?? false;
                        });
                      },
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, indexDefinitions),
                  child: const Text('Proceed'),
                ),
              ],
            );
          },
        );
      },
    );

    if (importConfig == null) return;
    indexDefinitions = importConfig as bool;

    if (!mounted) return;

    bool cancelled = false;
    // Show progress dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return PopScope(
          canPop: false,
          child: AlertDialog(
            title: const Text('Adding Folder Contents'),
            content: ValueListenableBuilder<ImportProgress>(
              valueListenable: _progressNotifier,
              builder: (context, progress, child) {
                return _buildProgressContent(
                  progress,
                  onCancel: () {
                    cancelled = true;
                    Navigator.pop(context);
                  },
                );
              },
            ),
          ),
        );
      },
    );

    try {
      ImportProgress? finalProgress;
      final stream = _dictionaryManager.addFolderStream(
        folderPath,
        indexDefinitions: indexDefinitions,
      );

      await for (final progress in stream) {
        if (cancelled) break;
        _progressNotifier.value = progress;

        // Auto-assign to group if folder name was captured
        if (progress.dictId != null && progress.groupName != null) {
          await DictionaryGroupManager.addDictionaryToGroup(
            progress.groupName!,
            progress.dictId!,
          );
        }

        if (progress.isCompleted) {
          finalProgress = progress;
          if (progress.error != null) {
            throw Exception(progress.error);
          }
        }
      }

      if (mounted) {
        Navigator.pop(context); // Close progress dialog
        await _loadDictionaries();
        if (finalProgress != null) {
          _showImportReport(finalProgress, title: 'Folder Processing Report');
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close progress dialog
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to add folder: $e')));
      }
    }
  }

  void _showImportReport(
    ImportProgress progress, {
    String title = 'Import Report',
  }) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (progress.linkedEntries != null &&
                  progress.linkedEntries!.isNotEmpty) ...[
                const Text(
                  'Linked Dictionaries (Not Copied):',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
                const SizedBox(height: 4),
                ...progress.linkedEntries!.map(
                  (e) => Padding(
                    padding: const EdgeInsets.only(left: 8.0, bottom: 2.0),
                    child: Text('• $e', style: const TextStyle(fontSize: 12)),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              if (progress.importedEntries != null &&
                  progress.importedEntries!.isNotEmpty) ...[
                const Text(
                  'Imported Dictionaries (Data Copied):',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(height: 4),
                ...progress.importedEntries!.map(
                  (e) => Padding(
                    padding: const EdgeInsets.only(left: 8.0, bottom: 2.0),
                    child: Text('• $e', style: const TextStyle(fontSize: 12)),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              if (progress.alreadyExistsEntries != null &&
                  progress.alreadyExistsEntries!.isNotEmpty) ...[
                const Text(
                  'ALREADY EXISTS:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.purple,
                  ),
                ),
                const SizedBox(height: 4),
                ...progress.alreadyExistsEntries!.map(
                  (e) => Padding(
                    padding: const EdgeInsets.only(left: 8.0, bottom: 2.0),
                    child: Text('• $e', style: const TextStyle(fontSize: 12)),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              if (progress.incompleteEntries != null &&
                  progress.incompleteEntries!.isNotEmpty) ...[
                const Text(
                  'ERRORS / Not Processed:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.orange,
                  ),
                ),
                const SizedBox(height: 4),
                ...progress.incompleteEntries!.map(
                  (e) => Padding(
                    padding: const EdgeInsets.only(left: 8.0, bottom: 2.0),
                    child: Text('• $e', style: const TextStyle(fontSize: 12)),
                  ),
                ),
              ],
              if ((progress.linkedEntries == null ||
                      progress.linkedEntries!.isEmpty) &&
                  (progress.importedEntries == null ||
                      progress.importedEntries!.isEmpty) &&
                  (progress.alreadyExistsEntries == null ||
                      progress.alreadyExistsEntries!.isEmpty) &&
                  (progress.incompleteEntries == null ||
                      progress.incompleteEntries!.isEmpty))
                const Text('No dictionaries found in the selected folder.'),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  final ValueNotifier<ImportProgress> _progressNotifier = ValueNotifier(
    ImportProgress(message: 'Starting...', value: 0.0),
  );

  Future<void> _reindexAll() async {
    if (_dictionaries.isEmpty) return;

    final localContext = context;
    final bool? confirm = await showDialog<bool>(
      context: localContext,
      builder: (context) => AlertDialog(
        title: const Text('Reindex All'),
        content: const Text(
          'This will re-index all installed dictionaries. Dictionaries previously indexed with definitions will keep that setting. "Headword Only" is the default for others.\n\nContinue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reindex'),
          ),
        ],
      ),
    );

    if (confirm != true) return;
    if (!localContext.mounted) return;

    bool cancelled = false;
    showDialog(
      context: localContext,
      barrierDismissible: false,
      builder: (context) {
        return PopScope(
          canPop: false,
          child: AlertDialog(
            title: const Text('Re-indexing All'),
            content: ValueListenableBuilder<ImportProgress>(
              valueListenable: _progressNotifier,
              builder: (context, progress, child) {
                return _buildProgressContent(
                  progress,
                  onCancel: () {
                    cancelled = true;
                    Navigator.pop(context);
                  },
                );
              },
            ),
          ),
        );
      },
    );

    int successCount = 0;
    for (int i = 0; i < _dictionaries.length; i++) {
      if (cancelled) break;
      final dict = _dictionaries[i];
      final int dictId = dict['id'] as int;
      final String name = dict['name'] as String;
      final bool indexDefinitions = (dict['index_definitions'] ?? 0) == 1;

      try {
        final stream = _dictionaryManager.reindexDictionaryStream(
          dictId,
          indexDefinitions: indexDefinitions,
        );

        await for (final progress in stream) {
          if (cancelled) break;
          _progressNotifier.value = ImportProgress(
            message:
                '(${i + 1}/${_dictionaries.length}) $name: ${progress.message}',
            value: progress.value,
            isCompleted: progress.isCompleted,
            error: progress.error,
          );
        }
        successCount++;
      } catch (e) {
        debugPrint('Error re-indexing $name: $e');
      }
    }

    if (mounted) {
      final NavigatorState navigator = Navigator.of(context);
      final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);

      navigator.pop(); // Close progress dialog
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Re-indexed $successCount/${_dictionaries.length} dictionaries',
          ),
        ),
      );
      await _loadDictionaries();
    }
  }

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
        () {
          final double screenWidth = MediaQuery.sizeOf(context).width;
          final bool isWide =
              screenWidth > 680; // wider to comfortably fit 4 buttons

          if (isWide) {
            return Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildFooterButton(
                  onPressed: _isLoading ? null : _importDictionary,
                  icon: Icons.file_open_outlined,
                  label: 'Import File',
                  isPrimary: false,
                ),
                const SizedBox(width: 8),
                _buildFooterButton(
                  onPressed: _isLoading ? null : _addFolder,
                  icon: Icons.create_new_folder_outlined,
                  label: 'Add Folder',
                  isPrimary: false,
                ),
                const SizedBox(width: 8),
                _buildFooterButton(
                  onPressed: _isLoading ? null : _downloadDictionary,
                  icon: Icons.public,
                  label: 'Download from Web',
                  isPrimary: false,
                ),
                const SizedBox(width: 8),
                _buildFooterButton(
                  onPressed: _isLoading ? null : _downloadFreedictDictionary,
                  icon: Icons.language,
                  label: 'Select by Language',
                  isPrimary: true,
                ),
              ],
            );
          } else {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _buildFooterButton(
                        onPressed: _isLoading ? null : _importDictionary,
                        icon: Icons.file_open_outlined,
                        label: 'Import File',
                        isPrimary: false,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildFooterButton(
                        onPressed: _isLoading ? null : _addFolder,
                        icon: Icons.create_new_folder_outlined,
                        label: 'Add Folder',
                        isPrimary: false,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _buildFooterButton(
                        onPressed: _isLoading ? null : _downloadDictionary,
                        icon: Icons.public,
                        label: 'Download from Web',
                        isPrimary: false,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildFooterButton(
                        onPressed: _isLoading
                            ? null
                            : _downloadFreedictDictionary,
                        icon: Icons.language,
                        label: 'Select by Language',
                        isPrimary: true,
                      ),
                    ),
                  ],
                ),
              ],
            );
          }
        }(),
      ],

      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _dictionaries.isEmpty
          ? _buildEmptyState()
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 8.0,
                  ),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search dictionaries...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () => _searchController.clear(),
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _isLoading || _dictionaries.isEmpty
                              ? null
                              : _reindexAll,
                          icon: const Icon(Icons.refresh, size: 18),
                          label: const Text('Reindex All'),
                          style: OutlinedButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${_dictionaries.where((d) => d['is_enabled'] == 1).length} / ${_dictionaries.length} active',
                        style: Theme.of(
                          context,
                        ).textTheme.bodySmall?.copyWith(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: Text(
                    _filteredDictionaries.length == _dictionaries.length
                        ? 'Drag to reorder (favorite first)'
                        : 'Search results (${_filteredDictionaries.length})',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
                Expanded(
                  child: ReorderableListView.builder(
                    buildDefaultDragHandles: false,
                    itemCount: _filteredDictionaries.length,
                    onReorder: (oldIndex, newIndex) async {
                      if (newIndex > oldIndex) newIndex -= 1;

                      final item = _filteredDictionaries[oldIndex];
                      final actualOldIndex = _dictionaries.indexOf(item);

                      final targetItem = _filteredDictionaries[newIndex];
                      final actualNewIndex = _dictionaries.indexOf(targetItem);

                      if (actualOldIndex == -1 || actualNewIndex == -1) return;

                      final List<Map<String, dynamic>> updatedList = List.from(
                        _dictionaries,
                      );
                      final movedItem = updatedList.removeAt(actualOldIndex);
                      updatedList.insert(actualNewIndex, movedItem);

                      setState(() {
                        _dictionaries = updatedList;
                        _filterDictionaries();
                      });

                      final sortedIds = updatedList
                          .map((d) => d['id'] as int)
                          .toList();
                      await _dictionaryManager.reorderDictionaries(sortedIds);
                    },
                    itemBuilder: (context, index) {
                      final dict = _filteredDictionaries[index];
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
                            '${dict['word_count']} hw${(dict['definition_word_count'] ?? 0) > 0 ? ', ${dict['definition_word_count']} def' : ''}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
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
                              PopupMenuButton<String>(
                                icon: const Icon(Icons.more_vert),
                                onSelected: (value) {
                                  if (value == 'reindex') {
                                    _showReindexDialog(dict);
                                  } else if (value == 'delete') {
                                    _showDeleteDialog(dict);
                                  }
                                },
                                itemBuilder: (BuildContext context) => [
                                  const PopupMenuItem(
                                    value: 'reindex',
                                    child: ListTile(
                                      leading: Icon(
                                        Icons.refresh,
                                        color: Colors.blueAccent,
                                      ),
                                      title: Text('Re-index'),
                                      contentPadding: EdgeInsets.zero,
                                    ),
                                  ),
                                  const PopupMenuItem(
                                    value: 'delete',
                                    child: ListTile(
                                      leading: Icon(
                                        Icons.delete_outline,
                                        color: Colors.redAccent,
                                      ),
                                      title: Text('Delete'),
                                      contentPadding: EdgeInsets.zero,
                                    ),
                                  ),
                                ],
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
              Icon(
                Icons.library_books_outlined,
                size: 64,
                color: Colors.grey.withValues(alpha: 0.5),
              ),
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
              onPressed: _downloadFreedictDictionary,
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
              'You can also use "Import File" or "Download Web" below if you have a specific file or URL.',
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
      final progressNotifier = ValueNotifier<DeletionProgress>(
        DeletionProgress(message: 'Starting deletion...', value: 0.0),
      );

      bool cancelled = false;
      if (!mounted) return;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          return PopScope(
            canPop: false,
            child: AlertDialog(
              title: const Text('Deleting Dictionary'),
              content: ValueListenableBuilder<DeletionProgress>(
                valueListenable: progressNotifier,
                builder: (context, progress, child) {
                  return SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        LinearProgressIndicator(value: progress.value),
                        const SizedBox(height: 16),
                        Text(progress.message, textAlign: TextAlign.center),
                        if (!progress.isCompleted) ...[
                          const SizedBox(height: 24),
                          OutlinedButton.icon(
                            onPressed: () {
                              cancelled = true;
                              Navigator.pop(context);
                            },
                            icon: const Icon(Icons.cancel, size: 18),
                            label: const Text('Cancel Operation'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red,
                              side: const BorderSide(color: Colors.red),
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),
            ),
          );
        },
      );

      try {
        final stream = _dictionaryManager.deleteDictionaryStream(dict['id']);
        await for (final progress in stream) {
          if (cancelled) break;
          progressNotifier.value = progress;
        }

        if (mounted) {
          Navigator.pop(context);
          _loadDictionaries();
        }
      } catch (e) {
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Deletion failed: $e')));
        }
      }
    }
  }

  Widget _buildFooterButton({
    required VoidCallback? onPressed,
    required IconData icon,
    required String label,
    required bool isPrimary,
  }) {
    final style =
        (isPrimary ? FilledButton.styleFrom : OutlinedButton.styleFrom)(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        );

    if (isPrimary) {
      return FilledButton.icon(
        onPressed: onPressed,
        icon: Icon(icon),
        label: Text(label),
        style: style,
      );
    } else {
      return OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon),
        label: Text(label),
        style: style,
      );
    }
  }

  Future<void> _showReindexDialog(Map<String, dynamic> dict) async {
    final bool? indexDefinitions = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Re-index Dictionary'),
        content: const Text('How would you like to re-index this dictionary?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Headwords & Definitions'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Headwords Only'),
          ),
        ],
      ),
    );

    if (indexDefinitions != null) {
      if (!mounted) return;
      bool cancelled = false;
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
                  return _buildProgressContent(
                    progress,
                    onCancel: () {
                      cancelled = true;
                      Navigator.pop(context);
                    },
                  );
                },
              ),
            ),
          );
        },
      );

      try {
        final stream = _dictionaryManager.reindexDictionaryStream(
          dict['id'],
          indexDefinitions: indexDefinitions,
        );
        await for (final progress in stream) {
          if (cancelled) break;
          _progressNotifier.value = progress;
          if (progress.isCompleted && progress.error != null) {
            throw Exception(progress.error);
          }
        }
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Re-indexing of "${dict['name']}" complete.'),
            ),
          );
          _loadDictionaries();
        }
      } catch (e) {
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Re-indexing failed: $e')));
        }
      }
    }
  }

  Widget _buildProgressContent(
    ImportProgress progress, {
    VoidCallback? onCancel,
  }) {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (progress.dictionaryName != null) ...[
            Text(
              progress.dictionaryName!,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
          ],
          LinearProgressIndicator(value: progress.value),
          const SizedBox(height: 16),
          Text(progress.message, textAlign: TextAlign.center),
          if (progress.headwordCount > 0) ...[
            const SizedBox(height: 8),
            Text(
              '${progress.headwordCount} headwords'
              '${(progress.definitionWordCount > 0) ? ', ${progress.definitionWordCount} definition words indexed' : ' indexed'}',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ],
          if (onCancel != null && !progress.isCompleted) ...[
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: onCancel,
              icon: const Icon(Icons.cancel, size: 18),
              label: const Text('Cancel Operation'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: const BorderSide(color: Colors.red),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
