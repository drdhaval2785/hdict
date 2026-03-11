import 'package:flutter/material.dart';
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
      if (mounted) {
        setState(() {
          _allDictionaries = cachedDicts;
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
      if (mounted) {
        setState(() {
          _allDictionaries = dicts;
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
    sources.sort();
    return sources;
  }

  List<String> get _targetLanguages {
    if (_selectedSourceLanguage == null) return [];
    final targets = _allDictionaries
        .where((d) => d.sourceLanguageCode == _selectedSourceLanguage)
        .map((d) => d.targetLanguageCode)
        .toSet()
        .toList();
    targets.sort();
    return targets;
  }

  List<StardictDictionary> get _filteredDictionaries {
    if (_selectedSourceLanguage == null || _selectedTargetLanguage == null) {
      return [];
    }
    return _allDictionaries
        .where(
          (d) =>
              d.sourceLanguageCode == _selectedSourceLanguage &&
              d.targetLanguageCode == _selectedTargetLanguage,
        )
        .toList();
  }

  String _getLanguageName(String code) {
    if (_allDictionaries.isEmpty) return code;
    return _allDictionaries
                .firstWhere(
                  (d) =>
                      d.sourceLanguageCode == code ||
                      d.targetLanguageCode == code,
                  orElse: () => _allDictionaries.first,
                )
                .sourceLanguageCode ==
            code
        ? _allDictionaries
              .firstWhere((d) => d.sourceLanguageCode == code)
              .sourceLanguageName
        : _allDictionaries
              .firstWhere((d) => d.targetLanguageCode == code)
              .targetLanguageName;
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
        DropdownButtonFormField<String>(
          decoration: const InputDecoration(
            labelText: 'Source Language',
            border: OutlineInputBorder(),
          ),
          initialValue: _selectedSourceLanguage,
          isExpanded: true,
          items: _sourceLanguages.map((code) {
            final name = _getLanguageName(code);
            return DropdownMenuItem(value: code, child: Text('$name ($code)'));
          }).toList(),
          onChanged: (val) {
            setState(() {
              _selectedSourceLanguage = val;
              _selectedTargetLanguage = null;
            });
          },
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          decoration: const InputDecoration(
            labelText: 'Target Language',
            border: OutlineInputBorder(),
          ),
          initialValue: _selectedTargetLanguage,
          isExpanded: true,
          items: _targetLanguages.map((code) {
            final name = _getLanguageName(code);
            return DropdownMenuItem(value: code, child: Text('$name ($code)'));
          }).toList(),
          onChanged: _selectedSourceLanguage == null
              ? null
              : (val) {
                  setState(() {
                    _selectedTargetLanguage = val;
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

                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    title: Text(dict.name),
                    subtitle: Text(
                      'Version: ${dict.version.isEmpty ? "N/A" : dict.version} • Headwords: ${dict.headwords.isEmpty ? "N/A" : dict.headwords}',
                    ),
                    trailing: FilledButton.icon(
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
