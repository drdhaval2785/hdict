/// A utility to find word boundaries in text.
class WordBoundary {
  static final RegExp _wordRegExp = RegExp(r'[\p{L}\p{N}\p{M}]+', unicode: true);

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
}
