/// A utility to find word boundaries in text.
class WordBoundary {
  static final RegExp _wordRegExp = RegExp(
    r'[\p{L}\p{N}\p{M}]+',
    unicode: true,
  );

  /// Extracts the word at [offset] from [text].
  ///
  /// Returns null if the character at [offset] is not a word character or if the offset is out of bounds.
  static String? wordAt(String text, int offset) {
    if (offset < 0 || offset >= text.length) return null;

    // Check if the character at the offset is a word character
    final char = text[offset];
    if (!_wordRegExp.hasMatch(char)) return null;

    // Find all word matches in the text
    final matches = _wordRegExp.allMatches(text);

    // Find the match that contains the offset
    for (final match in matches) {
      if (offset >= match.start && offset < match.end) {
        return match.group(0);
      }
    }

    return null;
  }

  /// Creates a regex pattern to find words starting with [prefix].
  ///
  /// Uses Unicode-aware word boundaries to support all scripts including Devanagari.
  /// The returned RegExp will match words that start with the given prefix.
  ///
  /// Example:
  /// ```dart
  /// final regex = WordBoundary.prefixRegex('क');
  /// final matches = regex.allMatches('कर्म की गोद में खड़ा है कमल');
  /// // matches: ['कर्म', 'की', 'खड़ा', 'कमल']
  /// ```
  static RegExp prefixRegex(String prefix) {
    return RegExp(
      r'(?<!\p{L})' + RegExp.escape(prefix) + r'[\p{L}\p{N}\p{M}]*',
      caseSensitive: false,
      unicode: true,
    );
  }

  /// Finds all words in [text] that start with [prefix].
  ///
  /// Returns a Set of unique lowercase words matching the prefix.
  /// Uses Unicode-aware word boundaries to support all scripts including Devanagari.
  static Set<String> findWordsStartingWith(String text, String prefix) {
    final regex = prefixRegex(prefix);
    final matches = regex.allMatches(text);
    return matches.map((m) => m.group(0)!.toLowerCase()).toSet();
  }
}
