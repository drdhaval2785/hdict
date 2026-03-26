import 'package:flutter/widgets.dart';
import 'package:flutter_html/flutter_html.dart';

class AnchorIdExtension extends HtmlExtension {
  const AnchorIdExtension();

  @override
  Set<String> get supportedTags => const {''};

  @override
  bool matches(ExtensionContext context) {
    return context.id.isNotEmpty &&
        context.id != '[[No ID]]' &&
        context.currentStep == CurrentStep.building;
  }

  @override
  InlineSpan build(ExtensionContext context) {
    final anchorKey = AnchorKey.of(context.parser.key, context.styledElement);

    final child = CssBoxWidget.withInlineSpanChildren(
      children: context.inlineSpanChildren!,
      style: context.style!,
    );

    return WidgetSpan(
      child: Container(key: anchorKey, child: child),
    );
  }
}
