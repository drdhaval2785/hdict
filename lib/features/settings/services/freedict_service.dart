import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:hdict/core/database/database_helper.dart';
import 'package:hdict/core/constants/iso_639_2_languages.dart';

class FreedictRelease {
  final String url;
  final String format;
  final String size;
  final String version;

  FreedictRelease({
    required this.url,
    required this.format,
    required this.size,
    required this.version,
  });

  factory FreedictRelease.fromJson(Map<String, dynamic> json) {
    return FreedictRelease(
      url: (json['URL'] ?? '').toString(),
      format: (json['platform'] ?? '').toString(),
      size: (json['size'] ?? '').toString(),
      version: (json['version'] ?? '').toString(),
    );
  }
}

class FreedictDictionary {
  final String name;
  final String sourceLanguageCode;
  final String targetLanguageCode;
  final List<FreedictRelease> releases;
  final String headwords;

  FreedictDictionary({
    required this.name,
    required this.sourceLanguageCode,
    required this.targetLanguageCode,
    required this.releases,
    required this.headwords,
  });

  String get sourceLanguageName =>
      iso639_2Languages[sourceLanguageCode] ?? sourceLanguageCode;

  String get targetLanguageName =>
      iso639_2Languages[targetLanguageCode] ?? targetLanguageCode;

  factory FreedictDictionary.fromJson(Map<String, dynamic> json) {
    final name = (json['name'] ?? '').toString();
    final parts = name.split('-');
    final sourceCode = parts.isNotEmpty ? parts[0] : '';
    final targetCode = parts.length > 1 ? parts[1] : '';

    final releasesJson = json['releases'] as List<dynamic>? ?? [];
    final releases = releasesJson
        .map((r) => FreedictRelease.fromJson(r as Map<String, dynamic>))
        .toList();

    return FreedictDictionary(
      name: name,
      sourceLanguageCode: sourceCode,
      targetLanguageCode: targetCode,
      releases: releases,
      headwords: (json['headwords'] ?? '0').toString(),
    );
  }
  
  FreedictRelease? getPreferredRelease() {
    // prefer stardict, then slob, then dictd.
    try {
      return releases.firstWhere((r) => r.format == 'stardict');
    } catch (_) {}
    try {
      return releases.firstWhere((r) => r.format == 'slob');
    } catch (_) {}
    try {
      return releases.firstWhere((r) => r.format == 'dictd');
    } catch (_) {}
    return null;
  }
}

class FreedictService {
  static const String _databaseUrl =
      'https://freedict.org/freedict-database.json';
  final DatabaseHelper _dbHelper = DatabaseHelper();

  Future<List<FreedictDictionary>> fetchDictionaries() async {
    // 1. Try to load from database cache
    final cachedData = await _dbHelper.getFreedictDictionaries();
    if (cachedData.isNotEmpty) {
      return cachedData.map((row) {
        return FreedictDictionary(
          name: row['name'] as String,
          sourceLanguageCode: row['source_lang'] as String,
          targetLanguageCode: row['target_lang'] as String,
          headwords: row['headwords'] as String? ?? '0',
          releases: (json.decode(row['releases_json'] as String) as List)
              .map((r) => FreedictRelease.fromJson(r as Map<String, dynamic>))
              .toList(),
        );
      }).toList();
    }

    // 2. If no cache, return empty list (UI will handle loading/refresh)
    return [];
  }

  Future<List<FreedictDictionary>> refreshDictionaries() async {
    final response = await http.get(Uri.parse(_databaseUrl)).timeout(const Duration(seconds: 15));
    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      final List<FreedictDictionary> dicts = data
          .map((json) => FreedictDictionary.fromJson(json as Map<String, dynamic>))
          .where((d) => d.getPreferredRelease() != null)
          .toList();

      // Save to database
      final List<Map<String, dynamic>> dbRows = dicts.map((d) => {
        'name': d.name,
        'source_lang': d.sourceLanguageCode,
        'target_lang': d.targetLanguageCode,
        'headwords': d.headwords,
        'releases_json': json.encode(d.releases.map((r) => {
          'URL': r.url,
          'platform': r.format,
          'size': r.size,
          'version': r.version,
        }).toList()),
      }).toList();

      await _dbHelper.insertFreedictDictionaries(dbRows);
      return dicts;
    } else {
      throw Exception('Failed to refresh FreeDict database (HTTP ${response.statusCode})');
    }
  }
}
