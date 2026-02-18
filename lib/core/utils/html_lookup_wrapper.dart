/// A utility to wrap every word in a string with HTML links for dictionary lookup.
class HtmlLookupWrapper {
  /// Wraps every alphanumeric word in the [html] string with `<a href="look_up:word">word</a>`.
  /// Preserves existing HTML tags.
  static String wrapWords(String html) {
    // Regex explanation:
    // (?<!<[^>]*) : Negative lookbehind to ensure we aren't inside an HTML tag
    // \b(\w+)\b   : Match a whole word
    // (?! [^<]*>) : Negative lookahead to ensure we aren't inside an HTML tag
    // Note: Dart's RegExp lookbehind is limited, so we use a simpler strategy.

    final tagRegExp = RegExp(r'<[^>]*>|[^<]+');
    final wordRegExp = RegExp(r'(\b\w+\b)');

    final StringBuffer buffer = StringBuffer();
    final matches = tagRegExp.allMatches(html);

    for (final match in matches) {
      final part = match.group(0)!;
      if (part.startsWith('<')) {
        // It's a tag, just append it
        buffer.write(part);
      } else {
        // It's text, wrap the words
        final wrapped = part.replaceAllMapped(wordRegExp, (m) {
          final word = m.group(1)!;
          // Avoid wrapping small numbers or single letters if desired,
          // but usually we want everything.
          return '<a href="look_up:$word">$word</a>';
        });
        buffer.write(wrapped);
      }
    }

    return buffer.toString();
  }
}
