import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:hdict/core/database/database_helper.dart';
import 'package:hdict/core/constants/iso_639_2_languages.dart';
import 'package:hdict/core/utils/logger.dart';

class StardictRelease {
  final String url;
  final String format;
  final String size;
  final String version;
  final String date;

  StardictRelease({
    required this.url,
    required this.format,
    required this.size,
    required this.version,
    required this.date,
  });

  factory StardictRelease.fromTsv(Map<String, dynamic> row) {
    return StardictRelease(
      url: (row['Link'] ?? '').toString(),
      format: 'stardict',
      size: (row['Size'] ?? '').toString(),
      version: (row['Version'] ?? '').toString(),
      date: (row['Date'] ?? '').toString(),
    );
  }
}

class StardictDictionary {
  final String sourceLanguageCode;
  final String targetLanguageCode;
  final String name;
  final String url;
  final String headwords;
  final String version;
  final String date;
  final List<StardictRelease> releases;

  StardictDictionary({
    required this.sourceLanguageCode,
    required this.targetLanguageCode,
    required this.name,
    required this.url,
    required this.headwords,
    required this.version,
    required this.date,
    required this.releases,
  });

  String get sourceLanguageName =>
      iso639_2Languages[sourceLanguageCode] ?? sourceLanguageCode;

  String get targetLanguageName =>
      iso639_2Languages[targetLanguageCode] ?? targetLanguageCode;

  factory StardictDictionary.fromTsvRow(List<String> values) {
    final sourceCode = values[0].trim();
    final targetCode = values[1].trim();
    final name = values[2].trim();
    final url = values[3].trim();
    final headwords = values[4].trim();
    final version = values[5].trim();
    final date = values[6].trim();

    final release = StardictRelease(
      url: url,
      format: 'stardict',
      size: '',
      version: version,
      date: date,
    );

    return StardictDictionary(
      sourceLanguageCode: sourceCode,
      targetLanguageCode: targetCode,
      name: name,
      url: url,
      headwords: headwords,
      version: version,
      date: date,
      releases: [release],
    );
  }

  factory StardictDictionary.fromDbRow(Map<String, dynamic> row) {
    final releasesJson = row['releases_json'] as String? ?? '[]';
    final releasesList = json.decode(releasesJson) as List<dynamic>;
    final releases = releasesList
        .map(
          (r) => StardictRelease(
            url: r['Link'] ?? '',
            format: r['format'] ?? 'stardict',
            size: r['size'] ?? '',
            version: r['Version'] ?? '',
            date: r['date'] ?? '',
          ),
        )
        .toList();

    return StardictDictionary(
      sourceLanguageCode: row['source_lang'] as String? ?? '',
      targetLanguageCode: row['target_lang'] as String? ?? '',
      name: row['name'] as String? ?? '',
      url: row['url'] as String? ?? '',
      headwords: row['headwords'] as String? ?? '0',
      version: row['version'] as String? ?? '',
      date: row['date'] as String? ?? '',
      releases: releases,
    );
  }

  Map<String, dynamic> toDbRow() {
    return {
      'name': name,
      'source_lang': sourceLanguageCode,
      'target_lang': targetLanguageCode,
      'url': url,
      'headwords': headwords,
      'version': version,
      'date': date,
      'releases_json': json.encode(
        releases
            .map(
              (r) => {
                'Link': r.url,
                'format': r.format,
                'size': r.size,
                'Version': r.version,
                'date': r.date,
              },
            )
            .toList(),
      ),
    };
  }

  StardictRelease? getPreferredRelease() {
    if (releases.isEmpty) return null;
    return releases.first;
  }
}

class StardictService {
  static const String _tsvUrl =
      'https://raw.githubusercontent.com/drdhaval2785/Stardict-lists/main/stardict_dictionaries.tsv';
  final DatabaseHelper _dbHelper = DatabaseHelper();

  Future<List<StardictDictionary>> fetchDictionaries() async {
    final cachedData = await _dbHelper.getFreedictDictionaries();
    if (cachedData.isNotEmpty) {
      final firstRow = cachedData.first;
      final hasUrl = firstRow.containsKey('url') && firstRow['url'] != null;
      final hasVersion =
          firstRow.containsKey('version') && firstRow['version'] != null;
      final hasDate = firstRow.containsKey('date') && firstRow['date'] != null;
      if (!hasUrl || !hasVersion || !hasDate) {
        await _dbHelper.clearFreedictDictionaries();
        return [];
      }
      return cachedData
          .map((row) => StardictDictionary.fromDbRow(row))
          .toList();
    }
    return [];
  }

  Future<List<StardictDictionary>> refreshDictionaries() async {
    final response = await http
        .get(Uri.parse(_tsvUrl))
        .timeout(const Duration(seconds: 30));
    if (response.statusCode == 200) {
      final List<StardictDictionary> dicts = [];
      final lines = response.body.split('\n');

      for (int i = 1; i < lines.length; i++) {
        final line = lines[i].trim();
        if (line.isEmpty) continue;

        final values = line.split('\t');
        if (values.length >= 7) {
          try {
            final dict = StardictDictionary.fromTsvRow(values);
            if (dict.url.isNotEmpty) {
              dicts.add(dict);
            }
          } catch (e) {
            continue;
          }
        }
      }

      final List<Map<String, dynamic>> dbRows = dicts
          .map((d) => d.toDbRow())
          .toList();

      await _dbHelper.insertFreedictDictionaries(dbRows);
      return dicts;
    } else {
      throw Exception(
        'Failed to refresh Stardict database (HTTP ${response.statusCode})',
      );
    }
  }

  Future<Set<String>> getDownloadedUrls() async {
    try {
      final db = await _dbHelper.database;
      final result = await db.query(
        'dictionaries',
        columns: ['source_url'],
        where: 'source_url IS NOT NULL AND source_url != ""',
      );
      return result
          .map((row) => row['source_url'] as String)
          .where((url) => url.isNotEmpty)
          .toSet();
    } catch (e) {
      hDebugPrint('Error getting downloaded URLs: $e');
      return {};
    }
  }
}
