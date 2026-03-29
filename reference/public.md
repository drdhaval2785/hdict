# Public API Reference (version 1.5.11)

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

##### Method: `injectCss`

Injects CSS content into HTML by inserting a style tag in the head or body.

| Parameter | Type | Description |
|-----------|------|-------------|
| `html` | `String` | The HTML content to inject CSS into |

**Returns:** `String` - HTML with CSS injected.

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

### 2. `lib/core/parser/mdict_reader.dart`

#### Class: `MdictReader`

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

---

### 3. `lib/core/parser/slob_reader.dart`

#### Class: `SlobReader`

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

**Returns:** `Future<Stream<Map<String, dynamic>>>` - Stream of word entries.

##### Method: `parseFromBytes`

Parses from raw bytes.

| Parameter | Type | Description |
|-----------|------|-------------|
| `bytes` | `Uint8List` | Raw IDX file bytes |

**Returns:** `Future<Stream<Map<String, dynamic>>>` - Stream of word entries.

---

### 7. `lib/core/parser/syn_parser.dart`

#### Class: `SynParser`

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

## Models

### 1. `lib/core/models/stardict_dictionary.dart`

#### Class: `StardictDictionary`

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

### 2. `lib/core/models/stardict_release.dart`

#### Class: `StardictRelease`

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

### 5. `lib/core/models/dictionary_group.dart`

#### Class: `DictionaryGroup`

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

### 6. `lib/core/models/deletion_progress.dart`

#### Class: `DeletionProgress`

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

### 7. `lib/core/models/import_progress.dart`

#### Class: `ImportProgress`

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

## Providers

### 1. `lib/features/settings/settings_provider.dart`

#### Class: `SettingsProvider`

Manages application settings using SharedPreferences.

##### Property: `isShowSearchSuggestionsEnabled`

```dart
bool get isShowSearchSuggestionsEnabled
```

Whether search suggestions (autocomplete) are enabled. Default: `true`.

##### Property: `isSearchAsYouTypeEnabled`

```dart
bool get isSearchAsYouTypeEnabled
```

Whether "Search As You Type" in definitions is enabled. Default: `true`.

See [SettingsProvider API](private.md#1-libfeaturessettingssettings_providerdart) for additional public methods.

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

### 14. `lib/core/utils/debouncer.dart`

#### Class: `Debouncer`

A utility class for debouncing function calls.

##### Constructor

```dart
Debouncer({int milliseconds = 250})
```

| Parameter | Type | Description |
|-----------|------|-------------|
| `milliseconds` | `int` | Debounce delay in milliseconds (default: 250) |

##### Property: `isActive`

```dart
bool get isActive
```

Returns true if the debouncer has an active timer.

##### Property: `milliseconds`

```dart
int get milliseconds
```

Returns the debounce delay in milliseconds.

##### Method: `run`

Runs the action after the debounce delay.

| Parameter | Type | Description |
|-----------|------|-------------|
| `action` | `void Function()` | The action to run |

##### Method: `cancel`

Cancels the pending action.

##### Method: `dispose`

Disposes the debouncer and cancels any pending action.

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

##### Method: `addFlashCardScore`

Adds a flash card score to the database.

| Parameter | Type | Description |
|-----------|------|-------------|
| `score` | `int` | The score achieved |
| `total` | `int` | Total possible points |
| `dictIds` | `String` | Comma-separated dictionary IDs used |

**Returns:** `Future<void>`

##### Method: `addSearchHistory`

Adds a search term to the search history.

| Parameter | Type | Description |
|-----------|------|-------------|
| `word` | `String` | The search word |
| `searchType` | `String` | Search type (default: 'Headword Search') |

**Returns:** `Future<void>`

##### Method: `clearDictionaryCache`

Clears the in-memory dictionary metadata cache.

**Returns:** `void`

##### Method: `clearFreedictDictionaries`

Clears all FreeDict dictionaries from the cache.

**Returns:** `Future<void>`

##### Method: `clearQueryCache`

Clears the query result cache.

**Returns:** `void`

##### Method: `clearSearchHistory`

Clears all search history.

**Returns:** `Future<void>`

##### Method: `deleteDictionary`

Deletes a dictionary and all associated data from the database.

| Parameter | Type | Description |
|-----------|------|-------------|
| `id` | `int` | Dictionary ID to delete |

**Returns:** `Future<void>`

##### Method: `deleteOldSearchHistory`

Deletes search history older than specified days.

| Parameter | Type | Description |
|-----------|------|-------------|
| `days` | `int` | Number of days to keep |

**Returns:** `Future<void>`

##### Method: `deleteWordsByDictionaryId`

Deletes all words for a specific dictionary.

| Parameter | Type | Description |
|-----------|------|-------------|
| `dictId` | `int` | Dictionary ID |

**Returns:** `Future<void>`

##### Method: `enableBulkInsertMode`

Enables bulk insert mode by setting PRAGMA synchronous to OFF and increasing cache size for faster batch inserts.

**Returns:** `Future<void>`

##### Method: `endBatchInsert`

Ends batch insert mode and restores normal PRAGMA settings.

**Returns:** `Future<void>`

##### Method: `getDatabaseSize`

Gets the total size of the database files.

**Returns:** `Future<int>` - Database size in bytes.

##### Method: `getEnabledDictionaries`

Gets all enabled dictionaries.

**Returns:** `Future<List<Map<String, dynamic>>>` - List of enabled dictionaries.

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

##### Method: `getSafScanCache`

Gets cached SAF scan data for a tree URI.

| Parameter | Type | Description |
|-----------|------|-------------|
| `treeUri` | `String` | Tree URI |

**Returns:** `Future<String?>` - Cached scan data as JSON, or null if not found.

##### Method: `getSampleWords`

Gets random sample words from a dictionary.

| Parameter | Type | Description |
|-----------|------|-------------|
| `dictId` | `int` | Dictionary ID |
| `limit` | `int` | Maximum number of words (default: 5) |

**Returns:** `Future<List<Map<String, dynamic>>>` - List of sample word entries.

##### Method: `getWordCountForDict`

Gets the word count for a specific dictionary.

| Parameter | Type | Description |
|-----------|------|-------------|
| `dictId` | `int` | Dictionary ID |

**Returns:** `Future<int>` - Word count.

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

##### Method: `insertFreedictDictionaries`

Inserts FreeDict dictionaries into the cache.

| Parameter | Type | Description |
|-----------|------|-------------|
| `dictionaries` | `List<Map<String, dynamic>>` | List of dictionaries to insert |

**Returns:** `Future<void>`

##### Method: `isDictionaryUrlDownloaded`

Checks if a dictionary URL has already been downloaded.

| Parameter | Type | Description |
|-----------|------|-------------|
| `url` | `String` | Source URL to check |

**Returns:** `Future<bool>` - True if already downloaded.

##### Method: `optimizeDatabase`

Optimizes the database by running VACUUM and FTS5 optimize.

**Returns:** `Future<void>`

##### Method: `rebuildFts5IndexForDict`

Rebuilds the FTS5 index for a specific dictionary.

| Parameter | Type | Description |
|-----------|------|-------------|
| `dictId` | `int` | Dictionary ID |

**Returns:** `Future<void>`

##### Method: `reorderDictionaries`

Reorders dictionaries based on the provided list of IDs.

| Parameter | Type | Description |
|-----------|------|-------------|
| `sortedIds` | `List<int>` | List of dictionary IDs in new order |

**Returns:** `Future<void>`

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

##### Method: `saveSafScanCache`

Saves SAF scan data to the cache.

| Parameter | Type | Description |
|-----------|------|-------------|
| `treeUri` | `String` | Tree URI |
| `scanDataJson` | `String` | Scan data as JSON |

**Returns:** `Future<void>`

##### Method: `startBatchInsert`

Starts batch insert mode and returns the current maximum ID.

**Returns:** `Future<int>` - Current maximum word_metadata ID.

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

##### Method: `updateDictionaryRowIdRange`

Updates the rowid range for a dictionary.

| Parameter | Type | Description |
|-----------|------|-------------|
| `id` | `int` | Dictionary ID |
| `start` | `int` | Start rowid |
| `end` | `int` | End rowid |

**Returns:** `Future<void>`

##### Method: `updateDictionaryWordCount`

Updates the word count for a dictionary.

| Parameter | Type | Description |
|-----------|------|-------------|
| `id` | `int` | Dictionary ID |
| `wordCount` | `int` | Number of words |
| `definitionWordCount` | `int?` | Optional definition word count |

**Returns:** `Future<void>`

##### Method: `clearSafScanCache`

Clears the SAF scan cache.

| Parameter | Type | Description |
|-----------|------|-------------|
| `treeUri` | `String` | Tree URI to clear cache for |

**Returns:** `Future<void>`

##### Method: `getBatchSampleWords`

Gets a batch of random sample words from enabled dictionaries for flash cards.

| Parameter | Type | Description |
|-----------|------|-------------|
| `totalCount` | `int` | Total number of words to retrieve |
| `dictIds` | `List<int>` | List of dictionary IDs to sample from |

**Returns:** `Future<List<Map<String, dynamic>>>`

##### Method: `getDictionaries`

Gets all dictionaries.

**Returns:** `Future<List<Map<String, dynamic>>>` - List of all dictionaries.

##### Method: `getDictionaryByChecksum`

Gets a dictionary by its checksum.

| Parameter | Type | Description |
|-----------|------|-------------|
| `checksum` | `String` | Dictionary checksum |

**Returns:** `Future<Map<String, dynamic>?>` - Dictionary data or null.

##### Method: `getDictionaryById`

Gets a dictionary by its ID.

| Parameter | Type | Description |
|-----------|------|-------------|
| `id` | `int` | Dictionary ID |

**Returns:** `Future<Map<String, dynamic>?>` - Dictionary data or null.

##### Method: `getDictionaryByIdSync`

Synchronously gets a dictionary by its ID from the cache.

| Parameter | Type | Description |
|-----------|------|-------------|
| `id` | `int` | Dictionary ID |

**Returns:** `Map<String, dynamic>?` - Dictionary data or null.

##### Method: `getFlashCardScores`

Gets flash card scores from the database.

**Returns:** `Future<List<Map<String, dynamic>>>`

##### Method: `getFreedictDictionaries`

Gets cached FreeDict dictionaries.

**Returns:** `Future<List<Map<String, dynamic>>>` - List of FreeDict dictionaries.

##### Method: `getSearchHistory`

Gets search history from the database.

**Returns:** `Future<List<Map<String, dynamic>>>`

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
