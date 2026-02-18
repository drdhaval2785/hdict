import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsProvider with ChangeNotifier {
  static const String _keyFontFamily = 'font_family';
  static const String _keyFontSize = 'font_size';
  static const String _keyBgColor = 'bg_color';
  static const String _keyFontColor = 'font_color';
  static const String _keyTextColor = 'text_color';
  static const String _keyPreviewLines = 'preview_lines';
  static const String _keyFuzzySearch = 'fuzzy_search';
  static const String _keyTapMeaning = 'tap_meaning';
  static const String _keyOpenPopup = 'open_popup';
  static const String _keyHistoryDays = 'history_days';

  String _fontFamily = 'Roboto';
  double _fontSize = 16.0;
  Color _backgroundColor = Colors.white;
  Color _fontColor = Colors.black;
  Color _textColor = Colors.black87;
  int _previewLines = 3;
  bool _isFuzzySearchEnabled = false;
  bool _isTapOnMeaningEnabled = true;
  bool _isOpenPopupOnTap = true;
  int _historyRetentionDays = 30;

  String get fontFamily => _fontFamily;
  double get fontSize => _fontSize;
  Color get backgroundColor => _backgroundColor;
  Color get fontColor => _fontColor;
  Color get textColor => _textColor;
  int get previewLines => _previewLines;
  bool get isFuzzySearchEnabled => _isFuzzySearchEnabled;
  bool get isTapOnMeaningEnabled => _isTapOnMeaningEnabled;
  bool get isOpenPopupOnTap => _isOpenPopupOnTap;
  int get historyRetentionDays => _historyRetentionDays;

  SettingsProvider() {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _fontFamily = prefs.getString(_keyFontFamily) ?? 'Roboto';
    _fontSize = prefs.getDouble(_keyFontSize) ?? 16.0;
    _backgroundColor = Color(prefs.getInt(_keyBgColor) ?? Colors.white.value);
    _fontColor = Color(prefs.getInt(_keyFontColor) ?? Colors.black.value);
    _textColor = Color(prefs.getInt(_keyTextColor) ?? Colors.black87.value);
    _previewLines = prefs.getInt(_keyPreviewLines) ?? 3;
    _isFuzzySearchEnabled = prefs.getBool(_keyFuzzySearch) ?? false;
    _isTapOnMeaningEnabled = prefs.getBool(_keyTapMeaning) ?? true;
    _isOpenPopupOnTap = prefs.getBool(_keyOpenPopup) ?? true;
    _historyRetentionDays = prefs.getInt(_keyHistoryDays) ?? 30;
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
    await prefs.setInt(_keyBgColor, color.value);
    notifyListeners();
  }

  Future<void> setFontColor(Color color) async {
    _fontColor = color;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyFontColor, color.value);
    notifyListeners();
  }

  Future<void> setTextColor(Color color) async {
    _textColor = color;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyTextColor, color.value);
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
}
