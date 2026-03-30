# hdict API Documentation

## File: `lib/core/database/database_helper.dart`

### Class: `DatabaseHelper`
#### Fields
- Field: `static final DatabaseHelper _instance`
- Field: `static Database? _database`
- Field: `static bool? _fts5Available`
- Field: `static Directory? _appDocDir`
- Field: `static bool needsMigrationAlert`
- Field: `final LinkedHashMap<String, List<Map<String, dynamic>>> _queryCache`
- Field: `static const int _maxQueryCacheEntries`
- Field: `List<Map<String, dynamic>>? _dictionaryCache`
- Field: `Map<int, Map<String, dynamic>>? _dictionaryMapCache`
#### Constructors
- Constructor: `factory DatabaseHelper()`
- Constructor: `DatabaseHelper._internal()`
#### Methods
- Method: `void _addToQueryCache(String key, List<Map<String, dynamic>> value)`
  - Parameter: `String key`
  - Parameter: `List<Map<String, dynamic>> value`
- Method: `List<Map<String, dynamic>>? _getFromQueryCache(String key)`
  - Parameter: `String key`
- Method: `void clearQueryCache()`
- Method: `void clearDictionaryCache()`
- Method: `void _log(String type, String sql, [dynamic args, dynamic result])`
  - Parameter: `String type`
  - Parameter: `String sql`
  - Parameter: `dynamic args`
  - Parameter: `dynamic result`
- Method: `static Future<void> initializeDatabaseFactory()`
- Property: `Future<Database> get database`
- Method: `static void setDatabase(Database db)`
  - Parameter: `Database db`
- Method: `Future<Database> _initDatabase()`
- Method: `static Future<bool> _checkFts5Available(Database db)`
  - Parameter: `Database db`
- Method: `static Future<void> _ensureWordIndexTable(Database db)`
  - Parameter: `Database db`
- Method: `Future<void> _onOpen(Database db)`
  - Parameter: `Database db`
- Method: `Future<void> _onCreate(Database db, int version)`
  - Parameter: `Database db`
  - Parameter: `int version`
- Method: `Future<void> _onUpgrade(Database db, int oldVersion, int newVersion)`
  - Parameter: `Database db`
  - Parameter: `int oldVersion`
  - Parameter: `int newVersion`
- Method: `static String _tokenizeContent(String? text)`
  - Parameter: `String? text`
- Method: `String _translateWildcards(String query)`
  - Parameter: `String query`
- Method: `Future<String> resolvePath(String storedPath)`
  - Parameter: `String storedPath`
- Method: `Future<void> saveFile(int dictId, String fileName, Uint8List bytes)`
  - Parameter: `int dictId`
  - Parameter: `String fileName`
  - Parameter: `Uint8List bytes`
- Method: `Future<Uint8List?> getFile(int dictId, String fileName)`
  - Parameter: `int dictId`
  - Parameter: `String fileName`
- Method: `Future<Uint8List?> getFilePart(int dictId, String fileName, int offset, int length)`
  - Parameter: `int dictId`
  - Parameter: `String fileName`
  - Parameter: `int offset`
  - Parameter: `int length`
- Method: `Future<int> insertDictionary(String name, String path, {bool indexDefinitions = false, String format = 'stardict', String? typeSequence, String? checksum, String? sourceUrl, String sourceType = 'managed', String? sourceBookmark, String? companionUri, String? mddPath})`
  - Parameter: `String name`
  - Parameter: `String path`
  - Parameter: `bool indexDefinitions = false`
  - Parameter: `String format = 'stardict'`
  - Parameter: `String? typeSequence`
  - Parameter: `String? checksum`
  - Parameter: `String? sourceUrl`
  - Parameter: `String sourceType = 'managed'`
  - Parameter: `String? sourceBookmark`
  - Parameter: `String? companionUri`
  - Parameter: `String? mddPath`
- Method: `Future<void> updateDictionaryWordCount(int id, int wordCount, [int? definitionWordCount])`
  - Parameter: `int id`
  - Parameter: `int wordCount`
  - Parameter: `int? definitionWordCount`
- Method: `Future<void> updateDictionaryRowIdRange(int id, int start, int end)`
  - Parameter: `int id`
  - Parameter: `int start`
  - Parameter: `int end`
- Method: `Future<int> getWordCountForDict(int dictId)`
  - Parameter: `int dictId`
- Method: `Future<List<Map<String, dynamic>>> getBatchSampleWords(int totalCount, List<int> dictIds)`
  - Parameter: `int totalCount`
  - Parameter: `List<int> dictIds`
- Method: `Future<List<Map<String, dynamic>>> getSampleWords(int dictId, {int limit = 5})`
  - Parameter: `int dictId`
  - Parameter: `int limit = 5`
- Method: `Future<void> updateDictionaryEnabled(int id, bool isEnabled)`
  - Parameter: `int id`
  - Parameter: `bool isEnabled`
- Method: `Future<void> updateDictionaryIndexDefinitions(int id, bool indexDefinitions)`
  - Parameter: `int id`
  - Parameter: `bool indexDefinitions`
- Method: `Future<void> deleteWordsByDictionaryId(int dictId)`
  - Parameter: `int dictId`
- Method: `Future<void> deleteDictionary(int id)`
  - Parameter: `int id`
- Method: `Future<void> optimizeDatabase()`
- Method: `Future<int> getDatabaseSize()`
- Method: `Future<List<Map<String, dynamic>>> getDictionaries()`
- Method: `Future<List<Map<String, dynamic>>> getEnabledDictionaries()`
- Method: `Future<bool> isDictionaryUrlDownloaded(String url)`
  - Parameter: `String url`
- Method: `Future<void> reorderDictionaries(List<int> sortedIds)`
  - Parameter: `List<int> sortedIds`
- Method: `Future<void> _ensureDictionaryMapCache()`
- Method: `Map<String, dynamic>? getDictionaryByIdSync(int id)`
  - Parameter: `int id`
- Method: `Future<Map<String, dynamic>?> getDictionaryById(int id)`
  - Parameter: `int id`
- Method: `Future<Map<String, dynamic>?> getDictionaryByChecksum(String checksum)`
  - Parameter: `String checksum`
- Method: `Future<void> addSearchHistory(String word, {String searchType = 'Headword Search'})`
  - Parameter: `String word`
  - Parameter: `String searchType = 'Headword Search'`
- Method: `Future<List<Map<String, dynamic>>> getSearchHistory()`
- Method: `Future<void> clearSearchHistory()`
- Method: `Future<void> deleteOldSearchHistory(int days)`
  - Parameter: `int days`
- Method: `Future<void> addFlashCardScore(int score, int total, String dictIds)`
  - Parameter: `int score`
  - Parameter: `int total`
  - Parameter: `String dictIds`
- Method: `Future<List<Map<String, dynamic>>> getFlashCardScores()`
- Method: `Future<int> startBatchInsert()`
- Method: `Future<void> endBatchInsert()`
- Method: `Future<void> enableBulkInsertMode()`
- Method: `Future<({int startId, int duplicateCount})> batchInsertWords(int dictId, List<Map<String, dynamic>> words, {int? startId, bool populateFts5 = true, String? dictName})`
  - Parameter: `int dictId`
  - Parameter: `List<Map<String, dynamic>> words`
  - Parameter: `int? startId`
  - Parameter: `bool populateFts5 = true`
  - Parameter: `String? dictName`
- Method: `Future<void> rebuildFts5IndexForDict(int dictId)`
  - Parameter: `int dictId`
- Method: `Future<List<Map<String, dynamic>>> findDictsNeedingFts5Rebuild()`
- Method: `Future<int> _getWordCountForDict(int dictId)`
  - Parameter: `int dictId`
- Method: `Future<List<Map<String, dynamic>>> searchWords({String? headwordQuery, SearchMode headwordMode = SearchMode.prefix, String? definitionQuery, SearchMode definitionMode = SearchMode.substring, int? dictId, int limit = 50})`
  - Parameter: `String? headwordQuery`
  - Parameter: `SearchMode headwordMode = SearchMode.prefix`
  - Parameter: `String? definitionQuery`
  - Parameter: `SearchMode definitionMode = SearchMode.substring`
  - Parameter: `int? dictId`
  - Parameter: `int limit = 50`
- Method: `Future<List<Map<String, dynamic>>> _searchWordsSequential({String? headwordQuery, required SearchMode headwordMode, int? dictId, required int limit})`
  - Parameter: `String? headwordQuery`
  - Parameter: `required SearchMode headwordMode`
  - Parameter: `int? dictId`
  - Parameter: `required int limit`
- Method: `Future<List<String>> getPrefixSuggestions(String prefix, {int limit = 50, bool fuzzy = false})`
  - Parameter: `String prefix`
  - Parameter: `int limit = 50`
  - Parameter: `bool fuzzy = false`
- Method: `Future<List<String>> getDefinitionSuggestions(String query, {int limit = 50})`
  - Parameter: `String query`
  - Parameter: `int limit = 50`
- Method: `Future<void> insertFreedictDictionaries(List<Map<String, dynamic>> dictionaries)`
  - Parameter: `List<Map<String, dynamic>> dictionaries`
- Method: `Future<List<Map<String, dynamic>>> getFreedictDictionaries()`
- Method: `Future<void> clearFreedictDictionaries()`
- Method: `Future<void> saveSafScanCache(String treeUri, String scanDataJson)`
  - Parameter: `String treeUri`
  - Parameter: `String scanDataJson`
- Method: `Future<String?> getSafScanCache(String treeUri)`
  - Parameter: `String treeUri`
- Method: `Future<void> clearSafScanCache(String treeUri)`
  - Parameter: `String treeUri`

## File: `lib/core/constants/iso_639_2_languages.dart`

### Top-Level Variables
- `const Map<String, String> iso639_2Languages`

## File: `lib/core/utils/word_boundary.dart`

### Class: `WordBoundary`
#### Fields
- Field: `static final RegExp _wordRegExp`
#### Methods
- Method: `static String? wordAt(String text, int offset)`
  - Parameter: `String text`
  - Parameter: `int offset`
- Method: `static RegExp prefixRegex(String prefix)`
  - Parameter: `String prefix`
- Method: `static Set<String> findWordsStartingWith(String text, String prefix)`
  - Parameter: `String text`
  - Parameter: `String prefix`

## File: `lib/core/utils/folder_scanner.dart`

### Class: `DiscoveredDict`
#### Fields
- Field: `final String path`
- Field: `final String format`
- Field: `final String? companionPath`
- Field: `final String? parentFolderName`
- Field: `final Map<String, String>? safUris`
#### Constructors
- Constructor: `const DiscoveredDict({required this.path, required this.format, this.companionPath, this.parentFolderName, this.safUris})`
  - Parameter: `required this.path`
  - Parameter: `required this.format`
  - Parameter: `this.companionPath`
  - Parameter: `this.parentFolderName`
  - Parameter: `this.safUris`
#### Methods
- Method: `Map<String, dynamic> toMap()`
- Method: `static DiscoveredDict fromMap(Map<String, dynamic> map)`
  - Parameter: `Map<String, dynamic> map`

### Class: `IncompleteDict`
#### Fields
- Field: `final String name`
- Field: `final String format`
- Field: `final List<String> missingFiles`
- Field: `final String? parentFolderName`
#### Constructors
- Constructor: `const IncompleteDict({required this.name, required this.format, required this.missingFiles, this.parentFolderName})`
  - Parameter: `required this.name`
  - Parameter: `required this.format`
  - Parameter: `required this.missingFiles`
  - Parameter: `this.parentFolderName`
#### Methods
- Method: `Map<String, dynamic> toMap()`
- Method: `static IncompleteDict fromMap(Map<String, dynamic> map)`
  - Parameter: `Map<String, dynamic> map`

### Class: `FolderScanResult`
#### Fields
- Field: `final List<DiscoveredDict> discovered`
- Field: `final List<IncompleteDict> incomplete`
- Field: `final List<String> foundArchives`
#### Constructors
- Constructor: `const FolderScanResult({required this.discovered, required this.incomplete, this.foundArchives = const []})`
  - Parameter: `required this.discovered`
  - Parameter: `required this.incomplete`
  - Parameter: `this.foundArchives = const []`
#### Methods
- Method: `Map<String, dynamic> toMap()`
- Method: `static FolderScanResult fromMap(Map<String, dynamic> map)`
  - Parameter: `Map<String, dynamic> map`

### Function: `bool _isArchive(String lowerPath)`
  - Parameter: `String lowerPath`

### Function: `Future<void> _extractArchiveToDir(String filePath, String destDir)`
  - Parameter: `String filePath`
  - Parameter: `String destDir`

### Function: `String? _findFile(String base, List<String> suffixes)`
  - Parameter: `String base`
  - Parameter: `List<String> suffixes`

### Function: `Future<FolderScanResult> scanFolderForDictionaries(String directoryPath, {bool extractArchives = true})`
  - Parameter: `String directoryPath`
  - Parameter: `bool extractArchives = true`

## File: `lib/core/utils/html_lookup_wrapper.dart`

### Class: `HtmlLookupWrapper`
#### Fields
- Field: `static final RegExp _tagRegExp`
#### Methods
- Method: `static String processRecord({required String html, required String format, String? typeSequence, String? highlightQuery, String? underlineQuery})`
  - Parameter: `required String html`
  - Parameter: `required String format`
  - Parameter: `String? typeSequence`
  - Parameter: `String? highlightQuery`
  - Parameter: `String? underlineQuery`
- Method: `static String highlightText(String html, String query)`
  - Parameter: `String html`
  - Parameter: `String query`
- Method: `static String underlineText(String html, String query)`
  - Parameter: `String html`
  - Parameter: `String query`

## File: `lib/core/utils/debouncer.dart`

### Class: `Debouncer`
#### Fields
- Field: `final int milliseconds`
- Field: `Timer? _timer`
#### Constructors
- Constructor: `Debouncer({this.milliseconds = 250})`
  - Parameter: `this.milliseconds = 250`
#### Methods
- Method: `void run(void Function() action)`
  - Parameter: `void Function() action`
- Method: `void cancel()`
- Property: `bool get isActive`
- Method: `void dispose()`

## File: `lib/core/utils/logger.dart`

### Top-Level Variables
- `bool enableDebugLogs`

### Top-Level Variables
- `bool showHtmlProcessing`

### Top-Level Variables
- `bool showMultimediaProcessing`

### Top-Level Variables
- `bool showSorting`

### Function: `void hDebugPrint(String? message, {int? wrapWidth})`
  - Parameter: `String? message`
  - Parameter: `int? wrapWidth`

### Class: `HPerf`
#### Fields
- Field: `static final Map<String, List<int>> _samples`
#### Methods
- Method: `static Stopwatch? start(String name)`
  - Parameter: `String name`
- Method: `static void end(Stopwatch? sw, String name)`
  - Parameter: `Stopwatch? sw`
  - Parameter: `String name`
- Method: `static void record(String name, int ms)`
  - Parameter: `String name`
  - Parameter: `int ms`
- Method: `static void recordUs(String name, int us)`
  - Parameter: `String name`
  - Parameter: `int us`
- Method: `static void dump({String prefix = '--- PERF'})`
  - Parameter: `String prefix = '--- PERF'`
- Method: `static void reset()`

## File: `lib/core/utils/benchmark_utils.dart`

### Class: `HBenchmark`
#### Fields
- Field: `static final _dbHelper`
- Field: `static final _dictManager`
#### Methods
- Method: `static Future<String> runLookupBenchmark({int wordsPerDict = 20})`
  - Parameter: `int wordsPerDict = 20`

## File: `lib/core/utils/anchor_id_extension.dart`

### Class: `AnchorIdExtension`
#### Constructors
- Constructor: `const AnchorIdExtension()`
#### Methods
- Property: `Set<String> get supportedTags`
- Method: `bool matches(ExtensionContext context)`
  - Parameter: `ExtensionContext context`
- Method: `InlineSpan build(ExtensionContext context)`
  - Parameter: `ExtensionContext context`

## File: `lib/core/utils/multimedia_processor.dart`

### Class: `MultimediaProcessor`
#### Fields
- Field: `final MdictReader? _mddReader`
- Field: `final String? _cssContent`
#### Constructors
- Constructor: `MultimediaProcessor(this._mddReader, this._cssContent)`
  - Parameter: `this._mddReader`
  - Parameter: `this._cssContent`
#### Methods
- Property: `String? get cssContent`
- Method: `Future<String> processHtmlWithMedia(String html)`
  - Parameter: `String html`
- Method: `String _convertSoundLinks(String html)`
  - Parameter: `String html`
- Method: `String injectCss(String html)`
  - Parameter: `String html`
- Method: `Future<String> _replaceImgSrcWithDataUris(String html)`
  - Parameter: `String html`
- Method: `String? _extractResourceKey(String src)`
  - Parameter: `String src`
- Method: `String _getMimeType(String filename)`
  - Parameter: `String filename`
- Method: `String _getVideoMimeType(String filename)`
  - Parameter: `String filename`
- Method: `String _addMediaTapHandlers(String html, {bool inlineVideo = false})`
  - Parameter: `String html`
  - Parameter: `bool inlineVideo = false`
- Method: `Future<String> processHtmlWithInlineVideo(String html)`
  - Parameter: `String html`
- Method: `Future<Uint8List?> getAudioResource(String key)`
  - Parameter: `String key`
- Method: `Future<Uint8List?> getVideoResource(String key)`
  - Parameter: `String key`

## File: `lib/core/parser/mdict_reader.dart`

### Enum: `MdictSourceType`
#### Constants
- `local`
- `saf`
- `bookmark`

### Class: `MdictReader`
#### Fields
- Field: `final String mdxPath`
- Field: `final RandomAccessSource source`
- Field: `dr.DictReader _parser`
- Field: `bool _isInitialized`
- Field: `final String? _mddPath`
- Field: `final MdictSourceType _mddSourceType`
- Field: `final String? _mddBookmark`
- Field: `MddReader? _mddReader`
- Field: `String? _cssContent`
- Field: `final String? name`
#### Constructors
- Constructor: `MdictReader(this.mdxPath, {required this.source, String? mddPath, MdictSourceType mddSourceType = MdictSourceType.local, String? mddBookmark, this.name})`
  - Parameter: `this.mdxPath`
  - Parameter: `required this.source`
  - Parameter: `String? mddPath`
  - Parameter: `MdictSourceType mddSourceType = MdictSourceType.local`
  - Parameter: `String? mddBookmark`
  - Parameter: `this.name`
- Constructor: `MdictReader._fromParser(dr.DictReader parser, String path, {String? mddPath})`
  - Parameter: `dr.DictReader parser`
  - Parameter: `String path`
  - Parameter: `String? mddPath`
#### Methods
- Method: `static Future<MdictReader> fromPath(String path, {String? mddPath, String? name})`
  - Parameter: `String path`
  - Parameter: `String? mddPath`
  - Parameter: `String? name`
- Method: `static Future<MdictReader> fromLinkedSource(String source, {String? targetPath, String? actualPath, String? mddPath, String? name})`
  - Parameter: `String source`
  - Parameter: `String? targetPath`
  - Parameter: `String? actualPath`
  - Parameter: `String? mddPath`
  - Parameter: `String? name`
- Method: `static Future<MdictReader> fromUri(String uri, {String? mddPath, String? name})`
  - Parameter: `String uri`
  - Parameter: `String? mddPath`
  - Parameter: `String? name`
- Method: `static Future<MdictReader> fromBytes(Uint8List bytes, {String? fileName, String? mddPath})`
  - Parameter: `Uint8List bytes`
  - Parameter: `String? fileName`
  - Parameter: `String? mddPath`
- Method: `Future<void> open()`
- Method: `Future<void> _openMdd()`
- Property: `String? get cssContent`
- Property: `bool get hasMdd`
- Method: `Future<List<int>?> getMddResource(String key)`
  - Parameter: `String key`
- Method: `Future<Uint8List?> getMddResourceBytes(String key)`
  - Parameter: `String key`
- Method: `Future<String?> lookup(String word)`
  - Parameter: `String word`
- Method: `Future<List<(String, int)>> prefixSearch(String prefix, {int limit = 50000})`
  - Parameter: `String prefix`
  - Parameter: `int limit = 50000`
- Method: `Future<void> close()`

## File: `lib/core/parser/bookmark_random_access_source.dart`

### Class: `BookmarkRandomAccessSource`
#### Fields
- Field: `final String bookmark`
- Field: `final String? targetPath`
- Field: `RandomAccessFile? _file`
- Field: `String? _resolvedPath`
- Field: `int? _length`
#### Constructors
- Constructor: `BookmarkRandomAccessSource(this.bookmark, {this.targetPath})`
  - Parameter: `this.bookmark`
  - Parameter: `this.targetPath`
#### Methods
- Method: `Future<void> open()`
- Method: `Future<void> _ensureOpened()`
- Property: `Future<int> get length`
- Method: `Future<Uint8List> read(int offset, int length)`
  - Parameter: `int offset`
  - Parameter: `int length`
- Method: `Future<void> close()`

## File: `lib/core/parser/syn_parser.dart`

### Class: `SynParser`
#### Methods
- Method: `Stream<Map<String, dynamic>> parse(RandomAccessSource source)`
  - Parameter: `RandomAccessSource source`
- Method: `Stream<Map<String, dynamic>> parseFromBytes(Uint8List bytes)`
  - Parameter: `Uint8List bytes`

## File: `lib/core/parser/slob_reader.dart`

### Class: `SlobReader`
#### Fields
- Field: `final String path`
- Field: `final RandomAccessSource source`
- Field: `lib.SlobReader? _reader`
- Field: `bool _isInitialized`
#### Constructors
- Constructor: `SlobReader(this.path, {required this.source})`
  - Parameter: `this.path`
  - Parameter: `required this.source`
#### Methods
- Property: `Future<int> get fileSize`
- Method: `static Future<SlobReader> fromPath(String path, {String? name})`
  - Parameter: `String path`
  - Parameter: `String? name`
- Method: `static Future<SlobReader> fromLinkedSource(String source, {String? targetPath, String? actualPath, String? name})`
  - Parameter: `String source`
  - Parameter: `String? targetPath`
  - Parameter: `String? actualPath`
  - Parameter: `String? name`
- Method: `static Future<SlobReader> fromUri(String uri, {String? name})`
  - Parameter: `String uri`
  - Parameter: `String? name`
- Method: `static Future<SlobReader> fromBytes(Uint8List bytes, {String? fileName})`
  - Parameter: `Uint8List bytes`
  - Parameter: `String? fileName`
- Method: `Future<void> open()`
- Method: `Future<lib.SlobBlob?> getBlob(int index)`
  - Parameter: `int index`
- Property: `String get bookName`
- Property: `int get blobCount`
- Property: `Stream<dynamic> get blobs`
- Method: `Future<String?> lookup(String word)`
  - Parameter: `String word`
- Method: `Future<String?> getBlobContent(int index)`
  - Parameter: `int index`
- Method: `Future<String?> getBlobContentById(int id)`
  - Parameter: `int id`
- Method: `Future<List<String>> getBlobsContentByIds(List<int> ids)`
  - Parameter: `List<int> ids`
- Method: `Future<List<lib.SlobBlob>> getBlobsByRange(int start, int count)`
  - Parameter: `int start`
  - Parameter: `int count`
- Method: `Future<void> close()`

## File: `lib/core/parser/saf_random_access_source.dart`

### Class: `SafRandomAccessSource`
#### Fields
- Field: `final String uri`
- Field: `final String? name`
- Field: `final int bufferSize`
- Field: `final _safStream`
- Field: `static const _channel`
- Field: `static int _totalMemoryUsed`
- Field: `static const int _maxTotalMemory`
- Field: `static const int _maxPerFileMemory`
- Field: `int _bufferOffset`
- Field: `Uint8List? _buffer`
- Field: `bool _isFullFileInMemory`
- Field: `Completer<void>? _readLock`
- Field: `int _size`
- Field: `bool _sizePopulated`
- Field: `Future<void>? _openFuture`
#### Constructors
- Constructor: `SafRandomAccessSource(this.uri, {this.name, this.bufferSize = 5242880})`
  - Parameter: `this.uri`
  - Parameter: `this.name`
  - Parameter: `this.bufferSize = 5242880`
#### Methods
- Property: `bool get isFullFileInMemory`
- Method: `Future<void> open()`
- Method: `Future<void> _performOpen()`
- Method: `Future<void> _triggerInitialLoad()`
- Property: `Future<int> get length`
- Method: `Future<Uint8List> read(int offset, int length)`
  - Parameter: `int offset`
  - Parameter: `int length`
- Method: `Uint8List readSync(int offset, int length)`
  - Parameter: `int offset`
  - Parameter: `int length`
- Method: `Future<Uint8List> _readWithLock(int offset, int length)`
  - Parameter: `int offset`
  - Parameter: `int length`
- Method: `Future<void> close()`

## File: `lib/core/parser/dict_reader.dart`

### Class: `DictReader`
#### Fields
- Field: `final RandomAccessSource source`
- Field: `final String path`
- Field: `final int? dictId`
- Field: `DictzipReader? _dzReader`
#### Constructors
- Constructor: `DictReader(this.path, {required this.source, this.dictId})`
  - Parameter: `this.path`
  - Parameter: `required this.source`
  - Parameter: `this.dictId`
#### Methods
- Method: `static Future<DictReader> fromPath(String path, {int? dictId, String? name})`
  - Parameter: `String path`
  - Parameter: `int? dictId`
  - Parameter: `String? name`
- Method: `static Future<DictReader> fromLinkedSource(String source, {String? targetPath, String? actualPath, String? name})`
  - Parameter: `String source`
  - Parameter: `String? targetPath`
  - Parameter: `String? actualPath`
  - Parameter: `String? name`
- Method: `static Future<DictReader> fromUri(String uri, {int? dictId})`
  - Parameter: `String uri`
  - Parameter: `int? dictId`
- Method: `static Future<DictReader> fromBytes(Uint8List bytes, {String? fileName, int? dictId})`
  - Parameter: `Uint8List bytes`
  - Parameter: `String? fileName`
  - Parameter: `int? dictId`
- Property: `bool get isDz`
- Method: `Future<void> open()`
- Method: `Future<String> readAtIndex(int offset, int length)`
  - Parameter: `int offset`
  - Parameter: `int length`
- Method: `String readAtIndexSync(int offset, int length)`
  - Parameter: `int offset`
  - Parameter: `int length`
- Method: `List<String> readBulkSync(List<({int offset, int length})> entries)`
  - Parameter: `List<({int offset, int length})> entries`
- Method: `Future<List<String>> readBulk(List<({int offset, int length})> entries)`
  - Parameter: `List<({int offset, int length})> entries`
- Method: `Future<void> close()`
- Method: `Future<String> readEntry(int offset, int length)`
  - Parameter: `int offset`
  - Parameter: `int length`

## File: `lib/core/parser/dictd_reader.dart`

### Class: `DictdReader`
#### Fields
- Field: `final String dictPath`
- Field: `lib.DictdReader? _reader`
- Field: `RandomAccessSource? _source`
#### Constructors
- Constructor: `DictdReader(this.dictPath)`
  - Parameter: `this.dictPath`
#### Methods
- Property: `Future<int> get fileSize`
- Property: `RandomAccessSource? get source`
- Method: `static Future<DictdReader> fromPath(String path, {String? name})`
  - Parameter: `String path`
  - Parameter: `String? name`
- Method: `static Future<DictdReader> fromUri(String uri, {String? name})`
  - Parameter: `String uri`
  - Parameter: `String? name`
- Method: `static Future<DictdReader> fromLinkedSource(String source, {String? targetPath, String? actualPath, String? name})`
  - Parameter: `String source`
  - Parameter: `String? targetPath`
  - Parameter: `String? actualPath`
  - Parameter: `String? name`
- Method: `Future<void> openSource(RandomAccessSource source)`
  - Parameter: `RandomAccessSource source`
- Method: `Future<void> open()`
- Method: `Future<String?> readEntry(int offset, int length)`
  - Parameter: `int offset`
  - Parameter: `int length`
- Method: `Future<List<String>> readEntries(List<({int offset, int length})> entries)`
  - Parameter: `List<({int offset, int length})> entries`
- Method: `Future<void> close()`

## File: `lib/core/parser/ifo_parser.dart`

### Class: `IfoParser`
#### Fields
- Field: `final Map<String, String> _metadata`
#### Methods
- Method: `Future<void> parse(String path)`
  - Parameter: `String path`
- Method: `Future<void> parseSource(RandomAccessSource source)`
  - Parameter: `RandomAccessSource source`
- Method: `void parseContent(String content)`
  - Parameter: `String content`
- Method: `void _parseLines(List<String> lines)`
  - Parameter: `List<String> lines`
- Property: `String? get version`
- Property: `String? get bookName`
- Property: `int get wordCount`
- Property: `int get idxFileSize`
- Property: `String? get author`
- Property: `String? get email`
- Property: `String? get website`
- Property: `String? get description`
- Property: `String? get date`
- Property: `String? get sameTypeSequence`
- Property: `Map<String, String> get metadata`
- Property: `int get idxOffsetBits`
- Property: `int get synWordCount`

## File: `lib/core/parser/bookmark_manager.dart`

### Class: `BookmarkManager`
#### Fields
- Field: `static const _channel`
- Field: `static final Map<String, int> _sessionCounts`
#### Methods
- Method: `static Future<String?> resolveBookmark(String bookmark)`
  - Parameter: `String bookmark`
- Method: `static Future<String?> pickDirectory()`
- Method: `static Future<List<String>?> pickFiles()`
- Method: `static Future<void> stopAccess(String bookmark)`
  - Parameter: `String bookmark`
- Method: `static Future<String?> createBookmark(String path)`
  - Parameter: `String path`
- Method: `static Future<bool> startAccessingPath(String path)`
  - Parameter: `String path`
- Method: `static Future<void> stopAccessingPath(String path)`
  - Parameter: `String path`

## File: `lib/core/parser/mdd_reader.dart`

### Class: `MddReader`
#### Fields
- Field: `final RandomAccessSource source`
- Field: `final String _path`
- Field: `dr.DictReader _parser`
- Field: `bool _isInitialized`
- Field: `final Map<String, Uint8List> _resourceCache`
- Field: `static const int _maxCacheEntries`
#### Constructors
- Constructor: `MddReader(this._path, {required this.source})`
  - Parameter: `this._path`
  - Parameter: `required this.source`
#### Methods
- Method: `Future<void> open()`
- Method: `Future<void> close()`
- Method: `Future<List<int>?> getResource(String key)`
  - Parameter: `String key`
- Method: `Future<String?> getResourceAsString(String key)`
  - Parameter: `String key`
- Method: `Future<Uint8List?> getResourceAsBytes(String key)`
  - Parameter: `String key`
- Method: `void _cacheResource(String key, List<int> data)`
  - Parameter: `String key`
  - Parameter: `List<int> data`
- Method: `Future<String?> detectCssKey()`
- Method: `Future<String?> getCssContent()`
- Property: `bool get isInitialized`

## File: `lib/core/parser/idx_parser.dart`

### Class: `IdxParser`
#### Fields
- Field: `final IfoParser ifo`
#### Constructors
- Constructor: `IdxParser(this.ifo)`
  - Parameter: `this.ifo`
#### Methods
- Method: `Stream<Map<String, dynamic>> parse(RandomAccessSource source)`
  - Parameter: `RandomAccessSource source`
- Method: `Stream<Map<String, dynamic>> parseFromBytes(Uint8List bytes)`
  - Parameter: `Uint8List bytes`

## File: `lib/core/manager/dictionary_manager.dart`

### Function: `List<int> _decompressGzip(List<int> bytes)`
  - Parameter: `List<int> bytes`

### Function: `List<int> _decompressBZip2(List<int> bytes)`
  - Parameter: `List<int> bytes`

### Function: `List<int> _decompressXZ(List<int> bytes)`
  - Parameter: `List<int> bytes`

### Function: `bool _dictPathIsDz(String dictPath)`
  - Parameter: `String dictPath`

### Function: `Future<int> _getDictFileSize(String dictPath, String? dictUri, bool isLinked, String? sourceBookmark)`
  - Parameter: `String dictPath`
  - Parameter: `String? dictUri`
  - Parameter: `bool isLinked`
  - Parameter: `String? sourceBookmark`

### Function: `Future<Uint8List> _loadDictFileIntoMemory(String dictPath, String? dictUri, bool isLinked, String? sourceBookmark)`
  - Parameter: `String dictPath`
  - Parameter: `String? dictUri`
  - Parameter: `bool isLinked`
  - Parameter: `String? sourceBookmark`

### Function: `Future<int> _getSlobFileSize(String slobPath, bool isLinked, String? sourceBookmark)`
  - Parameter: `String slobPath`
  - Parameter: `bool isLinked`
  - Parameter: `String? sourceBookmark`

### Function: `Future<Uint8List> _loadSlobFileIntoMemory(String slobPath, bool isLinked, String? sourceBookmark)`
  - Parameter: `String slobPath`
  - Parameter: `bool isLinked`
  - Parameter: `String? sourceBookmark`

### Function: `Future<int> _getMdxFileSize(String mdxPath, bool isLinked, String? sourceBookmark)`
  - Parameter: `String mdxPath`
  - Parameter: `bool isLinked`
  - Parameter: `String? sourceBookmark`

### Function: `Future<Uint8List> _loadMdxFileIntoMemory(String mdxPath, bool isLinked, String? sourceBookmark)`
  - Parameter: `String mdxPath`
  - Parameter: `bool isLinked`
  - Parameter: `String? sourceBookmark`

### Class: `ImportProgress`
#### Fields
- Field: `final String message`
- Field: `final double value`
- Field: `final bool isCompleted`
- Field: `final int? dictId`
- Field: `final String? error`
- Field: `final String? ifoPath`
- Field: `final List<String>? sampleWords`
- Field: `final int headwordCount`
- Field: `final int definitionWordCount`
- Field: `final String? dictionaryName`
- Field: `final List<String>? incompleteEntries`
- Field: `final List<String>? linkedEntries`
- Field: `final List<String>? importedEntries`
- Field: `final List<String>? alreadyExistsEntries`
- Field: `final String? groupName`
#### Constructors
- Constructor: `ImportProgress({required this.message, required this.value, this.isCompleted = false, this.dictId, this.error, this.ifoPath, this.sampleWords, this.headwordCount = 0, this.definitionWordCount = 0, this.dictionaryName, this.incompleteEntries, this.linkedEntries, this.importedEntries, this.alreadyExistsEntries, this.groupName})`
  - Parameter: `required this.message`
  - Parameter: `required this.value`
  - Parameter: `this.isCompleted = false`
  - Parameter: `this.dictId`
  - Parameter: `this.error`
  - Parameter: `this.ifoPath`
  - Parameter: `this.sampleWords`
  - Parameter: `this.headwordCount = 0`
  - Parameter: `this.definitionWordCount = 0`
  - Parameter: `this.dictionaryName`
  - Parameter: `this.incompleteEntries`
  - Parameter: `this.linkedEntries`
  - Parameter: `this.importedEntries`
  - Parameter: `this.alreadyExistsEntries`
  - Parameter: `this.groupName`
#### Methods
- Method: `ImportProgress copyWith({String? message, double? value, bool? isCompleted, int? dictId, String? error, String? ifoPath, List<String>? sampleWords, int? headwordCount, int? definitionWordCount, String? dictionaryName, List<String>? incompleteEntries, List<String>? linkedEntries, List<String>? importedEntries, List<String>? alreadyExistsEntries, String? groupName})`
  - Parameter: `String? message`
  - Parameter: `double? value`
  - Parameter: `bool? isCompleted`
  - Parameter: `int? dictId`
  - Parameter: `String? error`
  - Parameter: `String? ifoPath`
  - Parameter: `List<String>? sampleWords`
  - Parameter: `int? headwordCount`
  - Parameter: `int? definitionWordCount`
  - Parameter: `String? dictionaryName`
  - Parameter: `List<String>? incompleteEntries`
  - Parameter: `List<String>? linkedEntries`
  - Parameter: `List<String>? importedEntries`
  - Parameter: `List<String>? alreadyExistsEntries`
  - Parameter: `String? groupName`

### Class: `DeletionProgress`
#### Fields
- Field: `final String message`
- Field: `final double value`
- Field: `final bool isCompleted`
- Field: `final String? error`
#### Constructors
- Constructor: `DeletionProgress({required this.message, required this.value, this.isCompleted = false, this.error})`
  - Parameter: `required this.message`
  - Parameter: `required this.value`
  - Parameter: `this.isCompleted = false`
  - Parameter: `this.error`

### Class: `_ImportArgs`
#### Fields
- Field: `final String archivePath`
- Field: `final String tempDirPath`
- Field: `final SendPort sendPort`
- Field: `final RootIsolateToken rootIsolateToken`
#### Constructors
- Constructor: `_ImportArgs(this.archivePath, this.tempDirPath, this.sendPort, this.rootIsolateToken)`
  - Parameter: `this.archivePath`
  - Parameter: `this.tempDirPath`
  - Parameter: `this.sendPort`
  - Parameter: `this.rootIsolateToken`

### Class: `_IndexArgs`
#### Fields
- Field: `final int dictId`
- Field: `final String idxPath`
- Field: `final String dictPath`
- Field: `final String? synPath`
- Field: `final bool indexDefinitions`
- Field: `final IfoParser ifoParser`
- Field: `final String? sourceType`
- Field: `final String? sourceBookmark`
- Field: `final SendPort sendPort`
- Field: `final RootIsolateToken rootIsolateToken`
- Field: `final String? idxUri`
- Field: `final String? dictUri`
- Field: `final String? synUri`
#### Constructors
- Constructor: `_IndexArgs(this.dictId, this.idxPath, this.dictPath, this.synPath, this.indexDefinitions, this.ifoParser, this.sourceType, this.sourceBookmark, this.sendPort, this.rootIsolateToken, {this.idxUri, this.dictUri, this.synUri})`
  - Parameter: `this.dictId`
  - Parameter: `this.idxPath`
  - Parameter: `this.dictPath`
  - Parameter: `this.synPath`
  - Parameter: `this.indexDefinitions`
  - Parameter: `this.ifoParser`
  - Parameter: `this.sourceType`
  - Parameter: `this.sourceBookmark`
  - Parameter: `this.sendPort`
  - Parameter: `this.rootIsolateToken`
  - Parameter: `this.idxUri`
  - Parameter: `this.dictUri`
  - Parameter: `this.synUri`

### Class: `_IndexMdictArgs`
#### Fields
- Field: `final int dictId`
- Field: `final String mdxPath`
- Field: `final Uint8List? mdxBytes`
- Field: `final bool indexDefinitions`
- Field: `final String bookName`
- Field: `final String? sourceType`
- Field: `final String? sourceBookmark`
- Field: `final SendPort sendPort`
- Field: `final RootIsolateToken rootIsolateToken`
- Field: `final String? mdxUri`
- Field: `final String? mddUri`
#### Constructors
- Constructor: `_IndexMdictArgs({required this.dictId, required this.mdxPath, this.mdxBytes, required this.indexDefinitions, required this.bookName, this.sourceType, this.sourceBookmark, required this.sendPort, required this.rootIsolateToken, this.mdxUri, this.mddUri})`
  - Parameter: `required this.dictId`
  - Parameter: `required this.mdxPath`
  - Parameter: `this.mdxBytes`
  - Parameter: `required this.indexDefinitions`
  - Parameter: `required this.bookName`
  - Parameter: `this.sourceType`
  - Parameter: `this.sourceBookmark`
  - Parameter: `required this.sendPort`
  - Parameter: `required this.rootIsolateToken`
  - Parameter: `this.mdxUri`
  - Parameter: `this.mddUri`

### Class: `_IndexSlobArgs`
#### Fields
- Field: `final int dictId`
- Field: `final String slobPath`
- Field: `final Uint8List? slobBytes`
- Field: `final bool indexDefinitions`
- Field: `final String bookName`
- Field: `final String? sourceType`
- Field: `final String? sourceBookmark`
- Field: `final SendPort sendPort`
- Field: `final RootIsolateToken rootIsolateToken`
#### Constructors
- Constructor: `_IndexSlobArgs({required this.dictId, required this.slobPath, this.slobBytes, required this.indexDefinitions, required this.bookName, this.sourceType, this.sourceBookmark, required this.sendPort, required this.rootIsolateToken})`
  - Parameter: `required this.dictId`
  - Parameter: `required this.slobPath`
  - Parameter: `this.slobBytes`
  - Parameter: `required this.indexDefinitions`
  - Parameter: `required this.bookName`
  - Parameter: `this.sourceType`
  - Parameter: `this.sourceBookmark`
  - Parameter: `required this.sendPort`
  - Parameter: `required this.rootIsolateToken`

### Class: `_IndexDictdArgs`
#### Fields
- Field: `final int dictId`
- Field: `final String indexPath`
- Field: `final String dictPath`
- Field: `final bool indexDefinitions`
- Field: `final String bookName`
- Field: `final String? sourceType`
- Field: `final String? sourceBookmark`
- Field: `final SendPort sendPort`
- Field: `final RootIsolateToken rootIsolateToken`
- Field: `final String? indexUri`
- Field: `final String? dictUri`
#### Constructors
- Constructor: `_IndexDictdArgs({required this.dictId, required this.indexPath, required this.dictPath, required this.indexDefinitions, required this.bookName, this.sourceType, this.sourceBookmark, required this.sendPort, required this.rootIsolateToken, this.indexUri, this.dictUri})`
  - Parameter: `required this.dictId`
  - Parameter: `required this.indexPath`
  - Parameter: `required this.dictPath`
  - Parameter: `required this.indexDefinitions`
  - Parameter: `required this.bookName`
  - Parameter: `this.sourceType`
  - Parameter: `this.sourceBookmark`
  - Parameter: `required this.sendPort`
  - Parameter: `required this.rootIsolateToken`
  - Parameter: `this.indexUri`
  - Parameter: `this.dictUri`

### Function: `Future<void> _indexEntry(_IndexArgs args)`
  - Parameter: `_IndexArgs args`

### Function: `Future<void> _indexMdictEntry(_IndexMdictArgs args)`
  - Parameter: `_IndexMdictArgs args`

### Function: `Future<void> _indexSlobEntry(_IndexSlobArgs args)`
  - Parameter: `_IndexSlobArgs args`

### Function: `Future<void> _indexDictdEntry(_IndexDictdArgs args)`
  - Parameter: `_IndexDictdArgs args`

### Class: `_ExtractArgs`
#### Fields
- Field: `final String filePath`
- Field: `final String workspacePath`
#### Constructors
- Constructor: `_ExtractArgs(this.filePath, this.workspacePath)`
  - Parameter: `this.filePath`
  - Parameter: `this.workspacePath`

### Function: `Future<void> _extractToWorkspaceSync(_ExtractArgs args)`
  - Parameter: `_ExtractArgs args`

### Function: `Future<void> _extractToWorkspace(String filePath, String workspacePath)`
  - Parameter: `String filePath`
  - Parameter: `String workspacePath`

### Function: `Future<void> _importEntry(_ImportArgs args)`
  - Parameter: `_ImportArgs args`

### Class: `DictionaryManager`
#### Fields
- Field: `final DatabaseHelper _dbHelper`
- Field: `final http.Client _client`
- Field: `static DictionaryManager? _instance`
- Field: `String? _currentImportSourceUrl`
- Field: `static final Map<int, dynamic> _readerCache`
- Field: `final LinkedHashMap<String, String> _definitionCache`
- Field: `static const int _maxCacheEntries`
- Field: `static final Map<int, Future<void>> _readerLocks`
- Field: `static Future<void> _safLock`
#### Constructors
- Constructor: `DictionaryManager({DatabaseHelper? dbHelper, http.Client? client})`
  - Parameter: `DatabaseHelper? dbHelper`
  - Parameter: `http.Client? client`
#### Methods
- Property: `static DictionaryManager get instance`
- Method: `void _addToCache(String key, String value)`
  - Parameter: `String key`
  - Parameter: `String value`
- Method: `String? _getFromCache(String key)`
  - Parameter: `String key`
- Method: `static Future<T> _runSafAction<T>(Future<T> Function() action, [String? debugLabel])`
  - Parameter: `Future<T> Function() action`
  - Parameter: `String? debugLabel`
- Method: `Future<T> _synchronized<T>(int dictId, Future<T> Function() task)`
  - Parameter: `int dictId`
  - Parameter: `Future<T> Function() task`
- Method: `Future<dynamic> _getReader(Map<String, dynamic> dict)`
  - Parameter: `Map<String, dynamic> dict`
- Method: `String? _deriveMddPath(String mdxPath, {bool isLinked = false, String? sourceBookmark})`
  - Parameter: `String mdxPath`
  - Parameter: `bool isLinked = false`
  - Parameter: `String? sourceBookmark`
- Method: `static Future<void> closeReader(int dictId)`
  - Parameter: `int dictId`
- Method: `dynamic getReader(int dictId)`
  - Parameter: `int dictId`
- Method: `MdictReader? getMdictReader(int dictId)`
  - Parameter: `int dictId`
- Method: `bool isFastReader(int dictId)`
  - Parameter: `int dictId`
- Method: `Future<String> _calculateChecksum(String filePath)`
  - Parameter: `String filePath`
- Method: `Future<List<String>> getOrphanedDictionaryFolders()`
- Method: `Future<void> deleteOrphanedFolders(List<String> folderNames)`
  - Parameter: `List<String> folderNames`
- Method: `static Future<void> clearReaderCache()`
- Method: `Future<String> _maybeDecompress(String path)`
  - Parameter: `String path`
- Method: `void _triggerBackgroundPreWarm()`
- Method: `Stream<ImportProgress> importDictionaryStream(String archivePath, {bool indexDefinitions = false})`
  - Parameter: `String archivePath`
  - Parameter: `bool indexDefinitions = false`
- Method: `Stream<ImportProgress> importDictionaryWebStream(String fileName, Uint8List bytes, {bool indexDefinitions = false})`
  - Parameter: `String fileName`
  - Parameter: `Uint8List bytes`
  - Parameter: `bool indexDefinitions = false`
- Method: `Stream<ImportProgress> importMultipleFilesStream(List<String> filePaths, {bool indexDefinitions = false})`
  - Parameter: `List<String> filePaths`
  - Parameter: `bool indexDefinitions = false`
- Method: `Stream<ImportProgress> importFolderStream(String folderPath, {bool indexDefinitions = false})`
  - Parameter: `String folderPath`
  - Parameter: `bool indexDefinitions = false`
- Method: `Stream<ImportProgress> linkFolderStream(String folderPath, {bool indexDefinitions = false})`
  - Parameter: `String folderPath`
  - Parameter: `bool indexDefinitions = false`
- Method: `Future<void> _syncSafFolderBackground(String treeUri, FolderScanResult cachedResult)`
  - Parameter: `String treeUri`
  - Parameter: `FolderScanResult cachedResult`
- Method: `Future<FolderScanResult> _scanSafFolder(String treeUri)`
  - Parameter: `String treeUri`
- Method: `Stream<ImportProgress> addFolderStream(String folderPath, {bool indexDefinitions = false})`
  - Parameter: `String folderPath`
  - Parameter: `bool indexDefinitions = false`
- Method: `String? _resolveLocalFile(String basePath, List<String> extensions)`
  - Parameter: `String basePath`
  - Parameter: `List<String> extensions`
- Method: `Future<String?> _resolveSafFile(String treeUri, String baseName, List<String> extensions)`
  - Parameter: `String treeUri`
  - Parameter: `String baseName`
  - Parameter: `List<String> extensions`
- Method: `Stream<ImportProgress> _linkStarDict(String ifoPath, {bool indexDefinitions = false, Map<String, String>? safUris})`
  - Parameter: `String ifoPath`
  - Parameter: `bool indexDefinitions = false`
  - Parameter: `Map<String, String>? safUris`
- Method: `Stream<ImportProgress> _linkMdict(String mdxPath, {bool indexDefinitions = false, Map<String, String>? safUris})`
  - Parameter: `String mdxPath`
  - Parameter: `bool indexDefinitions = false`
  - Parameter: `Map<String, String>? safUris`
- Method: `Stream<ImportProgress> _linkSlob(String slobPath, {bool indexDefinitions = false, Map<String, String>? safUris})`
  - Parameter: `String slobPath`
  - Parameter: `bool indexDefinitions = false`
  - Parameter: `Map<String, String>? safUris`
- Method: `Stream<ImportProgress> _linkDictd(String indexPath, String dictPath, {bool indexDefinitions = false, Map<String, String>? safUris})`
  - Parameter: `String indexPath`
  - Parameter: `String dictPath`
  - Parameter: `bool indexDefinitions = false`
  - Parameter: `Map<String, String>? safUris`
- Method: `Stream<ImportProgress> importMultipleFilesWebStream(List<({String name, Uint8List bytes})> files, {bool indexDefinitions = false})`
  - Parameter: `List<({String name, Uint8List bytes})> files`
  - Parameter: `bool indexDefinitions = false`
- Method: `Stream<ImportProgress> _processDictionaryFiles(String ifoPath, {bool indexDefinitions = false})`
  - Parameter: `String ifoPath`
  - Parameter: `bool indexDefinitions = false`
- Method: `Future<Uint8List> _maybeDecompressWeb(String name, Uint8List bytes)`
  - Parameter: `String name`
  - Parameter: `Uint8List bytes`
- Method: `String _getDecompressedName(String name)`
  - Parameter: `String name`
- Method: `Stream<ImportProgress> _processDictionaryFilesWeb(String ifoName, Map<String, Uint8List> files, {bool indexDefinitions = false})`
  - Parameter: `String ifoName`
  - Parameter: `Map<String, Uint8List> files`
  - Parameter: `bool indexDefinitions = false`
- Method: `Future<void> preWarmReaders()`
- Method: `Future<List<Map<String, dynamic>>> getDictionaries()`
- Method: `Future<void> toggleDictionaryEnabled(int id, bool isEnabled)`
  - Parameter: `int id`
  - Parameter: `bool isEnabled`
- Method: `Future<void> updateDictionaryIndexDefinitions(int id, bool indexDefinitions)`
  - Parameter: `int id`
  - Parameter: `bool indexDefinitions`
- Method: `Stream<DeletionProgress> deleteDictionaryStream(int id)`
  - Parameter: `int id`
- Method: `Future<void> deleteDictionary(int id)`
  - Parameter: `int id`
- Method: `Future<void> reorderDictionaries(List<int> sortedIds)`
  - Parameter: `List<int> sortedIds`
- Method: `Stream<ImportProgress> importMdictStream(String mdxPath, {String? mddPath, bool indexDefinitions = false, bool isLinked = false, String? sourceBookmark})`
  - Parameter: `String mdxPath`
  - Parameter: `String? mddPath`
  - Parameter: `bool indexDefinitions = false`
  - Parameter: `bool isLinked = false`
  - Parameter: `String? sourceBookmark`
- Method: `Stream<ImportProgress> importDictdStream(String indexPath, String dictPath, {bool indexDefinitions = false})`
  - Parameter: `String indexPath`
  - Parameter: `String dictPath`
  - Parameter: `bool indexDefinitions = false`
- Method: `Stream<ImportProgress> importSlobStream(String slobPath, {bool indexDefinitions = false, bool isLinked = false, String? sourceBookmark})`
  - Parameter: `String slobPath`
  - Parameter: `bool indexDefinitions = false`
  - Parameter: `bool isLinked = false`
  - Parameter: `String? sourceBookmark`
- Method: `Future<String?> fetchDefinition(Map<String, dynamic> dictRecord, String word, int offset, int length)`
  - Parameter: `Map<String, dynamic> dictRecord`
  - Parameter: `String word`
  - Parameter: `int offset`
  - Parameter: `int length`
- Method: `List<String?>? fetchDefinitionsBatchSync(Map<String, dynamic> dictRecord, List<Map<String, dynamic>> requests)`
  - Parameter: `Map<String, dynamic> dictRecord`
  - Parameter: `List<Map<String, dynamic>> requests`
- Method: `Future<List<String?>> fetchDefinitionsBatch(Map<String, dynamic> dictRecord, List<Map<String, dynamic>> requests)`
  - Parameter: `Map<String, dynamic> dictRecord`
  - Parameter: `List<Map<String, dynamic>> requests`
- Method: `Stream<ImportProgress> reIndexDictionariesStream()`
- Method: `Stream<ImportProgress> reindexDictionaryStream(int dictId, {bool indexDefinitions = true})`
  - Parameter: `int dictId`
  - Parameter: `bool indexDefinitions = true`
- Method: `String _resolveDownloadFilename(String url, Map<String, String> headers)`
  - Parameter: `String url`
  - Parameter: `Map<String, String> headers`
- Method: `String? _getChecksumFromHeaders(Map<String, String> headers)`
  - Parameter: `Map<String, String> headers`
- Method: `bool _isRecognizedExtension(String name)`
  - Parameter: `String name`
- Method: `Stream<ImportProgress> downloadAndImportDictionaryStream(String url, {bool indexDefinitions = false, String? sourceUrl})`
  - Parameter: `String url`
  - Parameter: `bool indexDefinitions = false`
  - Parameter: `String? sourceUrl`

## File: `lib/core/manager/dictionary_group_manager.dart`

### Class: `DictionaryGroup`
#### Fields
- Field: `final String id`
- Field: `final String name`
- Field: `final List<int> dictIds`
#### Constructors
- Constructor: `DictionaryGroup({required this.id, required this.name, required this.dictIds})`
  - Parameter: `required this.id`
  - Parameter: `required this.name`
  - Parameter: `required this.dictIds`
- Constructor: `factory DictionaryGroup.fromJson(Map<String, dynamic> json)`
  - Parameter: `Map<String, dynamic> json`
#### Methods
- Method: `Map<String, dynamic> toJson()`

### Class: `DictionaryGroupManager`
#### Fields
- Field: `static const String _key`
#### Methods
- Method: `static Future<List<DictionaryGroup>> getGroups()`
- Method: `static Future<void> saveGroups(List<DictionaryGroup> groups)`
  - Parameter: `List<DictionaryGroup> groups`
- Method: `static Future<void> addDictionaryToGroup(String groupName, int dictId)`
  - Parameter: `String groupName`
  - Parameter: `int dictId`
- Method: `static Future<void> removeDictionaryFromGroup(String groupId, int dictId)`
  - Parameter: `String groupId`
  - Parameter: `int dictId`
- Method: `static Future<void> removeDictionaryFromAllGroups(int dictId)`
  - Parameter: `int dictId`
- Method: `static Future<void> deleteGroup(String groupId)`
  - Parameter: `String groupId`
- Method: `static Future<void> createCustomGroup(String groupName)`
  - Parameter: `String groupName`
- Method: `static Future<void> toggleGroup(String groupId, bool enable)`
  - Parameter: `String groupId`
  - Parameter: `bool enable`
- Method: `static Future<bool> isGroupActive(String groupId)`
  - Parameter: `String groupId`
- Method: `static Future<void> autoGenerateGroupsFromDownloaded(List<Map<String, dynamic>> installedDicts)`
  - Parameter: `List<Map<String, dynamic>> installedDicts`

## File: `lib/core/theme/app_theme.dart`

### Class: `AppTheme`
#### Methods
- Method: `static ThemeData getTheme(Brightness brightness, String fontFamily)`
  - Parameter: `Brightness brightness`
  - Parameter: `String fontFamily`
- Property: `static ThemeData get lightTheme`
- Property: `static ThemeData get darkTheme`

## File: `lib/features/flash_cards/score_history_screen.dart`

### Class: `ScoreHistoryScreen`
#### Constructors
- Constructor: `const ScoreHistoryScreen({super.key})`
  - Parameter: `super.key`
#### Methods
- Method: `State<ScoreHistoryScreen> createState()`

### Class: `_ScoreHistoryScreenState`
#### Fields
- Field: `final DatabaseHelper _dbHelper`
- Field: `List<Map<String, dynamic>> _scores`
- Field: `List<Map<String, dynamic>> _allDictionaries`
- Field: `bool _isLoading`
#### Methods
- Method: `void initState()`
- Method: `Future<void> _loadScores()`
- Method: `Widget build(BuildContext context)`
  - Parameter: `BuildContext context`
- Method: `void _showDictionariesDialog(String dictNames)`
  - Parameter: `String dictNames`
- Method: `Color _getScoreColor(int percentage)`
  - Parameter: `int percentage`
- Method: `Widget _buildEmptyState()`

## File: `lib/features/flash_cards/flash_cards_screen.dart`

### Class: `FlashCardsScreen`
#### Constructors
- Constructor: `const FlashCardsScreen({super.key})`
  - Parameter: `super.key`
#### Methods
- Method: `State<FlashCardsScreen> createState()`

### Class: `_FlashCardsScreenState`
#### Fields
- Field: `final DatabaseHelper _dbHelper`
- Field: `List<Map<String, dynamic>> _allDictionaries`
- Field: `final Set<int> _selectedDictIds`
- Field: `bool _isLoading`
- Field: `bool _isQuizStarted`
- Field: `List<Map<String, dynamic>> _quizWords`
- Field: `int _currentIndex`
- Field: `int _score`
- Field: `bool _showMeaning`
- Field: `List<bool> _results`
- Field: `bool _isPeeking`
- Field: `int _peekCount`
- Field: `bool _isFetchingMeaning`
- Field: `AnimationController _slideController`
- Field: `Animation<Offset> _slideAnimation`
#### Methods
- Method: `void initState()`
- Method: `void dispose()`
- Method: `Future<void> _loadDictionaries()`
- Method: `Future<void> _startQuiz()`
- Method: `void _animateToNextCard(VoidCallback onComplete)`
  - Parameter: `VoidCallback onComplete`
- Method: `void _answer(bool correct)`
  - Parameter: `bool correct`
- Method: `Future<void> _finishQuiz()`
- Method: `Future<void> _fetchMeaningAtIndex(int index)`
  - Parameter: `int index`
- Method: `void _peekMeaning()`
- Method: `Widget build(BuildContext context)`
  - Parameter: `BuildContext context`
- Method: `Widget _buildSetupUI()`
- Method: `Widget _buildQuizUI()`
- Method: `Widget _buildReviewUI()`
- Method: `void _showWordPopup(String word)`
  - Parameter: `String word`
- Method: `Widget _buildDefinitionContentInPopup(ThemeData theme, Map<String, dynamic> def)`
  - Parameter: `ThemeData theme`
  - Parameter: `Map<String, dynamic> def`
- Method: `Widget _buildActionButton(IconData icon, Color color, VoidCallback onPressed)`
  - Parameter: `IconData icon`
  - Parameter: `Color color`
  - Parameter: `VoidCallback onPressed`

## File: `lib/features/flash_cards/result_screen.dart`

### Class: `ResultScreen`
#### Fields
- Field: `final int score`
- Field: `final int total`
- Field: `final int peekCount`
#### Constructors
- Constructor: `const ResultScreen({super.key, required this.score, required this.total, required this.peekCount})`
  - Parameter: `super.key`
  - Parameter: `required this.score`
  - Parameter: `required this.total`
  - Parameter: `required this.peekCount`
#### Methods
- Method: `Widget build(BuildContext context)`
  - Parameter: `BuildContext context`
- Method: `String _label(int pct)`
  - Parameter: `int pct`

## File: `lib/features/settings/dictionary_groups_screen.dart`

### Class: `DictionaryGroupsScreen`
#### Constructors
- Constructor: `const DictionaryGroupsScreen({super.key})`
  - Parameter: `super.key`
#### Methods
- Method: `State<DictionaryGroupsScreen> createState()`

### Class: `_DictionaryGroupsScreenState`
#### Fields
- Field: `List<DictionaryGroup> _groups`
- Field: `List<Map<String, dynamic>> _allDictionaries`
- Field: `bool _isLoading`
#### Methods
- Method: `void initState()`
- Method: `Future<void> _loadData()`
- Method: `Future<void> _createCustomGroup()`
- Method: `Future<void> _manageGroupDictionaries(DictionaryGroup group)`
  - Parameter: `DictionaryGroup group`
- Method: `Widget build(BuildContext context)`
  - Parameter: `BuildContext context`

## File: `lib/features/settings/settings_screen.dart`

### Class: `SettingsScreen`
#### Constructors
- Constructor: `const SettingsScreen({super.key})`
  - Parameter: `super.key`
#### Methods
- Method: `State<SettingsScreen> createState()`

### Class: `_SettingsScreenState`
#### Fields
- Field: `final DatabaseHelper _dbHelper`
- Field: `int _databaseSize`
- Field: `bool _isOptimizing`
#### Methods
- Method: `void initState()`
- Method: `Future<void> _loadDatabaseSize()`
- Method: `String _formatBytes(int bytes)`
  - Parameter: `int bytes`
- Method: `Future<void> _optimizeDatabase()`
- Method: `Widget build(BuildContext context)`
  - Parameter: `BuildContext context`
- Method: `Widget _buildSectionHeader(ThemeData theme, String title)`
  - Parameter: `ThemeData theme`
  - Parameter: `String title`
- Method: `Widget _buildColorTile(BuildContext context, String title, Color currentColor,  Function(Color) onColorChanged)`
  - Parameter: `BuildContext context`
  - Parameter: `String title`
  - Parameter: `Color currentColor`
  - Parameter: ` Function(Color) onColorChanged`
- Method: `void _showFontPicker(BuildContext context, SettingsProvider settings)`
  - Parameter: `BuildContext context`
  - Parameter: `SettingsProvider settings`

## File: `lib/features/settings/dictionary_management_screen.dart`

### Class: `DictionaryManagementScreen`
#### Fields
- Field: `final bool triggerSelectByLanguage`
#### Constructors
- Constructor: `const DictionaryManagementScreen({super.key, this.triggerSelectByLanguage = false})`
  - Parameter: `super.key`
  - Parameter: `this.triggerSelectByLanguage = false`
#### Methods
- Method: `State<DictionaryManagementScreen> createState()`

### Class: `_DictionaryManagementScreenState`
#### Fields
- Field: `final DictionaryManager _dictionaryManager`
- Field: `final TextEditingController _searchController`
- Field: `List<Map<String, dynamic>> _dictionaries`
- Field: `List<Map<String, dynamic>> _filteredDictionaries`
- Field: `bool _isLoading`
- Field: `final ValueNotifier<ImportProgress> _progressNotifier`
#### Methods
- Method: `void initState()`
- Method: `void dispose()`
- Method: `void _onSearchChanged()`
- Method: `void _filterDictionaries()`
- Method: `Future<void> _loadDictionaries()`
- Method: `Future<void> _downloadDictionary()`
- Method: `Future<void> _downloadFreedictDictionary()`
- Method: `Future<void> _importDictionary()`
- Method: `Future<void> _addFolder()`
- Method: `void _showImportReport(ImportProgress progress, {String title = 'Import Report'})`
  - Parameter: `ImportProgress progress`
  - Parameter: `String title = 'Import Report'`
- Method: `Future<void> _reindexAll()`
- Method: `Widget build(BuildContext context)`
  - Parameter: `BuildContext context`
- Method: `Widget _buildEmptyState()`
- Method: `Widget _buildGuidanceCard(ThemeData theme)`
  - Parameter: `ThemeData theme`
- Method: `Future<void> _showDeleteDialog(Map<String, dynamic> dict)`
  - Parameter: `Map<String, dynamic> dict`
- Method: `Widget _buildFooterButton({required VoidCallback? onPressed, required IconData icon, required String label, required bool isPrimary})`
  - Parameter: `required VoidCallback? onPressed`
  - Parameter: `required IconData icon`
  - Parameter: `required String label`
  - Parameter: `required bool isPrimary`
- Method: `Future<void> _showReindexDialog(Map<String, dynamic> dict)`
  - Parameter: `Map<String, dynamic> dict`
- Method: `Widget _buildProgressContent(ImportProgress progress, {VoidCallback? onCancel})`
  - Parameter: `ImportProgress progress`
  - Parameter: `VoidCallback? onCancel`

## File: `lib/features/settings/search_history_screen.dart`

### Class: `SearchHistoryScreen`
#### Constructors
- Constructor: `const SearchHistoryScreen({super.key})`
  - Parameter: `super.key`
#### Methods
- Method: `State<SearchHistoryScreen> createState()`

### Class: `_SearchHistoryScreenState`
#### Fields
- Field: `final DatabaseHelper _dbHelper`
- Field: `List<Map<String, dynamic>> _history`
- Field: `bool _isLoading`
#### Methods
- Method: `void initState()`
- Method: `Future<void> _loadHistory()`
- Method: `Future<void> _clearHistory()`
- Method: `Widget build(BuildContext context)`
  - Parameter: `BuildContext context`
- Method: `Widget _buildEmptyState()`

## File: `lib/features/settings/settings_provider.dart`

### Enum: `SearchMode`
#### Constants
- `prefix('Prefix')`
- `suffix('Suffix')`
- `substring('Substring')`
- `exact('Exact')`
#### Fields
- Field: `final String label`
#### Constructors
- Constructor: `const SearchMode(this.label)`
  - Parameter: `this.label`
#### Methods
- Method: `static SearchMode fromString(String value)`
  - Parameter: `String value`

### Enum: `AppThemeMode`
#### Constants
- `light('Light')`
- `dark('Dark')`
- `custom('Custom')`
#### Fields
- Field: `final String label`
#### Constructors
- Constructor: `const AppThemeMode(this.label)`
  - Parameter: `this.label`
#### Methods
- Method: `static AppThemeMode fromString(String value)`
  - Parameter: `String value`

### Class: `SettingsProvider`
#### Fields
- Field: `static const String _keyAppThemeMode`
- Field: `static const String _keyFontFamily`
- Field: `static const String _keyFontSize`
- Field: `static const String _keyBgColor`
- Field: `static const String _keyTextColor`
- Field: `static const String _keyPreviewLines`
- Field: `static const String _keyFuzzySearch`
- Field: `static const String _keyTapMeaning`
- Field: `static const String _keyOpenPopup`
- Field: `static const String _keyHistoryDays`
- Field: `static const String _keySearchInHeadwords`
- Field: `static const String _keySearchInDefinitions`
- Field: `static const String _keyHeadwordSearchMode`
- Field: `static const String _keyDefinitionSearchMode`
- Field: `static const String _keyHeadwordColor`
- Field: `static const String _keySearchResultLimit`
- Field: `static const String _keyFlashCardWordCount`
- Field: `static const String _keyAppFirstLaunchDate`
- Field: `static const String _keyNextReviewPromptDate`
- Field: `static const String _keyReviewPromptCount`
- Field: `static const String _keyHasGivenReview`
- Field: `static const String _keyListMode`
- Field: `static const String _keyShowSearchSuggestions`
- Field: `static const String _keySearchAsYouType`
- Field: `AppThemeMode _appThemeMode`
- Field: `String _fontFamily`
- Field: `double _fontSize`
- Field: `Color _backgroundColor`
- Field: `Color _textColor`
- Field: `int _previewLines`
- Field: `bool _isFuzzySearchEnabled`
- Field: `bool _isTapOnMeaningEnabled`
- Field: `bool _isOpenPopupOnTap`
- Field: `int _historyRetentionDays`
- Field: `bool _isSearchInHeadwordsEnabled`
- Field: `bool _isSearchInDefinitionsEnabled`
- Field: `SearchMode _headwordSearchMode`
- Field: `SearchMode _definitionSearchMode`
- Field: `Color _headwordColor`
- Field: `int _searchResultLimit`
- Field: `int _flashCardWordCount`
- Field: `int _appFirstLaunchDate`
- Field: `int _nextReviewPromptDate`
- Field: `int _reviewPromptCount`
- Field: `bool _hasGivenReview`
- Field: `bool _reviewPromptedThisSession`
- Field: `bool _isListModeEnabled`
- Field: `bool _isShowSearchSuggestionsEnabled`
- Field: `bool _isSearchAsYouTypeEnabled`
#### Constructors
- Constructor: `SettingsProvider()`
#### Methods
- Property: `AppThemeMode get appThemeMode`
- Property: `String get fontFamily`
- Property: `double get fontSize`
- Property: `Color get backgroundColor`
- Property: `Color get textColor`
- Property: `int get previewLines`
- Property: `bool get isFuzzySearchEnabled`
- Property: `bool get isTapOnMeaningEnabled`
- Property: `bool get isOpenPopupOnTap`
- Property: `int get historyRetentionDays`
- Property: `bool get isSearchInHeadwordsEnabled`
- Property: `bool get isSearchInDefinitionsEnabled`
- Property: `SearchMode get headwordSearchMode`
- Property: `SearchMode get definitionSearchMode`
- Property: `Color get headwordColor`
- Property: `int get searchResultLimit`
- Property: `int get flashCardWordCount`
- Property: `int get appFirstLaunchDate`
- Property: `int get nextReviewPromptDate`
- Property: `int get reviewPromptCount`
- Property: `bool get hasGivenReview`
- Property: `bool get reviewPromptedThisSession`
- Property: `bool get isListModeEnabled`
- Property: `bool get isShowSearchSuggestionsEnabled`
- Property: `bool get isSearchAsYouTypeEnabled`
- Method: `Color getEffectiveBackgroundColor(BuildContext context)`
  - Parameter: `BuildContext context`
- Method: `Color getEffectiveTextColor(BuildContext context)`
  - Parameter: `BuildContext context`
- Method: `Color getEffectiveHeadwordColor(BuildContext context)`
  - Parameter: `BuildContext context`
- Method: `Future<void> _loadSettings()`
- Method: `Future<void> setAppThemeMode(AppThemeMode mode)`
  - Parameter: `AppThemeMode mode`
- Method: `Future<void> setFontFamily(String family)`
  - Parameter: `String family`
- Method: `Future<void> setFontSize(double size)`
  - Parameter: `double size`
- Method: `Future<void> setBackgroundColor(Color color)`
  - Parameter: `Color color`
- Method: `Future<void> setTextColor(Color color)`
  - Parameter: `Color color`
- Method: `Future<void> setPreviewLines(int lines)`
  - Parameter: `int lines`
- Method: `Future<void> setFuzzySearch(bool enabled)`
  - Parameter: `bool enabled`
- Method: `Future<void> setTapOnMeaning(bool enabled)`
  - Parameter: `bool enabled`
- Method: `Future<void> setOpenPopup(bool enabled)`
  - Parameter: `bool enabled`
- Method: `Future<void> setHistoryRetentionDays(int days)`
  - Parameter: `int days`
- Method: `Future<void> searchInHeadwords(bool enabled)`
  - Parameter: `bool enabled`
- Method: `Future<void> searchInDefinitions(bool enabled)`
  - Parameter: `bool enabled`
- Method: `Future<void> setHeadwordSearchMode(SearchMode mode)`
  - Parameter: `SearchMode mode`
- Method: `Future<void> setDefinitionSearchMode(SearchMode mode)`
  - Parameter: `SearchMode mode`
- Method: `Future<void> setHeadwordColor(Color color)`
  - Parameter: `Color color`
- Method: `Future<void> setSearchResultLimit(int limit)`
  - Parameter: `int limit`
- Method: `Future<void> setFlashCardWordCount(int count)`
  - Parameter: `int count`
- Method: `Future<void> initAppFirstLaunchDateIfNeeded()`
- Method: `Future<void> incrementReviewPromptCountAndSetNextDate()`
- Method: `Future<void> setHasGivenReview(bool given)`
  - Parameter: `bool given`
- Method: `void setReviewPromptedThisSession(bool prompted)`
  - Parameter: `bool prompted`
- Method: `Future<void> setListMode(bool enabled)`
  - Parameter: `bool enabled`
- Method: `Future<void> setShowSearchSuggestions(bool enabled)`
  - Parameter: `bool enabled`
- Method: `Future<void> setSearchAsYouType(bool enabled)`
  - Parameter: `bool enabled`

## File: `lib/features/settings/services/stardict_service.dart`

### Class: `StardictRelease`
#### Fields
- Field: `final String url`
- Field: `final String format`
- Field: `final String size`
- Field: `final String version`
- Field: `final String date`
#### Constructors
- Constructor: `StardictRelease({required this.url, required this.format, required this.size, required this.version, required this.date})`
  - Parameter: `required this.url`
  - Parameter: `required this.format`
  - Parameter: `required this.size`
  - Parameter: `required this.version`
  - Parameter: `required this.date`
- Constructor: `factory StardictRelease.fromTsv(Map<String, dynamic> row)`
  - Parameter: `Map<String, dynamic> row`

### Class: `StardictDictionary`
#### Fields
- Field: `final String sourceLanguageCode`
- Field: `final String targetLanguageCode`
- Field: `final String name`
- Field: `final String url`
- Field: `final String headwords`
- Field: `final String version`
- Field: `final String date`
- Field: `final List<StardictRelease> releases`
#### Constructors
- Constructor: `StardictDictionary({required this.sourceLanguageCode, required this.targetLanguageCode, required this.name, required this.url, required this.headwords, required this.version, required this.date, required this.releases})`
  - Parameter: `required this.sourceLanguageCode`
  - Parameter: `required this.targetLanguageCode`
  - Parameter: `required this.name`
  - Parameter: `required this.url`
  - Parameter: `required this.headwords`
  - Parameter: `required this.version`
  - Parameter: `required this.date`
  - Parameter: `required this.releases`
- Constructor: `factory StardictDictionary.fromTsvRow(List<String> values)`
  - Parameter: `List<String> values`
- Constructor: `factory StardictDictionary.fromDbRow(Map<String, dynamic> row)`
  - Parameter: `Map<String, dynamic> row`
#### Methods
- Property: `String get sourceLanguageName`
- Property: `String get targetLanguageName`
- Method: `Map<String, dynamic> toDbRow()`
- Method: `StardictRelease? getPreferredRelease()`

### Class: `StardictService`
#### Fields
- Field: `static const String _tsvUrl`
- Field: `final DatabaseHelper _dbHelper`
#### Methods
- Method: `Future<List<StardictDictionary>> fetchDictionaries()`
- Method: `Future<List<StardictDictionary>> refreshDictionaries()`
- Method: `Future<Set<String>> getDownloadedUrls()`

## File: `lib/features/settings/widgets/stardict_download_dialog.dart`

### Class: `StardictDownloadDialog`
#### Constructors
- Constructor: `const StardictDownloadDialog({super.key})`
  - Parameter: `super.key`
#### Methods
- Method: `State<StardictDownloadDialog> createState()`

### Class: `_StardictDownloadDialogState`
#### Fields
- Field: `final StardictService _service`
- Field: `List<StardictDictionary> _allDictionaries`
- Field: `bool _isLoading`
- Field: `bool _isRefreshing`
- Field: `String? _error`
- Field: `Set<String> _downloadedUrls`
- Field: `String? _selectedSourceLanguage`
- Field: `String? _selectedTargetLanguage`
- Field: `bool _indexDefinitions`
- Field: `final Set<String> _selectedUrls`
#### Methods
- Method: `void initState()`
- Method: `Future<void> _loadData()`
- Method: `Future<void> _refreshInBackground()`
- Method: `Future<void> _refresh()`
- Property: `List<String> get _sourceLanguages`
- Method: `int _getSourceLanguageCount(String code)`
  - Parameter: `String code`
- Property: `List<String> get _targetLanguages`
- Method: `int _getTargetLanguageCount(String code)`
  - Parameter: `String code`
- Property: `List<StardictDictionary> get _filteredDictionaries`
- Method: `String _formatSourceLanguageOption(String code)`
  - Parameter: `String code`
- Method: `String _parseCodeFromOption(String option)`
  - Parameter: `String option`
- Method: `String _getLanguageName(String code)`
  - Parameter: `String code`
- Method: `Widget build(BuildContext context)`
  - Parameter: `BuildContext context`
- Method: `Widget _buildContent()`

## File: `lib/features/home/home_screen.dart`

### Enum: `SuggestionTarget`
#### Constants
- `none`
- `headword`
- `definition`

### Class: `EntryToProcess`
#### Fields
- Field: `final int index`
- Field: `final String content`
- Field: `final String word`
- Field: `final String format`
- Field: `final String? typeSequence`
#### Constructors
- Constructor: `EntryToProcess({required this.index, required this.content, required this.word, required this.format, this.typeSequence})`
  - Parameter: `required this.index`
  - Parameter: `required this.content`
  - Parameter: `required this.word`
  - Parameter: `required this.format`
  - Parameter: `this.typeSequence`

### Class: `HomeScreen`
#### Fields
- Field: `final String? initialWord`
#### Constructors
- Constructor: `const HomeScreen({super.key, this.initialWord})`
  - Parameter: `super.key`
  - Parameter: `this.initialWord`
#### Methods
- Method: `static Future<List<Map<String, dynamic>>> consolidateDefinitions(List<MapEntry<int, Map<String, List<Map<String, dynamic>>>>> groupedResults, {Map<int, Map<String, dynamic>>? dictMap})`
  - Parameter: `List<MapEntry<int, Map<String, List<Map<String, dynamic>>>>> groupedResults`
  - Parameter: `Map<int, Map<String, dynamic>>? dictMap`
- Method: `static String normalizeWhitespace(String text, {String? format, String? typeSequence})`
  - Parameter: `String text`
  - Parameter: `String? format`
  - Parameter: `String? typeSequence`
- Method: `State<HomeScreen> createState()`

### Class: `_HomeScreenState`
#### Fields
- Field: `final TextEditingController _headwordController`
- Field: `final TextEditingController _definitionController`
- Field: `final DatabaseHelper _dbHelper`
- Field: `final DictionaryManager _dictManager`
- Field: `final AudioPlayer _pronunciationPlayer`
- Field: `List<Map<String, dynamic>> _currentDefinitions`
- Field: `bool _isLoading`
- Field: `String? _selectedWord`
- Field: `String _lastHeadwordQuery`
- Field: `String _lastDefinitionQuery`
- Field: `TabController? _tabController`
- Field: `int _searchSqliteMs`
- Field: `int _searchOtherMs`
- Field: `int _searchTotalMs`
- Field: `int _searchResultCount`
- Field: `int _searchGeneration`
- Field: `bool _isPopupOpen`
- Field: `final Debouncer _suggestionsDebouncer`
- Field: `List<String> _suggestions`
- Field: `bool _isLoadingSuggestions`
- Field: `final FocusNode _headwordFocusNode`
- Field: `final FocusNode _definitionFocusNode`
- Field: `final Debouncer _definitionSuggestionsDebouncer`
- Field: `List<String> _definitionSuggestions`
- Field: `bool _isLoadingDefinitionSuggestions`
- Field: `SuggestionTarget _activeSuggestionTarget`
- Field: `final Debouncer _quickSearchDebouncer`
- Field: `bool _hasDictionaries`
- Field: `bool _checkingDicts`
- Field: `Future<List<Map<String, dynamic>>> _dictionariesFuture`
#### Methods
- Method: `void _playPronunciation(String url, int dictId)`
  - Parameter: `String url`
  - Parameter: `int dictId`
- Method: `void _showMediaPlayer(String url, int dictId)`
  - Parameter: `String url`
  - Parameter: `int dictId`
- Method: `SuggestionTarget _getActiveSuggestionTarget()`
- Method: `Future<List<String>> _getSuggestions(String query)`
  - Parameter: `String query`
- Method: `Future<List<String>> _getDefinitionSuggestions(String query)`
  - Parameter: `String query`
- Method: `void _triggerLiveSearch()`
- Method: `void _onSuggestionSelected(String suggestion)`
  - Parameter: `String suggestion`
- Method: `Future<void> _performSearch({bool isRobust = false})`
  - Parameter: `bool isRobust = false`
- Method: `Future<void> _onWordSelected(String word)`
  - Parameter: `String word`
- Method: `void initState()`
- Method: `void dispose()`
- Method: `Future<void> _checkAndPromptReview()`
- Method: `void _showMigrationNotice()`
- Method: `Future<void> _cleanOrphanedFiles()`
- Method: `void _showOrphanCleanupDialog(List<String> folders)`
  - Parameter: `List<String> folders`
- Method: `Future<void> _cleanHistory()`
- Method: `Future<void> _checkDictionaries()`
- Method: `Widget build(BuildContext context)`
  - Parameter: `BuildContext context`
- Method: `Widget _buildEmptyState(ThemeData theme)`
  - Parameter: `ThemeData theme`
- Method: `Widget _buildGuidanceCard(ThemeData theme)`
  - Parameter: `ThemeData theme`
- Method: `Widget _buildSearchBars(ThemeData theme)`
  - Parameter: `ThemeData theme`
- Method: `void _onDefinitionSuggestionSelected(String suggestion)`
  - Parameter: `String suggestion`
- Method: `Widget _buildSuggestionsRow()`
- Method: `Widget _buildDefaultContent(ThemeData theme)`
  - Parameter: `ThemeData theme`
- Method: `Widget _buildResultsView(ThemeData theme)`
  - Parameter: `ThemeData theme`
- Method: `Widget _buildDefinitionContent(ThemeData theme, Map<String, dynamic> defMap, {String? highlightHeadword, String? highlightDefinition, int? searchSqliteMs, int? searchOtherMs, int? searchTotalMs, int? searchResultCount, int startIndex = 0, void Function(String word)? onWordTapInListMode, bool forceDefaultMode = false})`
  - Parameter: `ThemeData theme`
  - Parameter: `Map<String, dynamic> defMap`
  - Parameter: `String? highlightHeadword`
  - Parameter: `String? highlightDefinition`
  - Parameter: `int? searchSqliteMs`
  - Parameter: `int? searchOtherMs`
  - Parameter: `int? searchTotalMs`
  - Parameter: `int? searchResultCount`
  - Parameter: `int startIndex = 0`
  - Parameter: `void Function(String word)? onWordTapInListMode`
  - Parameter: `bool forceDefaultMode = false`
- Method: `Widget _buildDefinitionContentSync(ThemeData theme, Map<String, dynamic> defMap, {String? highlightHeadword, String? highlightDefinition, int? searchSqliteMs, int? searchOtherMs, int? searchTotalMs, int? searchResultCount, int startIndex = 0, void Function(String word)? onWordTapInListMode, bool forceDefaultMode = false})`
  - Parameter: `ThemeData theme`
  - Parameter: `Map<String, dynamic> defMap`
  - Parameter: `String? highlightHeadword`
  - Parameter: `String? highlightDefinition`
  - Parameter: `int? searchSqliteMs`
  - Parameter: `int? searchOtherMs`
  - Parameter: `int? searchTotalMs`
  - Parameter: `int? searchResultCount`
  - Parameter: `int startIndex = 0`
  - Parameter: `void Function(String word)? onWordTapInListMode`
  - Parameter: `bool forceDefaultMode = false`
- Method: `void _showWordPopup(String word)`
  - Parameter: `String word`
- Method: `String _extractTextFromHtml(String html)`
  - Parameter: `String html`
- Method: `Widget _buildAccordionItem({required BuildContext context, required SettingsProvider settings, required ThemeData theme, required Map<String, dynamic> defData, required Map<String, dynamic> defMap, required String definitionHtml, required String highlightCol, required int index, required int globalIndex})`
  - Parameter: `required BuildContext context`
  - Parameter: `required SettingsProvider settings`
  - Parameter: `required ThemeData theme`
  - Parameter: `required Map<String, dynamic> defData`
  - Parameter: `required Map<String, dynamic> defMap`
  - Parameter: `required String definitionHtml`
  - Parameter: `required String highlightCol`
  - Parameter: `required int index`
  - Parameter: `required int globalIndex`

### Class: `_MdictDefinitionContent`
#### Fields
- Field: `final Map<String, dynamic> defMap`
- Field: `final int dictId`
- Field: `final ThemeData theme`
- Field: `final String? highlightHeadword`
- Field: `final String? highlightDefinition`
- Field: `final int? searchSqliteMs`
- Field: `final int? searchOtherMs`
- Field: `final int? searchTotalMs`
- Field: `final int? searchResultCount`
- Field: `final void Function(String word)? onEntryTap`
- Field: `final int startIndex`
- Field: `final void Function(String word)? onWordTapInListMode`
- Field: `final bool forceDefaultMode`
#### Constructors
- Constructor: `const _MdictDefinitionContent({super.key, required this.defMap, required this.dictId, required this.theme, this.highlightHeadword, this.highlightDefinition, this.searchSqliteMs, this.searchOtherMs, this.searchTotalMs, this.searchResultCount, this.onEntryTap, this.startIndex = 0, this.onWordTapInListMode, this.forceDefaultMode = false})`
  - Parameter: `super.key`
  - Parameter: `required this.defMap`
  - Parameter: `required this.dictId`
  - Parameter: `required this.theme`
  - Parameter: `this.highlightHeadword`
  - Parameter: `this.highlightDefinition`
  - Parameter: `this.searchSqliteMs`
  - Parameter: `this.searchOtherMs`
  - Parameter: `this.searchTotalMs`
  - Parameter: `this.searchResultCount`
  - Parameter: `this.onEntryTap`
  - Parameter: `this.startIndex = 0`
  - Parameter: `this.onWordTapInListMode`
  - Parameter: `this.forceDefaultMode = false`
#### Methods
- Method: `State<_MdictDefinitionContent> createState()`

### Class: `_MdictDefinitionContentState`
#### Fields
- Field: `bool _isProcessing`
- Field: `List<Map<String, dynamic>> _rawDefinitions`
#### Methods
- Method: `void initState()`
- Method: `Future<void> _processMultimedia()`
- Method: `Widget build(BuildContext context)`
  - Parameter: `BuildContext context`
- Method: `Widget _buildDefinitionContentSync(ThemeData theme, Map<String, dynamic> defMap, {String? highlightHeadword, String? highlightDefinition, int? searchSqliteMs, int? searchOtherMs, int? searchTotalMs, int? searchResultCount})`
  - Parameter: `ThemeData theme`
  - Parameter: `Map<String, dynamic> defMap`
  - Parameter: `String? highlightHeadword`
  - Parameter: `String? highlightDefinition`
  - Parameter: `int? searchSqliteMs`
  - Parameter: `int? searchOtherMs`
  - Parameter: `int? searchTotalMs`
  - Parameter: `int? searchResultCount`
- Method: `String _extractTextFromHtml(String html)`
  - Parameter: `String html`
- Method: `Widget _buildAccordionItem({required BuildContext context, required SettingsProvider settings, required ThemeData theme, required Map<String, dynamic> defData, required Map<String, dynamic> defMap, required String definitionHtml, required String highlightCol, required int index, required int globalIndex})`
  - Parameter: `required BuildContext context`
  - Parameter: `required SettingsProvider settings`
  - Parameter: `required ThemeData theme`
  - Parameter: `required Map<String, dynamic> defData`
  - Parameter: `required Map<String, dynamic> defMap`
  - Parameter: `required String definitionHtml`
  - Parameter: `required String highlightCol`
  - Parameter: `required int index`
  - Parameter: `required int globalIndex`

### Class: `_MediaPlayerDialog`
#### Fields
- Field: `final Uint8List data`
- Field: `final String mediaType`
- Field: `final String filename`
#### Constructors
- Constructor: `const _MediaPlayerDialog({required this.data, required this.mediaType, required this.filename})`
  - Parameter: `required this.data`
  - Parameter: `required this.mediaType`
  - Parameter: `required this.filename`
#### Methods
- Method: `State<_MediaPlayerDialog> createState()`

### Class: `_MediaPlayerDialogState`
#### Fields
- Field: `AudioPlayer? _audioPlayer`
- Field: `VideoPlayerController? _videoController`
- Field: `bool _isLoading`
- Field: `String? _error`
- Field: `String? _tempFilePath`
#### Methods
- Method: `void initState()`
- Method: `Future<void> _initPlayer()`
- Method: `void dispose()`
- Method: `Widget build(BuildContext context)`
  - Parameter: `BuildContext context`
- Method: `Widget _buildContent(BuildContext context)`
  - Parameter: `BuildContext context`
- Method: `Widget _buildAudioPlayer(BuildContext context)`
  - Parameter: `BuildContext context`
- Method: `Widget _buildVideoPlayer(BuildContext context)`
  - Parameter: `BuildContext context`
- Method: `String _formatDuration(Duration duration)`
  - Parameter: `Duration duration`

### Class: `MddVideoHtmlExtension`
#### Fields
- Field: `final int dictId`
#### Constructors
- Constructor: `MddVideoHtmlExtension({required this.dictId})`
  - Parameter: `required this.dictId`
#### Methods
- Property: `Set<String> get supportedTags`
- Method: `InlineSpan build(ExtensionContext context)`
  - Parameter: `ExtensionContext context`

### Class: `_MddVideoWidget`
#### Fields
- Field: `final String resourceKey`
- Field: `final int dictId`
- Field: `final double? width`
- Field: `final double? height`
- Field: `final bool controls`
- Field: `final bool autoplay`
- Field: `final bool loop`
#### Constructors
- Constructor: `const _MddVideoWidget({required this.resourceKey, required this.dictId, this.width, this.height, this.controls = true, this.autoplay = false, this.loop = false})`
  - Parameter: `required this.resourceKey`
  - Parameter: `required this.dictId`
  - Parameter: `this.width`
  - Parameter: `this.height`
  - Parameter: `this.controls = true`
  - Parameter: `this.autoplay = false`
  - Parameter: `this.loop = false`
#### Methods
- Method: `State<_MddVideoWidget> createState()`

### Class: `_MddVideoWidgetState`
#### Fields
- Field: `VideoPlayerController? _videoController`
- Field: `ChewieController? _chewieController`
- Field: `bool _isLoading`
- Field: `String? _error`
- Field: `String? _tempFilePath`
#### Methods
- Method: `void initState()`
- Method: `Future<void> _loadVideo()`
- Method: `void dispose()`
- Method: `Widget build(BuildContext context)`
  - Parameter: `BuildContext context`

### Class: `_InlineVideoWidget`
#### Fields
- Field: `final String resourceKey`
- Field: `final int dictId`
#### Constructors
- Constructor: `const _InlineVideoWidget({required this.resourceKey, required this.dictId})`
  - Parameter: `required this.resourceKey`
  - Parameter: `required this.dictId`
#### Methods
- Method: `State<_InlineVideoWidget> createState()`

### Class: `_InlineVideoWidgetState`
#### Fields
- Field: `VideoPlayerController? _controller`
- Field: `bool _isLoading`
- Field: `String? _error`
- Field: `String? _tempFilePath`
#### Methods
- Method: `void initState()`
- Method: `Future<void> _loadVideo()`
- Method: `void dispose()`
- Method: `Widget build(BuildContext context)`
  - Parameter: `BuildContext context`

### Class: `_VideoControls`
#### Fields
- Field: `final VideoPlayerController controller`
#### Constructors
- Constructor: `const _VideoControls({required this.controller})`
  - Parameter: `required this.controller`
#### Methods
- Method: `Widget build(BuildContext context)`
  - Parameter: `BuildContext context`
- Method: `String _formatDuration(Duration duration)`
  - Parameter: `Duration duration`

## File: `lib/features/home/widgets/app_drawer.dart`

### Class: `AppDrawer`
#### Constructors
- Constructor: `const AppDrawer({super.key})`
  - Parameter: `super.key`
#### Methods
- Method: `Future<String> _getVersion()`
- Method: `Widget build(BuildContext context)`
  - Parameter: `BuildContext context`

## File: `lib/features/about/about_screen.dart`

### Class: `AboutScreen`
#### Constructors
- Constructor: `const AboutScreen({super.key})`
  - Parameter: `super.key`
#### Methods
- Method: `Future<String> _getVersion()`
- Method: `Widget build(BuildContext context)`
  - Parameter: `BuildContext context`

## File: `lib/features/support/support_screen.dart`

### Class: `SupportScreen`
#### Constructors
- Constructor: `const SupportScreen({super.key})`
  - Parameter: `super.key`
#### Methods
- Method: `Future<void> _launchUrl(String urlString, BuildContext context)`
  - Parameter: `String urlString`
  - Parameter: `BuildContext context`
- Method: `void _copyUpiId(BuildContext context)`
  - Parameter: `BuildContext context`
- Method: `void _showUpiOptions(BuildContext context)`
  - Parameter: `BuildContext context`
- Method: `void _showQrCodeDialog(BuildContext context)`
  - Parameter: `BuildContext context`
- Method: `void _donatePaypal(BuildContext context)`
  - Parameter: `BuildContext context`
- Method: `Widget build(BuildContext context)`
  - Parameter: `BuildContext context`

## File: `lib/features/help/manual_screen.dart`

### Class: `ManualScreen`
#### Constructors
- Constructor: `const ManualScreen({super.key})`
  - Parameter: `super.key`
#### Methods
- Method: `State<ManualScreen> createState()`

### Class: `_ManualScreenState`
#### Fields
- Field: `String _appVersion`
#### Methods
- Method: `void initState()`
- Method: `Future<void> _loadVersion()`
- Method: `Widget build(BuildContext context)`
  - Parameter: `BuildContext context`

## File: `lib/main.dart`

### Function: `void main()`

### Class: `MyApp`
#### Constructors
- Constructor: `const MyApp({super.key})`
  - Parameter: `super.key`
#### Methods
- Method: `Widget build(BuildContext context)`
  - Parameter: `BuildContext context`

