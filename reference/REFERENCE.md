# API Reference (version 1.5.12)

This document lists all classes, functions, and methods in the HDict codebase. Each entry includes the file location, description, parameters, return types, and usage examples where applicable.

For each class, public members are listed first followed by private members.

---

## Table of Contents

### Core Services
1. [`lib/core/utils/word_boundary.dart`](#libcoreutilsword_boundary-dart)
2. [`lib/core/utils/html_lookup_wrapper.dart`](#libcoreutilshtml_lookup_wrapper-dart)
3. [`lib/core/utils/multimedia_processor.dart`](#libcoreutilsmultimedia_processor-dart)
4. [`lib/core/utils/logger.dart`](#libcoreutilslogger-dart)
5. [`lib/core/utils/anchor_id_extension.dart`](#libcoreutilsanchor_id_extension-dart)
6. [`lib/core/utils/folder_scanner.dart`](#libcoreutilsfolder_scanner-dart)
7. [`lib/core/utils/debouncer.dart`](#libcoreutilsdebouncer-dart)

### Dictionary Readers
1. [`lib/core/parser/dict_reader.dart`](#libcoreparserdict_reader-dart)
2. [`lib/core/parser/mdict_reader.dart`](#libcoreparsermdict_reader-dart)
3. [`lib/core/parser/mdd_reader.dart`](#libcoreparsermdd_reader-dart)
4. [`lib/core/parser/slob_reader.dart`](#libcoreparserslob_reader-dart)
5. [`lib/core/parser/dictd_reader.dart`](#libcoreparsersdictd_reader-dart)
6. [`lib/core/parser/ifo_parser.dart`](#libcoreparserifo_parser-dart)
7. [`lib/core/parser/idx_parser.dart`](#libcoreparseridx_parser-dart)
8. [`lib/core/parser/syn_parser.dart`](#libcoreparsersyn_parser-dart)

### Database
1. [`lib/core/database/database_helper.dart`](#libcoredatabasedatabase_helper-dart)

### Managers
1. [`lib/core/manager/dictionary_manager.dart`](#libcoremanagerdictionary_manager-dart)
2. [`lib/core/manager/dictionary_group_manager.dart`](#libcoremanagerdictionary_group_manager-dart)

### Models
1. [`lib/core/models/stardict_dictionary.dart`](#libcoremodelsstardict_dictionary-dart)
2. [`lib/core/models/stardict_release.dart`](#libcoremodelsstardict_release-dart)
3. [`lib/core/models/discovered_dict.dart`](#libcoremodelsdiscovered_dict-dart)
4. [`lib/core/models/incomplete_dict.dart`](#libcoremodelsincomplete_dict-dart)
5. [`lib/core/models/dictionary_group.dart`](#libcoremodelsdictionary_group-dart)
6. [`lib/core/models/deletion_progress.dart`](#libcoremodelsdeletion_progress-dart)
7. [`lib/core/models/import_progress.dart`](#libcoremodelsimport_progress-dart)
8. [`lib/core/models/folder_scan_result.dart`](#libcoremodelsfolder_scan_result-dart)

### Providers
1. [`lib/features/settings/settings_provider.dart`](#libfeaturessettingssettings_provider-dart)
2. [`lib/core/benchmark.dart`](#libcorebenchmark-dart)
3. [`lib/core/hperf.dart`](#libcorehperf-dart)

### Services
1. [`lib/features/settings/services/stardict_service.dart`](#libfeaturessettingsservicesstardict_service-dart)

### Main App
1. [`lib/main.dart`](#libmain-dart)
2. [`lib/core/theme/app_theme.dart`](#libcorethemeapp_theme-dart)

### Screens
1. [`lib/features/home/home_screen.dart`](#libfeatureshomehome_screen-dart)
2. [`lib/features/settings/settings_screen.dart`](#libfeaturessettingssettings_screen-dart)
3. [`lib/features/bookmarks/bookmarks_screen.dart`](#libfeaturesbookmarksbookmarks_screen-dart)
4. [`lib/features/flash_cards/flash_cards_screen.dart`](#libfeaturesflash_cardsflash_cards_screen-dart)
5. [`lib/features/dictionary_management/dictionary_management_screen.dart`](#libfeaturesdictionary_managementdictionary_management_screen-dart)
6. [`lib/features/dictionary_groups/dictionary_groups_screen.dart`](#libfeaturesdictionary_groupsdictionary_groups_screen-dart)
7. [`lib/features/search_history/search_history_screen.dart`](#libfeaturessearch_historysearch_history_screen-dart)
8. [`lib/features/score_history/score_history_screen.dart`](#libfeaturesscore_historyscore_history_screen-dart)
9. [`lib/features/about/about_screen.dart`](#libfeaturesaboutabout_screen-dart)
10. [`lib/features/help/manual_screen.dart`](#libfeatureshelphelp_manual-dart)
11. [`lib/features/support/support_screen.dart`](#libfeaturessupportsupport_screen-dart)
12. [`lib/features/home/widgets/app_drawer.dart`](#libfeatureshomewidgetsapp_drawer-dart)

### Bookmarks
1. [`lib/core/bookmark_manager.dart`](#libcorebookmark_manager-dart)

---

# Core Services

---

## `lib/core/utils/word_boundary.dart` {#libcoreutilsword_boundary-dart}

### Class: `WordBoundary`

A utility to find word boundaries in text based on Unicode character properties.

##### Static Method: `wordAt`

Extracts the word at a given offset from text.

| Parameter | Type | Description |
|-----------|------|-------------|
| `text` | `String` | The text to search |
| `offset` | `int` | The character offset position |

**Returns:** `String?` - The word at the offset, or null if not a word character or out of bounds.

```dart
final word = WordBoundary.wordAt("Hello world", 0); // Returns "Hello"
final word = WordBoundary.wordAt("Hello world", 6); // Returns "world"
```

##### Static Method: `prefixRegex`

Creates a regex pattern to find words starting with a given prefix using Unicode-aware word boundaries.

| Parameter | Type | Description |
|-----------|------|-------------|
| `prefix` | `String` | The prefix to match |

**Returns:** `RegExp` - A compiled regex that matches words starting with the prefix.

```dart
final regex = WordBoundary.prefixRegex('क');
final matches = regex.allMatches('कर्म की गोद में खड़ा है');
// matches: ['कर्म', 'की', 'खड़ा', 'कमल']
```

##### Static Method: `findWordsStartingWith`

Finds all words in text that start with a given prefix using Unicode-aware word boundaries.

| Parameter | Type | Description |
|-----------|------|-------------|
| `text` | `String` | The text to search |
| `prefix` | `String` | The prefix to match |

**Returns:** `Set<String>` - A set of unique lowercase words matching the prefix.

```dart
final words = WordBoundary.findWordsStartingWith(
  'कर्म की गोद में खड़ा है कमल',
  'क'
);
// Returns: {'कर्म', 'की', 'खड़ा', 'कमल'}
```

---

## `lib/core/utils/html_lookup_wrapper.dart` {#libcoreutilshtml_lookup_wrapper-dart}

### Class: `HtmlLookupWrapper`

A utility to process dictionary record HTML. Combines whitespace normalization, highlighting, and underlining.

##### Static Method: `processRecord`

Processes a dictionary record in a single pass for maximum performance.

| Parameter | Type | Description |
|-----------|------|-------------|
| `html` | `String` | The HTML content to process |
| `format` | `String` | Dictionary format (e.g., 'stardict', 'mdict') |
| `typeSequence` | `String?` | Optional type sequence for format-specific processing |
| `highlightQuery` | `String?` | Optional query to highlight in the text |
| `underlineQuery` | `String?` | Optional query to underline in the text |

**Returns:** `String` - Processed HTML with whitespace normalized and queries highlighted.

```dart
final processed = HtmlLookupWrapper.processRecord(
  html: '<div>Hello world</div>',
  format: 'stardict',
  highlightQuery: 'hello',
);
```

##### Static Method: `highlightText`

Process record for basic highlighting.

| Parameter | Type | Description |
|-----------|------|-------------|
| `html` | `String` | The HTML content |
| `query` | `String` | Query string to highlight |

**Returns:** `String` - HTML with query wrapped in `<mark>` tags.

```dart
final highlighted = HtmlLookupWrapper.highlightText(html, 'search');
```

##### Static Method: `underlineText`

Process record for underlining.

| Parameter | Type | Description |
|-----------|------|-------------|
| `html` | `String` | The HTML content |
| `query` | `String` | Query string to underline |

**Returns:** `String` - HTML with query wrapped in `<mark>` tags (for underline styling).

---

## `lib/core/utils/multimedia_processor.dart` {#libcoreutilsmultimedia_processor-dart}

### Class: `MultimediaProcessor`

Processes HTML to embed multimedia content (audio, video, images) from MDD resources.

##### Constructor

```dart
MultimediaProcessor(MdictReader? mddReader, String? cssContent)
```

| Parameter | Type | Description |
|-----------|------|-------------|
| `mddReader` | `MdictReader?` | Optional MDD reader for embedded media |
| `cssContent` | `String?` | Optional CSS content for styling |

##### Property: `cssContent`

```dart
String? get cssContent
```

Returns the CSS content.

##### Method: `processHtmlWithMedia`

Processes HTML with embedded multimedia.

| Parameter | Type | Description |
|-----------|------|-------------|
| `html` | `String` | The HTML content to process |

**Returns:** `Future<String>` - Processed HTML with media converted to data URIs or tap handlers.

##### Method: `injectCss`

Injects CSS content into HTML by inserting a style tag in the head or body.

| Parameter | Type | Description |
|-----------|------|-------------|
| `html` | `String` | The HTML content to inject CSS into |

**Returns:** `String` - HTML with CSS injected.

##### Method: `processHtmlWithInlineVideo`

Processes HTML with inline video support. Converts sound links and adds video tap handlers for inline playback.

| Parameter | Type | Description |
|-----------|------|-------------|
| `html` | `String` | The HTML content to process |

**Returns:** `Future<String>` - Processed HTML with inline video support.

##### Method: `getAudioResource`

Retrieves audio resource bytes from the MDD reader.

| Parameter | Type | Description |
|-----------|------|-------------|
| `key` | `String` | Resource key/path |

**Returns:** `Future<Uint8List?>` - Audio bytes, or null if not found.

##### Method: `getVideoResource`

Retrieves video resource bytes from the MDD reader.

| Parameter | Type | Description |
|-----------|------|-------------|
| `key` | `String` | Resource key/path |

**Returns:** `Future<Uint8List?>` - Video bytes, or null if not found.

---

## `lib/core/utils/logger.dart` {#libcoreutilslogger-dart}

### Global Variables

| Variable | Type | Description |
|----------|------|-------------|
| `enableDebugLogs` | `bool` | Global flag to control debug logging |
| `showHtmlProcessing` | `bool` | Enable verbose HTML processing logs |
| `showMultimediaProcessing` | `bool` | Enable multimedia processing logs (images, audio, video) |
| `showSorting` | `bool` | Enable sorting debug logs |

##### Function: `hDebugPrint`

A wrapper around `debugPrint` that checks the `enableDebugLogs` flag and adds timestamps.

```dart
void hDebugPrint(String? message, {int? wrapWidth})
```

| Parameter | Type | Description |
|-----------|------|-------------|
| `message` | `String?` | The message to print |
| `wrapWidth` | `int?` | Optional wrap width for output |

### Class: `HPerf`

Lightweight call-count + timing profiler, active only in debug mode.

##### Static Method: `start`

Returns a started `Stopwatch` - call `end` with the same `name` when done. Returns null (no-op) in release mode.

| Parameter | Type | Description |
|-----------|------|-------------|
| `name` | `String` | Operation name for grouping |

**Returns:** `Stopwatch?` - A started stopwatch, or null in release mode.

```dart
final t = HPerf.start('fetchDef[stardict]');
// ... do work ...
HPerf.end(t, 'fetchDef[stardict]');
```

##### Static Method: `end`

Records the elapsed time from `sw` under `name`. Safe to call with a null `sw` (produced by `start` in release mode).

| Parameter | Type | Description |
|-----------|------|-------------|
| `sw` | `Stopwatch?` | The stopwatch from `start` |
| `name` | `String` | Operation name |

##### Static Method: `record`

One-liner shortcut: records a known `ms` value under `name`.

| Parameter | Type | Description |
|-----------|------|-------------|
| `name` | `String` | Operation name |
| `ms` | `int` | Duration in milliseconds |

##### Static Method: `recordUs`

Records a known `us` value under `name`.

| Parameter | Type | Description |
|-----------|------|-------------|
| `name` | `String` | Operation name |
| `us` | `int` | Duration in microseconds |

##### Static Method: `dump`

Dumps a formatted summary of all recorded operations to the debug log.

| Parameter | Type | Description |
|-----------|------|-------------|
| `prefix` | `String` | Prefix for output (default: '--- PERF') |

##### Static Method: `reset`

Clears all accumulated samples.

---

## `lib/core/utils/benchmark_utils.dart` {#libcoreutilsbenchmark_utils-dart}

### Class: `HBenchmark`

Utility for measuring and reporting dictionary lookup performance.

##### Static Method: `runLookupBenchmark`

Runs a comprehensive benchmark of dictionary lookups.

| Parameter | Type | Description |
|-----------|------|-------------|
| `wordsPerDict` | `int` | Number of words to lookup per dictionary (default: 20) |

**Returns:** `Future<String>` - A formatted benchmark report.

The benchmark:
1. Finds the first 3 enabled dictionaries
2. Fetches 20 random words from each
3. Performs lookups and reports timings via `HPerf`

---

## `lib/core/utils/anchor_id_extension.dart` {#libcoreutilsanchor_id_extension-dart}

### Class: `AnchorIdExtension`

Provides extension methods for handling HTML anchor IDs and links.

##### Static Property: `supportedTags`

```dart
static const Set<String> get supportedTags
```

Returns the set of HTML tags that support anchor IDs.

##### Static Method: `extractAnchorId`

Extracts the anchor ID from an HTML element.

| Parameter | Type | Description |
|-----------|------|-------------|
| `element` | `Element` | The HTML element |
| `tagName` | `String` | The tag name |

**Returns:** `String?` - The anchor ID or null if not found.

##### Static Method: `toHtmlAnchor`

Converts an element to an anchor tag.

| Parameter | Type | Description |
|-----------|------|-------------|
| `element` | `Element` | The HTML element |

**Returns:** `AnchorElement` - The converted anchor element.

---

## `lib/core/utils/folder_scanner.dart` {#libcoreutilsfolder_scanner-dart}

### Class: `DiscoveredDict`

Represents a dictionary discovered during folder scanning.

##### Constructor

```dart
DiscoveredDict({
  required this.path,
  required this.name,
  required this.format,
  this.mddPath,
})
```

| Parameter | Type | Description |
|-----------|------|-------------|
| `path` | `String` | Path to the dictionary |
| `name` | `String` | Dictionary name |
| `format` | `String` | Dictionary format |
| `mddPath` | `String?` | Optional path to MDD file |

##### Property: `path`

```dart
final String path
```

The path to the dictionary.

##### Property: `name`

```dart
final String name
```

The dictionary name.

##### Property: `format`

```dart
final String format
```

The dictionary format (stardict, mdict, etc.).

##### Property: `mddPath`

```dart
final String? mddPath
```

Optional path to MDD file for multimedia resources.

##### Method: `toJson`

Converts to JSON representation.

**Returns:** `Map<String, dynamic>` - JSON representation.

##### Method: `toString`

Returns a string representation.

**Returns:** `String`

---

### Class: `IncompleteDict`

Represents an incomplete or corrupted dictionary discovered during scanning.

##### Constructor

```dart
IncompleteDict({
  required this.path,
  required this.reason,
  this.fileSize,
})
```

| Parameter | Type | Description |
|-----------|------|-------------|
| `path` | `String` | Path to the incomplete dictionary |
| `reason` | `String` | Reason why the dictionary is incomplete |
| `fileSize` | `int?` | Optional file size |

##### Property: `path`

```dart
final String path
```

The path to the incomplete dictionary.

##### Property: `reason`

```dart
final String reason
```

The reason why the dictionary is incomplete.

##### Property: `fileSize`

```dart
final int? fileSize
```

Optional file size in bytes.

---

### Class: `FolderScanResult`

Result of a folder scan operation.

##### Constructor

```dart
FolderScanResult({
  required this.dictionaries,
  required this.incomplete,
  this.errors,
})
```

| Parameter | Type | Description |
|-----------|------|-------------|
| `dictionaries` | `List<DiscoveredDict>` | List of discovered dictionaries |
| `incomplete` | `List<IncompleteDict>` | List of incomplete dictionaries |
| `errors` | `List<String>?` | Optional list of errors encountered |

##### Property: `dictionaries`

```dart
final List<DiscoveredDict> dictionaries
```

The list of discovered dictionaries.

##### Property: `incomplete`

```dart
final List<IncompleteDict> incomplete
```

The list of incomplete dictionaries.

##### Property: `errors`

```dart
final List<String>? errors
```

Optional list of errors encountered during scanning.

##### Method: `totalCount`

Returns the total number of dictionaries (complete + incomplete).

**Returns:** `int`

##### Method: `isEmpty`

Returns true if no dictionaries were found.

**Returns:** `bool`

##### Method: `toJson`

Converts to JSON representation.

**Returns:** `Map<String, dynamic>` - JSON representation.

---

### Functions

##### Function: `scanFolderForDictionaries`

Scans a directory for dictionary files.

```dart
Future<FolderScanResult> scanFolderForDictionaries(String directoryPath, {bool extractArchives = true})
```

| Parameter | Type | Description |
|-----------|------|-------------|
| `directoryPath` | `String` | The directory path to scan |
| `extractArchives` | `bool` | Whether to extract archive files (default: true) |

**Returns:** `Future<FolderScanResult>` - The scan result containing discovered dictionaries.

---

## `lib/core/utils/debouncer.dart` {#libcoreutilsdebouncer-dart}

### Class: `Debouncer`

A utility to debounce function calls.

##### Constructor

```dart
Debouncer({required Duration delay})
```

| Parameter | Type | Description |
|-----------|------|-------------|
| `delay` | `Duration` | The delay before executing the callback |

##### Field: `milliseconds`

```dart
final int milliseconds
```

The delay duration in milliseconds before executing the callback.

##### Property: `isActive`

```dart
bool get isActive
```

Returns true if the debouncer is currently active (has a pending callback).

##### Method: `run`

Runs the callback after the delay, canceling any previous pending callback.

```dart
void run(void Function() callback)
```

| Parameter | Type | Description |
|-----------|------|-------------|
| `callback` | `void Function()` | The callback to run |

##### Method: `cancel`

Cancels any pending callback.

```dart
void cancel()
```

##### Method: `dispose`

Disposes the debouncer and cancels any pending callbacks.

```dart
void dispose()
```

---

## `lib/core/utils/folder_scanner.dart` {#libcoreutilsfolder_scanner-dart}

### Private Functions

##### `_isArchive`

```dart
bool _isArchive(String lowerPath)
```

Checks if the given path (in lowercase) is a supported archive format.

| Parameter | Type | Description |
|-----------|------|-------------|
| `lowerPath` | `String` | Lowercase path to check |

**Returns:** `bool` - True if the path ends with a supported archive extension (.zip, .tar.gz, .tgz, .tar, .tar.bz2, .tbz2, .tar.xz, .txz, .7z).

##### `_extractArchiveToDir`

```dart
Future<void> _extractArchiveToDir(String filePath, String destDir)
```

Extracts an archive file into the specified destination directory.

| Parameter | Type | Description |
|-----------|------|-------------|
| `filePath` | `String` | Path to the archive file |
| `destDir` | `String` | Destination directory for extraction |

**Returns:** `Future<void>`

Supports: `.zip`, `.tar.gz`, `.tgz`, `.tar`, `.tar.bz2`, `.tbz2`, `.tar.xz`, `.txz`, `.7z`.

##### `_findFile`

```dart
String? _findFile(String base, List<String> suffixes)
```

Finds a file with any of the given suffixes.

| Parameter | Type | Description |
|-----------|------|-------------|
| `base` | `String` | Base path |
| `suffixes` | `List<String>` | List of possible suffixes |

**Returns:** `String?` - The matching file path or null if not found.

---

*Last updated: March 2026*

# Dictionary Readers

---

## `lib/core/parser/dict_reader.dart` {#libcoreparserdict_reader-dart}

### Class: `DictReader`

Reads definitions from a StarDict .dict or .dict.dz file at specified offsets and lengths.

##### Constructor

```dart
DictReader(String path, {required RandomAccessSource source, int? dictId})
```

| Parameter | Type | Description |
|-----------|------|-------------|
| `path` | `String` | Path to the dictionary file |
| `source` | `RandomAccessSource` | Random access source |
| `dictId` | `int?` | Optional dictionary ID |

##### Properties

| Property | Type | Description |
|----------|------|-------------|
| `source` | `RandomAccessSource` | Random access source |
| `path` | `String` | Path to the SLOB file |
| `dictId` | `int?` | Optional dictionary ID |
| `isDz` | `bool` | True for .dict.dz files; false for plain .dict |

##### Static Method: `fromPath`

Creates a DictReader from a local file path.

| Parameter | Type | Description |
|-----------|------|-------------|
| `path` | `String` | Path to the dictionary file |
| `dictId` | `int?` | Optional dictionary ID |
| `name` | `String?` | Optional name for the source |

**Returns:** `Future<DictReader>` - A new DictReader instance.

##### Static Method: `fromUri`

Creates a DictReader from an Android SAF URI.

| Parameter | Type | Description |
|-----------|------|-------------|
| `uri` | `String` | SAF URI string |
| `dictId` | `int?` | Optional dictionary ID |

**Returns:** `Future<DictReader>` - A new DictReader instance.

##### Static Method: `fromLinkedSource`

Creates a DictReader from a linked source (SAF or Bookmark).

| Parameter | Type | Description |
|-----------|------|-------------|
| `source` | `String` | Content URI (Android) or bookmark/path (iOS/macOS) |
| `targetPath` | `String?` | Optional target path |
| `actualPath` | `String?` | Optional actual path (iOS/macOS) |
| `name` | `String?` | Optional name for the source |

**Returns:** `Future<DictReader>` - A new DictReader instance.

##### Static Method: `fromBytes`

Creates a DictReader from in-memory bytes.

| Parameter | Type | Description |
|-----------|------|-------------|
| `bytes` | `Uint8List` | Raw dictionary file bytes |
| `fileName` | `String?` | Optional file name |
| `dictId` | `int?` | Optional dictionary ID |

**Returns:** `Future<DictReader>` - A new DictReader instance.

##### Method: `open`

Opens the file for reading. Prepares the underlying source (fills SAF buffer / opens file handle).

**Returns:** `Future<void>`

##### Method: `close`

Closes the file. For plain `.dict` files this is a no-op.

**Returns:** `Future<void>`

##### Method: `readAtIndex`

Reads bytes at the specified offset and length.

| Parameter | Type | Description |
|-----------|------|-------------|
| `offset` | `int` | Byte offset position |
| `length` | `int` | Number of bytes to read |

**Returns:** `Future<String>` - Decoded string content.

##### Method: `readAtIndexSync`

Synchronously reads bytes at the specified offset and length. Throws if called on Web or compressed files.

| Parameter | Type | Description |
|-----------|------|-------------|
| `offset` | `int` | Byte offset position |
| `length` | `int` | Number of bytes to read |

**Returns:** `String` - Decoded string content.

##### Method: `readBulk`

Reads multiple definitions at the given offsets and lengths.

| Parameter | Type | Description |
|-----------|------|-------------|
| `entries` | `List<({int offset, int length})>` | List of entries to read |

**Returns:** `Future<List<String>>` - List of decoded string contents.

##### Method: `readBulkSync`

Synchronously reads multiple definitions. Throws if called on Web or compressed files.

| Parameter | Type | Description |
|-----------|------|-------------|
| `entries` | `List<({int offset, int length})>` | List of entries to read |

**Returns:** `List<String>` - List of decoded string contents.

##### Method: `readEntry`

Reads the definition at the given offset and length. Automatically opens the reader if needed for compressed files.

| Parameter | Type | Description |
|-----------|------|-------------|
| `offset` | `int` | Byte offset position |
| `length` | `int` | Number of bytes to read |

**Returns:** `Future<String>` - Decoded string content.

---

## `lib/core/parser/mdict_reader.dart` {#libcoreparsermdict_reader-dart}

### Enum: `MdictSourceType`

Specifies the source type for MDict dictionary files.

| Value | Description |
|-------|-------------|
| `local` | Local file system source |
| `saf` | Storage Access Framework source |
| `bookmark` | Bookmark-based source |

### Enum: `SearchMode`

Specifies the search mode for dictionary lookups.

| Value | Description |
|-------|-------------|
| `prefix` | Prefix matching (default) |
| `suffix` | Suffix matching |
| `substring` | Substring matching |
| `exact` | Exact match |

##### Field: `label`

```dart
final String label
```

Human-readable label for the search mode.

##### Static Method: `fromString`

Creates a SearchMode from a string value.

| Parameter | Type | Description |
|-----------|------|-------------|
| `value` | `String` | String representation of the mode |

**Returns:** `SearchMode` - The matching mode, or `prefix` if not found.

### Enum: `AppThemeMode`

Specifies the app theme mode.

| Value | Description |
|-------|-------------|
| `light` | Light theme |
| `dark` | Dark theme |
| `custom` | Custom theme with user-defined colors |

##### Field: `label`

```dart
final String label
```

Human-readable label for the theme mode.

##### Static Method: `fromString`

Creates an AppThemeMode from a string value.

| Parameter | Type | Description |
|-----------|------|-------------|
| `value` | `String` | String representation of the mode |

**Returns:** `AppThemeMode` - The matching mode, or `custom` if not found.

### Class: `MdictReader`

Reads MDict dictionary files (.mdx, .mdd).

##### Constructor

```dart
MdictReader(String mdxPath, {required RandomAccessSource source, String? mddPath, String? name})
```

##### Properties

| Property | Type | Description |
|----------|------|-------------|
| `source` | `RandomAccessSource` | Random access source |

##### Static Method: `fromPath`

Creates an MdictReader from a file path.

| Parameter | Type | Description |
|-----------|------|-------------|
| `path` | `String` | Path to the MDX file |
| `mddPath` | `String?` | Optional MDD file path |
| `name` | `String?` | Optional name for the source |

**Returns:** `Future<MdictReader>` - A new MdictReader instance.

##### Static Method: `fromUri`

Creates an MdictReader from a URI.

| Parameter | Type | Description |
|-----------|------|-------------|
| `uri` | `Uri` | URI to the MDX file |
| `mddPath` | `String?` | Optional MDD file path |
| `name` | `String?` | Optional name for the source |

**Returns:** `Future<MdictReader>` - A new MdictReader instance.

##### Static Method: `fromLinkedSource`

Creates an MdictReader from a linked source.

| Parameter | Type | Description |
|-----------|------|-------------|
| `source` | `String` | Source path or URI |
| `targetPath` | `String?` | Optional target path |
| `actualPath` | `String?` | Optional actual path |
| `mddPath` | `String?` | Optional MDD path |
| `name` | `String?` | Optional name for the source |

**Returns:** `Future<MdictReader>` - A new MdictReader instance.

##### Static Method: `fromBytes`

Creates an MdictReader from in-memory bytes.

| Parameter | Type | Description |
|-----------|------|-------------|
| `bytes` | `Uint8List` | Raw MDX file bytes |
| `fileName` | `String?` | Optional file name |
| `mddPath` | `String?` | Optional MDD file path |

**Returns:** `Future<MdictReader>` - A new MdictReader instance.

##### Method: `open`

Opens the MDX file and optionally initializes the MDD reader for multimedia resources.

**Returns:** `Future<void>`

##### Method: `close`

Closes the MDX file and MDD reader if open.

**Returns:** `Future<void>`

##### Method: `lookup`

Looks up a word in the dictionary.

| Parameter | Type | Description |
|-----------|------|-------------|
| `word` | `String` | The word to look up |

**Returns:** `Future<String?>` - The definition content, or null if not found.

##### Method: `getMddResource`

Gets a multimedia resource from the MDD file.

| Parameter | Type | Description |
|-----------|------|-------------|
| `key` | `String` | Resource key |

**Returns:** `Future<List<int>?>` - Resource data as bytes, or null if not found.

##### Method: `getMddResourceBytes`

Gets a multimedia resource from the MDD file as Uint8List.

| Parameter | Type | Description |
|-----------|------|-------------|
| `key` | `String` | Resource key |

**Returns:** `Future<Uint8List?>` - Resource data, or null if not found.

##### Method: `prefixSearch`

Performs a prefix search to find all words starting with a given prefix.

| Parameter | Type | Description |
|-----------|------|-------------|
| `prefix` | `String` | The prefix to search for |
| `limit` | `int` | Maximum number of results to return |

**Returns:** `Future<List<(String, int)>>` - List of tuples containing the word and its index.

```dart
final results = await reader.prefixSearch("app", limit: 100);
for (final (word, index) in results) {
  print("$word at index $index");
}
```

##### Property: `cssContent`

```dart
String? get cssContent
```

Returns the CSS content from the MDD file.

##### Property: `hasMdd`

```dart
bool get hasMdd
```

Returns true if the dictionary has an associated MDD (multimedia) file.

##### Property: `mdxPath`

```dart
String get mdxPath
```

Returns the path to the MDX file.

---

## `lib/core/parser/mdd_reader.dart` {#libcoreparsermdd_reader-dart}

### Class: `MddReader`

Reads MDict multimedia files (.mdd).

##### Fields

| Field | Type | Description |
|-------|------|-------------|
| `source` | `RandomAccessSource` | Random access source |
| `isInitialized` | `bool` | Whether the reader is initialized |

##### Constructor

```dart
MddReader(String path, {required RandomAccessSource source})
```

##### Method: `open`

Opens the MDD file for reading.

**Returns:** `Future<void>`

##### Method: `close`

Closes the MDD file and clears the resource cache.

**Returns:** `Future<void>`

##### Method: `getResource`

Gets a resource from the MDD file.

| Parameter | Type | Description |
|-----------|------|-------------|
| `key` | `String` | Resource key |

**Returns:** `Future<List<int>?>` - Resource data as bytes, or null if not found.

##### Method: `getResourceAsString`

Gets a resource from the MDD file as a String.

| Parameter | Type | Description |
|-----------|------|-------------|
| `key` | `String` | Resource key |

**Returns:** `Future<String?>` - Resource data as String, or null if not found.

##### Method: `getResourceAsBytes`

Gets a resource from the MDD file as Uint8List.

| Parameter | Type | Description |
|-----------|------|-------------|
| `key` | `String` | Resource key |

**Returns:** `Future<Uint8List?>` - Resource data, or null if not found.

##### Method: `detectCssKey`

Detects the CSS file key in the MDD archive.

**Returns:** `Future<String?>` - The CSS key if found, null otherwise.

##### Method: `getCssContent`

Gets the CSS content from the MDD file.

**Returns:** `Future<String?>` - CSS content, or null if not found.

##### Property: `isInitialized`

```dart
bool get isInitialized
```

Returns whether the reader is initialized.

##### Private Static Fields

###### `_maxCacheEntries`

```dart
static const int _maxCacheEntries = 100;
```

Maximum number of resource cache entries.

---

## `lib/core/parser/slob_reader.dart` {#libcoreparserslob_reader-dart}

### Class: `SlobReader`

Reads SLOB (Sorted List of Blobs) dictionary files.

##### Constructor

```dart
SlobReader(String path, {required RandomAccessSource source})
```

##### Properties

| Property | Type | Description |
|----------|------|-------------|
| `path` | `String` | Path to the SLOB file |
| `source` | `RandomAccessSource` | Random access source |

##### Property: `bookName`

```dart
String get bookName
```

Returns the dictionary label from tags, or filename if unavailable.

##### Property: `blobCount`

```dart
int get blobCount
```

Returns total number of blobs.

##### Property: `blobs`

```dart
Stream<dynamic> get blobs async*
```

Stream of all blobs in the slob file (async generator).

##### Property: `fileSize`

```dart
Future<int> get fileSize
```

Returns the file size of the dictionary.

##### Static Method: `fromPath`

Creates a SlobReader from a file path.

| Parameter | Type | Description |
|-----------|------|-------------|
| `path` | `String` | Path to the SLOB file |
| `name` | `String?` | Optional name for the source |

**Returns:** `Future<SlobReader>` - A new SlobReader instance.

##### Static Method: `fromUri`

Creates a SlobReader from a URI.

| Parameter | Type | Description |
|-----------|------|-------------|
| `uri` | `Uri` | URI to the SLOB file |
| `name` | `String?` | Optional name for the source |

**Returns:** `Future<SlobReader>` - A new SlobReader instance.

##### Static Method: `fromLinkedSource`

Creates a SlobReader from a linked source.

| Parameter | Type | Description |
|-----------|------|-------------|
| `source` | `String` | Source path or URI |
| `targetPath` | `String?` | Optional target path |
| `actualPath` | `String?` | Optional actual path |
| `name` | `String?` | Optional name for the source |

**Returns:** `Future<SlobReader>` - A new SlobReader instance.

##### Static Method: `fromBytes`

Creates a SlobReader from in-memory bytes.

| Parameter | Type | Description |
|-----------|------|-------------|
| `bytes` | `Uint8List` | Raw SLOB file bytes |
| `fileName` | `String?` | Optional file name |

**Returns:** `Future<SlobReader>` - A new SlobReader instance.

##### Method: `open`

Opens the Slob file.

**Returns:** `Future<void>`

##### Method: `close`

Closes the Slob file.

**Returns:** `Future<void>`

##### Method: `lookup`

Looks up the HTML definition for a word. Note: This is O(N).

| Parameter | Type | Description |
|-----------|------|-------------|
| `word` | `String` | The word to look up |

**Returns:** `Future<String?>` - The definition content, or null if not found.

##### Method: `getBlobContent`

Returns the content of the blob at the given index. This is O(1).

| Parameter | Type | Description |
|-----------|------|-------------|
| `index` | `int` | Blob index |

**Returns:** `Future<String?>` - Blob content, or null if not found.

##### Method: `getBlobContentById`

Returns the content of the blob for a specific id. This is the fastest O(1) lookup method.

| Parameter | Type | Description |
|-----------|------|-------------|
| `id` | `int` | Blob id |

**Returns:** `Future<String?>` - Blob content, or null if not found.

##### Method: `getBlobsContentByIds`

Returns the content of multiple blobs for given ids. Faster than calling getBlobContentById multiple times.

| Parameter | Type | Description |
|-----------|------|-------------|
| `ids` | `List<int>` | List of blob ids |

**Returns:** `Future<List<String>>` - List of blob contents.

##### Method: `getBlob`

Returns the internal blob for a given index. Primarily for internal use or bulk operations.

| Parameter | Type | Description |
|-----------|------|-------------|
| `index` | `int` | Blob index |

**Returns:** `Future<SlobBlob?>` - The blob at the given index.

##### Method: `getBlobsByRange`

Fetches multiple blobs starting at a given index in a single batched call. Uses getBlobs() which decompresses each compressed bin exactly once and returns key + content together - the fastest way to sequentially iterate all blobs in a slob file.

| Parameter | Type | Description |
|-----------|------|-------------|
| `start` | `int` | Starting blob index |
| `count` | `int` | Number of blobs to fetch |

**Returns:** `Future<List<SlobBlob>>` - List of blobs in the range.

---

## `lib/core/parser/dictd_reader.dart` {#libcoreparsersdictd_reader-dart}

### Class: `DictdReader`

Reads Dictd dictionary files.

##### Fields

| Field | Type | Description |
|-------|------|-------------|
| `dictPath` | `String` | Path to the Dictd dictionary file |
| `fileSize` | `int` | File size of the dictionary |
| `source` | `RandomAccessSource?` | Random access source for reading |

##### Constructor

```dart
DictdReader(String dictPath)
```

##### Property: `fileSize`

```dart
Future<int> get fileSize
```

Returns the file size of the dictionary.

##### Property: `source`

```dart
RandomAccessSource? get source
```

Returns the RandomAccessSource used for reading.

##### Static Method: `fromPath`

Creates a DictdReader from a file path.

| Parameter | Type | Description |
|-----------|------|-------------|
| `path` | `String` | Path to the Dictd index file |
| `name` | `String?` | Optional name for the source |

**Returns:** `Future<DictdReader>` - A new DictdReader instance.

##### Static Method: `fromUri`

Creates a DictdReader from a URI.

| Parameter | Type | Description |
|-----------|------|-------------|
| `uri` | `Uri` | URI to the Dictd index file |
| `name` | `String?` | Optional name for the source |

**Returns:** `Future<DictdReader>` - A new DictdReader instance.

##### Static Method: `fromLinkedSource`

Creates a DictdReader from a linked source.

| Parameter | Type | Description |
|-----------|------|-------------|
| `source` | `String` | Source path or URI |
| `targetPath` | `String?` | Optional target path |
| `actualPath` | `String?` | Optional actual path |
| `name` | `String?` | Optional name for the source |

**Returns:** `Future<DictdReader>` - A new DictdReader instance.

##### Method: `openSource`

Opens a random access source for reading dictionary entries.

| Parameter | Type | Description |
|-----------|------|-------------|
| `source` | `RandomAccessSource` | The random access source to read from |

**Returns:** `Future<void>`

##### Method: `readEntries`

Reads multiple dictionary entries in batch, sorted by offset for optimal disk seeking.

| Parameter | Type | Description |
|-----------|------|-------------|
| `entries` | `List<({int offset, int length})>` | List of entry offsets and lengths to read |

**Returns:** `Future<List<String>>` - List of entry contents in the same order as input.

---

## `lib/core/parser/ifo_parser.dart` {#libcoreparserifo_parser-dart}

### Class: `IfoParser`

Parses StarDict .ifo files (metadata/information).

##### Fields

| Field | Type | Description |
|-------|------|-------------|
| `version` | `String?` | Dictionary version |
| `bookName` | `String?` | Dictionary name |
| `wordCount` | `int` | Number of words |
| `idxFileSize` | `int` | Index file size |
| `author` | `String?` | Author |
| `email` | `String?` | Author email |
| `website` | `String?` | Website URL |
| `description` | `String?` | Description |
| `date` | `String?` | Release date |
| `sameTypeSequence` | `String?` | Same-type sequence |
| `idxOffsetBits` | `int` | Index offset bits (32 or 64) |
| `synWordCount` | `int` | Synonym word count |

##### Property: `metadata`

```dart
Map<String, String> get metadata
```

Returns all parsed metadata as a key-value map. This includes all fields defined in the IFO file such as version, bookName, wordCount, etc.

##### Method: `parse`

Parses an IFO file.

| Parameter | Type | Description |
|-----------|------|-------------|
| `path` | `String` | Path to the IFO file |

##### Method: `parseSource`

Parses from a RandomAccessSource.

| Parameter | Type | Description |
|-----------|------|-------------|
| `source` | `dynamic` | Data source |

##### Method: `parseContent`

Parses from content string.

| Parameter | Type | Description |
|-----------|------|-------------|
| `content` | `String` | IFO file content |

---

## `lib/core/parser/idx_parser.dart` {#libcoreparseridx_parser-dart}

### Class: `IdxParser`

Parses StarDict .idx files.

##### Fields

| Field | Type | Description |
|-------|------|-------------|
| `ifo` | `IfoParser` | Associated IFO parser |

##### Method: `parse`

Parses from a RandomAccessSource.

| Parameter | Type | Description |
|-----------|------|-------------|
| `source` | `RandomAccessSource` | Data source |

**Returns:** `Future<Stream<Map<String, dynamic>>>` - Stream of word entries.

##### Method: `parseFromBytes`

Parses from raw bytes.

| Parameter | Type | Description |
|-----------|------|-------------|
| `bytes` | `Uint8List` | Raw IDX file bytes |

**Returns:** `Future<Stream<Map<String, dynamic>>>` - Stream of word entries.

---

## `lib/core/parser/syn_parser.dart` {#libcoreparsersyn_parser-dart}

### Class: `SynParser`

Parses StarDict .syn files.

##### Static Method: `parse`

Parses a SYN file.

| Parameter | Type | Description |
|-----------|------|-------------|
| `source` | `RandomAccessSource` | The data source |

**Returns:** `Future<List<Map<String, dynamic>>>` - List of synonym entries.

##### Static Method: `parseFromBytes`

Parses a SYN file from raw bytes.

| Parameter | Type | Description |
|-----------|------|-------------|
| `bytes` | `Uint8List` | Raw SYN file bytes |

**Returns:** `Future<List<Map<String, dynamic>>>` - List of synonym entries.

---

*Last updated: March 2026*

# Models

---

## `lib/core/models/stardict_dictionary.dart` {#libcoremodelsstardict_dictionary-dart}

### Class: `StardictDictionary`

Represents a StarDict dictionary available for download.

##### Constructor

```dart
StardictDictionary({required String sourceLanguageCode, required String targetLanguageCode, required String name, required String url, required String headwords, required String version, required String date, required List<StardictRelease> releases})
```

##### Properties

| Property | Type | Description |
|----------|------|-------------|
| `name` | `String` | Dictionary name |
| `url` | `String` | Download URL |
| `headwords` | `String` | Number of headwords |
| `version` | `String` | Version string |
| `date` | `String` | Release date |
| `releases` | `List<StardictRelease>` | Available releases |
| `sourceLanguageCode` | `String` | ISO 639-2 source language code |
| `sourceLanguageName` | `String` | Source language name |
| `targetLanguageCode` | `String` | ISO 639-2 target language code |
| `targetLanguageName` | `String` | Target language name |

##### Method: `getPreferredRelease`

Gets the preferred (first) release from the releases list.

**Returns:** `StardictRelease?` - The preferred release, or null if no releases available.

##### Static Method: `fromDbRow`

Creates a StardictDictionary from a database row.

| Parameter | Type | Description |
|-----------|------|-------------|
| `row` | `Map<String, dynamic>` | Database row |

**Returns:** `StardictDictionary`

##### Static Method: `fromTsvRow`

Creates a StardictDictionary from a TSV row.

| Parameter | Type | Description |
|-----------|------|-------------|
| `values` | `List<String>` | TSV row values |

**Returns:** `StardictDictionary`

##### Method: `toDbRow`

Converts the dictionary to a database row.

**Returns:** `Map<String, dynamic>`

---

## `lib/core/models/stardict_release.dart` {#libcoremodelsstardict_release-dart}

### Class: `StardictRelease`

Represents a StarDict dictionary release.

##### Constructor

```dart
StardictRelease({required String url, required String format, required String size, required String version, required String date})
```

##### Properties

| Property | Type | Description |
|----------|------|-------------|
| `url` | `String` | Download URL |
| `format` | `String` | Dictionary format |
| `size` | `String` | File size |
| `version` | `String` | Version string |
| `date` | `String` | Release date |

##### Static Method: `fromTsv`

Creates a StardictRelease from a TSV row.

| Parameter | Type | Description |
|-----------|------|-------------|
| `row` | `Map<String, dynamic>` | TSV row data |

**Returns:** `StardictRelease`

---

## `lib/core/models/discovered_dict.dart` {#libcoremodelsdiscovered_dict-dart}

### Class: `DiscoveredDict`

Represents a dictionary discovered during scanning.

##### Fields

| Field | Type | Description |
|-------|------|-------------|
| `path` | `String` | Path to the primary anchor file |
| `format` | `String` | Format identifier ('stardict', 'mdict', 'slob', 'dictd') |
| `companionPath` | `String?` | For DICTD: path to companion .dict file |
| `parentFolderName` | `String?` | Name of the immediate parent folder |
| `safUris` | `Map<String, String>?` | Mapped URIs for SAF files |

##### Constructor

```dart
const DiscoveredDict({required String path, required String format, String? companionPath, String? parentFolderName, Map<String, String>? safUris})
```

##### Static Method: `fromMap`

Creates a DiscoveredDict from a Map.

| Parameter | Type | Description |
|-----------|------|-------------|
| `map` | `Map<String, dynamic>` | Map to convert |

**Returns:** `DiscoveredDict`

##### Method: `toMap`

Converts the instance to a Map.

**Returns:** `Map<String, dynamic>`

---

## `lib/core/models/incomplete_dict.dart` {#libcoremodelsincomplete_dict-dart}

### Class: `IncompleteDict`

Represents an incomplete or corrupted dictionary.

##### Fields

| Field | Type | Description |
|-------|------|-------------|
| `name` | `String` | Stem name without extension |
| `format` | `String` | Format identifier |
| `missingFiles` | `List<String>` | List of missing mandatory files |
| `parentFolderName` | `String?` | Name of the immediate parent folder |

##### Constructor

```dart
const IncompleteDict({required String name, required String format, required List<String> missingFiles, String? parentFolderName})
```

##### Static Method: `fromMap`

Creates an IncompleteDict from a Map.

| Parameter | Type | Description |
|-----------|------|-------------|
| `map` | `Map<String, dynamic>` | Map to convert |

**Returns:** `IncompleteDict`

##### Method: `toMap`

Converts the instance to a Map.

**Returns:** `Map<String, dynamic>`

---

## `lib/core/models/dictionary_group.dart` {#libcoremodelsdictionary_group-dart}

### Class: `DictionaryGroup`

Represents a group of dictionaries.

##### Constructor

```dart
DictionaryGroup({required String id, required String name, required List<int> dictIds})
```

##### Properties

| Property | Type | Description |
|----------|------|-------------|
| `id` | `String` | Unique group identifier |
| `dictIds` | `List<int>` | List of dictionary IDs in this group |
| `name` | `String` | Display name |

##### Method: `toJson`

Converts the instance to a JSON-compatible Map.

**Returns:** `Map<String, dynamic>`

##### Static Method: `fromJson`

Creates a DictionaryGroup from a JSON Map.

| Parameter | Type | Description |
|-----------|------|-------------|
| `json` | `Map<String, dynamic>` | JSON map |

**Returns:** `DictionaryGroup`

---

## `lib/core/models/deletion_progress.dart` {#libcoremodelsdeletion_progress-dart}

### Class: `DeletionProgress`

Represents the progress of dictionary deletion.

##### Constructor

```dart
DeletionProgress({required String message, required double value, bool isCompleted = false, String? error})
```

##### Property: `message`

```dart
final String message
```

Progress message.

##### Property: `value`

```dart
final double value
```

Progress value (0.0 to 1.0).

##### Property: `isCompleted`

```dart
final bool isCompleted
```

Whether operation is completed.

##### Property: `error`

```dart
final String? error
```

Error message if any.

---

## `lib/core/models/import_progress.dart` {#libcoremodelsimport_progress-dart}

### Class: `ImportProgress`

Represents the progress of dictionary import.

##### Constructor

```dart
ImportProgress({required String message, required double value, bool isCompleted = false, int? dictId, String? error, String? ifoPath, List<String>? sampleWords, int headwordCount = 0, int definitionWordCount = 0, String? dictionaryName, List<String>? incompleteEntries, List<String>? linkedEntries, List<String>? importedEntries, List<String>? alreadyExistsEntries, String? groupName})
```

##### Property: `value`

```dart
final double value
```

Progress value (0.0 to 1.0).

##### Property: `isCompleted`

```dart
final bool isCompleted
```

Whether operation is completed.

##### Property: `dictId`

```dart
final int? dictId
```

ID of imported dictionary.

##### Property: `error`

```dart
final String? error
```

Error message if any.

##### Property: `ifoPath`

```dart
final String? ifoPath
```

Path to IFO file.

##### Property: `sampleWords`

```dart
final List<String>? sampleWords
```

Sample words from dictionary.

##### Property: `headwordCount`

```dart
final int headwordCount
```

Number of headwords.

##### Property: `definitionWordCount`

```dart
final int definitionWordCount
```

Number of words in definitions.

##### Property: `dictionaryName`

```dart
final String? dictionaryName
```

Dictionary display name.

##### Property: `message`

```dart
final String message
```

Progress message.

##### Property: `incompleteEntries`

```dart
final List<String>? incompleteEntries
```

List of incomplete entries during import.

##### Property: `linkedEntries`

```dart
final List<String>? linkedEntries
```

List of linked entries.

##### Property: `importedEntries`

```dart
final List<String>? importedEntries
```

List of imported entries.

##### Property: `alreadyExistsEntries`

```dart
final List<String>? alreadyExistsEntries
```

List of entries that already exist.

##### Property: `groupName`

```dart
final String? groupName
```

Group name for the imported dictionary.

##### Method: `copyWith`

Creates a copy with modified fields.

| Parameter | Type | Description |
|-----------|------|-------------|
| `message` | `String?` | Progress message |
| `value` | `double?` | Progress value |
| `isCompleted` | `bool?` | Completion status |
| `dictId` | `int?` | Dictionary ID |
| `error` | `String?` | Error message |
| `ifoPath` | `String?` | IFO path |
| `sampleWords` | `List<String>?` | Sample words |
| `headwordCount` | `int?` | Headword count |
| `definitionWordCount` | `int?` | Definition word count |
| `dictionaryName` | `String?` | Dictionary name |
| `incompleteEntries` | `List<String>?` | Incomplete entries |
| `linkedEntries` | `List<String>?` | Linked entries |
| `importedEntries` | `List<String>?` | Imported entries |
| `alreadyExistsEntries` | `List<String>?` | Already existing entries |
| `groupName` | `String?` | Group name |

**Returns:** `ImportProgress`

---

## `lib/core/models/folder_scan_result.dart` {#libcoremodelsfolder_scan_result-dart}

### Class: `FolderScanResult`

Represents the result of scanning a folder for dictionaries.

##### Fields

| Field | Type | Description |
|-------|------|-------------|
| `discovered` | `List<DiscoveredDict>` | Valid dictionaries found |
| `incomplete` | `List<IncompleteDict>` | Incomplete dictionaries |
| `foundArchives` | `List<String>` | Archive files found |

##### Constructor

```dart
const FolderScanResult({required List<DiscoveredDict> discovered, required List<IncompleteDict> incomplete, List<String> foundArchives = const []})
```

##### Static Method: `fromMap`

Creates a FolderScanResult from a Map.

| Parameter | Type | Description |
|-----------|------|-------------|
| `map` | `Map<String, dynamic>` | Map to convert |

**Returns:** `FolderScanResult`

##### Method: `toMap`

Converts the instance to a Map.

**Returns:** `Map<String, dynamic>`

---

# Providers

---

## `lib/features/settings/settings_provider.dart` {#libfeaturessettingssettings_provider-dart}

### Enum: `SearchMode`

Specifies the search mode for dictionary lookups.

| Value | Description |
|-------|-------------|
| `prefix` | Prefix matching (default) |
| `suffix` | Suffix matching |
| `substring` | Substring matching |
| `exact` | Exact match |

##### Field: `label`

```dart
final String label
```

Human-readable label for the search mode.

##### Static Method: `fromString`

Creates a SearchMode from a string value.

| Parameter | Type | Description |
|-----------|------|-------------|
| `value` | `String` | String representation of the mode |

**Returns:** `SearchMode` - The matching mode, or `prefix` if not found.

### Enum: `AppThemeMode`

Specifies the app theme mode.

| Value | Description |
|-------|-------------|
| `light` | Light theme |
| `dark` | Dark theme |
| `custom` | Custom theme with user-defined colors |

##### Field: `label`

```dart
final String label
```

Human-readable label for the theme mode.

##### Static Method: `fromString`

Creates an AppThemeMode from a string value.

| Parameter | Type | Description |
|-----------|------|-------------|
| `value` | `String` | String representation of the mode |

**Returns:** `AppThemeMode` - The matching mode, or `custom` if not found.

### Class: `SettingsProvider`

Manages application settings using SharedPreferences.

##### Properties (Public)

| Property | Type | Description |
|----------|------|-------------|
| `appThemeMode` | `AppThemeMode` | Current app theme mode |
| `backgroundColor` | `Color` | Custom background color |
| `textColor` | `Color` | Custom text color |
| `headwordColor` | `Color` | Custom headword color |
| `fontSize` | `double` | Font size |
| `previewLines` | `int` | Number of preview lines |
| `headwordSearchMode` | `SearchMode` | Headword search mode |
| `definitionSearchMode` | `SearchMode` | Definition search mode |
| `isFuzzySearchEnabled` | `bool` | Whether fuzzy search is enabled |
| `isTapOnMeaningEnabled` | `bool` | Whether tap on meaning is enabled |
| `isOpenPopupOnTap` | `bool` | Whether to open popup on tap |
| `isSearchInHeadwordsEnabled` | `bool` | Whether to search in headwords |
| `isSearchInDefinitionsEnabled` | `bool` | Whether to search in definitions |
| `historyRetentionDays` | `int` | Days to retain search history |
| `searchResultLimit` | `int` | Maximum search results to return |
| `flashCardWordCount` | `int` | Number of words per flash card session |
| `appFirstLaunchDate` | `int` | Timestamp of first app launch |
| `nextReviewPromptDate` | `int` | Timestamp for next review prompt |
| `reviewPromptCount` | `int` | Number of times review has been prompted |
| `hasGivenReview` | `bool` | Whether user has given a review |
| `reviewPromptedThisSession` | `bool` | Whether review was prompted in current session |
| `isListModeEnabled` | `bool` | Whether list view mode is enabled |
| `isShowSearchSuggestionsEnabled` | `bool` | Whether search suggestions are enabled |
| `isSearchAsYouTypeEnabled` | `bool` | Whether "Search As You Type" is enabled |

##### Methods (Public)

##### Method: `getEffectiveBackgroundColor`

Gets the effective background color based on current settings.

**Returns:** `Color` - The effective background color.

##### Method: `getEffectiveTextColor`

Gets the effective text color based on current settings.

**Returns:** `Color` - The effective text color.

##### Method: `getEffectiveHeadwordColor`

Gets the effective headword color based on current settings.

**Returns:** `Color` - The effective headword color.

##### Method: `setAppThemeMode`

Sets the app theme mode.

| Parameter | Type | Description |
|-----------|------|-------------|
| `mode` | `AppThemeMode` | Theme mode to set |

**Returns:** `Future<void>`

##### Method: `setFontFamily`

Sets the font family.

| Parameter | Type | Description |
|-----------|------|-------------|
| `family` | `String` | Font family name |

**Returns:** `Future<void>`

##### Method: `setFontSize`

Sets the font size.

| Parameter | Type | Description |
|-----------|------|-------------|
| `size` | `double` | Font size |

**Returns:** `Future<void>`

##### Method: `setBackgroundColor`

Sets the background color.

| Parameter | Type | Description |
|-----------|------|-------------|
| `color` | `Color` | Background color |

**Returns:** `Future<void>`

##### Method: `setTextColor`

Sets the text color.

| Parameter | Type | Description |
|-----------|------|-------------|
| `color` | `Color` | Text color |

**Returns:** `Future<void>`

##### Method: `setHeadwordColor`

Sets the headword color.

| Parameter | Type | Description |
|-----------|------|-------------|
| `color` | `Color` | Headword color |

**Returns:** `Future<void>`

##### Method: `setPreviewLines`

Sets the number of preview lines.

| Parameter | Type | Description |
|-----------|------|-------------|
| `lines` | `int` | Number of preview lines |

**Returns:** `Future<void>`

##### Method: `setFuzzySearch`

Sets whether fuzzy search is enabled.

| Parameter | Type | Description |
|-----------|------|-------------|
| `enabled` | `bool` | Enable or disable fuzzy search |

**Returns:** `Future<void>`

##### Method: `setTapOnMeaning`

Sets whether tap on meaning is enabled.

| Parameter | Type | Description |
|-----------|------|-------------|
| `enabled` | `bool` | Enable or disable tap on meaning |

**Returns:** `Future<void>`

##### Method: `setOpenPopup`

Sets whether to open popup on tap.

| Parameter | Type | Description |
|-----------|------|-------------|
| `enabled` | `bool` | Enable or disable open popup |

**Returns:** `Future<void>`

##### Method: `setShowSearchSuggestions`

Sets whether search suggestions are shown.

| Parameter | Type | Description |
|-----------|------|-------------|
| `enabled` | `bool` | Enable or disable search suggestions |

**Returns:** `Future<void>`

##### Method: `setSearchAsYouType`

Sets whether "Search As You Type" is enabled.

| Parameter | Type | Description |
|-----------|------|-------------|
| `enabled` | `bool` | Enable or disable search as you type |

**Returns:** `Future<void>`

##### Method: `setReviewPromptCount`

Sets the review prompt count.

| Parameter | Type | Description |
|-----------|------|-------------|
| `count` | `int` | Review prompt count |

**Returns:** `Future<void>`

##### Method: `setHistoryRetentionDays`

Sets the number of days to retain search history.

| Parameter | Type | Description |
|-----------|------|-------------|
| `days` | `int` | Number of days to retain history |

**Returns:** `Future<void>`

##### Method: `searchInHeadwords`

Sets whether search results should include headwords.

| Parameter | Type | Description |
|-----------|------|-------------|
| `enabled` | `bool` | Enable or disable headword search |

**Returns:** `Future<void>`

##### Method: `searchInDefinitions`

Sets whether search results should include definitions.

| Parameter | Type | Description |
|-----------|------|-------------|
| `enabled` | `bool` | Enable or disable definition search |

**Returns:** `Future<void>`

##### Method: `setHeadwordSearchMode`

Sets the search mode for headword matching.

| Parameter | Type | Description |
|-----------|------|-------------|
| `mode` | `SearchMode` | Search mode to use |

**Returns:** `Future<void>`

##### Method: `setDefinitionSearchMode`

Sets the search mode for definition matching.

| Parameter | Type | Description |
|-----------|------|-------------|
| `mode` | `SearchMode` | Search mode to use |

**Returns:** `Future<void>`

##### Method: `setSearchResultLimit`

Sets the maximum number of search results to return.

| Parameter | Type | Description |
|-----------|------|-------------|
| `limit` | `int` | Maximum result count |

**Returns:** `Future<void>`

##### Method: `setFlashCardWordCount`

Sets the number of words per flash card session.

| Parameter | Type | Description |
|-----------|------|-------------|
| `count` | `int` | Number of words per session |

**Returns:** `Future<void>`

##### Method: `initAppFirstLaunchDateIfNeeded`

Initializes the first launch date if not already set. Sets both the launch date and schedules the first review prompt for 15 days later.

**Returns:** `Future<void>`

##### Method: `incrementReviewPromptCountAndSetNextDate`

Increments the review prompt count and schedules the next prompt for 15 days from now.

**Returns:** `Future<void>`

##### Method: `setHasGivenReview`

Sets whether the user has given a review.

| Parameter | Type | Description |
|-----------|------|-------------|
| `given` | `bool` | Whether review was given |

**Returns:** `Future<void>`

##### Method: `setReviewPromptedThisSession`

Sets whether the review prompt was shown in the current session.

| Parameter | Type | Description |
|-----------|------|-------------|
| `prompted` | `bool` | Whether prompt was shown |

**Returns:** `void` (synchronous, no SharedPreferences persistence)

##### Method: `setListMode`

Sets whether list view mode is enabled.

| Parameter | Type | Description |
|-----------|------|-------------|
| `enabled` | `bool` | Enable or disable list mode |

**Returns:** `Future<void>`

##### Private Static Fields

###### `_keyHeadwordColor`

```dart
static const String _keyHeadwordColor = 'headword_color';
```

Key for storing headword color preference.

###### `_keyTextColor`

```dart
static const String _keyTextColor = 'text_color';
```

Key for storing text color preference.

###### `_keyBackgroundColor`

```dart
static const String _keyBackgroundColor = 'background_color';
```

Key for storing background color preference.

###### `_keyFontSize`

```dart
static const String _keyFontSize = 'font_size';
```

Key for storing font size preference.

###### `_keyThemeMode`

```dart
static const String _keyThemeMode = 'theme_mode';
```

Key for storing theme mode preference.

###### `_keyHeadwordSearchMode`

```dart
static const String _keyHeadwordSearchMode = 'headword_search_mode';
```

Key for storing headword search mode preference.

###### `_keyTapOnMeaningEnabled`

```dart
static const String _keyTapOnMeaningEnabled = 'tap_on_meaning_enabled';
```

Key for storing tap on meaning setting.

###### `_keyOpenPopupOnTap`

```dart
static const String _keyOpenPopupOnTap = 'open_popup_on_tap';
```

Key for storing open popup on tap setting.

###### `_keyReviewPromptCount`

```dart
static const String _keyReviewPromptCount = 'review_prompt_count';
```

Key for storing review prompt count.

###### `_keyHasGivenReview`

```dart
static const String _keyHasGivenReview = 'has_given_review';
```

Key for storing whether user has given review.

###### `_keyListMode`

```dart
static const String _keyListMode = 'list_mode';
```

Key for storing list mode setting.

###### `_keyShowSearchSuggestions`

```dart
static const String _keyShowSearchSuggestions = 'show_search_suggestions';
```

Key for storing search suggestions toggle setting.

###### `_keySearchAsYouType`

```dart
static const String _keySearchAsYouType = 'search_as_you_type';
```

Key for storing Search As You Type toggle setting.

---

# Services

---

## `lib/features/settings/services/stardict_service.dart` {#libfeaturessettingsservicesstardict_service-dart}

### Class: `StardictDictionary`

Represents a StarDict dictionary available for download.

##### Constructor

```dart
StardictDictionary({required String sourceLanguageCode, required String targetLanguageCode, required String name, required String url, required String headwords, required String version, required String date, required List<StardictRelease> releases})
```

##### Properties

| Property | Type | Description |
|----------|------|-------------|
| `name` | `String` | Dictionary name |
| `url` | `String` | Download URL |
| `headwords` | `String` | Number of headwords |
| `version` | `String` | Version string |
| `date` | `String` | Release date |
| `releases` | `List<StardictRelease>` | Available releases |
| `sourceLanguageCode` | `String` | ISO 639-2 source language code |
| `sourceLanguageName` | `String` | Source language name |
| `targetLanguageCode` | `String` | ISO 639-2 target language code |
| `targetLanguageName` | `String` | Target language name |

##### Method: `getPreferredRelease`

Gets the preferred (first) release from the releases list.

**Returns:** `StardictRelease?` - The preferred release, or null if no releases available.

### Class: `StardictRelease`

Represents a StarDict dictionary release.

##### Constructor

```dart
StardictRelease({required String url, required String format, required String size, required String version, required String date})
```

##### Properties

| Property | Type | Description |
|----------|------|-------------|
| `url` | `String` | Download URL |
| `format` | `String` | Dictionary format |
| `size` | `String` | File size |
| `version` | `String` | Version string |
| `date` | `String` | Release date |

### Class: `StardictService`

Service for StarDict dictionary operations.

##### Method: `fetchDictionaries`

Fetches available StarDict dictionaries from the remote server.

**Returns:** `Future<List<Map<String, dynamic>>>` - List of available dictionaries.

##### Method: `refreshDictionaries`

Refreshes the dictionary list from the remote server.

**Returns:** `Future<void>`

##### Method: `getDownloadedUrls`

Gets the list of downloaded dictionary URLs.

**Returns:** `Future<Set<String>>` - Set of downloaded URLs.

##### Private Static Fields

###### `_tsvUrl`

```dart
static const String _tsvUrl = '...';
```

URL for the StarDict dictionary TSV file.

---

# Main App

---

## `lib/main.dart` {#libmain-dart}

### Function: `main`

Entry point for the HDict application. Initializes the database and runs the Flutter app.

```dart
void main()
```

### Class: `MyApp`

The main application widget.

---

## `lib/core/theme/app_theme.dart` {#libcorethemeapp_theme-dart}

### Class: `AppTheme`

Theme configuration utility.

##### Static Method: `getTheme`

Gets a theme based on brightness and font family.

| Parameter | Type | Description |
|-----------|------|-------------|
| `brightness` | `Brightness` | Theme brightness (light or dark) |
| `fontFamily` | `String` | Font family name |

**Returns:** `ThemeData` - The configured theme.

##### Static Property: `lightTheme`

```dart
static ThemeData get lightTheme
```

Returns the light theme with Roboto font.

**Returns:** `ThemeData` - Light theme configuration.

##### Static Property: `darkTheme`

```dart
static ThemeData get darkTheme
```

Returns the dark theme with Roboto font.

**Returns:** `ThemeData` - Dark theme configuration.

---

# Screens

---

## `lib/features/home/home_screen.dart` {#libfeatureshomehome_screen-dart}

### Enum: `SuggestionTarget`

Specifies where suggestion results should be displayed.

| Value | Description |
|-------|-------------|
| `searchBar` | Show suggestions in the search bar dropdown |
| `definitionArea` | Show suggestions in the definition area below |

### Class: `EntryToProcess`

Represents an entry to be processed with its content and metadata.

##### Constructor

```dart
EntryToProcess({
  required int index,
  required String content,
  required String word,
  required String format,
  String? typeSequence,
})
```

##### Property: `index`

```dart
final int index
```

The entry index.

##### Property: `content`

```dart
final String content
```

The definition content.

##### Property: `word`

```dart
final String word
```

The headword.

##### Property: `format`

```dart
final String format
```

Dictionary format.

##### Property: `typeSequence`

```dart
final String? typeSequence
```

Optional type sequence.

### Class: `HomeScreen`

Main home screen with search functionality.

##### Static Method: `normalizeWhitespace`

Normalizes whitespace in HTML content.

| Parameter | Type | Description |
|-----------|------|-------------|
| `text` | `String` | Input text |
| `format` | `String?` | Dictionary format (stardict, html, mdict) |
| `typeSequence` | `String?` | Optional type sequence |

**Returns:** `String` - Normalized string.

##### Static Method: `consolidateDefinitions`

Consolidates definitions from multiple dictionaries.

| Parameter | Type | Description |
|-----------|------|-------------|
| `groupedResults` | `List<MapEntry<int, Map<String, List<Map<String, dynamic>>>>>` | Grouped results |
| `dictMap` | `Map<int, Map<String, dynamic>>?` | Optional dictionary metadata map |

**Returns:** `Future<List<Map<String, dynamic>>>` - Consolidated definitions grouped by dictionary.

##### Field: `initialWord`

```dart
final String? initialWord
```

Optional initial word to search for when the screen opens.

### Class: `MddVideoHtmlExtension`

Custom HtmlExtension for flutter_html that renders MDD video resources. Handles `<video>` tags with `mdd-video:` source protocol.

##### Constructor

```dart
MddVideoHtmlExtension({required int dictId})
```

| Parameter | Type | Description |
|-----------|------|-------------|
| `dictId` | `int` | Dictionary ID for resource lookup |

##### Property: `supportedTags`

```dart
Set<String> get supportedTags => {'video'}
```

Returns the set of supported HTML tags.

##### Property: `supportedTags`

```dart
static const Set<String> get supportedTags
```

Returns the set of HTML tags that support anchor IDs.

##### Method: `matches`

Determines if this extension should process the given element.

| Parameter | Type | Description |
|-----------|------|-------------|
| `context` | `ExtensionContext` | The extension context |

**Returns:** `bool` - True if the element has a non-empty id and is in the building step.

##### Method: `build`

Builds an InlineSpan for video elements.

| Parameter | Type | Description |
|-----------|------|-------------|
| `context` | `ExtensionContext` | HTML extension context |

**Returns:** `dynamic` - WidgetSpan containing video player or Container.

#### Private Instance Fields

##### `_dictId`

```dart
final int _dictId
```

The dictionary ID used for resource lookup.

##### Private Instance Methods

###### `build`

```dart
Widget build(ExtensionContext context)
```

Builds an InlineSpan for video elements. Handles `mdd-video:` source protocol by extracting the resource key and creating an `_InlineVideoWidget`.

**Returns:** `WidgetSpan` containing video player or empty `Container` on error.

---

### Class: `_HomeScreenState`

The state class for HomeScreen.

##### Private Instance Fields

###### `_selectedWord`

```dart
String? _selectedWord
```

The currently selected word.

###### `_currentDefinitions`

```dart
List<Map<String, dynamic>> _currentDefinitions = []
```

The current search results.

###### `_isLoading`

```dart
bool _isLoading = false
```

Whether a search is in progress.

###### `_hasDictionaries`

```dart
bool _hasDictionaries = false
```

Whether any dictionaries are installed.

###### `_checkingDicts`

```dart
bool _checkingDicts = true
```

Whether dictionary check is in progress.

###### `_tabController`

```dart
TabController? _tabController
```

Controller for the dictionary tab bar.

###### `_headwordController`

```dart
TextEditingController _headwordController = TextEditingController()
```

Controller for headword search input.

###### `_defController`

```dart
TextEditingController _defController = TextEditingController()
```

Controller for definition search input.

###### `_searchSqliteMs`

```dart
int? _searchSqliteMs
```

SQLite query time in milliseconds.

###### `_searchOtherMs`

```dart
int? _searchOtherMs
```

Other processing time in milliseconds.

###### `_searchTotalMs`

```dart
int? _searchTotalMs
```

Total search time in milliseconds.

###### `_searchResultCount`

```dart
int? _searchResultCount
```

Number of search results.

###### `_lastHeadwordQuery`

```dart
String? _lastHeadwordQuery
```

Last headword search query.

###### `_lastDefinitionQuery`

```dart
String? _lastDefinitionQuery
```

Last definition search query.

###### `_isPopupOpen`

```dart
bool _isPopupOpen = false
```

Whether a popup is currently open.

##### Private Instance Methods

###### `initState`

```dart
void initState()
```

Called when this object is inserted into the tree. Initializes the home screen, checks for dictionaries, and sets up search controllers.

###### `dispose`

```dart
void dispose()
```

Called when this object is removed from the tree permanently. Disposes of controllers and cleans up resources.

###### `build`

```dart
Widget build(BuildContext context)
```

Builds the home screen UI with search bars, dictionary tabs, and results view.

###### `_performSearch`

Performs the dictionary search.

###### `_onWordSelected`

Handles word selection from history.

###### `_onDefinitionSelected`

Handles definition selection.

###### `_showWordPopup`

Shows the word lookup popup.

###### `_checkDictionaries`

Checks for installed dictionaries.

###### `_buildSearchBars`

Builds the search input UI.

###### `_buildDefaultContent`

Builds the default home content.

###### `_buildResultsView`

Builds the search results view.

###### `_buildDefinitionContent`

Builds the definition content widget.

###### `_buildDefinitionContentSync`

Builds definition content synchronously.

###### `_extractTextFromHtml`

Extracts plain text from HTML.

###### `_buildAccordionItem`

Builds an accordion item for list mode.

###### `_buildSuggestionsRow`

Builds the suggestions row widget for autocomplete display.

###### `_getSuggestions`

Gets headword suggestions for autocomplete based on query.

| Parameter | Type | Description |
|-----------|------|-------------|
| `query` | `String` | The search query |

**Returns:** `Future<List<String>>` - List of suggestion words.

###### `_getDefinitionSuggestions`

Gets definition-based suggestions for Search As You Type.

| Parameter | Type | Description |
|-----------|------|-------------|
| `query` | `String` | The search query |

**Returns:** `Future<List<String>>` - List of matching headwords.

---

### Class: `_MdictDefinitionContent`

Widget for MDict definition content.

##### Private Instance Fields

###### `defMap`

```dart
final Map<String, dynamic> defMap
```

Map containing definition data from dictionary lookup.

###### `theme`

```dart
final ThemeData? theme
```

Theme data for styling the content.

###### `highlightHeadword`

```dart
final String? highlightHeadword
```

Headword to highlight in the definition.

###### `highlightDefinition`

```dart
final String? highlightDefinition
```

Definition text to highlight.

###### `searchSqliteMs`

```dart
final int? searchSqliteMs
```

Time taken for SQLite query in milliseconds.

###### `searchOtherMs`

```dart
final int? searchOtherMs
```

Time taken for other processing in milliseconds.

###### `searchTotalMs`

```dart
final int? searchTotalMs
```

Total search time in milliseconds.

###### `searchResultCount`

```dart
final int? searchResultCount
```

Number of search results.

###### `startIndex`

```dart
final int? startIndex
```

Starting index for paginated results.

###### `forceDefaultMode`

```dart
final bool forceDefaultMode
```

Whether to force default view mode.

##### Private Constructor

```dart
_MdictDefinitionContent({
  Key? key,
  required this.defMap,
  this.theme,
  this.highlightHeadword,
  this.highlightDefinition,
  this.searchSqliteMs,
  this.searchOtherMs,
  this.searchTotalMs,
  this.searchResultCount,
  this.startIndex,
  this.forceDefaultMode = false,
});
```

Creates a definition content widget with the specified parameters.

##### Private Instance Methods

###### `createState`

```dart
State<StatefulWidget> createState()
```

Creates the mutable state for this widget.

**Returns:** `_MdictDefinitionContentState`

###### `_processMultimedia`

Processes multimedia content.

###### `_buildAccordionItem`

Builds an accordion item for list mode.

###### `_buildDefinitionContentSync`

Builds definition content synchronously.

---

### Class: `_MdictDefinitionContentState`

State class for `_MdictDefinitionContent` widget.

##### Private Instance Fields

###### `_isProcessing`

```dart
bool _isProcessing = false
```

Whether multimedia is being processed.

###### `_rawDefinitions`

```dart
late List<Map<String, dynamic>> _rawDefinitions
```

Raw definitions data.

##### Private Instance Methods

###### `initState`

```dart
void initState()
```

Called when this object is inserted into the tree. Initializes the definition content state.

###### `build`

```dart
Widget build(BuildContext context)
```

Builds the definition content UI.

###### `_processMultimedia`

Processes multimedia content including video from MDD resources.

---

### Class: `_MediaPlayerDialog`

Dialog for playing audio/video media.

##### Private Instance Fields

###### `data`

```dart
final String data
```

Base64-encoded media data or resource key.

###### `mediaType`

```dart
final String mediaType
```

Type of media ('audio' or 'video').

###### `filename`

```dart
final String filename
```

Original filename of the media.

##### Private Constructor

```dart
_MediaPlayerDialog({
  Key? key,
  required this.data,
  required this.mediaType,
  required this.filename,
});
```

Creates a media player dialog with the specified media data and type.

##### Private Instance Methods

###### `createState`

```dart
State<StatefulWidget> createState()
```

Creates the mutable state for this widget.

**Returns:** `_MediaPlayerDialogState`

###### `_initPlayer`

Initializes the media player.

###### `_formatDuration`

Formats duration for display.

---

### Class: `_MediaPlayerDialogState`

State class for `_MediaPlayerDialog`.

##### Private Instance Fields

###### `_audioPlayer`

```dart
AudioPlayer? _audioPlayer
```

Audio player instance.

###### `_videoController`

```dart
VideoPlayerController? _videoController
```

Video player controller.

##### Private Instance Methods

###### `initState`

```dart
void initState()
```

Called when this object is inserted into the tree. Initializes the media player.

###### `dispose`

```dart
void dispose()
```

Called when this object is removed from the tree. Disposes of player controllers.

###### `build`

```dart
Widget build(BuildContext context)
```

Builds the media player dialog UI with playback controls.

---

### Class: `_MddVideoWidget`

Widget for playing MDD video resources in a dialog with full playback controls.

##### Fields

| Field | Type | Description |
|-------|------|-------------|
| `resourceKey` | `String` | MDD resource key identifying the video file |
| `dictId` | `int` | Dictionary ID for looking up the MDD reader |
| `width` | `double?` | Optional video width constraint |
| `height` | `double?` | Optional video height constraint |
| `controls` | `bool` | Whether to show playback controls (default: true) |
| `autoplay` | `bool` | Whether to auto-play video (default: false) |
| `loop` | `bool` | Whether to loop video (default: false) |

##### Private Constructor

```dart
const _MddVideoWidget({
  required this.resourceKey,
  required this.dictId,
  this.width,
  this.height,
  this.controls = true,
  this.autoplay = false,
  this.loop = false,
});
```

Creates a `_MddVideoWidget` with the specified resource and playback options.

##### Methods

###### `createState`

```dart
State<_MddVideoWidget> createState()
```

Creates the mutable state for this widget.

**Returns:** `_MddVideoWidgetState`

---

### Class: `_MddVideoWidgetState`

State class for `_MddVideoWidget`.

##### Private Instance Fields

| Field | Type | Description |
|-------|------|-------------|
| `_videoController` | `VideoPlayerController?` | Video player controller |
| `_chewieController` | `ChewieController?` | Chewie controller |
| `_isLoading` | `bool` | Loading state |
| `_error` | `String?` | Error message |
| `_tempFilePath` | `String?` | Temporary file path |

##### Private Instance Methods

###### `initState`

```dart
void initState()
```

Called when this object is inserted into the tree. Calls `super.initState()` and initiates video loading via `_loadVideo()`.

###### `_loadVideo`

```dart
Future<void> _loadVideo()
```

Asynchronously loads video from MDD resource. Retrieves bytes from the dictionary's MDD reader, writes them to a temporary file, and initializes the video player controller with Chewie for playback controls.

**Operations:**
1. Gets the MDict reader for the dictionary ID
2. Retrieves resource bytes using `getMddResourceBytes`
3. Writes bytes to a temporary file
4. Initializes `VideoPlayerController` with the file
5. Creates a `ChewieController` with playback settings (autoplay, looping, controls)

**Error Handling:** Sets `_error` message and `_isLoading = false` on failure.

###### `dispose`

```dart
void dispose()
```

Called when this object is removed from the tree permanently. Disposes both Chewie and video controllers, and deletes the temporary video file.

###### `build`

```dart
Widget build(BuildContext context)
```

Builds the video player UI.

**Returns:**
- Loading indicator when `_isLoading` is true
- Error display with icon and message when `_error` is set
- `AspectRatio` widget with Chewie player when ready

---

### Class: `_InlineVideoWidget`

Widget for playing inline video from MDD resources.

##### Fields

| Field | Type | Description |
|-------|------|-------------|
| `resourceKey` | `String` | MDD resource key identifying the video file |
| `dictId` | `int` | Dictionary ID for looking up the MDD reader |

##### Private Constructor

```dart
const _InlineVideoWidget({required this.resourceKey, required this.dictId})
```

Creates an `_InlineVideoWidget` with the specified resource.

##### Methods

###### `createState`

```dart
State<_InlineVideoWidget> createState()
```

Creates the mutable state for this widget.

**Returns:** `_InlineVideoWidgetState`

---

### Class: `_InlineVideoWidgetState`

State class for `_InlineVideoWidget`.

##### Private Instance Fields

| Field | Type | Description |
|-------|------|-------------|
| `_controller` | `VideoPlayerController?` | Video player controller |
| `_isLoading` | `bool` | Loading state |
| `_error` | `String?` | Error message |
| `_tempFilePath` | `String?` | Temporary file path |

##### Private Instance Methods

###### `initState`

```dart
void initState()
```

Called when this object is inserted into the tree. Calls `super.initState()` and initiates video loading via `_loadVideo()`.

###### `_loadVideo`

```dart
Future<void> _loadVideo()
```

Asynchronously loads video from MDD resource for inline playback. Retrieves bytes from the dictionary's MDD reader, writes them to a temporary file, and initializes the video player controller.

**Operations:**
1. Gets the MDict reader for the dictionary ID
2. Retrieves resource bytes using `getMddResourceBytes`
3. Writes bytes to a temporary file with `inline_video_` prefix
4. Initializes `VideoPlayerController` with the file

**Error Handling:** Sets `_error` message and `_isLoading = false` on failure.

###### `dispose`

```dart
void dispose()
```

Called when this object is removed from the tree permanently. Disposes the video controller and deletes the temporary video file.

###### `build`

```dart
Widget build(BuildContext context)
```

Builds the inline video player UI.

**Returns:**
- Loading indicator when `_isLoading` is true
- Error display with icon and message when `_error` is set
- Video player with controls when ready

---

### Class: `_VideoControls`

Stateless widget for video playback controls.

##### Private Instance Fields

| Field | Type | Description |
|-------|------|-------------|
| `controller` | `VideoPlayerController` | Video player controller |

##### Private Instance Methods

###### `_formatDuration`

Formats duration for display.

---

## `lib/features/settings/settings_screen.dart` {#libfeaturessettingssettings_screen-dart}

### Class: `SettingsScreen`

Settings screen for configuring the app.

### Class: `_SettingsScreenState`

The state class for SettingsScreen.

##### Private Instance Methods

###### `_getPreviewTheme`

Gets preview theme for settings.

---

## `lib/features/bookmarks/bookmarks_screen.dart` {#libfeaturesbookmarksbookmarks_screen-dart}

### Class: `BookmarkManager`

Manages platform-specific persistent file access. Handles security-scoped bookmarks on iOS/macOS and SAF on Android.

##### Static Method: `createBookmark`

Creates a security-scoped bookmark for a file path.

| Parameter | Type | Description |
|-----------|------|-------------|
| `path` | `String` | File path to bookmark |

**Returns:** `Future<String?>` - Bookmark string or original path.

##### Static Method: `pickDirectory`

Picks a directory using native SAF picker on Android.

**Returns:** `Future<String?>` - Selected directory URI or null.

##### Static Method: `pickFiles`

Picks one or more files using native SAF picker on Android.

**Returns:** `Future<List<String>?>` - List of selected URIs or null.

##### Static Method: `resolveBookmark`

Resolves a security-scoped bookmark to a physical path.

| Parameter | Type | Description |
|-----------|------|-------------|
| `bookmark` | `String` | Bookmark string to resolve |

**Returns:** `Future<String?>` - Physical path or null.

##### Static Method: `startAccessingPath`

Starts security-scoped access for a physical path.

| Parameter | Type | Description |
|-----------|------|-------------|
| `path` | `String` | Physical path to access |

**Returns:** `Future<bool>` - True if successful.

##### Static Method: `stopAccess`

Stops security-scoped access for a previously resolved bookmark.

| Parameter | Type | Description |
|-----------|------|-------------|
| `bookmark` | `String` | Bookmark string |

**Returns:** `Future<void>`

##### Static Method: `stopAccessingPath`

Stops security-scoped access for a physical path.

| Parameter | Type | Description |
|-----------|------|-------------|
| `path` | `String` | Physical path |

**Returns:** `Future<void>`

---

## `lib/features/flash_cards/flash_cards_screen.dart` {#libfeaturesflash_cardsflash_cards_screen-dart}

### Class: `FlashCardsScreen`

Flash cards screen for vocabulary learning.

##### Method: `createState`

Creates the mutable state for this widget.

**Returns:** `_FlashCardsScreenState` - The state instance.

### Class: `_FlashCardsScreenState`

The state class for FlashCardsScreen.

##### Private Instance Fields

###### `_score`

```dart
int _score = 0
```

Current score.

###### `_index`

```dart
int _index = 0
```

Current card index.

##### Private Instance Methods

###### `initState`

```dart
void initState()
```

Called when this object is inserted into the tree. Initializes the flash card state and loads cards.

###### `dispose`

```dart
void dispose()
```

Called when this object is removed from the tree permanently. Cleans up resources like audio player.

###### `build`

```dart
Widget build(BuildContext context)
```

Builds the flash card UI with score display and card content.

###### `_loadCards`

Loads flash cards.

---

## `lib/features/dictionary_management/dictionary_management_screen.dart` {#libfeaturesdictionary_managementdictionary_management_screen-dart}

### Class: `DictionaryManagementScreen`

Dictionary management screen.

##### Method: `createState`

Creates the mutable state for this widget.

**Returns:** `_DictionaryManagementScreenState` - The state instance.

##### Field: `triggerSelectByLanguage`

```dart
final VoidCallback? triggerSelectByLanguage
```

Callback to trigger dictionary selection by language.

### Class: `_DictionaryManagementScreenState`

The state class for DictionaryManagementScreen.

##### Private Instance Methods

###### `_scanForDictionaries`

Scans for dictionaries in the app directory.

###### `_importDictionaries`

Imports selected dictionaries.

###### `_showImportDialog`

Shows the import dialog.

###### `_showDeleteDialog`

Shows the delete confirmation dialog.

### Class: `_ImportArgs`

Arguments passed to import isolate for processing archives.

##### Private Constructor

```dart
_ImportArgs(
  this.archivePath,
  this.tempDirPath,
  this.sendPort,
  this.rootIsolateToken,
)
```

##### Fields

| Field | Type | Description |
|-------|------|-------------|
| `archivePath` | `String` | Path to the archive file being imported |
| `tempDirPath` | `String` | Temporary directory for extraction |
| `sendPort` | `SendPort` | Port for communication with main isolate |
| `rootIsolateToken` | `RootIsolateToken` | Token for initializing background isolate |

---

## `lib/features/dictionary_groups/dictionary_groups_screen.dart` {#libfeaturesdictionary_groupsdictionary_groups_screen-dart}

### Class: `DictionaryGroupsScreen`

Dictionary groups management screen.

##### Method: `createState`

Creates the mutable state for this widget.

**Returns:** `_DictionaryGroupsScreenState` - The state instance.

### Class: `_DictionaryGroupsScreenState`

The state class for DictionaryGroupsScreen.

##### Private Instance Methods

###### `_loadGroups`

Loads dictionary groups from storage.

---

## `lib/features/search_history/search_history_screen.dart` {#libfeaturessearch_historysearch_history_screen-dart}

### Class: `SearchHistoryScreen`

Search history screen.

##### Method: `createState`

Creates the mutable state for this widget.

**Returns:** `_SearchHistoryScreenState` - The state instance.

### Class: `_SearchHistoryScreenState`

The state class for SearchHistoryScreen.

##### Private Instance Methods

###### `initState`

```dart
void initState()
```

Called when this object is inserted into the tree. Initializes the search history screen.

###### `build`

```dart
Widget build(BuildContext context)
```

Builds the search history list UI.

###### `_loadHistory`

Loads search history from database.

###### `_clearHistory`

Clears all search history.

---

## `lib/features/score_history/score_history_screen.dart` {#libfeaturesscore_historyscore_history_screen-dart}

### Class: `ScoreHistoryScreen`

Score history screen.

##### Method: `createState`

Creates the mutable state for this widget.

**Returns:** `_ScoreHistoryScreenState` - The state instance.

### Class: `_ScoreHistoryScreenState`

The state class for ScoreHistoryScreen.

##### Private Instance Methods

###### `initState`

```dart
void initState()
```

Called when this object is inserted into the tree. Initializes the score history screen.

###### `build`

```dart
Widget build(BuildContext context)
```

Builds the score history list UI with chart visualization.

###### `_loadScores`

Loads score history from database.

---

## `lib/features/about/about_screen.dart` {#libfeaturesaboutabout_screen-dart}

### Class: `AboutScreen`

About app screen.

---

## `lib/features/help/manual_screen.dart` {#libfeatureshelphelp_manual-dart}

### Class: `ManualScreen`

User manual screen.

##### Constructor

```dart
const ManualScreen({super.key})
```

### Class: `_ManualScreenState`

State class for ManualScreen.

##### Fields

| Field | Type | Description |
|-------|------|-------------|
| `_appVersion` | `String` | Current app version |

##### Method: `initState`

Called when this object is inserted into the tree.

##### Method: `_loadVersion`

Loads the app version from package info.

**Returns:** `Future<void>`

##### Method: `build`

Describes the part of the user interface represented by this widget.

| Parameter | Type | Description |
|-----------|------|-------------|
| `context` | `BuildContext` | The build context |

**Returns:** `Widget`

---

## `lib/features/support/support_screen.dart` {#libfeaturessupportsupport_screen-dart}

### Class: `SupportScreen`

Support/help screen.

---

## `lib/features/home/widgets/app_drawer.dart` {#libfeatureshomewidgetsapp_drawer-dart}

### Class: `AppDrawer`

Navigation drawer widget.

---

## `lib/core/bookmark_manager.dart` {#libcorebookmark_manager-dart}

### Class: `BookmarkRandomAccessSource`

Random access source for bookmarks.

##### Property: `length`

```dart
int get length
```

Returns the length of the bookmark.

##### Constructor

```dart
BookmarkRandomAccessSource(this._bookmark)
```

---

## `lib/core/saf_random_access_source.dart` {#libcoresaf_random_access_source-dart}

### Class: `SafRandomAccessSource`

Random access source for Storage Access Framework. Provides efficient random access reading of files accessed through Android's Storage Access Framework.

##### Fields

| Field | Type | Description |
|-------|------|-------------|
| `bufferSize` | `int` | Size of the internal read buffer |

##### Constructor

```dart
SafRandomAccessSource(RandomAccessFile file, int length, {int bufferSize = 65536})
```

##### Property: `length`

```dart
int get length
```

Returns the length of the content.

##### Property: `isFullFileInMemory`

```dart
bool get isFullFileInMemory
```

Returns true if the entire file is loaded in memory.

##### Method: `read`

Reads bytes from the source at the specified offset.

| Parameter | Type | Description |
|-----------|------|-------------|
| `offset` | `int` | Position to start reading from |
| `length` | `int` | Number of bytes to read |

**Returns:** `Future<Uint8List>` - The read bytes.

##### Method: `readSync`

Synchronously reads bytes from the source at the specified offset.

| Parameter | Type | Description |
|-----------|------|-------------|
| `offset` | `int` | Position to start reading from |
| `length` | `int` | Number of bytes to read |

**Returns:** `Uint8List` - The read bytes.

---

## `lib/core/manager/dictionary_manager.dart` {#libcoremanagerdictionary_manager-dart}

### Class: `DictionaryManager`

Manages dictionary readers.

##### Static Property: `instance`

```dart
static DictionaryManager get instance
```

Returns the singleton instance of DictionaryManager.

##### Static Method: `clearReaderCache`

Clears all cached dictionary readers.

##### Static Method: `closeReader`

Closes a specific dictionary reader.

| Parameter | Type | Description |
|-----------|------|-------------|
| `dictId` | `int` | Dictionary ID |

##### Method: `getReader`

Gets a dictionary reader by ID.

| Parameter | Type | Description |
|-----------|------|-------------|
| `dictId` | `int` | Dictionary ID |

**Returns:** `dynamic` - The dictionary reader instance.

##### Method: `getMdictReader`

Gets an MdictReader by ID, or null if the reader is not an MdictReader.

| Parameter | Type | Description |
|-----------|------|-------------|
| `dictId` | `int` | Dictionary ID |

**Returns:** `MdictReader?` - The MdictReader instance or null.

##### Method: `isFastReader`

Checks if the reader for a dictionary is a fast reader (supports direct offset-based lookup).

| Parameter | Type | Description |
|-----------|------|-------------|
| `dictId` | `int` | Dictionary ID |

**Returns:** `bool` - True if the reader supports fast lookup.

##### Method: `getOrphanedDictionaryFolders`

Gets list of dictionary folders that exist on disk but are not registered in the database.

**Returns:** `Future<List<String>>` - List of orphaned folder paths.

##### Method: `deleteOrphanedFolders`

Deletes orphaned dictionary folders from disk.

| Parameter | Type | Description |
|-----------|------|-------------|
| `folderNames` | `List<String>` | List of folder paths to delete |

**Returns:** `Future<void>`

##### Method: `preWarmReaders`

Pre-warms dictionary readers for faster first search.

**Returns:** `Future<void>`

##### Method: `getDictionaries`

Gets all dictionaries from the database.

**Returns:** `Future<List<Map<String, dynamic>>>` - List of dictionary records.

##### Method: `toggleDictionaryEnabled`

Enables or disables a dictionary.

| Parameter | Type | Description |
|-----------|------|-------------|
| `id` | `int` | Dictionary ID |
| `isEnabled` | `bool` | Enable or disable |

**Returns:** `Future<void>`

##### Method: `deleteDictionaryStream`

Deletes a dictionary with progress updates.

| Parameter | Type | Description |
|-----------|------|-------------|
| `id` | `int` | Dictionary ID |

**Returns:** `Stream<DeletionProgress>` - Progress stream.

##### Method: `deleteDictionary`

Deletes a dictionary synchronously.

| Parameter | Type | Description |
|-----------|------|-------------|
| `id` | `int` | Dictionary ID |

**Returns:** `Future<void>`

##### Method: `reorderDictionaries`

Updates the sort order of dictionaries.

| Parameter | Type | Description |
|-----------|------|-------------|
| `sortedIds` | `List<int>` | Dictionary IDs in new order |

**Returns:** `Future<void>`

##### Method: `importDictionaryStream`

Imports a dictionary from an archive file with progress updates.

| Parameter | Type | Description |
|-----------|------|-------------|
| `archivePath` | `String` | Path to the archive file |
| `indexDefinitions` | `bool` | Whether to index definitions (default: false) |

**Returns:** `Stream<ImportProgress>` - Progress stream.

##### Method: `importDictionaryWebStream`

Imports a dictionary from web-downloaded bytes.

| Parameter | Type | Description |
|-----------|------|-------------|
| `fileName` | `String` | Original filename |
| `bytes` | `Uint8List` | Archive file bytes |
| `indexDefinitions` | `bool` | Whether to index definitions (default: false) |

**Returns:** `Stream<ImportProgress>` - Progress stream.

##### Method: `importMultipleFilesStream`

Imports multiple dictionary files from paths.

| Parameter | Type | Description |
|-----------|------|-------------|
| `filePaths` | `List<String>` | List of file paths |
| `indexDefinitions` | `bool` | Whether to index definitions (default: false) |

**Returns:** `Stream<ImportProgress>` - Progress stream.

##### Method: `importFolderStream`

Imports dictionaries from a folder.

| Parameter | Type | Description |
|-----------|------|-------------|
| `folderPath` | `String` | Path to the folder |
| `indexDefinitions` | `bool` | Whether to index definitions (default: false) |

**Returns:** `Stream<ImportProgress>` - Progress stream.

##### Method: `linkFolderStream`

Links dictionaries from a folder (for SAF-linked dictionaries).

| Parameter | Type | Description |
|-----------|------|-------------|
| `folderPath` | `String` | Path to the folder |
| `indexDefinitions` | `bool` | Whether to index definitions (default: false) |

**Returns:** `Stream<ImportProgress>` - Progress stream.

##### Method: `addFolderStream`

Adds dictionaries from a folder (alias for importFolderStream).

| Parameter | Type | Description |
|-----------|------|-------------|
| `folderPath` | `String` | Path to the folder |
| `indexDefinitions` | `bool` | Whether to index definitions (default: false) |

**Returns:** `Stream<ImportProgress>` - Progress stream.

##### Method: `importMultipleFilesWebStream`

Imports multiple dictionary files from web bytes.

| Parameter | Type | Description |
|-----------|------|-------------|
| `files` | `List<({String name, Uint8List bytes})>` | List of file data |
| `indexDefinitions` | `bool` | Whether to index definitions (default: false) |

**Returns:** `Stream<ImportProgress>` - Progress stream.

##### Method: `importMdictStream`

Imports an MDict dictionary (MDX/MDD pair).

| Parameter | Type | Description |
|-----------|------|-------------|
| `mdxPath` | `String` | Path to the MDX file |
| `mddPath` | `String?` | Optional path to the MDD file |
| `indexDefinitions` | `bool` | Whether to index definitions (default: false) |
| `isLinked` | `bool` | Whether this is a linked source (default: false) |
| `sourceBookmark` | `String?` | Source bookmark for linked dictionaries |

**Returns:** `Stream<ImportProgress>` - Progress stream.

##### Method: `importDictdStream`

Imports a DICTD dictionary.

| Parameter | Type | Description |
|-----------|------|-------------|
| `indexPath` | `String` | Path to the index file |
| `dictPath` | `String` | Path to the dictionary file |
| `indexDefinitions` | `bool` | Whether to index definitions (default: false) |

**Returns:** `Stream<ImportProgress>` - Progress stream.

##### Method: `importSlobStream`

Imports a Slob dictionary.

| Parameter | Type | Description |
|-----------|------|-------------|
| `slobPath` | `String` | Path to the Slob file |
| `indexDefinitions` | `bool` | Whether to index definitions (default: false) |
| `isLinked` | `bool` | Whether this is a linked source (default: false) |
| `sourceBookmark` | `String?` | Source bookmark for linked dictionaries |

**Returns:** `Stream<ImportProgress>` - Progress stream.

##### Method: `fetchDefinition`

Fetches a single definition from a dictionary.

| Parameter | Type | Description |
|-----------|------|-------------|
| `dictRecord` | `Map<String, dynamic>` | Dictionary record |
| `word` | `String` | Word to look up |
| `offset` | `int` | Offset in the dictionary file |
| `length` | `int` | Length of the entry |

**Returns:** `Future<String?>` - The definition HTML, or null if not found.

##### Method: `fetchDefinitionsBatchSync`

Fetches multiple definitions synchronously from a dictionary.

| Parameter | Type | Description |
|-----------|------|-------------|
| `dictRecord` | `Map<String, dynamic>` | Dictionary record |
| `requests` | `List<Map<String, dynamic>>` | List of {word, offset, length} |

**Returns:** `List<String?>?` - List of definitions.

##### Method: `fetchDefinitionsBatch`

Fetches multiple definitions asynchronously from a dictionary.

| Parameter | Type | Description |
|-----------|------|-------------|
| `dictRecord` | `Map<String, dynamic>` | Dictionary record |
| `requests` | `List<Map<String, dynamic>>` | List of {word, offset, length} |

**Returns:** `Future<List<String?>>` - List of definitions.

##### Method: `reIndexDictionariesStream`

Re-indexes all dictionaries with definition indexing enabled.

**Returns:** `Stream<ImportProgress>` - Progress stream.

##### Method: `reindexDictionaryStream`

Re-indexes a specific dictionary.

| Parameter | Type | Description |
|-----------|------|-------------|
| `dictId` | `int` | Dictionary ID |
| `indexDefinitions` | `bool` | Whether to index definitions (default: true) |

**Returns:** `Stream<ImportProgress>` - Progress stream.

##### Method: `downloadAndImportDictionaryStream`

Downloads and imports a dictionary from a URL.

| Parameter | Type | Description |
|-----------|------|-------------|
| `url` | `String` | Download URL |
| `indexDefinitions` | `bool` | Whether to index definitions (default: false) |
| `sourceUrl` | `String?` | Original source URL for tracking |

**Returns:** `Stream<ImportProgress>` - Progress stream.

##### Private Static Fields

###### `_maxCacheEntries`

```dart
static const int _maxCacheEntries = 50;
```

Maximum number of reader cache entries.

##### Private Standalone Functions

###### `_decompressGzip`

```dart
List<int> _decompressGzip(List<int> bytes)
```

Decompresses gzip-encoded byte data using Dart's built-in GZipDecoder.

**Parameters:**
- `bytes` - The gzip-compressed byte data

**Returns:** Decompressed byte list

**Example:**
```dart
final decompressed = _decompressGzip(gzipBytes);
```

---

###### `_decompressBZip2`

```dart
List<int> _decompressBZip2(List<int> bytes)
```

Decompresses BZip2-encoded byte data using the archive package.

**Parameters:**
- `bytes` - The BZip2-compressed byte data

**Returns:** Decompressed byte list

---

###### `_decompressXZ`

```dart
List<int> _decompressXZ(List<int> bytes)
```

Decompresses XZ-encoded byte data using the archive package.

**Parameters:**
- `bytes` - The XZ-compressed byte data

**Returns:** Decompressed byte list

---

###### `_dictPathIsDz`

```dart
bool _dictPathIsDz(String dictPath)
```

Checks if a dictionary path points to a gzip-compressed .dz file.

**Parameters:**
- `dictPath` - The dictionary file path to check

**Returns:** `true` if the path ends with `.dz` (case-insensitive)

---

###### `_getDictFileSize`

```dart
Future<int> _getDictFileSize(
  String dictPath,
  String? dictUri,
  bool isLinked,
  String? sourceBookmark,
)
```

Gets the file size of a StarDict .dict file, handling SAF and bookmark sources.

**Parameters:**
- `dictPath` - Local path to the dictionary file
- `dictUri` - SAF URI for Android linked dictionaries
- `isLinked` - Whether the dictionary is linked (SAF/bookmark)
- `sourceBookmark` - Bookmark for bookmark-linked dictionaries

**Returns:** File size in bytes

---

###### `_loadDictFileIntoMemory`

```dart
Future<Uint8List> _loadDictFileIntoMemory(
  String dictPath,
  String? dictUri,
  bool isLinked,
  String? sourceBookmark,
)
```

Loads a StarDict .dict file entirely into memory for fast access on small files.

**Parameters:**
- `dictPath` - Local path to the dictionary file
- `dictUri` - SAF URI for Android linked dictionaries
- `isLinked` - Whether the dictionary is linked
- `sourceBookmark` - Bookmark for bookmark-linked dictionaries

**Returns:** File contents as Uint8List

**Usage:** Used for in-memory optimization when file size is under 50MB.

---

###### `_getSlobFileSize`

```dart
Future<int> _getSlobFileSize(
  String slobPath,
  bool isLinked,
  String? sourceBookmark,
)
```

Gets the file size of a Slob dictionary file.

**Parameters:**
- `slobPath` - Path to the .slob file
- `isLinked` - Whether the dictionary is linked
- `sourceBookmark` - Bookmark for bookmark-linked dictionaries

**Returns:** File size in bytes

---

###### `_loadSlobFileIntoMemory`

```dart
Future<Uint8List> _loadSlobFileIntoMemory(
  String slobPath,
  bool isLinked,
  String? sourceBookmark,
)
```

Loads a Slob dictionary file into memory for optimized access.

**Parameters:**
- `slobPath` - Path to the .slob file
- `isLinked` - Whether the dictionary is linked
- `sourceBookmark` - Bookmark for bookmark-linked dictionaries

**Returns:** File contents as Uint8List

---

###### `_getMdxFileSize`

```dart
Future<int> _getMdxFileSize(
  String mdxPath,
  bool isLinked,
  String? sourceBookmark,
)
```

Gets the file size of an MDict .mdx file.

**Parameters:**
- `mdxPath` - Path to the .mdx file
- `isLinked` - Whether the dictionary is linked
- `sourceBookmark` - Bookmark for bookmark-linked dictionaries

**Returns:** File size in bytes

---

###### `_loadMdxFileIntoMemory`

```dart
Future<Uint8List> _loadMdxFileIntoMemory(
  String mdxPath,
  bool isLinked,
  String? sourceBookmark,
)
```

Loads an MDict .mdx file into memory for optimized access.

**Parameters:**
- `mdxPath` - Path to the .mdx file
- `isLinked` - Whether the dictionary is linked
- `sourceBookmark` - Bookmark for bookmark-linked dictionaries

**Returns:** File contents as Uint8List

---

### Class: `_ExtractArgs`

Arguments class for archive extraction in isolate.

##### Fields

| Field | Type | Description |
|-------|------|-------------|
| `filePath` | `String` | Path to archive file |
| `workspacePath` | `String` | Destination workspace path |

##### Private Constructor

```dart
_ExtractArgs(this.filePath, this.workspacePath);
```

Creates an instance of `_ExtractArgs` with the specified file and workspace paths.

---

### Class: `_IndexArgs`

Arguments class for StarDict (.idx/.dict) indexing in isolate.

##### Fields

| Field | Type | Description |
|-------|------|-------------|
| `dictId` | `int` | Database ID of the dictionary |
| `idxPath` | `String` | Path to the .idx index file |
| `dictPath` | `String` | Path to the .dict file containing definitions |
| `synPath` | `String?` | Optional path to the .syn synonym file |
| `indexDefinitions` | `bool` | Whether to index definition content (enables FTS5) |
| `ifoParser` | `IfoParser` | Parsed .ifo metadata |
| `sourceType` | `String?` | Source type ('linked' for SAF/bookmark sources) |
| `sourceBookmark` | `String?` | Bookmark for linked dictionaries |
| `sendPort` | `SendPort` | Port for progress communication |
| `rootIsolateToken` | `RootIsolateToken` | Token for background isolate initialization |
| `idxUri` | `String?` | SAF URI for .idx file on Android |
| `dictUri` | `String?` | SAF URI for .dict file on Android |
| `synUri` | `String?` | SAF URI for .syn file on Android |

##### Private Constructor

```dart
_IndexArgs(
  this.dictId,
  this.idxPath,
  this.dictPath,
  this.synPath,
  this.indexDefinitions,
  this.ifoParser,
  this.sourceType,
  this.sourceBookmark,
  this.sendPort,
  this.rootIsolateToken, {
  this.idxUri,
  this.dictUri,
  this.synUri,
});
```

Creates an instance of `_IndexArgs` for StarDict indexing operations.

---

### Class: `_IndexMdictArgs`

Arguments class for MDict (.mdx) indexing in isolate.

##### Fields

| Field | Type | Description |
|-------|------|-------------|
| `dictId` | `int` | Database ID of the dictionary |
| `mdxPath` | `String` | Path to the .mdx file |
| `mdxBytes` | `Uint8List?` | Pre-loaded bytes for in-memory optimization |
| `indexDefinitions` | `bool` | Whether to index definition content |
| `bookName` | `String` | Display name of the dictionary |
| `sourceType` | `String?` | Source type for linked dictionaries |
| `sourceBookmark` | `String?` | Bookmark for linked dictionaries |
| `sendPort` | `SendPort` | Port for progress communication |
| `rootIsolateToken` | `RootIsolateToken` | Token for background isolate initialization |
| `mdxUri` | `String?` | SAF URI for .mdx file on Android |
| `mddUri` | `String?` | SAF URI for .mdd media file on Android |

##### Private Constructor

```dart
_IndexMdictArgs({
  required this.dictId,
  required this.mdxPath,
  this.mdxBytes,
  required this.indexDefinitions,
  required this.bookName,
  this.sourceType,
  this.sourceBookmark,
  required this.sendPort,
  required this.rootIsolateToken,
  this.mdxUri,
  this.mddUri,
});
```

Creates an instance of `_IndexMdictArgs` for MDict indexing operations.

---

### Class: `_IndexSlobArgs`

Arguments class for Slob (.slob) indexing in isolate.

##### Fields

| Field | Type | Description |
|-------|------|-------------|
| `dictId` | `int` | Database ID of the dictionary |
| `slobPath` | `String` | Path to the .slob file |
| `slobBytes` | `Uint8List?` | Pre-loaded bytes for in-memory optimization |
| `indexDefinitions` | `bool` | Whether to index definition content |
| `bookName` | `String` | Display name of the dictionary |
| `sourceType` | `String?` | Source type for linked dictionaries |
| `sourceBookmark` | `String?` | Bookmark for linked dictionaries |
| `sendPort` | `SendPort` | Port for progress communication |
| `rootIsolateToken` | `RootIsolateToken` | Token for background isolate initialization |

##### Private Constructor

```dart
_IndexSlobArgs({
  required this.dictId,
  required this.slobPath,
  this.slobBytes,
  required this.indexDefinitions,
  required this.bookName,
  this.sourceType,
  this.sourceBookmark,
  required this.sendPort,
  required this.rootIsolateToken,
});
```

Creates an instance of `_IndexSlobArgs` for Slob indexing operations.

---

### Class: `_IndexDictdArgs`

Arguments class for DICTD indexing in isolate.

##### Fields

| Field | Type | Description |
|-------|------|-------------|
| `dictId` | `int` | Database ID of the dictionary |
| `indexPath` | `String` | Path to the index file |
| `dictPath` | `String` | Path to the dictionary data file |
| `indexDefinitions` | `bool` | Whether to index definition content |
| `bookName` | `String` | Display name of the dictionary |
| `sourceType` | `String?` | Source type for linked dictionaries |
| `sourceBookmark` | `String?` | Bookmark for linked dictionaries |
| `sendPort` | `SendPort` | Port for progress communication |
| `rootIsolateToken` | `RootIsolateToken` | Token for background isolate initialization |
| `indexUri` | `String?` | SAF URI for index file on Android |
| `dictUri` | `String?` | SAF URI for dict file on Android |

##### Private Constructor

```dart
_IndexDictdArgs({
  required this.dictId,
  required this.indexPath,
  required this.dictPath,
  required this.indexDefinitions,
  required this.bookName,
  this.sourceType,
  this.sourceBookmark,
  required this.sendPort,
  required this.rootIsolateToken,
  this.indexUri,
  this.dictUri,
});
```

Creates an instance of `_IndexDictdArgs` for DICTD server indexing operations.

##### Private Standalone Functions

###### `_indexEntry`

```dart
Future<void> _indexEntry(_IndexArgs args)
```

Isolate entry point for indexing StarDict dictionaries (.idx/.dict format). Parses the index file, optionally reads definitions, and batch-inserts entries into the database with FTS5 support.

**Parameters:**
- `args` - Indexing arguments containing dictionary ID, file paths, and configuration

**Operations:**
1. Initializes database factory for background isolate
2. Parses .idx index file
3. Reads .dict definitions (if enabled) with memory optimization for files < 50MB
4. Processes synonyms from .syn file if present
5. Batch inserts entries to database
6. Rebuilds FTS5 index in background if deferred

---

###### `_indexMdictEntry`

```dart
Future<void> _indexMdictEntry(_IndexMdictArgs args)
```

Isolate entry point for indexing MDict dictionaries (.mdx format). Uses prefix search to enumerate all entries and batch-inserts them.

**Parameters:**
- `args` - MDict indexing arguments

**Operations:**
1. Initializes database factory for background isolate
2. Opens MDict reader (from bytes, URI, or path)
3. Uses prefix search with empty prefix to get all keys
4. Batch inserts entries to database with optional FTS5 indexing

---

###### `_indexSlobEntry`

```dart
Future<void> _indexSlobEntry(_IndexSlobArgs args)
```

Isolate entry point for indexing Slob dictionaries (.slob format). Leverages the getBlobsByRange API for efficient batch decompression and reading.

**Parameters:**
- `args` - Slob indexing arguments

**Operations:**
1. Initializes database factory for background isolate
2. Opens Slob reader (from bytes, URI, or path)
3. Uses getBlobsByRange for efficient batch reading
4. Batch inserts entries with optional FTS5 indexing

---

###### `_indexDictdEntry`

```dart
Future<void> _indexDictdEntry(_IndexDictdArgs args)
```

Isolate entry point for indexing DICTD server dictionaries. Parses index entries and reads definitions from the DICTD server connection.

**Parameters:**
- `args` - DICTD indexing arguments

**Operations:**
1. Initializes database factory for background isolate
2. Parses index file and opens DICTD reader
3. Optionally loads entire dict file into memory for optimization
4. Batch inserts entries with optional FTS5 indexing

---

###### `_extractToWorkspaceSync`

```dart
Future<void> _extractToWorkspaceSync(_ExtractArgs args)
```

Synchronously extracts an archive file to the workspace directory. Supports .zip, .tar.gz, .tar.bz2, .tar.xz, and .7z formats.

**Parameters:**
- `args` - Extraction arguments with file and destination paths

**Supported Formats:**
- `.zip` - Standard zip archives
- `.tar.gz` / `.tgz` - Gzip-compressed tar
- `.tar` - Uncompressed tar
- `.tar.bz2` / `.tbz2` - BZip2-compressed tar
- `.tar.xz` - XZ-compressed tar (tries native tar, then 7zip, then archive package)
- `.7z` - 7-zip archives (using flutter_7zip)

---

###### `_extractToWorkspace`

```dart
Future<void> _extractToWorkspace(String filePath, String workspacePath)
```

Extracts an archive to the workspace using compute for background processing.

**Parameters:**
- `filePath` - Path to the archive file
- `workspacePath` - Destination directory

**Usage:** Convenience wrapper around `_extractToWorkspaceSync` using Flutter's compute function.

---

###### `_importEntry`

```dart
Future<void> _importEntry(_ImportArgs args)
```

Isolate entry point for import operations. Extracts an archive and scans for dictionary files, reporting discovered dictionaries and any incomplete entries.

**Parameters:**
- `args` - Import arguments with archive path and communication port

**Operations:**
1. Extracts archive to temporary directory
2. Scans for dictionary files using scanFolderForDictionaries
3. Sends back discovered dictionaries as JSON-encoded map
4. Reports incomplete/missing file entries as human-readable messages

---

## `lib/core/manager/dictionary_group_manager.dart` {#libcoremanagerdictionary_group_manager-dart}

### Class: `DictionaryGroup`

Represents a group of dictionaries.

##### Constructor

```dart
DictionaryGroup({required String id, required String name, required List<int> dictIds})
```

##### Properties

| Property | Type | Description |
|----------|------|-------------|
| `id` | `String` | Unique group identifier |
| `dictIds` | `List<int>` | List of dictionary IDs in this group |
| `name` | `String` | Display name |

##### Method: `toJson`

Converts the instance to a JSON-compatible Map.

**Returns:** `Map<String, dynamic>`

##### Static Method: `fromJson`

Creates a DictionaryGroup from a JSON Map.

| Parameter | Type | Description |
|-----------|------|-------------|
| `json` | `Map<String, dynamic>` | JSON map |

**Returns:** `DictionaryGroup`

### Class: `DictionaryGroupManager`

Manages dictionary groups stored in SharedPreferences.

##### Static Method: `getGroups`

Gets all groups.

**Returns:** `Future<List<DictionaryGroup>>` - List of groups.

##### Static Method: `saveGroups`

Saves groups to storage.

| Parameter | Type | Description |
|-----------|------|-------------|
| `groups` | `List<DictionaryGroup>` | List of groups to save |

**Returns:** `Future<void>`

##### Static Method: `addDictionaryToGroup`

Adds a dictionary to a group.

| Parameter | Type | Description |
|-----------|------|-------------|
| `groupName` | `String` | Group name |
| `dictId` | `int` | Dictionary ID |

**Returns:** `Future<void>`

##### Static Method: `removeDictionaryFromGroup`

Removes a dictionary from a group.

| Parameter | Type | Description |
|-----------|------|-------------|
| `groupId` | `String` | Group ID |
| `dictId` | `int` | Dictionary ID |

**Returns:** `Future<void>`

##### Static Method: `removeDictionaryFromAllGroups`

Removes a dictionary from all groups.

| Parameter | Type | Description |
|-----------|------|-------------|
| `dictId` | `int` | Dictionary ID |

**Returns:** `Future<void>`

##### Static Method: `deleteGroup`

Deletes a group.

| Parameter | Type | Description |
|-----------|------|-------------|
| `groupId` | `String` | Group ID |

**Returns:** `Future<void>`

##### Static Method: `createCustomGroup`

Creates a custom group.

| Parameter | Type | Description |
|-----------|------|-------------|
| `groupName` | `String` | Group name |

**Returns:** `Future<void>`

##### Static Method: `toggleGroup`

Toggles a group's active state.

| Parameter | Type | Description |
|-----------|------|-------------|
| `groupId` | `String` | Group ID |
| `enable` | `bool` | Enable or disable |

**Returns:** `Future<void>`

##### Static Method: `isGroupActive`

Checks if a group is active.

| Parameter | Type | Description |
|-----------|------|-------------|
| `groupId` | `String` | Group ID |

**Returns:** `Future<bool>` - True if the group is active.

##### Static Method: `autoGenerateGroupsFromDownloaded`

Auto-generates groups from downloaded dictionaries.

| Parameter | Type | Description |
|-----------|------|-------------|
| `installedDicts` | `List<Map<String, dynamic>>` | List of installed dictionaries |

**Returns:** `Future<void>`

##### Private Static Fields

###### `_key`

```dart
static const String _key = 'dictionary_groups';
```

Key for storing dictionary groups in SharedPreferences.

---

# Database

---

## `lib/core/database/database_helper.dart` {#libcoredatabasedatabase_helper-dart}

### Class: `DatabaseHelper`

Database helper for SQLite operations.

##### Property: `database`

```dart
Database get database
```

Returns the database instance.

##### Property: `needsMigrationAlert`

```dart
bool get needsMigrationAlert
```

Returns true if a migration alert is needed.

##### Static Method: `initializeDatabaseFactory`

Initializes the database factory for the current platform.

**Returns:** `Future<void>`

##### Method: `setDatabase`

Sets the database instance.

| Parameter | Type | Description |
|-----------|------|-------------|
| `db` | `Database` | Database instance |

##### Method: `resolvePath`

Resolves a stored path to an absolute path.

| Parameter | Type | Description |
|-----------|------|-------------|
| `storedPath` | `String` | Stored relative or absolute path |

**Returns:** `Future<String>` - Absolute path.

##### Method: `saveFile`

Saves a file to the virtual filesystem.

| Parameter | Type | Description |
|-----------|------|-------------|
| `dictId` | `int` | Dictionary ID |
| `fileName` | `String` | File name |
| `bytes` | `Uint8List` | File content |

**Returns:** `Future<void>`

##### Method: `getFile`

Gets a file from the virtual filesystem.

| Parameter | Type | Description |
|-----------|------|-------------|
| `dictId` | `int` | Dictionary ID |
| `fileName` | `String` | File name |

**Returns:** `Future<Uint8List?>` - File bytes, or null if not found.

##### Method: `getFilePart`

Gets a segment of a file from the virtual filesystem.

| Parameter | Type | Description |
|-----------|------|-------------|
| `dictId` | `int` | Dictionary ID |
| `fileName` | `String` | File name |
| `offset` | `int` | Byte offset |
| `length` | `int` | Number of bytes to read |

**Returns:** `Future<Uint8List?>` - File segment, or null if not found.

##### Method: `insertDictionary`

Inserts a new dictionary into the database.

| Parameter | Type | Description |
|-----------|------|-------------|
| `name` | `String` | Dictionary name |
| `path` | `String` | Dictionary path |
| `indexDefinitions` | `bool` | Whether to index definitions |
| `format` | `String` | Dictionary format (default: 'stardict') |
| `typeSequence` | `String?` | Optional type sequence |
| `checksum` | `String?` | Optional checksum |
| `sourceUrl` | `String?` | Optional source URL |
| `sourceType` | `String` | Source type (default: 'managed') |
| `sourceBookmark` | `String?` | Optional source bookmark |
| `companionUri` | `String?` | Optional companion file URI |
| `mddPath` | `String?` | Optional MDD file path |

**Returns:** `Future<int>` - Inserted dictionary ID.

##### Method: `updateDictionaryWordCount`

Updates the word count for a dictionary.

| Parameter | Type | Description |
|-----------|------|-------------|
| `id` | `int` | Dictionary ID |
| `wordCount` | `int` | Number of words |
| `definitionWordCount` | `int?` | Optional definition word count |

**Returns:** `Future<void>`

##### Method: `updateDictionaryRowIdRange`

Updates the rowid range for a dictionary.

| Parameter | Type | Description |
|-----------|------|-------------|
| `id` | `int` | Dictionary ID |
| `start` | `int` | Start rowid |
| `end` | `int` | End rowid |

**Returns:** `Future<void>`

##### Method: `getWordCountForDict`

Gets the word count for a specific dictionary.

| Parameter | Type | Description |
|-----------|------|-------------|
| `dictId` | `int` | Dictionary ID |

**Returns:** `Future<int>` - Word count.

##### Method: `getBatchSampleWords`

Gets a batch of random sample words from enabled dictionaries for flash cards.

| Parameter | Type | Description |
|-----------|------|-------------|
| `totalCount` | `int` | Total number of words to retrieve |
| `dictIds` | `List<int>` | List of dictionary IDs to sample from |

**Returns:** `Future<List<Map<String, dynamic>>>`

##### Method: `getSampleWords`

Gets random sample words from a dictionary.

| Parameter | Type | Description |
|-----------|------|-------------|
| `dictId` | `int` | Dictionary ID |
| `limit` | `int` | Maximum number of words (default: 5) |

**Returns:** `Future<List<Map<String, dynamic>>>` - List of sample word entries.

##### Method: `updateDictionaryEnabled`

Updates whether a dictionary is enabled.

| Parameter | Type | Description |
|-----------|------|-------------|
| `id` | `int` | Dictionary ID |
| `isEnabled` | `bool` | Enable or disable |

**Returns:** `Future<void>`

##### Method: `updateDictionaryIndexDefinitions`

Updates whether a dictionary has definitions indexed.

| Parameter | Type | Description |
|-----------|------|-------------|
| `id` | `int` | Dictionary ID |
| `indexDefinitions` | `bool` | Enable or disable definition indexing |

**Returns:** `Future<void>`

##### Method: `deleteWordsByDictionaryId`

Deletes all words for a specific dictionary.

| Parameter | Type | Description |
|-----------|------|-------------|
| `dictId` | `int` | Dictionary ID |

**Returns:** `Future<void>`

##### Method: `deleteDictionary`

Deletes a dictionary and all associated data from the database.

| Parameter | Type | Description |
|-----------|------|-------------|
| `id` | `int` | Dictionary ID to delete |

**Returns:** `Future<void>`

##### Method: `optimizeDatabase`

Optimizes the database by running VACUUM and FTS5 optimize.

**Returns:** `Future<void>`

##### Method: `getDatabaseSize`

Gets the total size of the database files.

**Returns:** `Future<int>` - Database size in bytes.

##### Method: `getDictionaries`

Gets all dictionaries.

**Returns:** `Future<List<Map<String, dynamic>>>` - List of all dictionaries.

##### Method: `getEnabledDictionaries`

Gets all enabled dictionaries.

**Returns:** `Future<List<Map<String, dynamic>>>` - List of enabled dictionaries.

##### Method: `isDictionaryUrlDownloaded`

Checks if a dictionary URL has already been downloaded.

| Parameter | Type | Description |
|-----------|------|-------------|
| `url` | `String` | Source URL to check |

**Returns:** `Future<bool>` - True if already downloaded.

##### Method: `reorderDictionaries`

Reorders dictionaries based on the provided list of IDs.

| Parameter | Type | Description |
|-----------|------|-------------|
| `sortedIds` | `List<int>` | List of dictionary IDs in new order |

**Returns:** `Future<void>`

##### Method: `getDictionaryByIdSync`

Synchronously gets a dictionary by its ID from the cache.

| Parameter | Type | Description |
|-----------|------|-------------|
| `id` | `int` | Dictionary ID |

**Returns:** `Map<String, dynamic>?` - Dictionary data or null.

##### Method: `getDictionaryById`

Gets a dictionary by its ID.

| Parameter | Type | Description |
|-----------|------|-------------|
| `id` | `int` | Dictionary ID |

**Returns:** `Future<Map<String, dynamic>?>` - Dictionary data or null.

##### Method: `getDictionaryByChecksum`

Gets a dictionary by its checksum.

| Parameter | Type | Description |
|-----------|------|-------------|
| `checksum` | `String` | Dictionary checksum |

**Returns:** `Future<Map<String, dynamic>?>` - Dictionary data or null.

##### Method: `addSearchHistory`

Adds a search term to the search history.

| Parameter | Type | Description |
|-----------|------|-------------|
| `word` | `String` | The search word |
| `searchType` | `String` | Search type (default: 'Headword Search') |

**Returns:** `Future<void>`

##### Method: `getSearchHistory`

Gets search history from the database.

**Returns:** `Future<List<Map<String, dynamic>>>`

##### Method: `clearSearchHistory`

Clears all search history.

**Returns:** `Future<void>`

##### Method: `deleteOldSearchHistory`

Deletes search history older than specified days.

| Parameter | Type | Description |
|-----------|------|-------------|
| `days` | `int` | Number of days to keep |

**Returns:** `Future<void>`

##### Method: `addFlashCardScore`

Adds a flash card score to the database.

| Parameter | Type | Description |
|-----------|------|-------------|
| `score` | `int` | The score achieved |
| `total` | `int` | Total possible points |
| `dictIds` | `String` | Comma-separated dictionary IDs used |

**Returns:** `Future<void>`

##### Method: `getFlashCardScores`

Gets flash card scores from the database.

**Returns:** `Future<List<Map<String, dynamic>>>`

##### Method: `startBatchInsert`

Starts batch insert mode and returns the current maximum ID.

**Returns:** `Future<int>` - Current maximum word_metadata ID.

##### Method: `endBatchInsert`

Ends batch insert mode and restores normal PRAGMA settings.

**Returns:** `Future<void>`

##### Method: `enableBulkInsertMode`

Enables bulk insert mode by setting PRAGMA synchronous to OFF and increasing cache size for faster batch inserts.

**Returns:** `Future<void>`

##### Method: `batchInsertWords`

Inserts multiple words into the database within a transaction. Used during dictionary import for efficient batch insertion with optional FTS5 indexing.

| Parameter | Type | Description |
|-----------|------|-------------|
| `dictId` | `int` | Dictionary ID |
| `words` | `List<Map<String, dynamic>>` | List of words to insert |
| `startId` | `int?` | Starting ID for insertion |
| `populateFts5` | `bool` | Whether to populate FTS5 index (default: true) |
| `dictName` | `String?` | Optional dictionary name for logging |

**Returns:** `Future<({int startId, int duplicateCount})>` - Starting ID and count of duplicates.

##### Method: `rebuildFts5IndexForDict`

Rebuilds the word_index table for a specific dictionary. If FTS5 is available, populates as FTS5 virtual table; otherwise populates as regular table (fallback).

| Parameter | Type | Description |
|-----------|------|-------------|
| `dictId` | `int` | Dictionary ID |

**Returns:** `Future<void>`

##### Method: `findDictsNeedingFts5Rebuild`

Finds dictionaries that have `index_definitions=1` but whose word_index has no content. Used to identify dictionaries that need their definition index rebuilt.

**Returns:** `Future<List<Map<String, dynamic>>>` - List of dictionaries needing FTS5 rebuild.

##### Method: `searchWords`

Searches for words in enabled dictionaries.

| Parameter | Type | Description |
|-----------|------|-------------|
| `headwordQuery` | `String?` | Headword search query |
| `headwordMode` | `SearchMode` | Headword search mode (default: prefix) |
| `definitionQuery` | `String?` | Definition search query |
| `definitionMode` | `SearchMode` | Definition search mode (default: substring) |
| `dictId` | `int?` | Optional dictionary ID to search |
| `limit` | `int` | Maximum results (default: 50) |

**Returns:** `Future<List<Map<String, dynamic>>>`

##### Method: `getPrefixSuggestions`

Gets prefix-based word suggestions from enabled dictionaries for autocomplete.

| Parameter | Type | Description |
|-----------|------|-------------|
| `prefix` | `String` | The search prefix |
| `limit` | `int` | Maximum number of suggestions (default: 50) |
| `fuzzy` | `bool` | Enable fuzzy matching (default: false) |

**Returns:** `Future<List<String>>` - List of matching word suggestions.

##### Method: `getDefinitionSuggestions`

Gets definition-based word suggestions from indexed dictionaries for "Search As You Type" in definitions.

| Parameter | Type | Description |
|-----------|------|-------------|
| `query` | `String` | The search query |
| `limit` | `int` | Maximum number of suggestions (default: 50) |

**Returns:** `Future<List<String>>` - List of matching headwords.

##### Method: `insertFreedictDictionaries`

Inserts FreeDict dictionaries into the cache.

| Parameter | Type | Description |
|-----------|------|-------------|
| `dictionaries` | `List<Map<String, dynamic>>` | List of dictionaries to insert |

**Returns:** `Future<void>`

##### Method: `getFreedictDictionaries`

Gets cached FreeDict dictionaries.

**Returns:** `Future<List<Map<String, dynamic>>>` - List of FreeDict dictionaries.

##### Method: `clearFreedictDictionaries`

Clears all FreeDict dictionaries from the cache.

**Returns:** `Future<void>`

##### Method: `saveSafScanCache`

Saves SAF scan data to the cache.

| Parameter | Type | Description |
|-----------|------|-------------|
| `treeUri` | `String` | Tree URI |
| `scanDataJson` | `String` | Scan data as JSON |

**Returns:** `Future<void>`

##### Method: `getSafScanCache`

Gets cached SAF scan data for a tree URI.

| Parameter | Type | Description |
|-----------|------|-------------|
| `treeUri` | `String` | Tree URI |

**Returns:** `Future<String?>` - Cached scan data as JSON, or null if not found.

##### Method: `clearSafScanCache`

Clears the SAF scan cache.

| Parameter | Type | Description |
|-----------|------|-------------|
| `treeUri` | `String` | Tree URI to clear cache for |

**Returns:** `Future<void>`

##### Method: `clearDictionaryCache`

Clears the in-memory dictionary metadata cache.

**Returns:** `void`

##### Method: `clearQueryCache`

Clears the query result cache.

**Returns:** `void`

##### Static Method: `sqfliteFfiInit`

Initializes the sqflite_common_ffi database factory for desktop platforms.

**Returns:** `void`

##### Method: `toFts5Query`

Converts a search query to FTS5 format.

| Parameter | Type | Description |
|-----------|------|-------------|
| `query` | `String` | Search query |
| `isPrefix` | `bool` | Whether this is a prefix search |

**Returns:** `String` - FTS5 formatted query.

##### Private Static Fields

###### `_maxQueryCacheEntries`

```dart
static const int _maxQueryCacheEntries = 1000;
```

Maximum number of query cache entries.

---

# Result Screens

---

## `lib/features/result/result_screen.dart` {#libfeaturesresultresult_screen-dart}

### Class: `ResultScreen`

Screen for displaying search results.

##### Field: `peekCount`

```dart
final int peekCount
```

Number of items to peek ahead in the definition.

---

# Dialogs

---

## `lib/features/dictionary_management/stardict_download_dialog.dart` {#libfeaturesdictionary_managementstardict_download_dialog-dart}

### Class: `StardictDownloadDialog`

Dialog for downloading StarDict dictionaries.

##### Method: `createState`

Creates the mutable state for this widget.

**Returns:** `_StardictDownloadDialogState` - The state instance.

### Class: `_StardictDownloadDialogState`

The state class for StardictDownloadDialog.

##### Private Instance Methods

###### `_downloadAndImport`

Downloads and imports the dictionary.

---

## Dependency Graph

Below is a dependency list showing which modules depend on others (similar to `flutter pub deps`):

```
hdict
├── lib/main.dart
│   ├── flutter/material.dart
│   ├── provider (package)
│   ├── lib/core/theme/app_theme.dart
│   ├── lib/core/database/database_helper.dart
│   └── lib/features/home/home_screen.dart
│
├── lib/core/
│   ├── constants/
│   │   └── iso_639_2_languages.dart (standalone - no deps)
│   │
│   ├── database/
│   │   └── database_helper.dart
│   │       ├── dart:collection
│   │       ├── dart:io
│   │       ├── dart:math
│   │       ├── flutter/foundation.dart
│   │       ├── path (package)
│   │       ├── path_provider (package)
│   │       ├── sqflite (package)
│   │       ├── sqflite_common_ffi (package)
│   │       ├── sqflite_common_ffi_web (package)
│   │       └── lib/core/utils/logger.dart
│   │
│   ├── manager/
│   │   ├── dictionary_manager.dart
│   │   │   ├── dart:collection
│   │   │   ├── dart:convert
│   │   │   ├── dart:io
│   │   │   ├── dart:isolate
│   │   │   ├── dart:async
│   │   │   ├── flutter/foundation.dart
│   │   │   ├── flutter/services.dart
│   │   │   ├── archive (package)
│   │   │   ├── archive_io (package)
│   │   │   ├── path (package)
│   │   │   ├── path_provider (package)
│   │   │   ├── http (package)
│   │   │   ├── crypto (package)
│   │   │   ├── flutter_7zip (package)
│   │   │   ├── docman (package)
│   │   │   ├── lib/core/database/database_helper.dart
│   │   │   ├── lib/core/parser/ifo_parser.dart
│   │   │   ├── lib/core/parser/idx_parser.dart
│   │   │   ├── lib/core/parser/syn_parser.dart
│   │   │   ├── lib/core/parser/dict_reader.dart
│   │   │   ├── lib/core/parser/mdict_reader.dart
│   │   │   ├── lib/core/parser/slob_reader.dart
│   │   │   ├── lib/core/parser/dictd_reader.dart
│   │   │   ├── lib/core/parser/random_access_source.dart
│   │   │   ├── lib/core/parser/bookmark_random_access_source.dart
│   │   │   ├── lib/core/parser/saf_random_access_source.dart
│   │   │   ├── lib/core/parser/bookmark_manager.dart
│   │   │   ├── lib/core/utils/folder_scanner.dart
│   │   │   ├── lib/core/utils/logger.dart
│   │   │   └── lib/core/manager/dictionary_group_manager.dart
│   │   │
│   │   └── dictionary_group_manager.dart
│   │       ├── dart:convert
│   │       ├── shared_preferences (package)
│   │       └── lib/core/manager/dictionary_manager.dart
│   │
│   ├── parser/
│   │   ├── ifo_parser.dart
│   │   │   ├── dart:convert
│   │   │   ├── dart:io
│   │   │   ├── flutter/foundation.dart
│   │   │   └── lib/core/parser/random_access_source.dart
│   │   │
│   │   ├── idx_parser.dart
│   │   │   ├── dart:typed_data
│   │   │   ├── dart:convert
│   │   │   ├── flutter/foundation.dart
│   │   │   ├── lib/core/parser/random_access_source.dart
│   │   │   └── lib/core/parser/ifo_parser.dart
│   │   │
│   │   ├── syn_parser.dart
│   │   │   ├── dart:typed_data
│   │   │   ├── dart:convert
│   │   │   └── lib/core/parser/random_access_source.dart
│   │   │
│   │   ├── dict_reader.dart
│   │   │   ├── flutter/foundation.dart
│   │   │   ├── dart:io
│   │   │   ├── dart:convert
│   │   │   ├── dictzip_reader (package)
│   │   │   ├── path (package)
│   │   │   ├── lib/core/database/database_helper.dart
│   │   │   ├── lib/core/parser/random_access_source.dart
│   │   │   ├── lib/core/parser/saf_random_access_source.dart
│   │   │   └── lib/core/parser/bookmark_random_access_source.dart
│   │   │
│   │   ├── mdict_reader.dart
│   │   │   ├── flutter/foundation.dart
│   │   │   ├── dart:io
│   │   │   ├── dict_reader (package)
│   │   │   ├── path (package)
│   │   │   ├── lib/core/utils/logger.dart
│   │   │   ├── lib/core/parser/random_access_source.dart
│   │   │   ├── lib/core/parser/saf_random_access_source.dart
│   │   │   ├── lib/core/parser/bookmark_random_access_source.dart
│   │   │   └── lib/core/parser/mdd_reader.dart
│   │   │
│   │   ├── mdd_reader.dart
│   │   │   ├── dart:typed_data
│   │   │   └── dict_reader (package)
│   │   │
│   │   ├── slob_reader.dart
│   │   │   ├── slob_reader (package)
│   │   │   ├── flutter/foundation.dart
│   │   │   ├── dart:io
│   │   │   ├── dart:convert
│   │   │   ├── path (package)
│   │   │   ├── lib/core/parser/random_access_source.dart
│   │   │   ├── lib/core/parser/saf_random_access_source.dart
│   │   │   └── lib/core/parser/bookmark_random_access_source.dart
│   │   │
│   │   ├── dictd_reader.dart
│   │   │   ├── dart:io
│   │   │   ├── flutter/foundation.dart
│   │   │   ├── path (package)
│   │   │   ├── dictd_reader (package)
│   │   │   ├── lib/core/parser/random_access_source.dart
│   │   │   ├── lib/core/parser/saf_random_access_source.dart
│   │   │   └── lib/core/parser/bookmark_random_access_source.dart
│   │   │
│   │   ├── random_access_source.dart (standalone - re-exports from dictzip_reader)
│   │   │
│   │   ├── bookmark_manager.dart
│   │   │   ├── flutter/foundation.dart
│   │   │   ├── flutter/services.dart
│   │   │   └── dart:io
│   │   │
│   │   ├── bookmark_random_access_source.dart
│   │   │   ├── dart:typed_data
│   │   │   ├── dart:io
│   │   │   ├── path (package)
│   │   │   ├── lib/core/parser/random_access_source.dart
│   │   │   └── lib/core/parser/bookmark_manager.dart
│   │   │
│   │   └── saf_random_access_source.dart
│   │       ├── dart:async
│   │       ├── dart:math
│   │       ├── dart:typed_data
│   │       ├── saf_stream (package)
│   │       ├── docman (package)
│   │       └── lib/core/parser/random_access_source.dart
│   │
│   ├── theme/
│   │   └── app_theme.dart
│   │       └── flutter/material.dart
│   │
│   └── utils/
│       ├── anchor_id_extension.dart
│       │   ├── flutter/widgets.dart
│       │   └── flutter_html (package)
│       │
│       ├── benchmark_utils.dart
│       │   ├── dart:async
│       │   ├── lib/core/database/database_helper.dart
│       │   ├── lib/core/manager/dictionary_manager.dart
│       │   └── lib/core/utils/logger.dart
│       │
│       ├── folder_scanner.dart
│       │   ├── dart:io
│       │   ├── archive (package)
│       │   ├── archive_io (package)
│       │   ├── flutter_7zip (package)
│       │   ├── path (package)
│       │   └── lib/core/utils/logger.dart
│       │
│       ├── html_lookup_wrapper.dart
│       │   └── lib/core/utils/logger.dart
│       │
│       ├── logger.dart
│       │   └── flutter/foundation.dart
│       │
│       ├── multimedia_processor.dart
│       │   ├── dart:convert
│       │   ├── dart:typed_data
│       │   ├── lib/core/parser/mdict_reader.dart
│       │   └── lib/core/utils/logger.dart
│       │
│       └── word_boundary.dart (standalone - no deps)
│
└── lib/features/
    ├── about/
    │   └── about_screen.dart
    │       ├── flutter/material.dart
    │       ├── flutter/services.dart
    │       ├── url_launcher (package)
    │       └── lib/features/home/widgets/app_drawer.dart
    │
    ├── flash_cards/
    │   ├── flash_cards_screen.dart
    │   │   ├── flutter/material.dart
    │   │   ├── flutter/rendering.dart
    │   │   ├── dart:math
    │   │   ├── flutter_html (package)
    │   │   ├── provider (package)
    │   │   ├── lib/core/database/database_helper.dart
    │   │   ├── lib/core/manager/dictionary_manager.dart
    │   │   ├── lib/core/utils/html_lookup_wrapper.dart
    │   │   ├── lib/core/utils/word_boundary.dart
    │   │   ├── lib/core/utils/logger.dart
    │   │   ├── lib/features/home/widgets/app_drawer.dart
    │   │   ├── lib/features/settings/settings_provider.dart
    │   │   └── lib/features/flash_cards/result_screen.dart
    │   │
    │   ├── result_screen.dart (standalone)
    │   │
    │   └── score_history_screen.dart
    │       ├── flutter/material.dart
    │       ├── intl (package)
    │       ├── lib/core/database/database_helper.dart
    │       └── lib/features/home/widgets/app_drawer.dart
    │
    ├── help/
    │   └── manual_screen.dart
    │       ├── flutter/material.dart
    │       ├── flutter/services.dart
    │       ├── flutter_markdown_plus (package)
    │       └── lib/features/home/widgets/app_drawer.dart
    │
    ├── home/
    │   ├── home_screen.dart
    │   │   ├── flutter/material.dart
    │   │   ├── flutter/services.dart
    │   │   ├── flutter/rendering.dart
    │   │   ├── flutter/foundation.dart
    │   │   ├── url_launcher (package)
    │   │   ├── flutter_html (package)
    │   │   ├── just_audio (package)
    │   │   ├── video_player (package)
    │   │   ├── chewie (package)
    │   │   ├── in_app_review (package)
    │   │   ├── provider (package)
    │   │   ├── path_provider (package)
    │   │   ├── lib/core/utils/logger.dart
    │   │   ├── lib/core/database/database_helper.dart
    │   │   ├── lib/core/manager/dictionary_manager.dart
    │   │   ├── lib/core/utils/html_lookup_wrapper.dart
    │   │   ├── lib/core/utils/multimedia_processor.dart
    │   │   ├── lib/core/utils/anchor_id_extension.dart
    │   │   ├── lib/core/utils/word_boundary.dart
    │   │   ├── lib/features/settings/settings_provider.dart
    │   │   ├── lib/features/home/widgets/app_drawer.dart
    │   │   └── lib/features/settings/dictionary_management_screen.dart
    │   │
    │   └── widgets/
    │       └── app_drawer.dart
    │           ├── flutter/material.dart
    │           ├── lib/features/about/about_screen.dart
    │           ├── lib/features/flash_cards/flash_cards_screen.dart
    │           ├── lib/features/flash_cards/score_history_screen.dart
    │           ├── lib/features/help/manual_screen.dart
    │           ├── lib/features/home/home_screen.dart
    │           ├── lib/features/settings/dictionary_management_screen.dart
    │           ├── lib/features/settings/search_history_screen.dart
    │           ├── lib/features/settings/settings_screen.dart
    │           ├── lib/features/support/support_screen.dart
    │           └── lib/features/settings/dictionary_groups_screen.dart
    │
    ├── settings/
    │   ├── settings_screen.dart
    │   │   ├── flutter/material.dart
    │   │   ├── flutter_colorpicker (package)
    │   │   ├── provider (package)
    │   │   ├── lib/features/settings/settings_provider.dart
    │   │   ├── lib/features/home/widgets/app_drawer.dart
    │   │   └── lib/core/database/database_helper.dart
    │   │
    │   ├── settings_provider.dart
    │   │   ├── flutter/material.dart
    │   │   └── shared_preferences (package)
    │   │
    │   ├── dictionary_management_screen.dart
    │   │   ├── flutter/material.dart
    │   │   ├── dart:io
    │   │   ├── flutter/foundation.dart
    │   │   ├── file_selector (package)
    │   │   ├── file_picker (package)
    │   │   ├── lib/core/manager/dictionary_manager.dart
    │   │   ├── lib/core/manager/dictionary_group_manager.dart
    │   │   ├── lib/core/parser/bookmark_manager.dart
    │   │   ├── lib/features/home/widgets/app_drawer.dart
    │   │   └── lib/features/settings/widgets/stardict_download_dialog.dart
    │   │
    │   ├── dictionary_groups_screen.dart
    │   │   ├── flutter/material.dart
    │   │   ├── lib/core/manager/dictionary_manager.dart
    │   │   ├── lib/core/manager/dictionary_group_manager.dart
    │   │   └── lib/features/home/widgets/app_drawer.dart
    │   │
    │   ├── search_history_screen.dart
    │   │   ├── flutter/material.dart
    │   │   ├── intl (package)
    │   │   ├── lib/core/database/database_helper.dart
    │   │   └── lib/features/home/widgets/app_drawer.dart
    │   │
    │   ├── services/
    │   │   └── stardict_service.dart
    │   │       ├── dart:convert
    │   │       ├── http (package)
    │   │       ├── lib/core/database/database_helper.dart
    │   │       ├── lib/core/constants/iso_639_2_languages.dart
    │   │       └── lib/core/utils/logger.dart
    │   │
    │   └── widgets/
    │       └── stardict_download_dialog.dart
    │           ├── flutter/material.dart
    │           ├── lib/core/constants/iso_639_2_languages.dart
    │           └── lib/features/settings/services/stardict_service.dart
    │
    └── support/
        └── support_screen.dart
            ├── flutter/material.dart
            ├── flutter/services.dart
            ├── url_launcher (package)
            └── lib/features/home/widgets/app_drawer.dart
```

---

## Function-Level Dependencies

```
HomeScreen._performSearch
├── DatabaseHelper.searchWords
│   ├── DatabaseHelper._ensureDictionaryMapCache
│   │   ├── DatabaseHelper.database
│   │   └── sqflite queries
│   └── sqflite FTS5 queries
├── DictionaryManager.fetchDefinitionsBatch
│   ├── DictionaryManager._getReader
│   │   ├── MdictReader._openMdict
│   │   │   ├── IfoParser.parseContent / .parseSource
│   │   │   └── MddReader._openMdd
│   │   ├── SlobReader._openSlob
│   │   │   └── SlobReader.blobs
│   │   ├── DictReader._openDict
│   │   │   ├── IfoParser.parseContent / .parseSource
│   │   │   ├── IdxParser (for .idx)
│   │   │   └── SynParser (for .syn)
│   │   └── DictdReader._connect
│   └── DictReader/MdictReader/SlobReader/DictdReader.readAtIndex/readBulk
├── HomeScreen.consolidateDefinitions
│   └── DatabaseHelper.getDictionaryById
└── HtmlLookupWrapper.processRecord
    └── HtmlLookupWrapper._tagRegExp (private regex)

DictionaryManager.importDictionaryStream
├── DictionaryManager._extractToWorkspace
│   ├── DictionaryManager._extractToWorkspaceSync
│   │   └── GZipDecoder / BZip2Decoder / XZDecoder / SZArchive.extract
│   └── FolderScanner._extractArchiveToDir
├── scanFolderForDictionaries
│   └── FolderScanner._extractArchiveToDir
└── _processDictionaryFiles
    ├── IfoParser
    ├── IdxParser
    ├── SynParser
    └── DatabaseHelper.batchInsertWords
        ├── DatabaseHelper.startBatchInsert
        └── DatabaseHelper.endBatchInsert

DictionaryManager.fetchDefinition
├── DictionaryManager._getReader
│   ├── MdictReader (for .mdx)
│   │   └── MddReader (for .mdd multimedia)
│   ├── SlobReader (for .slob)
│   ├── DictReader (for StarDict .dict)
│   └── DictdReader (for DICTD)
└── DictionaryManager._definitionCache (LRU)

DatabaseHelper.searchWords
├── DatabaseHelper._ensureDictionaryMapCache
│   ├── DatabaseHelper.database
│   └── sqflite queries
├── sqflite database queries (FTS5 or fallback)
└── DatabaseHelper._queryCache (LRU)

HtmlLookupWrapper.processRecord
└── logger.hDebugPrint (showHtmlProcessing check)

MultimediaProcessor.processHtmlWithMedia
├── MddReader.getMddResourceBytes
├── MultimediaProcessor._replaceImgSrcWithDataUris
│   ├── MddReader.getMddResourceBytes
│   └── MultimediaProcessor._base64EncodeImage
└── MultimediaProcessor._addMediaTapHandlers
    ├── MddReader.getCssContent
    ├── MultimediaProcessor._createMediaWidget
    └── MultimediaProcessor.injectCss

FlashCardsScreen._startQuiz
├── DatabaseHelper.getBatchSampleWords
│   ├── DatabaseHelper._ensureDictionaryMapCache
│   │   ├── DatabaseHelper.database
│   │   └── sqflite queries
│   └── Random.sample
└── DictionaryManager.instance.fetchDefinition

StardictService.refreshDictionaries
├── StardictService._fetchDictionariesFromUrl
│   ├── http.get (package)
│   └── StardictDictionary.fromTsvRow
├── DatabaseHelper.insertFreedictDictionaries
└── StardictDictionary.fromTsvRow

DictionaryGroupManager.autoGenerateGroupsFromDownloaded
├── StardictService.fetchDictionaries
│   └── DatabaseHelper.getFreedictDictionaries
├── StardictService.refreshDictionaries
│   ├── StardictService._fetchDictionariesFromUrl
│   │   ├── http.get (package)
│   │   └── StardictDictionary.fromTsvRow
│   ├── DatabaseHelper.insertFreedictDictionaries
│   └── StardictDictionary.fromTsvRow
└── DictionaryGroupManager._saveGroups
    └── SharedPreferences
```

---

*Last updated: March 2026*
