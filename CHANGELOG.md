# Changelog

All notable changes to this project will be documented in this file.

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

