import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum SearchMode {
  prefix('Prefix'),
  suffix('Suffix'),
  substring('Substring'),
  exact('Exact');

  final String label;
  const SearchMode(this.label);

  static SearchMode fromString(String value) {
    return SearchMode.values.firstWhere(
      (e) => e.name == value,
      orElse: () => SearchMode.prefix,
    );
  }
}

class SettingsProvider with ChangeNotifier {
  static const String _keyFontFamily = 'font_family';
  static const String _keyFontSize = 'font_size';
  static const String _keyBgColor = 'bg_color';
  static const String _keyTextColor = 'text_color';
  static const String _keyPreviewLines = 'preview_lines';
  static const String _keyFuzzySearch = 'fuzzy_search';
  static const String _keyTapMeaning = 'tap_meaning';
  static const String _keyOpenPopup = 'open_popup';
  static const String _keyHistoryDays = 'history_days';
  static const String _keySearchInHeadwords = 'search_in_headwords';
  static const String _keySearchInDefinitions = 'search_in_definitions';
  static const String _keyHeadwordSearchMode = 'headword_search_mode';
  static const String _keyDefinitionSearchMode = 'definition_search_mode';
  static const String _keyHeadwordColor = 'headword_color';
  static const String _keySearchResultLimit = 'search_result_limit';
  static const String _keyFlashCardWordCount = 'flash_card_word_count';

  String _fontFamily = 'Roboto';
  double _fontSize = 16.0;
  Color _backgroundColor = Colors.white;
  Color _textColor = Colors.black87;
  int _previewLines = 3;
  bool _isFuzzySearchEnabled = false;
  bool _isTapOnMeaningEnabled = true;
  bool _isOpenPopupOnTap = true;
  int _historyRetentionDays = 30;
  bool _isSearchInHeadwordsEnabled = true;
  bool _isSearchInDefinitionsEnabled = true;
  SearchMode _headwordSearchMode = SearchMode.prefix;
  SearchMode _definitionSearchMode = SearchMode.prefix;
  Color _headwordColor = Colors.brown;
  int _searchResultLimit = 50;
  int _flashCardWordCount = 10;

  String get fontFamily => _fontFamily;
  double get fontSize => _fontSize;
  Color get backgroundColor => _backgroundColor;
  Color get textColor => _textColor;
  int get previewLines => _previewLines;
  bool get isFuzzySearchEnabled => _isFuzzySearchEnabled;
  bool get isTapOnMeaningEnabled => _isTapOnMeaningEnabled;
  bool get isOpenPopupOnTap => _isOpenPopupOnTap;
  int get historyRetentionDays => _historyRetentionDays;
  bool get isSearchInHeadwordsEnabled => _isSearchInHeadwordsEnabled;
  bool get isSearchInDefinitionsEnabled => _isSearchInDefinitionsEnabled;
  SearchMode get headwordSearchMode => _headwordSearchMode;
  SearchMode get definitionSearchMode => _definitionSearchMode;
  Color get headwordColor => _headwordColor;
  int get searchResultLimit => _searchResultLimit;
  int get flashCardWordCount => _flashCardWordCount;

  SettingsProvider() {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _fontFamily = prefs.getString(_keyFontFamily) ?? 'Roboto';
    _fontSize = prefs.getDouble(_keyFontSize) ?? 16.0;
    _backgroundColor = Color(prefs.getInt(_keyBgColor) ?? Colors.white.toARGB32());
    _textColor = Color(prefs.getInt(_keyTextColor) ?? Colors.black87.toARGB32());
    _previewLines = prefs.getInt(_keyPreviewLines) ?? 3;
    _isFuzzySearchEnabled = prefs.getBool(_keyFuzzySearch) ?? false;
    _isTapOnMeaningEnabled = prefs.getBool(_keyTapMeaning) ?? true;
    _isOpenPopupOnTap = prefs.getBool(_keyOpenPopup) ?? true;
    _historyRetentionDays = prefs.getInt(_keyHistoryDays) ?? 30;
    _isSearchInHeadwordsEnabled = prefs.getBool(_keySearchInHeadwords) ?? true;
    _isSearchInDefinitionsEnabled =
        prefs.getBool(_keySearchInDefinitions) ?? true;
    _headwordSearchMode = SearchMode.fromString(
        prefs.getString(_keyHeadwordSearchMode) ?? 'prefix');
    _definitionSearchMode = SearchMode.fromString(
        prefs.getString(_keyDefinitionSearchMode) ?? 'prefix');
    _headwordColor =
        Color(prefs.getInt(_keyHeadwordColor) ?? Colors.brown.toARGB32());
    _searchResultLimit = prefs.getInt(_keySearchResultLimit) ?? 50;
    _flashCardWordCount = prefs.getInt(_keyFlashCardWordCount) ?? 10;
    notifyListeners();
  }

  Future<void> setFontFamily(String family) async {
    _fontFamily = family;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyFontFamily, family);
    notifyListeners();
  }

  Future<void> setFontSize(double size) async {
    _fontSize = size;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyFontSize, size);
    notifyListeners();
  }

  Future<void> setBackgroundColor(Color color) async {
    _backgroundColor = color;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyBgColor, color.toARGB32());
    notifyListeners();
  }

  Future<void> setTextColor(Color color) async {
    _textColor = color;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyTextColor, color.toARGB32());
    notifyListeners();
  }

  Future<void> setPreviewLines(int lines) async {
    _previewLines = lines;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyPreviewLines, lines);
    notifyListeners();
  }

  Future<void> setFuzzySearch(bool enabled) async {
    _isFuzzySearchEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyFuzzySearch, enabled);
    notifyListeners();
  }

  Future<void> setTapOnMeaning(bool enabled) async {
    _isTapOnMeaningEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyTapMeaning, enabled);
    notifyListeners();
  }

  Future<void> setOpenPopup(bool enabled) async {
    _isOpenPopupOnTap = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyOpenPopup, enabled);
    notifyListeners();
  }

  Future<void> setHistoryRetentionDays(int days) async {
    _historyRetentionDays = days;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyHistoryDays, days);
    notifyListeners();
  }

  Future<void> searchInHeadwords(bool enabled) async {
    _isSearchInHeadwordsEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keySearchInHeadwords, enabled);
    notifyListeners();
  }

  Future<void> searchInDefinitions(bool enabled) async {
    _isSearchInDefinitionsEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keySearchInDefinitions, enabled);
    notifyListeners();
  }

  Future<void> setHeadwordSearchMode(SearchMode mode) async {
    _headwordSearchMode = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyHeadwordSearchMode, mode.name);
    notifyListeners();
  }

  Future<void> setDefinitionSearchMode(SearchMode mode) async {
    _definitionSearchMode = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyDefinitionSearchMode, mode.name);
    notifyListeners();
  }

  Future<void> setHeadwordColor(Color color) async {
    _headwordColor = color;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyHeadwordColor, color.toARGB32());
    notifyListeners();
  }

  Future<void> setSearchResultLimit(int limit) async {
    _searchResultLimit = limit;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keySearchResultLimit, limit);
    notifyListeners();
  }

  Future<void> setFlashCardWordCount(int count) async {
    _flashCardWordCount = count;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyFlashCardWordCount, count);
    notifyListeners();
  }
}
