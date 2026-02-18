/// A utility to wrap every word in a string with HTML links for dictionary lookup.
class HtmlLookupWrapper {
  /// Wraps every alphanumeric word in the [html] string with `<a href="look_up:word">word</a>`.
  /// Preserves existing HTML tags.
  static String wrapWords(String html) {
    final tagRegExp = RegExp(r'<[^>]*>|[^<]+');
    // We match any sequence of Unicode letters, numbers, and marks.
    // Including \p{M} is critical for correctly matching Devanagari marks (maatras).
    final wordRegExp = RegExp(r'([\p{L}\p{N}\p{M}]+)', unicode: true);

    final StringBuffer buffer = StringBuffer();
    final matches = tagRegExp.allMatches(html);

    for (final match in matches) {
      final part = match.group(0)!;
      if (part.startsWith('<')) {
        buffer.write(part);
      } else {
        // Wrap the words in text segments first
        final wrapped = part.replaceAllMapped(wordRegExp, (m) {
          final word = m.group(1)!;
          return '<a href="look_up:${Uri.encodeComponent(word)}">$word</a>';
        });
        // Then replace newlines with <br> to preserve line breaks
        final wrappedWithBreaks = wrapped.replaceAll('\n', '<br>');
        buffer.write(wrappedWithBreaks);
      }
    }

    return buffer.toString();
  }
}
