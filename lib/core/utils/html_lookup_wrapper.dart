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

    final String? lowerHighlight = highlightQuery?.toLowerCase();
    final String? lowerUnderline = underlineQuery?.toLowerCase();
    
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
          // Direct StringBuffer iteration is much faster than replaceAllMapped
          final wordMatches = _wordRegExp.allMatches(text);
          int lastEnd = 0;
          
          for (final wm in wordMatches) {
            // Write the non-word characters before this word
            if (wm.start > lastEnd) {
              final gap = text.substring(lastEnd, wm.start);
              buffer.write(gap.contains('\n') ? gap.replaceAll('\n', '<br>') : gap);
            }
            
            final word = wm.group(1)!;
            String content = word;
            
            // Fast-path String operations are literally ~1000x faster than \b Unicode RegExp
            if (lowerHighlight != null && lowerHighlight.isNotEmpty) {
              final lowerWord = word.toLowerCase();
              if (lowerWord.startsWith(lowerHighlight)) {
                // Highlight matches word prefixes.
                final hLen = lowerHighlight.length;
                if (hLen <= word.length) {
                  content = '<mark>${word.substring(0, hLen)}</mark>${word.substring(hLen)}';
                }
              } else if (lowerUnderline != null && lowerUnderline.isNotEmpty) {
                final idx = lowerWord.indexOf(lowerUnderline);
                if (idx != -1) {
                  final uLen = lowerUnderline.length;
                  content = '${word.substring(0, idx)}<mark>${word.substring(idx, idx + uLen)}</mark>${word.substring(idx + uLen)}';
                }
              }
            } else if (lowerUnderline != null && lowerUnderline.isNotEmpty) {
               final lowerWord = word.toLowerCase();
               final idx = lowerWord.indexOf(lowerUnderline);
               if (idx != -1) {
                 final uLen = lowerUnderline.length;
                 content = '${word.substring(0, idx)}<mark>${word.substring(idx, idx + uLen)}</mark>${word.substring(idx + uLen)}';
               }
            }
            
            // Build the anchor
            final encoded = (word.contains('%') || word.contains(' ') || word.contains('?')) 
                ? Uri.encodeComponent(word) 
                : word;
                
            buffer.write('<a href="look_up:$encoded" class="dict-word">$content</a>');
            lastEnd = wm.end;
          }
          
          // Write any remaining non-word characters after the last word
          if (lastEnd < text.length) {
            final trailing = text.substring(lastEnd);
            buffer.write(trailing.contains('\n') ? trailing.replaceAll('\n', '<br>') : trailing);
          }
          
        } else {
          // No wrapping, just highlight/underline and newline replacement
          if (lowerHighlight != null && lowerHighlight.isNotEmpty || lowerUnderline != null && lowerUnderline.isNotEmpty) {
            final lowerText = text.toLowerCase();
            final StringBuffer noWrapBuf = StringBuffer();
            int curEnd = 0;
            
            // A simple naive highlighting for non-wrapped text
            if (lowerHighlight != null && lowerHighlight.isNotEmpty) {
               int i = lowerText.indexOf(lowerHighlight);
               while(i != -1) {
                 noWrapBuf.write(text.substring(curEnd, i));
                 noWrapBuf.write('<mark>${text.substring(i, i + lowerHighlight.length)}</mark>');
                 curEnd = i + lowerHighlight.length;
                 i = lowerText.indexOf(lowerHighlight, curEnd);
               }
               noWrapBuf.write(text.substring(curEnd));
               text = noWrapBuf.toString();
            } else if (lowerUnderline != null && lowerUnderline.isNotEmpty) {
               int i = lowerText.indexOf(lowerUnderline);
               while(i != -1) {
                 noWrapBuf.write(text.substring(curEnd, i));
                 noWrapBuf.write('<mark>${text.substring(i, i + lowerUnderline.length)}</mark>');
                 curEnd = i + lowerUnderline.length;
                 i = lowerText.indexOf(lowerUnderline, curEnd);
               }
               noWrapBuf.write(text.substring(curEnd));
               text = noWrapBuf.toString();
            }
          }

          if (text.contains('\n')) {
            buffer.write(text.replaceAll('\n', '<br>'));
          } else {
            buffer.write(text);
          }
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
