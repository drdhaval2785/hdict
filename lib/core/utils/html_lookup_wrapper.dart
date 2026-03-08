/// A utility to wrap every word in a string with HTML links for dictionary lookup.
class HtmlLookupWrapper {
  static final RegExp _tagRegExp = RegExp(r'<[^>]*>|&[a-z0-9#]{2,10};|[^<&]+', caseSensitive: false);
  static final RegExp _wordRegExp = RegExp(r'([\p{L}\p{N}\p{M}]+)', unicode: true);

  /// Processes a dictionary record in a single pass to maximize performance.
  /// Combines whitespace normalization, word wrapping, highlighting, and underlining.
  static String processRecord({
    required String html,
    required String format,
    String? typeSequence,
    required bool wrapWords,
    String? highlightQuery,
    String? underlineQuery,
    String? highlightColor,
  }) {
    if (html.isEmpty) return '';

    // Optimization: Pre-compile only if needed
    final bool hasHighlight = highlightQuery != null && highlightQuery.isNotEmpty;
    final bool hasUnderline = underlineQuery != null && underlineQuery.isNotEmpty;
    
    final highlightReg = hasHighlight
        ? RegExp('(\\b${RegExp.escape(highlightQuery)}[\\w]*)', caseSensitive: false, unicode: true)
        : null;

    final underlineReg = hasUnderline
        ? RegExp(RegExp.escape(underlineQuery), caseSensitive: false)
        : null;

    final StringBuffer buffer = StringBuffer();
    final matches = _tagRegExp.allMatches(html);
    
    bool inAnchor = false;
    final isStardict = format == 'stardict';

    for (final match in matches) {
      final part = match.group(0)!;
      final charCode = part.codeUnitAt(0);
      
      if (charCode == 60) { // Tag starts with <
        buffer.write(part);
        final lowerPart = part.toLowerCase();
        if (lowerPart.startsWith('<a ') || lowerPart == '<a>') {
          inAnchor = true;
        } else if (lowerPart == '</a>') {
          inAnchor = false;
        }
      } else if (charCode == 38 && part.endsWith(';')) { // Entity starts with &
        buffer.write(part);
      } else {
        // Text node: Normalize, Wrap, Highlight, Underline
        String text = part;
        
        if (!isStardict) {
          // Fast path for normalization if no multi-spaces or \r
          if (text.contains('\r') || text.contains('  ')) {
            text = text.replaceAll('\r\n', '\n').replaceAll(RegExp(r' [ ]+'), ' ');
          }
        }

        // Optimization: Combining word wrapping and highlighting safely
        if (wrapWords && !inAnchor && text.trim().isNotEmpty && text.length < 20000) {
          // If we have highlights, we must handle them during wrapping to avoid breaking tags
          text = text.replaceAllMapped(_wordRegExp, (m) {
            final word = m.group(1)!;
            String content = word;

            if (highlightReg != null && highlightReg.hasMatch(word)) {
              content = highlightReg.allMatches(word).fold(word, (prev, m) =>
                prev.replaceRange(m.start, m.end, '<mark>${m.group(1)}</mark>'));
            } else if (underlineReg != null && underlineReg.hasMatch(word)) {
              content = underlineReg.allMatches(word).fold(word, (prev, m) =>
                prev.replaceRange(m.start, m.end, '<mark>${m.group(0)}</mark>'));
            }

            final encoded = (word.contains('%') || word.contains(' ') || word.contains('?')) 
                ? Uri.encodeComponent(word) 
                : word;
            
            return '<a href="look_up:$encoded" class="dict-word">$content</a>';
          });
        } else {
          // No wrapping, just highlight/underline
          if (highlightReg != null) {
            text = text.replaceAllMapped(highlightReg, (m) => '<mark>${m.group(1)!}</mark>');
          }
          if (underlineReg != null) {
            text = text.replaceAllMapped(underlineReg, (m) => '<mark>${m.group(0)!}</mark>');
          }
        }

        // Convert \n to <br> as the last step
        if (text.contains('\n')) {
          buffer.write(text.replaceAll('\n', '<br>'));
        } else {
          buffer.write(text);
        }
      }
    }

    return buffer.toString().trim();
  }

  /// Deprecated: Use [processRecord] for better performance.
  static String wrapWords(String html) {
    return processRecord(html: html, format: 'html', wrapWords: true);
  }

  /// Deprecated: Use [processRecord] for better performance.
  static String highlightText(String html, String query, {String highlightColor = '#ffeb3b', String textColor = 'black'}) {
    return processRecord(html: html, format: 'html', wrapWords: false, highlightQuery: query, highlightColor: highlightColor);
  }

  /// Deprecated: Use [processRecord] for better performance.
  static String underlineText(String html, String query) {
    return processRecord(html: html, format: 'html', wrapWords: false, underlineQuery: query);
  }
}
