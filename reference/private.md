# Private API Reference (version 1.5.11)

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

##### `_keyShowSearchSuggestions`

```dart
static const String _keyShowSearchSuggestions = 'show_search_suggestions';
```

Key for storing search suggestions toggle setting.

##### `_keySearchAsYouType`

```dart
static const String _keySearchAsYouType = 'search_as_you_type';
```

Key for storing Search As You Type toggle setting.

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

###### `consolidateDefinitions`

Static method to consolidate definitions.

###### `normalizeWhitespace`

Static method to normalize whitespace.

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

#### Class: `_MdictDefinitionContent`

Widget for MDict definition content.

##### Private Instance Fields

###### `defMap`

```dart
final Map<String, dynamic> defMap;
```

Map containing definition data from dictionary lookup.

###### `theme`

```dart
final ThemeData? theme;
```

Theme data for styling the content.

###### `highlightHeadword`

```dart
final String? highlightHeadword;
```

Headword to highlight in the definition.

###### `highlightDefinition`

```dart
final String? highlightDefinition;
```

Definition text to highlight.

###### `searchSqliteMs`

```dart
final int? searchSqliteMs;
```

Time taken for SQLite query in milliseconds.

###### `searchOtherMs`

```dart
final int? searchOtherMs;
```

Time taken for other processing in milliseconds.

###### `searchTotalMs`

```dart
final int? searchTotalMs;
```

Total search time in milliseconds.

###### `searchResultCount`

```dart
final int? searchResultCount;
```

Number of search results.

###### `startIndex`

```dart
final int? startIndex;
```

Starting index for paginated results.

###### `forceDefaultMode`

```dart
final bool forceDefaultMode;
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

#### Class: `_MediaPlayerDialog`

Dialog for playing audio/video media.

##### Private Instance Fields

###### `data`

```dart
final String data;
```

Base64-encoded media data or resource key.

###### `mediaType`

```dart
final String mediaType;
```

Type of media ('audio' or 'video').

###### `filename`

```dart
final String filename;
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

## Search History

### 1. `lib/features/search_history/search_history_screen.dart`

#### Class: `_SearchHistoryScreenState`

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

## Score History

### 1. `lib/features/score_history/score_history_screen.dart`

#### Class: `_ScoreHistoryScreenState`

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

## Media Players

### 1. `lib/features/home/home_screen.dart`

#### Class: `_MediaPlayerDialogState`

State class for `_MediaPlayerDialog`.

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

## Import/Export

### 1. `lib/features/dictionary_management/dictionary_management_screen.dart`

#### Class: `_ImportArgs`

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

#### Class: `_IndexArgs`

Arguments passed to index isolate for processing StarDict dictionaries.

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
})
```

##### Fields

| Field | Type | Description |
|-------|------|-------------|
| `dictId` | `int` | Database ID of the dictionary |
| `idxPath` | `String` | Path to the .idx file |
| `dictPath` | `String` | Path to the .dict file |
| `synPath` | `String?` | Optional path to the .syn file |
| `indexDefinitions` | `bool` | Whether to index definition content |
| `ifoParser` | `IfoParser` | Parsed IFO metadata |
| `sourceType` | `String?` | Source type ('linked', etc.) |
| `sourceBookmark` | `String?` | SAF bookmark for linked sources |
| `sendPort` | `SendPort` | Port for communication with main isolate |
| `rootIsolateToken` | `RootIsolateToken` | Token for initializing background isolate |
| `idxUri` | `String?` | URI for .idx file (SAF) |
| `dictUri` | `String?` | URI for .dict file (SAF) |
| `synUri` | `String?` | URI for .syn file (SAF) |

#### Class: `_IndexMdictArgs`

Arguments passed to index isolate for processing MDict dictionaries.

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
})
```

##### Fields

| Field | Type | Description |
|-------|------|-------------|
| `dictId` | `int` | Database ID of the dictionary |
| `mdxPath` | `String` | Path to the .mdx file |
| `mdxBytes` | `Uint8List?` | Optional pre-loaded MDX bytes |
| `indexDefinitions` | `bool` | Whether to index definition content |
| `bookName` | `String` | Name of the dictionary |
| `sourceType` | `String?` | Source type ('linked', etc.) |
| `sourceBookmark` | `String?` | SAF bookmark for linked sources |
| `sendPort` | `SendPort` | Port for communication with main isolate |
| `rootIsolateToken` | `RootIsolateToken` | Token for initializing background isolate |
| `mdxUri` | `String?` | URI for .mdx file (SAF) |
| `mddUri` | `String?` | URI for .mdd file (SAF) |

#### Class: `_IndexSlobArgs`

Arguments passed to index isolate for processing SLOB dictionaries.

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
})
```

##### Fields

| Field | Type | Description |
|-------|------|-------------|
| `dictId` | `int` | Database ID of the dictionary |
| `slobPath` | `String` | Path to the .slob file |
| `slobBytes` | `Uint8List?` | Optional pre-loaded SLOB bytes |
| `indexDefinitions` | `bool` | Whether to index definition content |
| `bookName` | `String` | Name of the dictionary |
| `sourceType` | `String?` | Source type ('linked', etc.) |
| `sourceBookmark` | `String?` | SAF bookmark for linked sources |
| `sendPort` | `SendPort` | Port for communication with main isolate |
| `rootIsolateToken` | `RootIsolateToken` | Token for initializing background isolate |

#### Class: `_IndexDictdArgs`

Arguments passed to index isolate for processing Dictd dictionaries.

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
})
```

##### Fields

| Field | Type | Description |
|-------|------|-------------|
| `dictId` | `int` | Database ID of the dictionary |
| `indexPath` | `String` | Path to the index file |
| `dictPath` | `String` | Path to the dictionary file |
| `indexDefinitions` | `bool` | Whether to index definition content |
| `bookName` | `String` | Name of the dictionary |
| `sourceType` | `String?` | Source type ('linked', etc.) |
| `sourceBookmark` | `String?` | SAF bookmark for linked sources |
| `sendPort` | `SendPort` | Port for communication with main isolate |
| `rootIsolateToken` | `RootIsolateToken` | Token for initializing background isolate |
| `indexUri` | `String?` | URI for index file (SAF) |
| `dictUri` | `String?` | URI for dictionary file (SAF) |

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

## Folder Scanner

### 1. `lib/core/utils/folder_scanner.dart`

#### Private Functions

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

Finds the first file that exists with any of the given suffixes.

| Parameter | Type | Description |
|-----------|------|-------------|
| `base` | `String` | Base path without extension |
| `suffixes` | `List<String>` | List of file suffixes to try |

**Returns:** `String?` - Full path to the first found file, or null if none exist.

---

## Video Widgets

### 1. `lib/features/home/home_screen.dart`

#### Class: `_MddVideoWidget`

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

#### Class: `_InlineVideoWidget`

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

#### Class: `_InlineVideoWidgetState`

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

##### Private Constructor

```dart
_ExtractArgs(this.filePath, this.workspacePath);
```

Creates an instance of `_ExtractArgs` with the specified file and workspace paths.

---

#### Class: `_ImportArgs`

Arguments class for dictionary import operations in isolate.

##### Fields

| Field | Type | Description |
|-------|------|-------------|
| `archivePath` | `String` | Path to the archive file being imported |
| `tempDirPath` | `String` | Temporary directory for extraction |
| `sendPort` | `SendPort` | Port for communicating progress back to main isolate |
| `rootIsolateToken` | `RootIsolateToken` | Token for initializing background isolate |

##### Private Constructor

```dart
_ImportArgs(
  this.archivePath,
  this.tempDirPath,
  this.sendPort,
  this.rootIsolateToken,
);
```

Creates an instance of `_ImportArgs` for passing import parameters to the isolate.

---

#### Class: `_IndexArgs`

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

#### Class: `_IndexMdictArgs`

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

#### Class: `_IndexSlobArgs`

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

#### Class: `_IndexDictdArgs`

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

---

#### Private Standalone Functions

#### Function: `_decompressGzip`

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

#### Function: `_decompressBZip2`

```dart
List<int> _decompressBZip2(List<int> bytes)
```

Decompresses BZip2-encoded byte data using the archive package.

**Parameters:**
- `bytes` - The BZip2-compressed byte data

**Returns:** Decompressed byte list

---

#### Function: `_decompressXZ`

```dart
List<int> _decompressXZ(List<int> bytes)
```

Decompresses XZ-encoded byte data using the archive package.

**Parameters:**
- `bytes` - The XZ-compressed byte data

**Returns:** Decompressed byte list

---

#### Function: `_dictPathIsDz`

```dart
bool _dictPathIsDz(String dictPath)
```

Checks if a dictionary path points to a gzip-compressed .dz file.

**Parameters:**
- `dictPath` - The dictionary file path to check

**Returns:** `true` if the path ends with `.dz` (case-insensitive)

---

#### Function: `_getDictFileSize`

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

#### Function: `_loadDictFileIntoMemory`

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

#### Function: `_getSlobFileSize`

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

#### Function: `_loadSlobFileIntoMemory`

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

#### Function: `_getMdxFileSize`

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

#### Function: `_loadMdxFileIntoMemory`

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

#### Function: `_indexEntry`

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

#### Function: `_indexMdictEntry`

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

#### Function: `_indexSlobEntry`

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

#### Function: `_indexDictdEntry`

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

#### Function: `_extractToWorkspaceSync`

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

#### Function: `_extractToWorkspace`

```dart
Future<void> _extractToWorkspace(String filePath, String workspacePath)
```

Extracts an archive to the workspace using compute for background processing.

**Parameters:**
- `filePath` - Path to the archive file
- `workspacePath` - Destination directory

**Usage:** Convenience wrapper around `_extractToWorkspaceSync` using Flutter's compute function.

---

#### Function: `_importEntry`

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

### 2. `lib/core/utils/folder_scanner.dart`

#### Private Standalone Functions

#### Function: `_isArchive`

```dart
bool _isArchive(String filePath)
```

Checks if a file path points to a supported archive format.

**Parameters:**
- `filePath` - The file path to check

**Returns:** `true` if the file has an archive extension (.zip, .tar.gz, .tar, .tar.bz2, .tar.xz, .7z, .gz)

---

#### Function: `_extractArchiveToDir`

```dart
Future<void> _extractArchiveToDir(String archivePath, String outputDir)
```

Extracts an archive file to a specified directory. Non-archive files are copied as-is.

**Parameters:**
- `archivePath` - Path to the archive file
- `outputDir` - Destination directory for extraction

**Supported Formats:** Same as `_extractToWorkspaceSync`

---

#### Function: `_findFile`

```dart
Future<List<File>> _findFile(
  Directory dir,
  String pattern,
  bool recursive,
)
```

Recursively searches a directory for files matching a glob pattern.

**Parameters:**
- `dir` - The directory to search in
- `pattern` - Glob pattern to match (e.g., "*.ifo")
- `recursive` - Whether to search subdirectories

**Returns:** List of matching File objects

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
