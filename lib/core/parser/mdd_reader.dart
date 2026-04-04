import 'dart:typed_data';
import 'package:hdict/core/parser/random_access_source.dart';
import 'package:hdict/core/mdict_reader/mdict_reader.dart' as dr;

class MddReader {
  final RandomAccessSource source;
  final String _path;
  late dr.DictReader _parser;
  bool _isInitialized = false;

  final Map<String, Uint8List> _resourceCache = {};
  static const int _maxCacheEntries = 100;

  MddReader(this._path, {required this.source}) {
    _parser = dr.DictReader(_path);
  }

  Future<void> open() async {
    if (_isInitialized) return;
    await _parser.initDict(
      readKeys: true,
      readRecordBlockInfo: true,
      readHeader: true,
    );
    _isInitialized = true;
  }

  Future<void> close() async {
    await _parser.close();
    _resourceCache.clear();
    _isInitialized = false;
  }

  Future<List<int>?> getResource(String key) async {
    if (!_isInitialized) await open();

    if (_resourceCache.containsKey(key)) {
      return _resourceCache[key];
    }

    try {
      final offsetInfo = await _parser.locate(key);
      if (offsetInfo == null) return null;

      final data = await _parser.readOneMdd(offsetInfo);
      _cacheResource(key, data);
      return data;
    } catch (e) {
      return null;
    }
  }

  Future<String?> getResourceAsString(String key) async {
    final data = await getResource(key);
    if (data == null) return null;
    return String.fromCharCodes(data);
  }

  Future<Uint8List?> getResourceAsBytes(String key) async {
    final data = await getResource(key);
    if (data == null) return null;
    return Uint8List.fromList(data);
  }

  void _cacheResource(String key, List<int> data) {
    if (_resourceCache.containsKey(key)) return;

    if (_resourceCache.length >= _maxCacheEntries) {
      final firstKey = _resourceCache.keys.first;
      _resourceCache.remove(firstKey);
    }
    _resourceCache[key] = Uint8List.fromList(data);
  }

  Future<String?> detectCssKey() async {
    if (!_isInitialized) await open();

    final cssKeys = [
      'style.css',
      'dictionary.css',
      'main.css',
      'styles.css',
      'mdd_style.css',
      'mdd.css',
    ];

    for (final key in cssKeys) {
      final exists = await _parser.locate(key);
      if (exists != null) return key;
    }

    final allKeys = _parser.search('', limit: 10000);
    for (final key in allKeys) {
      if (key.toLowerCase().endsWith('.css')) {
        return key;
      }
    }

    return null;
  }

  Future<String?> getCssContent() async {
    final cssKey = await detectCssKey();
    if (cssKey == null) return null;
    return getResourceAsString(cssKey);
  }

  bool get isInitialized => _isInitialized;
}
