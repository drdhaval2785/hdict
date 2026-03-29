# Public API Reference (version 1.5.10)

This document lists all public classes, functions, and methods in the HDict codebase. Each entry includes the file location, description, parameters, return types, and usage examples where applicable.

---

## Table of Contents

1. [Core Services](#core-services)
2. [Dictionary Readers](#dictionary-readers)
3. [Models](#models)
4. [Providers](#providers)
5. [Main App](#main-app)
6. [Screens](#screens)
7. [Utils](#utils)

---

## Core Services

### 1. `lib/core/utils/word_boundary.dart`

#### Class: `WordBoundary`

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

---

### 2. `lib/core/utils/html_lookup_wrapper.dart`

#### Class: `HtmlLookupWrapper`

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

### 3. `lib/core/utils/multimedia_processor.dart`

#### Class: `MultimediaProcessor`

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

---

### 4. `lib/core/utils/anchor_id_extension.dart`

#### Class: `AnchorIdExtension`

Custom HtmlExtension for flutter_html that registers AnchorKey for elements with id attributes. Enables bidirectional navigation between cross-references and footnotes.

##### Constructor

```dart
const AnchorIdExtension()
```

This extension automatically wraps all HTML elements with an `id` attribute in a GestureDetector with an AnchorKey, enabling `flutter_html`'s built-in anchor scrolling to work bidirectionally.

---

## Dictionary Readers

### 1. `lib/core/parser/dict_reader.dart`

#### Class: `DictReader`

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

##### Property: `source`

```dart
final RandomAccessSource source
```

The random access source for reading.

##### Property: `path`

```dart
final String path
```

The file path.

##### Property: `dictId`

```dart
final int? dictId
```

Optional dictionary ID.

##### Property: `isDz`

```dart
bool get isDz
```

True for .dict.dz files; false for plain .dict.

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

---

### 2. `lib/core/parser/mdict_reader.dart`

#### Class: `MdictReader`

Reads MDict dictionary files (.mdx, .mdd).

##### Fields

| Field | Type | Description |
|-------|------|-------------|
| `mdxPath` | `String` | Path to MDX file |
| `source` | `RandomAccessSource` | Random access source |
| `name` | `String?` | Optional name for the reader |
| `cssContent` | `String?` | CSS content from style.css |
| `hasMdd` | `bool` | Whether MDD resource file is attached |

##### Constructor

```dart
MdictReader(String mdxPath, {required RandomAccessSource source, String? mddPath, String? name})
```

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

---

### 2. `lib/core/parser/mdd_reader.dart`

#### Class: `MddReader`

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

##### Static Method: `fromPath`

Creates an MddReader from a file path.

| Parameter | Type | Description |
|-----------|------|-------------|
| `path` | `String` | Path to the MDD file |

**Returns:** `Future<MddReader>` - A new MddReader instance.

##### Static Method: `fromUri`

Creates an MddReader from a URI.

| Parameter | Type | Description |
|-----------|------|-------------|
| `uri` | `Uri` | URI to the MDD file |

**Returns:** `Future<MddReader>` - A new MddReader instance.

##### Static Method: `fromLinkedSource`

Creates an MddReader from a linked source.

| Parameter | Type | Description |
|-----------|------|-------------|
| `reader` | `RandomAccessSource` | Random access source |

**Returns:** `Future<MddReader>` - A new MddReader instance.

---

### 3. `lib/core/parser/slob_reader.dart`

#### Class: `SlobReader`

Reads SLOB (Sorted List of Blobs) dictionary files.

##### Fields

| Field | Type | Description |
|-------|------|-------------|
| `path` | `String` | File path |
| `source` | `RandomAccessSource` | Random access source |
| `fileSize` | `int` | File size of the dictionary |

##### Constructor

```dart
SlobReader(String path, {required RandomAccessSource source})
```

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

---

### 4. `lib/core/parser/dictd_reader.dart`

#### Class: `DictdReader`

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

---

### 5. `lib/core/parser/ifo_parser.dart`

#### Class: `IfoParser`

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

### 6. `lib/core/parser/idx_parser.dart`

#### Class: `IdxParser`

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

**Returns:** `Stream<Map<String, dynamic>>` - Stream of word entries.

##### Method: `parseFromBytes`

Parses from raw bytes.

| Parameter | Type | Description |
|-----------|------|-------------|
| `bytes` | `Uint8List` | Raw IDX file bytes |

**Returns:** `Stream<Map<String, dynamic>>` - Stream of word entries.

---

### 7. `lib/core/parser/syn_parser.dart`

#### Class: `SynParser`

Parses StarDict .syn files.

##### Static Method: `parse`

Parses a SYN file.

| Parameter | Type | Description |
|-----------|------|-------------|
| `content` | `String` | The SYN file content |

**Returns:** `List<Map<String, dynamic>>` - List of synonym entries.

---

## Models

### 1. `lib/core/models/stardict_dictionary.dart`

#### Class: `StardictDictionary`

Represents a StarDict dictionary available for download.

##### Fields

| Field | Type | Description |
|-------|------|-------------|
| `sourceLanguageCode` | `String` | ISO 639-2 source language code |
| `targetLanguageCode` | `String` | ISO 639-2 target language code |
| `sourceLanguageName` | `String` | Computed source language name |
| `targetLanguageName` | `String` | Computed target language name |
| `name` | `String` | Dictionary name |
| `url` | `String` | Download URL |
| `headwords` | `String` | Number of headwords |
| `version` | `String` | Version string |
| `date` | `String` | Release date |
| `releases` | `List<StardictRelease>` | Available releases |

---

### 2. `lib/core/models/stardict_release.dart`

#### Class: `StardictRelease`

Represents a StarDict dictionary release.

##### Fields

| Field | Type | Description |
|-------|------|-------------|
| `url` | `String` | Download URL |
| `format` | `String` | Dictionary format |
| `size` | `String` | File size |
| `version` | `String` | Version string |
| `date` | `String` | Release date |

---

### 3. `lib/core/models/discovered_dict.dart`

#### Class: `DiscoveredDict`

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

##### Method: `toMap`

Converts the instance to a Map.

**Returns:** `Map<String, dynamic>`

##### Static Method: `fromMap`

Creates a DiscoveredDict from a Map.

| Parameter | Type | Description |
|-----------|------|-------------|
| `map` | `Map<String, dynamic>` | Map to convert |

**Returns:** `DiscoveredDict`

---

### 4. `lib/core/models/incomplete_dict.dart`

#### Class: `IncompleteDict`

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

##### Method: `toMap`

Converts the instance to a Map.

**Returns:** `Map<String, dynamic>`

##### Static Method: `fromMap`

Creates an IncompleteDict from a Map.

| Parameter | Type | Description |
|-----------|------|-------------|
| `map` | `Map<String, dynamic>` | Map to convert |

**Returns:** `IncompleteDict`

---

### 5. `lib/core/models/dictionary_group.dart`

#### Class: `DictionaryGroup`

Represents a group of dictionaries.

##### Fields

| Field | Type | Description |
|-------|------|-------------|
| `id` | `String` | Unique group identifier |
| `name` | `String` | Display name |
| `dictIds` | `List<int>` | List of dictionary IDs in this group |

---

### 6. `lib/core/models/deletion_progress.dart`

#### Class: `DeletionProgress`

Represents the progress of dictionary deletion.

##### Fields

| Field | Type | Description |
|-------|------|-------------|
| `value` | `double` | Progress value (0.0 to 1.0) |
| `message` | `String` | Progress message |
| `isCompleted` | `bool` | Whether operation is completed |
| `error` | `String?` | Error message if any |

---

### 7. `lib/core/models/import_progress.dart`

#### Class: `ImportProgress`

Represents the progress of dictionary import.

##### Fields

| Field | Type | Description |
|-------|------|-------------|
| `value` | `double` | Progress value (0.0 to 1.0) |
| `message` | `String` | Progress message |
| `isCompleted` | `bool` | Whether operation is completed |
| `dictId` | `int?` | ID of imported dictionary |
| `error` | `String?` | Error message if any |
| `ifoPath` | `String?` | Path to IFO file |
| `sampleWords` | `List<String>?` | Sample words from dictionary |
| `headwordCount` | `int` | Number of headwords |
| `definitionWordCount` | `int` | Number of words in definitions |
| `dictionaryName` | `String?` | Dictionary display name |
| `groupName` | `String?` | Group name for the dictionary |
| `incompleteEntries` | `List<String>?` | Skipped due to missing files |
| `linkedEntries` | `List<String>?` | Linked dictionaries |
| `importedEntries` | `List<String>?` | Imported dictionaries |
| `alreadyExistsEntries` | `List<String>?` | Already existing entries |

---

### 8. `lib/core/models/folder_scan_result.dart`

#### Class: `FolderScanResult`

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

##### Method: `toMap`

Converts the instance to a Map.

**Returns:** `Map<String, dynamic>`

##### Static Method: `fromMap`

Creates a FolderScanResult from a Map.

| Parameter | Type | Description |
|-----------|------|-------------|
| `map` | `Map<String, dynamic>` | Map to convert |

**Returns:** `FolderScanResult`

---

## Providers

### 1. `lib/features/settings/settings_provider.dart`

#### Class: `SettingsProvider`

Manages application settings using SharedPreferences.

See [SettingsProvider API](private.md#1-libfeaturessettingssettings_providerdart) for public methods.

---

### 2. `lib/core/benchmark.dart`

#### Class: `HBenchmark`

Performance benchmarking utility.

##### Static Method: `runLookupBenchmark`

Runs a lookup benchmark.

| Parameter | Type | Description |
|-----------|------|-------------|
| `wordsPerDict` | `int` | Number of words to lookup per dictionary (default: 20) |

**Returns:** `Future<String>` - Benchmark report string.

---

### 3. `lib/core/hperf.dart`

#### Class: `HPerf`

Performance measurement utility.

##### Static Method: `start`

Starts a performance timer.

| Parameter | Type | Description |
|-----------|------|-------------|
| `name` | `String` | Timer name |

**Returns:** `Stopwatch?` - A stopwatch for the timer.

##### Static Method: `end`

Ends a performance timer.

| Parameter | Type | Description |
|-----------|------|-------------|
| `sw` | `Stopwatch?` | The stopwatch from start() |
| `name` | `String` | Timer name |

**Returns:** `void`

##### Static Method: `reset`

Resets all performance data.

##### Static Method: `dump`

Prints all performance data to console.

| Parameter | Type | Description |
|-----------|------|-------------|
| `prefix` | `String` | Prefix for output |

**Returns:** `void`

##### Static Method: `record`

Records a value.

| Parameter | Type | Description |
|-----------|------|-------------|
| `name` | `String` | Metric name |
| `ms` | `int` | Milliseconds value |

##### Static Method: `recordUs`

Records a microsecond value.

| Parameter | Type | Description |
|-----------|------|-------------|
| `name` | `String` | Metric name |
| `us` | `int` | Microseconds value |

---

## Main App

### 1. `lib/main.dart`

#### Class: `MyApp`

The main application widget.

---

### 2. `lib/core/utils/app_theme.dart`

#### Class: `AppTheme`

Theme configuration utility.

##### Static Method: `getTheme`

Gets a theme based on brightness and font family.

| Parameter | Type | Description |
|-----------|------|-------------|
| `brightness` | `Brightness` | Theme brightness (light or dark) |
| `fontFamily` | `String` | Font family name |

**Returns:** `ThemeData` - The configured theme.



---

## Screens

### 1. `lib/features/home/home_screen.dart`

#### Class: `HomeScreen`

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

##### Class: `EntryToProcess`

Represents an entry to be processed with its content and metadata.

##### Fields

| Field | Type | Description |
|-------|------|-------------|
| `index` | `int` | Original index in SQLite results |
| `content` | `String` | The definition content |
| `word` | `String` | The headword |
| `format` | `String` | Dictionary format |
| `typeSequence` | `String?` | Optional type sequence |

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

---

### 2. `lib/features/settings/settings_screen.dart`

#### Class: `SettingsScreen`

Settings screen for configuring the app.

---

### 3. `lib/features/bookmarks/bookmarks_screen.dart`

#### Class: `BookmarkManager`

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

### 4. `lib/features/flash_cards/flash_cards_screen.dart`

#### Class: `FlashCardsScreen`

Flash cards screen for vocabulary learning.

---

### 5. `lib/features/dictionary_management/dictionary_management_screen.dart`

#### Class: `DictionaryManagementScreen`

Dictionary management screen.

---

### 6. `lib/features/dictionary_groups/dictionary_groups_screen.dart`

#### Class: `DictionaryGroupsScreen`

Dictionary groups management screen.

---

### 7. `lib/features/search_history/search_history_screen.dart`

#### Class: `SearchHistoryScreen`

Search history screen.

---

### 8. `lib/features/score_history/score_history_screen.dart`

#### Class: `ScoreHistoryScreen`

Score history screen.

---

### 9. `lib/features/drawer/about_screen.dart`

#### Class: `AboutScreen`

About app screen.

---

### 10. `lib/features/drawer/manual_screen.dart`

#### Class: `ManualScreen`

User manual screen.

---

### 11. `lib/features/drawer/support_screen.dart`

#### Class: `SupportScreen`

Support/help screen.

---

### 12. `lib/features/drawer/app_drawer.dart`

#### Class: `AppDrawer`

Navigation drawer widget.

---

### 13. `lib/features/home/home_screen.dart`

#### Class: `MddVideoHtmlExtension`

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

##### Method: `build`

Builds an InlineSpan for video elements.

| Parameter | Type | Description |
|-----------|------|-------------|
| `context` | `ExtensionContext` | HTML extension context |

**Returns:** `dynamic` - WidgetSpan containing video player or Container.

---

## Utils

### 1. `lib/core/bookmark_manager.dart`

#### Class: `BookmarkRandomAccessSource`

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

### 2. `lib/core/saf_random_access_source.dart`

#### Class: `SafRandomAccessSource`

Random access source for Storage Access Framework.

##### Property: `length`

```dart
int get length
```

Returns the length of the content.

---

### 3. `lib/core/dictionary_manager.dart`

#### Class: `DictionaryManager`

Manages dictionary readers.

##### Static Method: `clearReaderCache`

Clears all cached dictionary readers.

##### Static Method: `closeReader`

Closes a specific dictionary reader.

| Parameter | Type | Description |
|-----------|------|-------------|
| `dictId` | `int` | Dictionary ID |

---

### 4. `lib/core/dictionary_group_manager.dart`

#### Class: `DictionaryGroupManager`

Manages dictionary groups stored in SharedPreferences.

##### Static Method: `addDictionaryToGroup`

Adds a dictionary to a group.

| Parameter | Type | Description |
|-----------|------|-------------|
| `groupName` | `String` | Group name |
| `dictId` | `int` | Dictionary ID |

**Returns:** `Future<void>`

##### Static Method: `autoGenerateGroupsFromDownloaded`

Auto-generates groups from downloaded dictionaries.

| Parameter | Type | Description |
|-----------|------|-------------|
| `installedDicts` | `List<Map<String, dynamic>>` | List of installed dictionaries |

**Returns:** `Future<void>`

##### Static Method: `createCustomGroup`

Creates a custom group.

| Parameter | Type | Description |
|-----------|------|-------------|
| `groupName` | `String` | Group name |

**Returns:** `Future<void>`

##### Static Method: `deleteGroup`

Deletes a group.

| Parameter | Type | Description |
|-----------|------|-------------|
| `groupId` | `String` | Group ID |

**Returns:** `Future<void>`

##### Static Method: `getGroups`

Gets all groups.

**Returns:** `Future<List<DictionaryGroup>>` - List of groups.

##### Static Method: `isGroupActive`

Checks if a group is active.

| Parameter | Type | Description |
|-----------|------|-------------|
| `groupId` | `String` | Group ID |

**Returns:** `Future<bool>` - True if the group is active.

##### Static Method: `removeDictionaryFromAllGroups`

Removes a dictionary from all groups.

| Parameter | Type | Description |
|-----------|------|-------------|
| `dictId` | `int` | Dictionary ID |

**Returns:** `Future<void>`

##### Static Method: `removeDictionaryFromGroup`

Removes a dictionary from a group.

| Parameter | Type | Description |
|-----------|------|-------------|
| `groupId` | `String` | Group ID |
| `dictId` | `int` | Dictionary ID |

**Returns:** `Future<void>`

##### Static Method: `saveGroups`

Saves groups to storage.

| Parameter | Type | Description |
|-----------|------|-------------|
| `groups` | `List<DictionaryGroup>` | List of groups to save |

**Returns:** `Future<void>`

##### Static Method: `toggleGroup`

Toggles a group's active state.

| Parameter | Type | Description |
|-----------|------|-------------|
| `groupId` | `String` | Group ID |
| `enable` | `bool` | Enable or disable |

**Returns:** `Future<void>`

---

### 5. `lib/core/stardict_service.dart`

#### Class: `StardictService`

Service for StarDict dictionary operations.

---

## Database

### 1. `lib/core/database_helper.dart`

#### Class: `DatabaseHelper`

Database helper for SQLite operations.

##### Property: `database`

```dart
Database get database
```

Returns the database instance.

##### Static Method: `initializeDatabaseFactory`

Initializes the database factory for the current platform.

**Returns:** `Future<void>`

##### Method: `setDatabase`

Sets the database instance.

| Parameter | Type | Description |
|-----------|------|-------------|
| `db` | `Database` | Database instance |

---

## Screens

### 1. `lib/features/result/result_screen.dart`

#### Class: `ResultScreen`

Screen for displaying search results.

---

## Dialogs

### 1. `lib/features/dictionary_management/stardict_download_dialog.dart`

#### Class: `StardictDownloadDialog`

Dialog for downloading StarDict dictionaries.

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
│   └── sqflite FTS5 queries
├── DictionaryManager.fetchDefinitionsBatch
│   ├── DictionaryManager._getReader
│   │   ├── MdictReader.fromPath / .fromLinkedSource / .fromUri
│   │   ├── SlobReader.fromPath / .fromLinkedSource / .fromUri
│   │   ├── DictReader.fromPath / .fromLinkedSource / .fromUri
│   │   └── DictdReader.fromPath / .fromLinkedSource / .fromUri
│   └── DictReader/MdictReader/SlobReader/DictdReader.readAtIndex/readBulk
├── HomeScreen.consolidateDefinitions
│   └── DatabaseHelper.getDictionaryById
└── HtmlLookupWrapper.processRecord

DictionaryManager.importDictionaryStream
├── _extractToWorkspace
│   └── _extractToWorkspaceSync
│       └── GZipDecoder / BZip2Decoder / XZDecoder / SZArchive.extract
├── scanFolderForDictionaries
│   └── FolderScanner._extractArchiveToDir
└── _processDictionaryFiles
    ├── IfoParser
    ├── IdxParser
    ├── SynParser
    └── DatabaseHelper.batchInsertWords
        └── DatabaseHelper.startBatchInsert / .endBatchInsert

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
├── sqflite database queries (FTS5 or fallback)
└── DatabaseHelper._queryCache (LRU)

HtmlLookupWrapper.processRecord
└── logger.hDebugPrint (showHtmlProcessing check)

MultimediaProcessor.processHtmlWithMedia
├── MddReader.getMddResourceBytes
├── MultimediaProcessor._replaceImgSrcWithDataUris
└── MultimediaProcessor._addMediaTapHandlers
    └── MultimediaProcessor.injectCss

FlashCardsScreen._startQuiz
├── DatabaseHelper.getBatchSampleWords
│   ├── DatabaseHelper._ensureDictionaryMapCache
│   └── Random.sample
└── DictionaryManager.instance.fetchDefinition

StardictService.refreshDictionaries
├── http.get (package)
├── DatabaseHelper.insertFreedictDictionaries
└── StardictDictionary.fromTsvRow

DictionaryGroupManager.autoGenerateGroupsFromDownloaded
├── StardictService.fetchDictionaries
│   └── DatabaseHelper.getFreedictDictionaries
└── StardictService.refreshDictionaries
```

---

*Last updated: March 2026*
