import 'package:hdict/core/utils/logger.dart';
/// A utility to wrap every word in a string with HTML links for dictionary lookup.
class HtmlLookupWrapper {
  static final RegExp _tagRegExp = RegExp(r'<[^>]*>|&[a-z0-9#]{2,10};|[^<&]+', caseSensitive: false);

  /// Processes a dictionary record in a single pass to maximize performance.
  /// Combines whitespace normalization, word wrapping, highlighting, and underlining.
  static String processRecord({
    required String html,
    required String format,
    String? typeSequence,
    String? highlightQuery,
    String? underlineQuery,
  }) {
    if (html.isEmpty) return '';
    hDebugPrint('HtmlLookupWrapper: Input: [$html]');

    final String? lowerHighlight = highlightQuery?.toLowerCase();
    final String? lowerUnderline = underlineQuery?.toLowerCase();
    
    final StringBuffer buffer = StringBuffer();
    final matches = _tagRegExp.allMatches(html);
    
    final isStardict = format == 'stardict';

    for (final match in matches) {
      final part = match.group(0)!;
      final charCode = part.codeUnitAt(0);
      
      if (charCode == 60) { // Tag starts with <
        buffer.write(part);
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

        // Wrapping logic removed in favor of tap-position detection in the UI layer.
        // This ensures better performance and avoids inflating HTML size.
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

    final result = buffer.toString().trim();
    hDebugPrint('HtmlLookupWrapper: Result: [$result]');
    return result;
  }

  /// Process record for basic highlighting.
  static String highlightText(String html, String query) {
    return processRecord(html: html, format: 'html', highlightQuery: query);
  }

  /// Process record for underlining.
  static String underlineText(String html, String query) {
    return processRecord(html: html, format: 'html', underlineQuery: query);
  }
}
