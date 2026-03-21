import 'dart:io';
import 'package:archive/archive.dart';
import 'package:archive/archive_io.dart';
import 'package:flutter_7zip/flutter_7zip.dart';
import 'package:path/path.dart' as p;
import 'package:hdict/core/utils/logger.dart';

/// A validated, importable dictionary found during folder scanning.
class DiscoveredDict {
  /// Path to the primary anchor file (e.g. `.ifo`, `.mdx`, `.slob`, `.index`).
  final String path;

  /// Format identifier: `'stardict'`, `'mdict'`, `'slob'`, or `'dictd'`.
  final String format;

  /// For DICTD: path to the companion `.dict` / `.dict.dz` file.
  final String? companionPath;

  /// The name of the immediate parent folder.
  final String? parentFolderName;

  /// Holds mapped URIs for all constituent files when using Android SAF.
  final Map<String, String>? safUris;

  const DiscoveredDict({
    required this.path,
    required this.format,
    this.companionPath,
    this.parentFolderName,
    this.safUris,
  });

  Map<String, String?> toMap() => {
    'path': path,
    'format': format,
    'companionPath': companionPath,
    'parentFolderName': parentFolderName,
  };
}

/// A dictionary entry whose mandatory files are missing.
class IncompleteDict {
  /// Stem name (without extension) used as the display name.
  final String name;

  /// Format identifier.
  final String format;

  /// Human-readable list of missing mandatory files, e.g. `['.idx', '.dict']`.
  final List<String> missingFiles;

  /// The name of the immediate parent folder.
  final String? parentFolderName;

  const IncompleteDict({
    required this.name,
    required this.format,
    required this.missingFiles,
    this.parentFolderName,
  });
}

/// Result returned by [scanFolderForDictionaries].
class FolderScanResult {
  /// Dictionaries that have all mandatory files and can be imported.
  final List<DiscoveredDict> discovered;

  /// Dictionaries detected (by their anchor file) but missing mandatory files.
  final List<IncompleteDict> incomplete;

  const FolderScanResult({
    required this.discovered,
    required this.incomplete,
  });
}

// ---------------------------------------------------------------------------
// Archive extensions that should be extracted during a folder scan.
// ---------------------------------------------------------------------------
bool _isArchive(String lowerPath) =>
    lowerPath.endsWith('.zip') ||
    lowerPath.endsWith('.tar.gz') ||
    lowerPath.endsWith('.tgz') ||
    lowerPath.endsWith('.tar') ||
    lowerPath.endsWith('.tar.bz2') ||
    lowerPath.endsWith('.tbz2') ||
    lowerPath.endsWith('.tar.xz') ||
    lowerPath.endsWith('.txz') ||
    lowerPath.endsWith('.7z');

/// Extracts an archive [filePath] into [destDir] in-process.
///
/// Supports: `.zip`, `.tar.gz`, `.tgz`, `.tar`, `.tar.bz2`, `.tbz2`,
/// `.tar.xz`, `.txz`, `.7z`.
Future<void> _extractArchiveToDir(String filePath, String destDir) async {
  final lowerPath = filePath.toLowerCase();
  try {
    if (lowerPath.endsWith('.7z')) {
      SZArchive.extract(filePath, destDir);
      return;
    }

    final bytes = await File(filePath).readAsBytes();
    Archive archive;

    if (lowerPath.endsWith('.zip')) {
      archive = ZipDecoder().decodeBytes(bytes);
    } else if (lowerPath.endsWith('.tar.gz') || lowerPath.endsWith('.tgz')) {
      archive = TarDecoder().decodeBytes(GZipDecoder().decodeBytes(bytes));
    } else if (lowerPath.endsWith('.tar.bz2') ||
        lowerPath.endsWith('.tbz2')) {
      archive = TarDecoder().decodeBytes(BZip2Decoder().decodeBytes(bytes));
    } else if (lowerPath.endsWith('.tar.xz') ||
        lowerPath.endsWith('.txz')) {
      try {
        archive = TarDecoder().decodeBytes(XZDecoder().decodeBytes(bytes));
      } catch (_) {
        if (Platform.isMacOS || Platform.isLinux) {
          Process.runSync('tar', ['-xf', filePath, '-C', destDir]);
        }
        return;
      }
    } else {
      // plain .tar
      archive = TarDecoder().decodeBytes(bytes);
    }

    for (final entry in archive) {
      final entryPath = p.join(destDir, entry.name);
      if (entry.isFile) {
        File(entryPath)
          ..createSync(recursive: true)
          ..writeAsBytesSync(entry.content as List<int>);
      } else {
        Directory(entryPath).createSync(recursive: true);
      }
    }
  } catch (e) {
    hDebugPrint('FolderScanner: failed to extract $filePath: $e');
  }
}

// ---------------------------------------------------------------------------
// StarDict companion-file helpers
// ---------------------------------------------------------------------------
String? _findFile(String base, List<String> suffixes) {
  for (final s in suffixes) {
    final candidate = '$base$s';
    if (File(candidate).existsSync()) return candidate;
  }
  return null;
}

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

/// Recursively scans [directoryPath] for supported dictionary formats.
///
/// Archives found directly inside the directory (at any depth) are extracted
/// into a temporary sub-directory so their contents are also scanned.
///
/// Returns a [FolderScanResult] with:
/// - [FolderScanResult.discovered] — dictionaries that pass mandatory-file
///   validation and can be imported immediately.
/// - [FolderScanResult.incomplete] — dictionaries whose anchor file was found
///   but one or more mandatory sibling files are missing.
Future<FolderScanResult> scanFolderForDictionaries(
  String directoryPath, {
  /// If `true`, archives found in the folder are extracted into a temporary
  /// sub-directory before scanning.  Set to `false` in unit tests that want
  /// to test plain-file detection only.
  bool extractArchives = true,
}) async {
  final dir = Directory(directoryPath);
  if (!await dir.exists()) {
    return const FolderScanResult(discovered: [], incomplete: []);
  }

  // --- Step 1: extract any archives found inside the folder ----------------
  if (extractArchives) {
    final allEntities = await dir.list(recursive: true).toList();
    for (final entity in allEntities) {
      if (entity is! File) continue;
      if (_isArchive(entity.path.toLowerCase())) {
        // Extract into a sibling directory named after the archive
        final stem = p.basenameWithoutExtension(
          p.basenameWithoutExtension(entity.path), // strip two extensions
        );
        final extractDir = Directory(
          p.join(p.dirname(entity.path), '${stem}_extracted'),
        );
        await extractDir.create(recursive: true);
        await _extractArchiveToDir(entity.path, extractDir.path);
      }
    }
  }

  // --- Step 2: scan every file recursively ---------------------------------
  final discovered = <DiscoveredDict>[];
  final incomplete = <IncompleteDict>[];

  final entities = await dir.list(recursive: true).toList();
  for (final entity in entities) {
    if (entity is! File) continue;

    final path = entity.path;
    final lowerPath = path.toLowerCase();
    final parentName = p.basename(p.dirname(path));
    // If it's a temp extraction dir, we might want the parent of that, 
    // but the requirement "name of the folder which is the last" usually means the immediate parent.
    // If the folder is "English-French/Dict1.ifo", group is "English-French".

    // -- StarDict: anchor = .ifo --------------------------------------------
    if (lowerPath.endsWith('.ifo') ||
        lowerPath.endsWith('.ifo.gz') ||
        lowerPath.endsWith('.ifo.dz') ||
        lowerPath.endsWith('.ifo.bz2') ||
        lowerPath.endsWith('.ifo.xz')) {
      // Remove all compression extensions to get the real base stem
      String basePath = path;
      for (final ext in ['.ifo.gz', '.ifo.dz', '.ifo.bz2', '.ifo.xz']) {
        if (lowerPath.endsWith(ext)) {
          basePath = path.substring(0, path.length - ext.length);
          break;
        }
      }
      if (lowerPath.endsWith('.ifo')) {
        basePath = p.withoutExtension(path);
      }

      final idxPath = _findFile(basePath, [
        '.idx', '.idx.gz', '.idx.dz', '.idx.bz2', '.idx.xz',
      ]);
      final dictFile = _findFile(basePath, [
        '.dict', '.dict.dz', '.dict.gz', '.dict.bz2', '.dict.xz',
      ]);

      final missing = <String>[];
      if (idxPath == null) missing.add('.idx');
      if (dictFile == null) missing.add('.dict / .dict.dz');

      if (missing.isEmpty) {
        discovered.add(DiscoveredDict(
          path: path,
          format: 'stardict',
          parentFolderName: parentName,
        ));
      } else {
        incomplete.add(IncompleteDict(
          name: p.basenameWithoutExtension(basePath),
          format: 'stardict',
          missingFiles: missing,
          parentFolderName: parentName,
        ));
      }
    }

    // -- MDict: anchor = .mdx -----------------------------------------------
    else if (lowerPath.endsWith('.mdx')) {
      discovered.add(DiscoveredDict(
        path: path,
        format: 'mdict',
        parentFolderName: parentName,
      ));
    }

    // -- Slob: anchor = .slob -----------------------------------------------
    else if (lowerPath.endsWith('.slob')) {
      discovered.add(DiscoveredDict(
        path: path,
        format: 'slob',
        parentFolderName: parentName,
      ));
    }

    // -- DICTD: anchor = .index ---------------------------------------------
    else if (lowerPath.endsWith('.index')) {
      final basePath = p.withoutExtension(path);
      final dictFile = _findFile(basePath, ['.dict.dz', '.dict']);

      if (dictFile != null) {
        discovered.add(DiscoveredDict(
          path: path,
          format: 'dictd',
          companionPath: dictFile,
          parentFolderName: parentName,
        ));
      } else {
        incomplete.add(IncompleteDict(
          name: p.basenameWithoutExtension(basePath),
          format: 'dictd',
          missingFiles: ['.dict / .dict.dz'],
          parentFolderName: parentName,
        ));
      }
    }
  }

  return FolderScanResult(discovered: discovered, incomplete: incomplete);
}
