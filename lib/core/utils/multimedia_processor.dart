import 'dart:convert';
import 'dart:typed_data';
import 'package:hdict/core/parser/mdict_reader.dart';
import 'package:hdict/core/utils/logger.dart';

class MultimediaProcessor {
  final MdictReader? _mddReader;
  final String? _cssContent;

  MultimediaProcessor(this._mddReader, this._cssContent);

  String? get cssContent => _cssContent;

  Future<String> processHtmlWithMedia(String html) async {
    String processed = html;

    if (showMultimediaProcessing) {
      hDebugPrint(
        'MultimediaProcessor: Input HTML (first 500): ${html.substring(0, html.length > 500 ? 500 : html.length)}',
      );
    }

    processed = _convertSoundLinks(processed);

    if (_mddReader != null) {
      processed = await _replaceImgSrcWithDataUris(processed);
      processed = _addMediaTapHandlers(processed);
    }

    if (showMultimediaProcessing) {
      hDebugPrint(
        'MultimediaProcessor: Output HTML (first 500): ${processed.substring(0, processed.length > 500 ? 500 : processed.length)}',
      );
    }

    processed = injectCss(processed);

    return processed;
  }

  String _convertSoundLinks(String html) {
    String processed = html;
    processed = processed.replaceAll('href="sound://', 'href="mdd-audio:');
    processed = processed.replaceAll("href='sound://", "href='mdd-audio:");
    return processed;
  }

  String injectCss(String html) {
    final css = _cssContent;
    if (css == null || css.isEmpty) return html;

    final styleTag = '<style type="text/css">$css</style>';

    if (html.toLowerCase().contains('<html')) {
      final headMatch = RegExp(
        r'<head([^>]*)>',
        caseSensitive: false,
      ).firstMatch(html);
      if (headMatch != null) {
        final headEnd = html.indexOf('>', headMatch.start);
        return '${html.substring(0, headEnd + 1)}$styleTag${html.substring(headEnd + 1)}';
      }
    }

    if (html.toLowerCase().contains('<body')) {
      final bodyMatch = RegExp(
        r'<body([^>]*)>',
        caseSensitive: false,
      ).firstMatch(html);
      if (bodyMatch != null) {
        final bodyEnd = html.indexOf('>', bodyMatch.start);
        return '${html.substring(0, bodyEnd + 1)}$styleTag${html.substring(bodyEnd + 1)}';
      }
    }

    return '$styleTag$html';
  }

  Future<String> _replaceImgSrcWithDataUris(String html) async {
    final imgRegex = RegExp(
      '<img\\s+[^>]*src\\s*=\\s*["\']+([^"\']+)["\']+[^>]*>',
      caseSensitive: false,
    );

    StringBuffer result = StringBuffer();
    int lastEnd = 0;

    for (final match in imgRegex.allMatches(html)) {
      result.write(html.substring(lastEnd, match.start));

      final src = match.group(1);
      if (showMultimediaProcessing) {
        hDebugPrint('MultimediaProcessor: Found img src: $src');
      }
      if (src != null && !src.startsWith('data:') && !src.startsWith('http')) {
        final resourceKey = _extractResourceKey(src);
        if (showMultimediaProcessing) {
          hDebugPrint(
            'MultimediaProcessor: Extracted resource key: $resourceKey',
          );
        }
        if (resourceKey != null) {
          final bytes = await _mddReader!.getMddResourceBytes(resourceKey);
          if (showMultimediaProcessing) {
            hDebugPrint('MultimediaProcessor: Got bytes: ${bytes?.length}');
          }
          if (bytes != null) {
            final mimeType = _getMimeType(resourceKey);
            final base64 = base64Encode(bytes);
            final dataUri = 'data:$mimeType;base64,$base64';
            final imgTag = match.group(0)!;
            final replaced = imgTag.replaceFirst(src, dataUri);
            result.write(replaced);
          } else {
            result.write(match.group(0));
          }
        } else {
          result.write(match.group(0));
        }
      } else {
        result.write(match.group(0));
      }
      lastEnd = match.end;
    }

    result.write(html.substring(lastEnd));
    return result.toString();
  }

  String? _extractResourceKey(String src) {
    if (src.startsWith('resource://')) {
      return src.substring('resource://'.length);
    }
    if (src.startsWith('file://')) {
      final path = src.substring('file://'.length);
      if (!path.contains('/')) return path;
      return path.split('/').last;
    }
    if (src.startsWith('http')) {
      return null;
    }
    if (src.startsWith('sound://')) {
      return src.substring('sound://'.length);
    }
    if (!src.contains('/')) {
      return src;
    }
    return src;
  }

  String _getMimeType(String filename) {
    final ext = filename.split('.').last.toLowerCase();
    switch (ext) {
      case 'png':
        return 'image/png';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'gif':
        return 'image/gif';
      case 'svg':
        return 'image/svg+xml';
      case 'webp':
        return 'image/webp';
      case 'bmp':
        return 'image/bmp';
      case 'ico':
        return 'image/x-icon';
      default:
        return 'application/octet-stream';
    }
  }

  String _getVideoMimeType(String filename) {
    final ext = filename.split('.').last.toLowerCase();
    switch (ext) {
      case 'mp4':
        return 'video/mp4';
      case 'webm':
        return 'video/webm';
      case 'avi':
        return 'video/x-msvideo';
      case 'mov':
        return 'video/quicktime';
      case 'mkv':
        return 'video/x-matroska';
      case 'mpg':
      case 'mpeg':
        return 'video/mpeg';
      default:
        return 'application/octet-stream';
    }
  }

  String _addMediaTapHandlers(String html, {bool inlineVideo = false}) {
    final audioRegex = RegExp(
      '<audio\\s+[^>]*src\\s*=\\s*["\']+([^"\']+)["\']+[^>]*>',
      caseSensitive: false,
    );

    final videoRegex = RegExp(
      '<video\\s+[^>]*src\\s*=\\s*["\']+([^"\']+)["\']+[^>]*>',
      caseSensitive: false,
    );

    String processed = html;

    processed = processed.replaceAllMapped(audioRegex, (match) {
      final src = match.group(1) ?? '';
      if (!src.startsWith('data:') && !src.startsWith('http')) {
        final resourceKey = _extractResourceKey(src);
        if (resourceKey != null) {
          return '<a href="mdd-audio:$resourceKey">🎧 Play Audio</a>';
        }
      }
      return match.group(0) ?? '';
    });

    processed = processed.replaceAllMapped(videoRegex, (match) {
      final src = match.group(1) ?? '';
      if (!src.startsWith('data:') && !src.startsWith('http')) {
        final resourceKey = _extractResourceKey(src);
        if (resourceKey != null) {
          if (inlineVideo) {
            final originalTag = match.group(0) ?? '';
            return originalTag.replaceFirst(src, 'mdd-video:$resourceKey');
          }
          return '<a href="mdd-video:$resourceKey">🎬 Play Video</a>';
        }
      }
      return match.group(0) ?? '';
    });

    processed = processed.replaceAll('href="sound://', 'href="mdd-audio:');
    processed = processed.replaceAll("href='sound://", "href='mdd-audio:");

    return processed;
  }

  Future<String> processHtmlWithInlineVideo(String html) async {
    String processed = html;

    if (showMultimediaProcessing) {
      hDebugPrint('MultimediaProcessor: Processing HTML with inline video');
    }

    processed = _convertSoundLinks(processed);

    if (_mddReader != null) {
      processed = await _replaceImgSrcWithDataUris(processed);
    }
    processed = _addMediaTapHandlers(processed, inlineVideo: true);

    processed = injectCss(processed);

    return processed;
  }

  Future<Uint8List?> getAudioResource(String key) async {
    if (_mddReader == null) return null;
    return _mddReader.getMddResourceBytes(key);
  }

  Future<Uint8List?> getVideoResource(String key) async {
    if (_mddReader == null) return null;
    return _mddReader.getMddResourceBytes(key);
  }
}
