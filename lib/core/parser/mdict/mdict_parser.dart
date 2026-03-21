import "dart:convert";
import "dart:typed_data";
import "package:blockchain_utils/crypto/crypto/hash/hash.dart";
import "package:charset/charset.dart";
import "package:collection/collection.dart";
import "package:hdict/core/parser/random_access_source.dart";
import "dart:io"; // for zlib

// Redefine internal types from dict_reader
class MdxRecord {
  final String key;
  final String data;
  MdxRecord(this.key, this.data);
}

class MddRecord {
  final String key;
  final List<int> data;
  MddRecord(this.key, this.data);
}

class RecordOffsetInfo {
  final String key;
  final int recordBlockOffset;
  final int startOffset;
  final int endOffset;
  final int compressedSize;
  RecordOffsetInfo(this.key, this.recordBlockOffset, this.startOffset, this.endOffset, this.compressedSize);
}

class _InitData {
  final List<(int, String)>? keyList;
  final int? numEntries;
  final int? recordBlockOffset;
  final List<(int, int)>? recordBlockInfoList;
  final int? totalDecompressedSize;
  _InitData(this.keyList, this.numEntries, this.recordBlockOffset, this.recordBlockInfoList, this.totalDecompressedSize);
}

Uint8List _fastDecrypt(Uint8List data, Uint8List key) {
  final b = data;
  final keyLength = key.length;
  int previous = 0x36;
  for (int i = 0; i < b.length; i++) {
    int t = (b[i] >> 4 | b[i] << 4) & 0xff;
    t = t ^ previous ^ (i & 0xff) ^ key[i % keyLength];
    previous = b[i];
    b[i] = t;
  }
  return b;
}

int _readByte(Uint8List buffer, int byteWidth, [int start = 0]) {
  final byteBuffer = ByteData.view(buffer.buffer);
  if (byteWidth == 1) {
    return byteBuffer.getUint8(start);
  } else {
    return byteBuffer.getUint16(start);
  }
}

int _readNumber(Uint8List buffer, int numberWidth, [int start = 0]) {
  final byteBuffer = ByteData.view(buffer.buffer);
  if (numberWidth == 4) {
    return byteBuffer.getInt32(start, Endian.big);
  } else {
    return byteBuffer.getInt64(start, Endian.big);
  }
}

/// A vendored version of DictReader from package:dict_reader.
/// Modified to use [RandomAccessSource] instead of [RandomAccessFile].
class MdxParser {
  final RandomAccessSource source;
  final String _path;

  late int numEntries;
  late int _numberWidth;
  late int _keyBlockOffset;
  late int _recordBlockOffset;
  late bool _mdx;
  late double _version;
  late String _encoding;
  late List<(int, String)> _keyList;
  late int _encrypt;
  List<(int, int)>? _recordBlockInfoList;
  int? _totalDecompressedSize;

  late Map<String, String> header;

  void Function()? _onRecordBlockInfoRead;

  MdxParser(this.source, this._path) {
    _mdx = _path.toLowerCase().endsWith(".mdx");
  }

  Future<void> initDict({
    bool readKeys = true,
    bool readRecordBlockInfo = true,
    bool readHeader = true,
  }) async {
    if (readHeader) {
      header = await _readHeader();
    }

    if (readKeys) {
      // NOTE: In this modified version, we stay on the current isolate
      // because RandomAccessSource might not be sendable across isolates.
      // If performance is an issue, we can optimize later.
      final initData = await _initDictLocal(
        readKeys,
        readRecordBlockInfo,
        _keyBlockOffset,
        _version,
        _numberWidth,
        _encrypt,
        _encoding,
      );

      _keyList = initData.keyList!;
      numEntries = initData.numEntries!;
      _recordBlockOffset = initData.recordBlockOffset!;

      if (readRecordBlockInfo) {
        _recordBlockInfoList = initData.recordBlockInfoList;
        _totalDecompressedSize = initData.totalDecompressedSize;
        if (_onRecordBlockInfoRead != null) {
          _onRecordBlockInfoRead!();
        }
      }
    }
  }

  Future<void> close() async {
    await source.close();
  }

  /// Original _initDictIsolate logic ported to run locally with [RandomAccessSource]
  Future<_InitData> _initDictLocal(
    bool readKeys,
    bool readRecordBlockInfo,
    int keyBlockOffset,
    double version,
    int numberWidth,
    int encrypt,
    String encoding,
  ) async {
    int currentOffset = keyBlockOffset;

    // Helper for local reading
    Future<int> readNum(int width) async {
      final bytes = await source.read(currentOffset, width);
      currentOffset += width;
      if (width == 4) {
        return ByteData.sublistView(bytes).getInt32(0);
      } else {
        return ByteData.sublistView(bytes).getInt64(0);
      }
    }

    // Number of key blocks
    await readNum(numberWidth);
    // Number of entries
    final numEntries = await readNum(numberWidth);

    if (version >= 2.0) {
      currentOffset += numberWidth; // decompressed key block info size
    }

    final keyBlockInfoSize = await readNum(numberWidth);
    final keyBlockSize = await readNum(numberWidth);

    if (version >= 2.0) {
      currentOffset += 4; // checksum?
    }

    final keyBlockInfoBytes = await source.read(currentOffset, keyBlockInfoSize);
    currentOffset += keyBlockInfoSize;
    final List<int> keyBlockInfoList = _decodeKeyBlockInfoManual(keyBlockInfoBytes, version, encrypt, encoding, numberWidth);

    final keyBlockCompressed = await source.read(currentOffset, keyBlockSize);
    currentOffset += keyBlockSize;

    final keyList = _decodeKeyBlockLocal(keyBlockCompressed, keyBlockInfoList);
    mergeSort(keyList, compare: (a, b) => a.$2.compareTo(b.$2));

    final recordBlockOffset = currentOffset;

    List<(int, int)>? recordBlockInfoList;
    int totalDecompressedSize = 0;

    if (readRecordBlockInfo) {
      int rbOffset = recordBlockOffset;
      Future<int> readRBNum(int width) async {
        final bytes = await source.read(rbOffset, width);
        rbOffset += width;
        if (width == 4) {
          return ByteData.sublistView(bytes).getInt32(0);
        } else {
          return ByteData.sublistView(bytes).getInt64(0);
        }
      }

      final numRecordBlocks = await readRBNum(numberWidth);
      await readRBNum(numberWidth); // num entries
      await readRBNum(numberWidth); // rb info size
      await readRBNum(numberWidth); // rb size

      recordBlockInfoList = [];
      for (var i = 0; i < numRecordBlocks; i++) {
        final compressed = await readRBNum(numberWidth);
        final decompressed = await readRBNum(numberWidth);
        recordBlockInfoList.add((compressed, decompressed));
        totalDecompressedSize += decompressed;
      }
    }

    return _InitData(keyList, numEntries, recordBlockOffset, recordBlockInfoList, totalDecompressedSize);
  }

  List<(int, String)> _decodeKeyBlockLocal(Uint8List keyBlockCompressed, List<int> keyBlockInfoList) {
    final List<(int, String)> keyList = [];
    var i = 0;
    for (final compressedSize in keyBlockInfoList) {
      final keyBlock = _decodeBlock(keyBlockCompressed.sublist(i, i + compressedSize));
      keyList.addAll(_splitKeyBlock(keyBlock));
      i += compressedSize;
    }
    return keyList;
  }

  List<int> _decodeKeyBlockInfoManual(Uint8List keyBlockInfoCompressed, double version, int encrypt, String encoding, int numberWidth) {
    List<int> keyBlockInfo;
    if (version >= 2.0) {
      if (encrypt == 2) {
        final key = Uint8List.fromList(RIPEMD128.hash(Uint8List.fromList([...keyBlockInfoCompressed.sublist(4, 8), 149, 54, 0, 0])));
        keyBlockInfoCompressed = Uint8List.fromList([...keyBlockInfoCompressed.sublist(0, 8), ..._fastDecrypt(keyBlockInfoCompressed.sublist(8), key)]);
      }
      keyBlockInfo = zlib.decode(keyBlockInfoCompressed.sublist(8));
    } else {
      keyBlockInfo = keyBlockInfoCompressed;
    }

    final List<int> keyBlockInfoList = [];
    var byteWidth = (version >= 2.0) ? 2 : 1;
    var textTerm = (version >= 2.0) ? 1 : 0;

    for (var i = 0; i < keyBlockInfo.length;) {
      i += numberWidth;
      final textHeadSize = _readByte(Uint8List.fromList(keyBlockInfo.sublist(i, i + byteWidth)), byteWidth);
      i += byteWidth;
      if (encoding != "UTF-16") {
        i += textHeadSize + textTerm;
      } else {
        i += (textHeadSize + textTerm) * 2;
      }
      final textTailSize = _readByte(Uint8List.fromList(keyBlockInfo.sublist(i, i + byteWidth)), byteWidth);
      i += byteWidth;
      if (encoding != "UTF-16") {
        i += textTailSize + textTerm;
      } else {
        i += (textTailSize + textTerm) * 2;
      }
      final keyBlockCompressedSize = _readNumber(Uint8List.fromList(keyBlockInfo.sublist(i, i + numberWidth)), numberWidth);
      i += numberWidth;
      i += numberWidth; // decompressed size
      keyBlockInfoList.add(keyBlockCompressedSize);
    }
    return keyBlockInfoList;
  }

  Future<RecordOffsetInfo?> locate(String key) async {
    final keyIndex = binarySearch(_keyList, (0, key), compare: (a, b) => a.$2.compareTo(b.$2));
    if (keyIndex < 0) return null;
    final recordStart = _keyList[keyIndex].$1;
    final recordEnd = (keyIndex < _keyList.length - 1) ? _keyList[keyIndex + 1].$1 : -1;
    final actualRecordEnd = (recordEnd == -1) ? _totalDecompressedSize! : recordEnd;

    int accumulatedDecompressedSize = 0;
    var recordBlockFileOffset = _recordBlockOffset + _numberWidth * 4;
    recordBlockFileOffset += _recordBlockInfoList!.length * _numberWidth * 2;

    for (final blockInfo in _recordBlockInfoList!) {
      final compressedSize = blockInfo.$1;
      final decompressedSize = blockInfo.$2;
      if (recordStart < accumulatedDecompressedSize + decompressedSize) {
        final startOffset = recordStart - accumulatedDecompressedSize;
        var endOffset = actualRecordEnd - accumulatedDecompressedSize;
        if (endOffset > decompressedSize) endOffset = decompressedSize;
        return RecordOffsetInfo(key, recordBlockFileOffset, startOffset, endOffset, compressedSize);
      }
      accumulatedDecompressedSize += decompressedSize;
      recordBlockFileOffset += compressedSize;
    }
    return null;
  }

  Future<String> readOneMdx(RecordOffsetInfo recordOffsetInfo) async {
    final chunk = await source.read(recordOffsetInfo.recordBlockOffset, recordOffsetInfo.compressedSize);
    final recordBlock = _decodeBlock(chunk);
    return _treatRecordMdxData(recordBlock.sublist(recordOffsetInfo.startOffset, recordOffsetInfo.endOffset));
  }

  Future<List<int>> readOneMdd(RecordOffsetInfo recordOffsetInfo) async {
    final chunk = await source.read(recordOffsetInfo.recordBlockOffset, recordOffsetInfo.compressedSize);
    final recordBlock = _decodeBlock(chunk);
    return recordBlock.sublist(recordOffsetInfo.startOffset, recordOffsetInfo.endOffset);
  }

  Future<List<(String, int)>> search(String key, {int? limit}) async {
    final firstMatchIndex = lowerBound(_keyList, (0, key), compare: (a, b) => a.$2.compareTo(b.$2));
    final matchedKeys = <(String, int)>[];
    for (var i = firstMatchIndex; i < _keyList.length; i++) {
      if (limit != null && matchedKeys.length >= limit) break;
      final currentKey = _keyList[i].$2;
      final currentOffset = _keyList[i].$1;
      if (currentKey.startsWith(key)) {
        matchedKeys.add((currentKey, currentOffset));
      } else {
        break;
      }
    }
    return matchedKeys;
  }

  // --- Internal helper methods from original code ---
  List<int> _decodeBlock(List<int> block) {
    final byteBuffer = ByteData.view(Uint8List.fromList(block).sublist(0, 4).buffer);
    final info = byteBuffer.getUint32(0, Endian.little);
    final compressionMethod = info & 0xf;
    final data = block.sublist(8);
    if (compressionMethod == 0) return data;
    if (compressionMethod == 2) return zlib.decode(data);
    throw "Compression method not supported: $compressionMethod";
  }

  List<(int, String)> _splitKeyBlock(List<int> keyBlock) {
    final List<(int, String)> keyList = [];
    var i = 0;
    while (i < keyBlock.length) {
      final recordStart = _readNumber(Uint8List.fromList(keyBlock.sublist(i, i + _numberWidth)), _numberWidth);
      i += _numberWidth;
      String keyText;
      if (_encoding == "UTF-16") {
        var j = i;
        while (j < keyBlock.length - 1 && (keyBlock[j] != 0 || keyBlock[j + 1] != 0)) {
          j += 2;
        }
        keyText = Utf16Decoder().decodeUtf16Le(keyBlock.sublist(i, j));
        i = j + 2;
      } else {
        var j = i;
        while (j < keyBlock.length && keyBlock[j] != 0) j++;
        keyText = Charset.getByName(_encoding)!.decode(keyBlock.sublist(i, j));
        i = j + 1;
      }
      keyList.add((recordStart, keyText));
    }
    return keyList;
  }

  String _treatRecordMdxData(List<int> rawData) {
    if (_encoding == "UTF-16") {
      return Utf16Decoder().decodeUtf16Le(rawData);
    } else {
      return Charset.getByName(_encoding)!.decode(rawData);
    }
  }

  Future<Map<String, String>> _readHeader() async {
    int pos = 0;
    final sizeBytes = await source.read(pos, 4);
    pos += 4;
    var headerBytesSize = ByteData.sublistView(sizeBytes).getUint32(0, Endian.big);
    
    final contentBytes = await source.read(pos, headerBytesSize);
    pos += headerBytesSize;
    _keyBlockOffset = headerBytesSize + 8;

    String content;
    if (contentBytes[contentBytes.length - 1] == 0 && contentBytes[contentBytes.length - 2] == 0) {
      content = Utf16Decoder().decodeUtf16Le(contentBytes.sublist(0, contentBytes.length - 2));
    } else {
      content = Utf8Decoder().convert(contentBytes.sublist(0, contentBytes.length - 1));
    }

    final tags = _parseHeader(content);
    String? encoding = tags["Encoding"] ?? (_mdx ? "UTF-8" : "UTF-16");
    if (["GBK", "GB2312"].contains(encoding)) encoding = "GB18030";
    _encoding = encoding;

    if (!tags.containsKey("Encrypted") || tags["Encrypted"] == "No") {
      _encrypt = 0;
    } else if (tags["Encrypted"] == "Yes") {
      _encrypt = 1;
    } else {
      _encrypt = int.parse(tags["Encrypted"]!);
    }

    _version = double.parse(tags["GeneratedByEngineVersion"] ?? "2.0");
    _numberWidth = (_version < 2.0) ? 4 : 8;
    if (_version >= 3.0) _encoding = "UTF-8";

    return tags;
  }

  Map<String, String> _parseHeader(String header) {
    final RegExp regex = RegExp(r'(\w+)="(.*?)"', dotAll: true);
    final Map<String, String> tagDict = {};
    final Iterable<RegExpMatch> matches = regex.allMatches(header);
    for (final match in matches) {
      tagDict[match.group(1)!] = match.group(2)!;
    }
    return tagDict;
  }
}
