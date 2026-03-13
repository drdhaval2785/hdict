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
    return '$name ($code) ($count)';
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
      content: SizedBox(
        width: double.maxFinite,
        height: MediaQuery.sizeOf(context).height * 0.8,
        child: _buildContent(),
      ),
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
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Selection Area
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
                prefixIcon: Icon(Icons.search),
              ),
              onSubmitted: (_) => onFieldSubmitted(),
            );
          },
          optionsViewBuilder: (context, onSelected, options) {
            return LayoutBuilder(
                builder: (context, constraints) {
                  return Align(
                    alignment: Alignment.topLeft,
                    child: Material(
                      elevation: 4.0,
                      borderRadius: BorderRadius.circular(8),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxHeight: 300,
                          maxWidth: constraints.maxWidth,
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
                              onTap: () => onSelected(code),
                            );
                          },
                        ),
                      ),
                    ),
                  );
                }
            );
          },
          onSelected: (code) {
            setState(() {
              _selectedSourceLanguage = code;
              _selectedTargetLanguage = null;
            });
            FocusManager.instance.primaryFocus?.unfocus();
          },
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: _selectedTargetLanguage,
          decoration: InputDecoration(
            labelText: 'Target Language',
            border: const OutlineInputBorder(),
            hintText: _selectedSourceLanguage == null
                ? 'Select source first'
                : 'Choose a language...',
            enabled: _selectedSourceLanguage != null,
            prefixIcon: const Icon(Icons.translate),
          ),
          items: _targetLanguages.map((code) {
            final count = _getTargetLanguageCount(code);
            return DropdownMenuItem<String>(
              value: code,
              child: Text(
                '${_getLanguageName(code)} ($code) ($count)',
                overflow: TextOverflow.ellipsis,
              ),
            );
          }).toList(),
          onChanged: _selectedSourceLanguage == null
              ? null
              : (String? value) {
            setState(() {
              _selectedTargetLanguage = value;
            });
          },
        ),
        const SizedBox(height: 8),
        CheckboxListTile(
          title: const Text('Index words in definitions'),
          subtitle: const Text(
            'Enables searching inside meanings',
            style: TextStyle(fontSize: 12),
          ),
          value: _indexDefinitions,
          onChanged: (val) {
            setState(() {
              _indexDefinitions = val ?? false;
            });
          },
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.zero,
          dense: true,
        ),
        const Divider(height: 24),
        // Results Area
        if (_filteredDictionaries.isEmpty)
          const Expanded(
            child: Center(
              child: Padding(
                padding: EdgeInsets.all(32.0),
                child: Text(
                  'Select languages to see available dictionaries.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
                ),
              ),
            ),
          )
        else ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Text(
              'Available Dictionaries (${_filteredDictionaries.length})',
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _filteredDictionaries.length,
              itemBuilder: (context, index) {
                final dict = _filteredDictionaries[index];
                final release = dict.getPreferredRelease();
                if (release == null) return const SizedBox.shrink();

                final isDownloaded = _downloadedUrls.contains(release.url);
                final theme = Theme.of(context);

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    dict.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Version: ${dict.version.isEmpty ? "N/A" : dict.version}',
                                    style: theme.textTheme.bodySmall,
                                  ),
                                  Text(
                                    'Headwords: ${dict.headwords.isEmpty ? "N/A" : dict.headwords}',
                                    style: theme.textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (isDownloaded)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.green.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.check_circle, color: Colors.green, size: 14),
                                    SizedBox(width: 4),
                                    Text(
                                      'Installed',
                                      style: TextStyle(
                                        color: Colors.green,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            else
                              ElevatedButton.icon(
                                icon: const Icon(Icons.download, size: 18),
                                label: const Text('Download'),
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  visualDensity: VisualDensity.compact,
                                ),
                                onPressed: () {
                                  Navigator.pop(context, {
                                    'url': release.url,
                                    'index': _indexDefinitions,
                                  });
                                },
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
      ],
    );
  }
}
