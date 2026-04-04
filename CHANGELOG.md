# Changelog

All notable changes to this project will be documented in this file.

## [1.5.13] - 2026-04-04

### Added

- **Slob lzma2 compression support**: Started to support lzma2 compression for slob files.

### Fixed

- **Wordnet dictionaries display**: Started to show colour-coded vertical bars for easier visual differentiation about parent-child relationships in wordnet dictionaries.
- **Freedict dictionaries display**: Started to show freedict dictionaries in cleaner way. Still a long way to go.
- **dictzip_reader**: Dependency on local package removed. Now uses dictzip_reader version 0.1.3 from pub.dev.
- **slob_reader**: Dependency on local package removed. Now uses slob_reader version 0.1.6 from pub.dev.
- **List Mode Fontsize issue**: List Mode now uses the user selected font size.

## [1.5.12] - 2026-03-30

### Added

- **Auto-Refresh for Select by Language**: Dictionary list now automatically refreshes when opening the "Select by Language" dialog. Shows cached data first for offline support, then silently updates in background when online.

### Fixed

- **FTS5 Availability Detection**: Fixed a bug where FTS5 was incorrectly reported as unavailable on Android. The issue was caused by a duplicate `_fts5_probe` table error during initialization. Now properly detects SQLite 3.52.0 with FTS5 support.
- **FTS5 Indexing for StarDict**: StarDict dictionaries now properly populate FTS5 index immediately during import instead of deferring to a background rebuild (which couldn't work with SAF file paths). Definition search now works correctly for newly imported dictionaries.
- **Unicode Support for Definition Suggestions**: Fixed issue where Devanagari and other non-ASCII scripts were not showing suggestions in definition search. Implemented Unicode-aware word boundary detection using `\p{L}` character classes.

### Changed

- **Default Theme**: Changed default app theme from "Custom" to "Light" for better out-of-box experience.

### Documentation

- **Android Permissions**: Clarified user manual to recommend `Documents/DictData` folder for dictionary storage on Android.
- **Search Suggestions**: Updated documentation to explain that suggestions work for both headwords and definition words.
- **Reindex All**: Added documentation for the "Reindex All" functionality in Settings.

## [1.5.11] - 2026-03-29

### Added
- **Search As You Type (Headword)**: Dynamic headword suggestions appear as you type in the headword search field. Shows up to 50 suggestions with 250ms debounce.
- **Search As You Type (Definition)**: Dynamic definition keyword suggestions appear as you type in the definition search field. Uses FTS5 MATCH for efficient searching.
- **Suggestion Settings**: Two new toggles in Settings:
  - "Show Search Suggestions" (default ON) - Controls visibility of suggestion chips
  - "Search As You Type" (default ON) - Controls automatic search on typing
- **Definition Index Caching**: Caches dictionary IDs with indexed definitions for faster suggestion queries.

### Fixed
- **ListMode Entry Expansion**: Fixed bug where expanding entry 4 in one dictionary would also expand entry 4 in all other dictionaries. Now uses global index for unique identification.

## [1.5.10] - 2026-03-29

### Fixed
- **Headword dissociation**: Especially on iOS and large dictionary collections, there were cases of some headwords and definitions getting dissociated. Wrong headword above the right definition. Corrected the bug. 

## [1.5.9] - 2026-03-28

### Fixed
- **Queries on Android**: Androids require SAF for accessing files outside AppData. As some users already have data and do not want to duplicate data to our AppData, started to handle SAF. That is notoriously slow. Optimized it quite a bit so that for majority of cases, results are available within 100ms. Quite fast for human eyes.


## [1.5.8] - 2026-03-26

### Fixed
- **Import and Deletion optimization**: Improved Import and Deletion times for dictionaries by avoiding repeated I/O calls. Reading the dict in memory and sending to SQLITE instead of repeated disk reads. Removed unnecesary FTS5 indexing if only for headword.

## [1.5.7] - 2026-03-26

### Added
- **List Mode**: This optional mode gives the user just the headwords as per his query. He can click on them to get the full definition. Pop-Up queries are also supported inside List Mode. Pop-up queries give full definition though, as it is expected that the user would be looking for just the quick meaning of that word.
- **Internal Reference**: Some stardict dictionaries provide internal references. Their support is started. It is not yet stable. May be improved if any glitches observed or bug report received.
- **Reference API Documentation**: Provided reference documentation for public and private functions, classes, methods and constants.

## [1.5.6] - 2026-03-25

### Added
- **Mdict Audio and Image support**: Reads .mdd files and provides image / audio support. Video is also supported, but not yet tested due to absence of test file.

## [1.5.5] - 2026-03-23

### Fixed
- **Flashcard Retrieval Issue**: Some bug was not allowing retrieval of flash cards. Fixed it.

## [1.5.4] - 2026-03-23

### Fixed
- **Flashcard History**: Fixed issue where flashcard history was not showing dictionary names. Now shows dictionary names on demand.
- **Flashcard Speedup**: Fixed an issue where flashcard took a lot of time to initiate for large number of dictionaries or too many words.
- **Lazy Loading of Meanings**: Added lazy loading of meanings in flashcards to speed up the process.  


## [1.5.3] - 2026-03-23

### Added
- **Speed Improvements**: 
    - **LRU Cache for headwords and definitions**: For speedier lookups in case of repeat seraches
    - **Avoid SQLITE calls for dictionary names**: Avoid calling SQLITE for dictionary names repeatedly by caching map of dict_id
    - **SQLITE WAL Mode**: Enabled WAL mode for SQLITE database for better performance
    - **SAF Buffer Size**: Increased buffer size for SAF reads to 512kb for better performance

## [1.5.2] - 2026-03-23

### Fixed
- **Speed Improvements**: 
    - **Optimized SAF reads**: Earlier byte by byte SAF read was creating latency of around 1000 ms in android even for small queries. Fixed it to regain around less than 100ms in reading files, even via SAF. This makes the speed comparable to storing in the App's Internal Storage where dart.io can access them directly.  
    
## [1.5.1] - 2026-03-23

### Added
- **Speed Improvements**: 
    - **Optimized Search**: Implemented a more efficient query strategy for prefix and wildcard searches, significantly reducing response times.
    - **Better Indexing**: Improved the indexing process to handle large dictionaries more effectively.

## [1.5.0] - 2026-03-22

### Added
- **Avoid Copying Data**: Reads data from user specified file or folder and avoids copying data as far as possible. This will work if the user data is in decompressed format. It is not possible to read tar, tar.gz or zip files non-sequentially on the fly. Therefore, they will continue to be copied / decompressed to AppData.
- **Checksum-based Deduplication**: Automatically detects and prevents importing duplicate dictionaries using MD5 checksums across all import workflows.
- **Enhanced Android SAF Support**: Robust Storage Access Framework (SAF) implementation for StarDict and DICTD formats, ensuring reliable indexing from external SD cards and cloud storage.
- **Import Report**: Providing user with a report at the end of importing via File, Folder, Web or by Language selection.
- **Improved Group Management**: Dictionaries can now belong to multiple groups simultaneously. Group membership is automatically cleaned up when a dictionary is deleted.
- **Automatic Folder Grouping**: Importing a folder now automatically creates and assigns dictionaries to a group named after the source folder.
- **Unified Import Workflow**: Simplified "Import Folder" and "Link Folder" into a single, intuitive "Add Folder" action.
- **Universal Archive Support**: Seamlessly handles `.tar.xz`, `.7z`, and other compressed formats by falling back through system tools and high-performance Dart libraries.

### Fixed
- **Dictionary Reader Stability**: Resolved edge-case crashes and data consolidation errors for MDict and Slob readers.
- **HTML Rendering**: Improved the internal HTML pipeline to safely handle non-standard or unclosed tags in dictionary definitions.
- **Android Archive Handling**: Corrected a platform-specific bug where Android occasionally treated compressed archives as folders.

## [1.4.7] - 2026-03-20
  
### Added
- **Dictionary Grouping**: Users can now create and manage dictionary groups for easier enabling/disabling of multiple dictionaries at once ([#21](https://github.com/drdhaval2785/hdict/issues/21)).
- **Automatic Folder Groups**: When using "Import Folder", a default group is automatically created and named after the source folder ([#27](https://github.com/drdhaval2785/hdict/issues/27)).
- **Bulk Reindexing**: Added a "Reindex All" button in Settings to reindex all installed dictionaries simultaneously ([#26](https://github.com/drdhaval2785/hdict/issues/26)).
- **Searchable Dictionary List**: Added a search bar in the dictionary management screen for quickly filtering large lists of dictionaries ([#25](https://github.com/drdhaval2785/hdict/issues/25)).
- **Multiple Concurrent Downloads**: Enabled checkbox selection in the "Select by Language" screen to download multiple dictionaries at once ([#22](https://github.com/drdhaval2785/hdict/issues/22)).
- **Cancellation Support**: Added "Cancel" buttons to progress bars for long-running tasks like dictionary downloads and indexing.
- **Explicit Theme Modes**: Added settings to choose between Light, Dark, and System theme modes ([#18](https://github.com/drdhaval2785/hdict/issues/18)).
- **Review Prompt Throttling**: Refined rating request logic to prevent excessive prompting; now limited to every 15 days in production and once per session in debug mode ([#18](https://github.com/drdhaval2785/hdict/issues/18)).
- **Online Dictionary Auto-grouping**: Automatically organizes "Search by Language" utility based dictionaries into logical groups.

### Fixed
- **iOS Folder Import**: Fixed a crash on iOS simulator when attempting to use "Import Folder" ([#24](https://github.com/drdhaval2785/hdict/issues/24)).
- **Android Support**: Fixed an issue preventing external URLs from opening and added necessary boundary padding for better layout on Android devices.
- **UI & Layout**: Corrected renderflow errors in the download dialog and improved visibility for dark/light modes.
- **Documentation**: Extensively updated README with App Store/Snap Store links and segregated developer information.
- **Licensing**: Updated project license to GNU GPLv3.0.

## [1.4.6] - 2026-03-17
  
### Added
- **Database optimization**: Database optimization option given to users in Settings to vacuum the database and free up space.
- **Search History Improvements**: Optimized search history interaction by linking entries directly to searched words.
 
## [1.4.5] - 2026-03-16
  
### Fixed
- **Wildcard search**: Fixed error which did not return results for wildcard search.

## [1.4.4] - 2026-03-16
 
### Added
- **Folder Import**: Users can now import entire directories of dictionaries at once.
- **Improved Slob Support**: Optimized `.slob` file reading using batch processing for much faster lookups.
- **Expanded Download Formats**: Enabled direct web downloads for `.slob`, `.dictd`, `.mdx`, and `.mdd` files.
 
### Fixed
- **StarDict Indexing**: Fixed a synonym indexing issue that caused the progress bar to appear frozen.
 - **UI Improvements**: Updated the "Download Web" label to "Download from Web" for better clarity across the app.
- **Enhanced Manual**: Completely rewritten User Manual with detailed instructions for importing, customization, and Flash Cards.

## [1.4.3] - 2026-03-13
 
### Fixed

- **Dictionary Scrolling**: Fixed a bug where dictionary scrolling was not working properly.
 
## [1.4.2] - 2026-03-13
 
### Added
- **Native Tap-to-Search**: 
    - Completely refactored definition interaction to use Flutter's native hit-testing instead of HTML anchor wrapping.
    - **Significant Performance Gain**: Reduced HTML size by ~50% and eliminated rendering bottlenecks for very large definitions.
    - **No More character Limits**: Removed the 20,000 character limit. Tap-to-search now works on definitions of any length.
- **Hover Cursor (Desktop)**: The mouse cursor now changes to a hand icon when hovering over words in the definition area on macOS, Windows, and Linux.
 
### Fixed
- **iOS/macOS Tap Reliability**: Fixed an issue where word detection would return `null` or be unresponsive on Apple platforms.
- **Dictionary Ordering**: Fixed a bug where search results ignored user-defined dictionary priority; results now strictly follow the `display_order`.
- **macOS Instance Bug**: Fixed an edge case where tapping words could trigger multiple app instances.
 
## [1.4.0] - 2026-03-11

### Added
- **Select Dictionaries by Language**: 
    - Browse and download around 1900 dictionaries organized by their origin and target languages.
- **Deletion Progress Monitoring**: Added a dedicated progress bar for dictionary deletion.


## [1.3.2] - 2026-03-10

### Added
- **Indexing Progress Display**: Progress bar now shows `X / Total indexed` using the true total headword count for all dictionary formats (StarDict, MDict, Slob, DICTD).
- **Unified Headword + Synonym Counter**: For StarDict dictionaries, the progress denominator combines base headwords and synonyms (`synwordcount` from the `.ifo` file), so a single counter advances continuously from the first headword to the last synonym without freezing.
- **7-Zip Support**: Added support for importing dictionaries compressed as `.7z` archives.
- **FreeDict Integration**: 
  - Added FreeDict list-of-dictionaries browser with language-based filtering.
  - FreeDict metadata/JSON is now stored in the database for instant loading without repeated network requests.
- **Batch Database Inserts**: Switched dictionary import to use batch inserts for significantly faster indexing.

### Fixed
- **Progress Bar Freeze**: Synonym indexing phase of StarDict dictionaries no longer shows a frozen bar; progress updates are emitted per batch throughout the synonym phase.
- **DICTD Progress Accuracy**: DICTD progress was previously calculated against a hardcoded denominator of 100,000; it now uses the actual entry count from the parsed index.

## [1.3.1] - 2026-03-09

### Added
- **Performance Optimizations**: 
  - Switched `dictzip`, `dictd`, and `slob` readers to batch mode using updated Dart packages for faster data retrieval.
  - Improved SQLite query performance and handling for headword queries.
  - Implemented lazy loading and optimized screen loading for a smoother user experience.
  - Reduced redundant calls to `dict.dz` and optimized dictionary locking during reads.
- **Improved Re-indexing**:
  - Corrected indexing logic to strictly respect "Headwords Only" vs "Headwords & Definitions" selection.
  - Enhanced re-indexing progress UI to conditionally display definition word counts.
- **Performance Monitoring**: Added performance statistics for pop-up calls.

### Fixed
- **Database**: Improved database upgrade error handling and schema consistency (v22).
- **Maintenance**: Audited and updated dependencies to latest versions and removed unused packages.

## [1.3.0] - 2026-03-06

### Added
- **Database Migration**: Optimised the database for faster lookups and less memory usage by contentless method.
- **Interactive Orphan Folder Cleanup**: Users can now choose which orphaned dictionary data folders to delete via a checkboxes dialog, for efficient cleanup.
- **Migration Notice**: Added a one-time informative alert for users upgrading from database version 16.
- **Split Re-indexing Options**: Provided separate options to re-index "Headwords Only" or "Headwords & Definitions".
- **Flash Card Sneak Peek**: Added Sneak Peek feature to Flash Card Learning System.
- **Flash Card Results**: Added a single view of Flash Card Results to show all the results at once.


### Fixed
- **Database Migration**: Resolved a critical issue where the `type_sequence` column was missing in previous upgrades.

## [1.2.7] - 2026-03-04

### Added
- **Search History Enhancements**:
  - Added tracking for different search types: 'Headword Search', 'Definition Search', and 'Pop-up Search'.
  - Updated UI to display search types in the search history list.
  - Implemented database migration (v15) to support search type storage.
- **Display Headword dand Definition Word counts in Manage Dictionary**:
  - Added headword and definition word counts to the Manage Dictionary screen.
- **Definition Indexing for slob, dictd and mdict**:
  - Added definition indexing for slob, dictd and mdict dictionaries.
- **Cleaning Database Space if a dictionary is deleted**:
  - Added clean up of database space, if a dictionary is deleted from Manage Dictionary screen.
- **Tests for dictd, mdict, slob files**:
  - Added tests for dictd, mdict, slob files.


---

## [1.2.6] - 2026-03-03

### Added
- **Slob Support**: Added support for reading and importing `.slob` (Sorted List of Blobs) dictionary files.
- **MDict Support**: Added support for reading and importing `.mdx` dictionary files.
- **Performance Optimization**: 
  - Implemented dictionary reader caching to eliminate startup lag on lookups.
  - Optimized Slob lookups using O(1) jump addresses (packed IDs).
  **Dart libraries**
  - Started to use `slob_reader`, `dictd_reader`, `dict_reader` dart libraries for slob, dictd and mdict dictionaries.
  - Started to use `dictzip_reader` dart library, so that dict.dz file can be read without decompression, so as to save storage space. 
- **HTML Rendering**: 
  - Added safety thresholds for large dictionary entries to prevent UI hangs.
  - Optimized regex processing for "Tap-on-Meaning" lookup links.
  - Improved standard HTML tag preservation (html, head, body).



---

## [1.2.5] - 2026-03-03

### Added

**SQLITE vacuuming**
- Added SQLITE vacuuming to reclaim space occupied by deleted entries.

**SQLITE Fallback**
- In machines without FTS5 support, the app will fallback to using SQLITE for search.

**Delete Stored Files**
- Added deletion of stored files, if a dictionary is deleted from Manage Dictionary screen.

**Restored Synonym Handling**
- Restored synonym handling for headword search.

## [1.2.4] - 2026-03-02

### Added

**Progress Bar Improvements**
- Added progress bar to the search screen to show the progress of the dictionary indexing.

**Headword Size Improvements**
- Headword size made the same as the definition size, to make it more readable.

**HTML Rendering**
- Added HTML rendering for texts which resemble HTML or has some HTML tags.

**Pop-up Timing Discrepancy Corrected**
- Corrected the pop-up timing discrepancy, so that the pop-up timings are shown correctly.

**Logo Update**
- Updated logo of the app. Now only the logo is there. Text removed from logo.

## [1.2.3] - 2026-02-28

### Added

**Default Dictionary Added**
- Added link to download default GCIDE dictionary to the app, so that users can play with the app.

## [1.2.2] - 2026-02-27

### Removed

**Security**
- Removed security.network entitlement from the app for release on App Store.

## [1.2.1] - 2026-02-25

### Added

**DICTD Support**
- Added .dictd file support.

**Compressed Files Support**
- Added support for tar.xz, tar.gz, .gz, .bz, .7z etc compressed file formats.

## [1.1.0] - 2026-02-25

**Prefix Search**
- Added prefix search as the default search type.
- Added FTS5 improvements for speedy retrieval.

**Definition Search**
- Added search within definition words.

**Flash Cards Improvement**
- Added faster loading of flash cards by generating random numbers.

**Multiple Headwords with the same Definition**
- Added a unified display for multiple headwords with the same definition.

**Pop-up Search**
- Added pop-up search to search for words in the definition area.

**Privacy Policy**
- Added privacy policy to the app.

[1.0.0] - 2026-02-22

**Dictionary Management**
- Added dictionary management screen to manage dictionaries.

**Search History**
- Added search history to keep track of search history.

**Flash Card Learning System**
- Added flash card learning system to learn words.

**Customizable Theme and Typography**
- Added customizable theme and typography to customize the app.

**Removed BHIM Payments**
- Removed BHIM Payments from the app to comply with App Store guidelines.

**Prefix Search if Word is Absent**
- If the word is not found in the dictionary, the app will perform a prefix search for the word.

