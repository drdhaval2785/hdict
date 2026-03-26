# Private API Reference (version 0.1.0)

This document lists all private classes, functions, methods, and fields in the HDict codebase. These are implementation details not intended for external use.

---

## Table of Contents

1. [Settings](#settings)
2. [Home Screen](#home-screen)
3. [Dictionary Management](#dictionary-management)
4. [Flash Cards](#flash-cards)
5. [Search History](#search-history)
6. [Score History](#score-history)
7. [Bookmark Management](#bookmark-management)
8. [Media Players](#media-players)
9. [Video Widgets](#video-widgets)
10. [Helper Classes](#helper-classes)

---

## Settings

### 1. `lib/features/settings/settings_provider.dart`

#### Private Static Fields

##### `_keyHeadwordColor`

```dart
static const String _keyHeadwordColor = 'headword_color';
```

Key for storing headword color preference.

##### `_keyTextColor`

```dart
static const String _keyTextColor = 'text_color';
```

Key for storing text color preference.

##### `_keyBackgroundColor`

```dart
static const String _keyBackgroundColor = 'background_color';
```

Key for storing background color preference.

##### `_keyFontSize`

```dart
static const String _keyFontSize = 'font_size';
```

Key for storing font size preference.

##### `_keyThemeMode`

```dart
static const String _keyThemeMode = 'theme_mode';
```

Key for storing theme mode preference.

##### `_keyHeadwordSearchMode`

```dart
static const String _keyHeadwordSearchMode = 'headword_search_mode';
```

Key for storing headword search mode preference.

##### `_keyTapOnMeaningEnabled`

```dart
static const String _keyTapOnMeaningEnabled = 'tap_on_meaning_enabled';
```

Key for storing tap on meaning setting.

##### `_keyOpenPopupOnTap`

```dart
static const String _keyOpenPopupOnTap = 'open_popup_on_tap';
```

Key for storing open popup on tap setting.

##### `_keyReviewPromptCount`

```dart
static const String _keyReviewPromptCount = 'review_prompt_count';
```

Key for storing review prompt count.

##### `_keyHasGivenReview`

```dart
static const String _keyHasGivenReview = 'has_given_review';
```

Key for storing whether user has given review.

##### `_keyListMode`

```dart
static const String _keyListMode = 'list_mode';
```

Key for storing list mode setting.

---

## Home Screen

### 1. `lib/features/home/home_screen.dart`

#### Class: `_HomeScreenState`

The state class for HomeScreen.

##### Private Instance Fields

###### `_selectedWord`

```dart
String? _selectedWord;
```

The currently selected word.

###### `_currentDefinitions`

```dart
List<Map<String, dynamic>> _currentDefinitions = [];
```

The current search results.

###### `_isLoading`

```dart
bool _isLoading = false;
```

Whether a search is in progress.

###### `_hasDictionaries`

```dart
bool _hasDictionaries = false;
```

Whether any dictionaries are installed.

###### `_checkingDicts`

```dart
bool _checkingDicts = true;
```

Whether dictionary check is in progress.

###### `_tabController`

```dart
TabController? _tabController;
```

Controller for the dictionary tab bar.

###### `_headwordController`

```dart
TextEditingController _headwordController = TextEditingController();
```

Controller for headword search input.

###### `_defController`

```dart
TextEditingController _defController = TextEditingController();
```

Controller for definition search input.

###### `_searchSqliteMs`

```dart
int? _searchSqliteMs;
```

SQLite query time in milliseconds.

###### `_searchOtherMs`

```dart
int? _searchOtherMs;
```

Other processing time in milliseconds.

###### `_searchTotalMs`

```dart
int? _searchTotalMs;
```

Total search time in milliseconds.

###### `_searchResultCount`

```dart
int? _searchResultCount;
```

Number of search results.

###### `_lastHeadwordQuery`

```dart
String? _lastHeadwordQuery;
```

Last headword search query.

###### `_lastDefinitionQuery`

```dart
String? _lastDefinitionQuery;
```

Last definition search query.

###### `_isPopupOpen`

```dart
bool _isPopupOpen = false;
```

Whether a popup is currently open.

##### Private Instance Methods

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

###### `consolidateDefinitions`

Static method to consolidate definitions.

###### `normalizeWhitespace`

Static method to normalize whitespace.

---

#### Class: `_MdictDefinitionContent`

Widget for MDict definition content.

##### Private Instance Fields

###### `_isProcessing`

```dart
bool _isProcessing = false;
```

Whether multimedia is being processed.

###### `_rawDefinitions`

```dart
late List<Map<String, dynamic>> _rawDefinitions;
```

Raw definitions data.

##### Private Instance Methods

###### `_processMultimedia`

Processes multimedia content.

###### `_buildAccordionItem`

Builds an accordion item for list mode.

###### `_buildDefinitionContentSync`

Builds definition content synchronously.

---

#### Class: `_MdictDefinitionContentState`

State class for `_MdictDefinitionContent` widget.

##### Private Instance Fields

###### `_isProcessing`

```dart
bool _isProcessing = false;
```

Whether multimedia is being processed.

###### `_rawDefinitions`

```dart
late List<Map<String, dynamic>> _rawDefinitions;
```

Raw definitions data.

##### Private Instance Methods

###### `_processMultimedia`

Processes multimedia content including video from MDD resources.

---

#### Class: `_MediaPlayerDialog`

Dialog for playing audio/video media.

##### Private Instance Fields

###### `_audioPlayer`

```dart
AudioPlayer? _audioPlayer;
```

Audio player instance.

###### `_videoController`

```dart
VideoPlayerController? _videoController;
```

Video player controller.

###### `_isLoading`

```dart
bool _isLoading = true;
```

Whether media is loading.

###### `_error`

```dart
String? _error;
```

Error message if any.

###### `_tempFilePath`

```dart
String? _tempFilePath;
```

Temporary file path for media.

##### Private Instance Methods

###### `_initPlayer`

Initializes the media player.

###### `_formatDuration`

Formats duration for display.

---

## Dictionary Management

### 1. `lib/features/dictionary_management/dictionary_management_screen.dart`

#### Class: `_DictionaryManagementScreenState`

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

---

### 2. `lib/features/dictionary_groups/dictionary_groups_screen.dart`

#### Class: `_DictionaryGroupsScreenState`

The state class for DictionaryGroupsScreen.

##### Private Instance Methods

###### `_loadGroups`

Loads dictionary groups from storage.

---

## Flash Cards

### 1. `lib/features/flash_cards/flash_cards_screen.dart`

#### Class: `_FlashCardsScreenState`

The state class for FlashCardsScreen.

##### Private Instance Fields

###### `_score`

```dart
int _score = 0;
```

Current score.

###### `_index`

```dart
int _index = 0;
```

Current card index.

##### Private Instance Methods

###### `_loadCards`

Loads flash cards.

---

## Search History

### 1. `lib/features/search_history/search_history_screen.dart`

#### Class: `_SearchHistoryScreenState`

The state class for SearchHistoryScreen.

##### Private Instance Methods

###### `_loadHistory`

Loads search history from database.

###### `_clearHistory`

Clears all search history.

---

## Score History

### 1. `lib/features/score_history/score_history_screen.dart`

#### Class: `_ScoreHistoryScreenState`

The state class for ScoreHistoryScreen.

##### Private Instance Methods

###### `_loadScores`

Loads score history from database.

---

## Media Players

### 1. `lib/features/home/home_screen.dart`

#### Class: `_MediaPlayerDialogState`

##### Private Instance Fields

###### `_audioPlayer`

```dart
AudioPlayer? _audioPlayer;
```

Audio player instance.

###### `_videoController`

```dart
VideoPlayerController? _videoController;
```

Video player controller.

---

## Import/Export

### 1. `lib/features/dictionary_management/dictionary_management_screen.dart`

#### Class: `_ImportArgs`

Arguments for import operation.

##### Fields

| Field | Type | Description |
|-------|------|-------------|
| `folderPath` | `String` | Path to folder |
| `newDicts` | `List<DiscoveredDict>` | New dictionaries found |

#### Class: `_IndexArgs`

Arguments for indexing operation.

##### Fields

| Field | Type | Description |
|-------|------|-------------|
| `source` | `DiscoveredDict` | Source dictionary |
| `destId` | `int?` | Destination ID |

#### Class: `_IndexMdictArgs`

Arguments for MDict indexing.

##### Fields

| Field | Type | Description |
|-------|------|-------------|
| `source` | `DiscoveredDict` | Source dictionary |
| `destId` | `int?` | Destination ID |
| `mdictReader` | `MdictReader` | MDict reader |

#### Class: `_IndexSlobArgs`

Arguments for SLOB indexing.

##### Fields

| Field | Type | Description |
|-------|------|-------------|
| `source` | `DiscoveredDict` | Source dictionary |
| `destId` | `int?` | Destination ID |
| `slobReader` | `SlobReader` | SLOB reader |

#### Class: `_IndexDictdArgs`

Arguments for Dictd indexing.

##### Fields

| Field | Type | Description |
|-------|------|-------------|
| `source` | `DiscoveredDict` | Source dictionary |
| `destId` | `int?` | Destination ID |
| `dictdReader` | `DictdReader` | Dictd reader |

#### Class: `_EntryToProcess`

Entry to be processed.

##### Fields

| Field | Type | Description |
|-------|------|-------------|
| `word` | `String` | Word |
| `offset` | `int` | Offset in dictionary |
| `length` | `int` | Entry length |
| `dictId` | `int` | Dictionary ID |

---

## Settings Screen

### 1. `lib/features/settings/settings_screen.dart`

#### Class: `_SettingsScreenState`

The state class for SettingsScreen.

##### Private Instance Methods

###### `_getPreviewTheme`

Gets preview theme for settings.

---

## Download Dialog

### 1. `lib/features/dictionary_management/stardict_download_dialog.dart`

#### Class: `_StardictDownloadDialogState`

The state class for StardictDownloadDialog.

##### Private Instance Methods

###### `_downloadAndImport`

Downloads and imports the dictionary.

---

## Video Widgets

### 1. `lib/features/home/home_screen.dart`

#### Class: `_MddVideoWidget`

Widget for playing MDD video resources in a dialog.

##### Private Instance Fields

| Field | Type | Description |
|-------|------|-------------|
| `resourceKey` | `String` | MDD resource key |
| `dictId` | `int` | Dictionary ID |
| `width` | `double?` | Video width |
| `height` | `double?` | Video height |
| `controls` | `bool` | Show controls (default: true) |
| `autoplay` | `bool` | Auto-play video (default: false) |
| `loop` | `bool` | Loop video (default: false) |

##### Private Instance Methods

###### `_loadVideo`

Loads video from MDD resource.

---

#### Class: `_MddVideoWidgetState`

State class for `_MddVideoWidget`.

##### Private Instance Fields

| Field | Type | Description |
|-------|------|-------------|
| `_videoController` | `VideoPlayerController?` | Video player controller |
| `_chewieController` | `ChewieController?` | Chewie controller |
| `_isLoading` | `bool` | Loading state |
| `_error` | `String?` | Error message |
| `_tempFilePath` | `String?` | Temporary file path |

---

#### Class: `_InlineVideoWidget`

Widget for playing inline video from MDD resources.

##### Private Instance Fields

| Field | Type | Description |
|-------|------|-------------|
| `resourceKey` | `String` | MDD resource key |
| `dictId` | `int` | Dictionary ID |

##### Private Instance Methods

###### `_loadVideo`

Loads video from MDD resource.

---

#### Class: `_InlineVideoWidgetState`

State class for `_InlineVideoWidget`.

##### Private Instance Fields

| Field | Type | Description |
|-------|------|-------------|
| `_controller` | `VideoPlayerController?` | Video player controller |
| `_isLoading` | `bool` | Loading state |
| `_error` | `String?` | Error message |
| `_tempFilePath` | `String?` | Temporary file path |

---

#### Class: `_VideoControls`

Stateless widget for video playback controls.

##### Private Instance Fields

| Field | Type | Description |
|-------|------|-------------|
| `controller` | `VideoPlayerController` | Video player controller |

##### Private Instance Methods

###### `_formatDuration`

Formats duration for display.

---

## Helper Classes

### 1. `lib/core/manager/dictionary_manager.dart`

#### Class: `_ExtractArgs`

Arguments class for archive extraction in isolate.

##### Fields

| Field | Type | Description |
|-------|------|-------------|
| `filePath` | `String` | Path to archive file |
| `workspacePath` | `String` | Destination workspace path |

---

## Private Constants

### `lib/core/database/database_helper.dart`

##### `_maxQueryCacheEntries`

```dart
static const int _maxQueryCacheEntries = 1000;
```

Maximum number of query cache entries.

---

### `lib/core/manager/dictionary_group_manager.dart`

##### `_key`

```dart
static const String _key = 'dictionary_groups';
```

Key for storing dictionary groups in SharedPreferences.

---

### `lib/core/manager/dictionary_manager.dart`

##### `_maxCacheEntries`

```dart
static const int _maxCacheEntries = 50;
```

Maximum number of reader cache entries.

---

### `lib/core/parser/mdd_reader.dart`

##### `_maxCacheEntries`

```dart
static const int _maxCacheEntries = 100;
```

Maximum number of resource cache entries.

---

### `lib/features/settings/services/stardict_service.dart`

##### `_tsvUrl`

```dart
static const String _tsvUrl = '...';
```

URL for the StarDict dictionary TSV file.

---

## Dependency Graph

Below is a dependency list showing which private modules depend on others:

```
hdict (private)
├── lib/core/
│   ├── database/
│   │   └── database_helper.dart
│   │       ├── lib/features/settings/settings_provider.dart
│   │       └── lib/core/utils/logger.dart
│   │
│   ├── manager/
│   │   ├── dictionary_manager.dart
│   │   │   ├── lib/core/database/database_helper.dart
│   │   │   ├── lib/core/parser/ifo_parser.dart
│   │   │   ├── lib/core/parser/idx_parser.dart
│   │   │   ├── lib/core/parser/syn_parser.dart
│   │   │   ├── lib/core/parser/dict_reader.dart
│   │   │   ├── lib/core/parser/mdict_reader.dart
│   │   │   ├── lib/core/parser/mdd_reader.dart
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
│   │       ├── lib/core/manager/dictionary_manager.dart
│   │       └── lib/features/settings/services/stardict_service.dart
│   │
│   ├── parser/
│   │   ├── ifo_parser.dart
│   │   │   ├── lib/core/parser/random_access_source.dart
│   │   │   └── lib/core/parser/saf_random_access_source.dart
│   │   │
│   │   ├── idx_parser.dart
│   │   │   ├── lib/core/parser/random_access_source.dart
│   │   │   └── lib/core/parser/ifo_parser.dart
│   │   │
│   │   ├── syn_parser.dart
│   │   │   └── lib/core/parser/random_access_source.dart
│   │   │
│   │   ├── dict_reader.dart
│   │   │   ├── lib/core/database/database_helper.dart
│   │   │   ├── lib/core/parser/random_access_source.dart
│   │   │   ├── lib/core/parser/saf_random_access_source.dart
│   │   │   └── lib/core/parser/bookmark_random_access_source.dart
│   │   │
│   │   ├── mdict_reader.dart
│   │   │   ├── lib/core/utils/logger.dart
│   │   │   ├── lib/core/parser/random_access_source.dart
│   │   │   ├── lib/core/parser/saf_random_access_source.dart
│   │   │   ├── lib/core/parser/bookmark_random_access_source.dart
│   │   │   └── lib/core/parser/mdd_reader.dart
│   │   │
│   │   ├── mdd_reader.dart
│   │   │   └── lib/core/parser/random_access_source.dart
│   │   │
│   │   ├── slob_reader.dart
│   │   │   ├── lib/core/parser/random_access_source.dart
│   │   │   ├── lib/core/parser/saf_random_access_source.dart
│   │   │   └── lib/core/parser/bookmark_random_access_source.dart
│   │   │
│   │   ├── dictd_reader.dart
│   │   │   ├── lib/core/parser/random_access_source.dart
│   │   │   ├── lib/core/parser/saf_random_access_source.dart
│   │   │   └── lib/core/parser/bookmark_random_access_source.dart
│   │   │
│   │   ├── bookmark_random_access_source.dart
│   │   │   ├── lib/core/parser/random_access_source.dart
│   │   │   └── lib/core/parser/bookmark_manager.dart
│   │   │
│   │   ├── saf_random_access_source.dart
│   │   │   └── lib/core/parser/random_access_source.dart
│   │   │
│   │   └── bookmark_manager.dart (standalone - no internal deps)
│   │
│   └── utils/
│       ├── benchmark_utils.dart
│       │   ├── lib/core/database/database_helper.dart
│       │   ├── lib/core/manager/dictionary_manager.dart
│       │   └── lib/core/utils/logger.dart
│       │
│       ├── folder_scanner.dart
│       │   └── lib/core/utils/logger.dart
│       │
│       ├── html_lookup_wrapper.dart
│       │   └── lib/core/utils/logger.dart
│       │
│       └── multimedia_processor.dart
│           ├── lib/core/parser/mdict_reader.dart
│           └── lib/core/utils/logger.dart
│
└── lib/features/
    ├── home/
    │   └── home_screen.dart
    │       ├── lib/core/utils/logger.dart
    │       ├── lib/core/database/database_helper.dart
    │       ├── lib/core/manager/dictionary_manager.dart
    │       ├── lib/core/utils/html_lookup_wrapper.dart
    │       ├── lib/core/utils/multimedia_processor.dart
    │       └── lib/features/settings/settings_provider.dart
    │
    └── settings/
        ├── services/
        │   └── stardict_service.dart
        │       ├── lib/core/database/database_helper.dart
        │       ├── lib/core/constants/iso_639_2_languages.dart
        │       └── lib/core/utils/logger.dart
        │
        └── widgets/
            └── stardict_download_dialog.dart
                └── lib/features/settings/services/stardict_service.dart
```

---

## Private Function-Level Dependencies

```
DictionaryManager._getReader
├── MdictReader._openMdict
│   ├── IfoParser.parseContent / .parseSource
│   └── MddReader._openMdd
├── SlobReader._openSlob
│   └── SlobReader.blobs
├── DictReader._openDict
│   ├── IfoParser.parseContent / .parseSource
│   ├── IdxParser (for .idx)
│   └── SynParser (for .syn)
└── DictdReader._connect

DictionaryManager._extractToWorkspace
├── GZipDecoder (dart:io)
├── BZip2Decoder (archive)
├── XZDecoder (archive)
├── SZArchive.extract (flutter_7zip)
└── FolderScanner._extractArchiveToDir

DatabaseHelper._ensureDictionaryMapCache
├── DatabaseHelper.database
└── sqflite queries

HtmlLookupWrapper._tagRegExp (private regex)
└── logger.hDebugPrint (showHtmlProcessing check)

MultimediaProcessor._replaceImgSrcWithDataUris
├── MddReader.getMddResourceBytes
└── MultimediaProcessor._base64EncodeImage

MultimediaProcessor._addMediaTapHandlers
├── MddReader.getCssContent
└── MultimediaProcessor._createMediaWidget

StardictService._fetchDictionariesFromUrl
├── http.get (package)
└── StardictDictionary.fromTsvRow

DictionaryGroupManager._saveGroups
└── SharedPreferences
```

---

*Last updated: March 2026*
