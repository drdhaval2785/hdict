import 'package:flutter/material.dart';
import 'package:hdict/core/constants/iso_639_2_languages.dart';
import 'package:hdict/features/settings/services/stardict_service.dart';

class StardictDownloadDialog extends StatefulWidget {
  const StardictDownloadDialog({super.key});

  @override
  State<StardictDownloadDialog> createState() => _StardictDownloadDialogState();
}

class _StardictDownloadDialogState extends State<StardictDownloadDialog> {
  final StardictService _service = StardictService();

  List<StardictDictionary> _allDictionaries = [];
  bool _isLoading = true;
  bool _isRefreshing = false;
  String? _error;
  Set<String> _downloadedUrls = {};

  String? _selectedSourceLanguage;
  String? _selectedTargetLanguage;
  bool _indexDefinitions = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final cachedDicts = await _service.fetchDictionaries();
      final downloadedUrls = await _service.getDownloadedUrls();

      if (mounted) {
        setState(() {
          _allDictionaries = cachedDicts;
          _downloadedUrls = downloadedUrls;
          _isLoading = false;
        });
      }

      if (cachedDicts.isEmpty) {
        _refresh();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _refresh() async {
    if (_isRefreshing) return;

    setState(() {
      _isRefreshing = true;
      _error = null;
    });

    try {
      final dicts = await _service.refreshDictionaries();
      final downloadedUrls = await _service.getDownloadedUrls();
      if (mounted) {
        setState(() {
          _allDictionaries = dicts;
          _downloadedUrls = downloadedUrls;
          _isRefreshing = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isRefreshing = false;
        });
      }
    }
  }

  List<String> get _sourceLanguages {
    final sources = _allDictionaries
        .map((d) => d.sourceLanguageCode)
        .toSet()
        .toList();
    sources.sort((a, b) {
      final nameA = iso639_2Languages[a] ?? a;
      final nameB = iso639_2Languages[b] ?? b;
      return nameA.toLowerCase().compareTo(nameB.toLowerCase());
    });
    return sources;
  }

  int _getSourceLanguageCount(String code) {
    return _allDictionaries.where((d) => d.sourceLanguageCode == code).length;
  }

  List<String> get _targetLanguages {
    if (_selectedSourceLanguage == null) return [];
    final targets = _allDictionaries
        .where((d) => d.sourceLanguageCode == _selectedSourceLanguage)
        .map((d) => d.targetLanguageCode)
        .toSet()
        .toList();
    targets.sort((a, b) {
      final nameA = iso639_2Languages[a] ?? a;
      final nameB = iso639_2Languages[b] ?? b;
      return nameA.toLowerCase().compareTo(nameB.toLowerCase());
    });
    return targets;
  }

  int _getTargetLanguageCount(String code) {
    if (_selectedSourceLanguage == null) return 0;
    return _allDictionaries
        .where(
          (d) =>
              d.sourceLanguageCode == _selectedSourceLanguage &&
              d.targetLanguageCode == code,
        )
        .length;
  }

  List<StardictDictionary> get _filteredDictionaries {
    if (_selectedSourceLanguage == null || _selectedTargetLanguage == null) {
      return [];
    }
    final dicts = _allDictionaries
        .where(
          (d) =>
              d.sourceLanguageCode == _selectedSourceLanguage &&
              d.targetLanguageCode == _selectedTargetLanguage,
        )
        .toList();
    dicts.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return dicts;
  }

  String _formatSourceLanguageOption(String code) {
    final name = _getLanguageName(code);
    final count = _getSourceLanguageCount(code);
    return '$name ($code) - $count ${count == 1 ? 'dictionary' : 'dictionaries'}';
  }

  String _formatTargetLanguageOption(String code) {
    final name = _getLanguageName(code);
    final count = _getTargetLanguageCount(code);
    return '$name ($code) - $count ${count == 1 ? 'dictionary' : 'dictionaries'}';
  }

  String _parseCodeFromOption(String option) {
    final match = RegExp(r'\(([a-z]{3})\)').firstMatch(option);
    return match?.group(1) ?? '';
  }

  String _getLanguageName(String code) {
    return iso639_2Languages[code] ?? code;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          const Expanded(child: Text('Download Stardict Dictionaries')),
          if (_isRefreshing)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            IconButton(
              icon: const Icon(Icons.refresh, size: 20),
              onPressed: _refresh,
              tooltip: 'Refresh dictionary list',
            ),
        ],
      ),
      content: SizedBox(width: double.maxFinite, child: _buildContent()),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ],
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Text(
          'Failed to load dictionaries:\n$_error',
          style: const TextStyle(color: Colors.red),
          textAlign: TextAlign.center,
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Autocomplete<String>(
          initialValue: TextEditingValue(
            text: _selectedSourceLanguage != null
                ? '${_getLanguageName(_selectedSourceLanguage!)} ($_selectedSourceLanguage)'
                : '',
          ),
          optionsBuilder: (textEditingValue) {
            if (textEditingValue.text.isEmpty) {
              return _sourceLanguages.map(
                (code) => _formatSourceLanguageOption(code),
              );
            }
            final query = textEditingValue.text.toLowerCase();
            return _sourceLanguages
                .where((code) {
                  final name = _getLanguageName(code).toLowerCase();
                  return name.contains(query) ||
                      code.toLowerCase().contains(query);
                })
                .map((code) => _formatSourceLanguageOption(code));
          },
          displayStringForOption: (code) => _formatSourceLanguageOption(code),
          fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
            return TextField(
              controller: controller,
              focusNode: focusNode,
              decoration: const InputDecoration(
                labelText: 'Source Language',
                border: OutlineInputBorder(),
                hintText: 'Type to search...',
              ),
              onSubmitted: (_) => onFieldSubmitted(),
            );
          },
          optionsViewBuilder: (context, onSelected, options) {
            return Align(
              alignment: Alignment.topLeft,
              child: Material(
                elevation: 4.0,
                borderRadius: BorderRadius.circular(4),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxHeight: 300,
                    maxWidth: 400,
                  ),
                  child: ListView.builder(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    itemCount: options.length,
                    itemBuilder: (context, index) {
                      final option = options.elementAt(index);
                      final code = _parseCodeFromOption(option);
                      return ListTile(
                        title: Text(option),
                        subtitle: Text(
                          '${_getSourceLanguageCount(code)} ${_getSourceLanguageCount(code) == 1 ? 'dictionary' : 'dictionaries'}',
                        ),
                        onTap: () => onSelected(code),
                      );
                    },
                  ),
                ),
              ),
            );
          },
          onSelected: (code) {
            setState(() {
              _selectedSourceLanguage = code;
              _selectedTargetLanguage = null;
            });
          },
        ),
        const SizedBox(height: 16),
        Autocomplete<String>(
          initialValue: TextEditingValue(
            text: _selectedTargetLanguage != null
                ? '${_getLanguageName(_selectedTargetLanguage!)} ($_selectedTargetLanguage)'
                : '',
          ),
          optionsBuilder: (textEditingValue) {
            if (_selectedSourceLanguage == null) {
              return const Iterable<String>.empty();
            }
            if (textEditingValue.text.isEmpty) {
              return _targetLanguages.map(
                (code) => _formatTargetLanguageOption(code),
              );
            }
            final query = textEditingValue.text.toLowerCase();
            return _targetLanguages
                .where((code) {
                  final name = _getLanguageName(code).toLowerCase();
                  return name.contains(query) ||
                      code.toLowerCase().contains(query);
                })
                .map((code) => _formatTargetLanguageOption(code));
          },
          displayStringForOption: (code) => _formatTargetLanguageOption(code),
          fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
            return TextField(
              controller: controller,
              focusNode: focusNode,
              enabled: _selectedSourceLanguage != null,
              decoration: InputDecoration(
                labelText: 'Target Language',
                border: const OutlineInputBorder(),
                hintText: _selectedSourceLanguage == null
                    ? 'Select source first'
                    : 'Type to search...',
              ),
              onSubmitted: (_) => onFieldSubmitted(),
            );
          },
          optionsViewBuilder: (context, onSelected, options) {
            return Align(
              alignment: Alignment.topLeft,
              child: Material(
                elevation: 4.0,
                borderRadius: BorderRadius.circular(4),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxHeight: 300,
                    maxWidth: 400,
                  ),
                  child: ListView.builder(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    itemCount: options.length,
                    itemBuilder: (context, index) {
                      final option = options.elementAt(index);
                      final code = _parseCodeFromOption(option);
                      return ListTile(
                        title: Text(option),
                        subtitle: Text(
                          '${_getTargetLanguageCount(code)} ${_getTargetLanguageCount(code) == 1 ? 'dictionary' : 'dictionaries'}',
                        ),
                        onTap: () => onSelected(code),
                      );
                    },
                  ),
                ),
              ),
            );
          },
          onSelected: (code) {
            setState(() {
              _selectedTargetLanguage = code;
            });
          },
        ),
        const SizedBox(height: 16),
        CheckboxListTile(
          title: const Text('Index words in definitions'),
          subtitle: const Text(
            'Enables searching inside meanings (takes more time/space)',
          ),
          value: _indexDefinitions,
          onChanged: (val) {
            setState(() {
              _indexDefinitions = val ?? false;
            });
          },
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.zero,
        ),
        const SizedBox(height: 16),
        const Divider(),
        if (_filteredDictionaries.isEmpty)
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'Select a source and target language to see available dictionaries.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          )
        else
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _filteredDictionaries.length,
              itemBuilder: (context, index) {
                final dict = _filteredDictionaries[index];
                final release = dict.getPreferredRelease();
                if (release == null) return const SizedBox.shrink();

                final isDownloaded = _downloadedUrls.contains(release.url);

                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    title: Text(dict.name),
                    subtitle: Text(
                      'Version: ${dict.version.isEmpty ? "N/A" : dict.version} • Headwords: ${dict.headwords.isEmpty ? "N/A" : dict.headwords}',
                    ),
                    trailing: isDownloaded
                        ? FilledButton.icon(
                            icon: const Icon(Icons.check, size: 18),
                            label: const Text('Downloaded'),
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.green,
                            ),
                            onPressed: null,
                          )
                        : FilledButton.icon(
                            icon: const Icon(Icons.download, size: 18),
                            label: const Text('Download'),
                            onPressed: () {
                              Navigator.pop(context, {
                                'url': release.url,
                                'index': _indexDefinitions,
                              });
                            },
                          ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}
