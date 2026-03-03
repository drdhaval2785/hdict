# Changelog

All notable changes to this project will be documented in this file.

## [1.2.6] - 2026-03-03

### Added
- **Slob Support**: Added support for reading and importing `.slob` (Sorted List of Blobs) dictionary files.
- **MDict Support**: Added support for reading and importing `.mdx` dictionary files.
- **Performance Optimization**: 
  - Implemented dictionary reader caching to eliminate startup lag on lookups.
  - Optimized Slob lookups using O(1) jump addresses (packed IDs).
  - Upgraded to `slob_reader` 0.1.2 with bulk-read optimizations.
- **HTML Rendering**: 
  - Added safety thresholds for large dictionary entries to prevent UI hangs.
  - Optimized regex processing for "Tap-on-Meaning" lookup links.
  - Improved standard HTML tag preservation (html, head, body).

### Changed
- Incremented app version to 1.2.6+8.
- Updated README.md with comprehensive format support details.

---

## [1.2.5] - Earlier

### Added
- Initial support for StarDict dictionaries.
- Flash card learning system.
- Customizable theme and typography.
