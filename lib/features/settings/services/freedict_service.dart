import 'dart:convert';
import 'package:http/http.dart' as http;
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
    // prefer slob, then stardict, then dictd.
    try {
      return releases.firstWhere((r) => r.format == 'slob');
    } catch (_) {}
    try {
      return releases.firstWhere((r) => r.format == 'stardict');
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

  Future<List<FreedictDictionary>> fetchDictionaries() async {
    final response = await http.get(Uri.parse(_databaseUrl));
    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data
          .map((json) => FreedictDictionary.fromJson(json as Map<String, dynamic>))
          .where((d) => d.getPreferredRelease() != null)
          .toList();
    } else {
      throw Exception('Failed to load FreeDict database');
    }
  }
}
