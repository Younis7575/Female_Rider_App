import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_theme.dart';

/// Lightweight renderer for the CMS's simple HTML (p, h1–h4, ul/ol/li, strong/b,
/// em/i, br, a). Avoids pulling in a full HTML engine for legal pages.
class SimpleHtml extends StatelessWidget {
  const SimpleHtml(this.html, {super.key});
  final String html;

  static final _block = RegExp(r'<(h[1-4]|p|li|blockquote)[^>]*>([\s\S]*?)</\1>', caseSensitive: false);

  @override
  Widget build(BuildContext context) {
    final blocks = <Widget>[];
    final source = html.replaceAll(RegExp(r'\r?\n'), ' ');
    var matched = false;
    var olIndex = 0;
    var lastEnd = 0;
    for (final m in _block.allMatches(source)) {
      matched = true;
      final between = source.substring(lastEnd, m.start).toLowerCase();
      if (between.contains('<ol')) olIndex = 0;
      final ordered = _isInsideOl(source, m.start);
      lastEnd = m.end;
      final tag = m.group(1)!.toLowerCase();
      final inner = m.group(2)!;
      switch (tag) {
        case 'h1':
        case 'h2':
          blocks.add(Padding(padding: const EdgeInsets.only(top: AppSpace.lg, bottom: AppSpace.xs), child: _rich(inner, AppText.h2)));
        case 'h3':
        case 'h4':
          blocks.add(Padding(padding: const EdgeInsets.only(top: AppSpace.md, bottom: AppSpace.xs), child: _rich(inner, AppText.h3)));
        case 'li':
          olIndex++;
          blocks.add(Padding(
            padding: const EdgeInsets.only(left: AppSpace.xs, bottom: 6),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SizedBox(width: 22, child: Text(ordered ? '$olIndex.' : '•', style: AppText.body.copyWith(color: AppColors.crimson, fontWeight: FontWeight.w700))),
              Expanded(child: _rich(inner, AppText.body)),
            ]),
          ));
        default:
          blocks.add(Padding(padding: const EdgeInsets.only(bottom: AppSpace.sm), child: _rich(inner, AppText.body)));
      }
    }
    if (!matched) blocks.add(_rich(source, AppText.body));
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: blocks);
  }

  bool _isInsideOl(String s, int pos) {
    final before = s.substring(0, pos).toLowerCase();
    final ol = before.lastIndexOf('<ol');
    final ul = before.lastIndexOf('<ul');
    final olClose = before.lastIndexOf('</ol');
    return ol > ul && ol > olClose;
  }

  static final _inline = RegExp(r'<(/?)(strong|b|em|i|br|a)[^>]*>', caseSensitive: false);

  Widget _rich(String inner, TextStyle base) {
    final spans = <TextSpan>[];
    var bold = 0, italic = 0, link = 0;
    var last = 0;
    void push(String text) {
      if (text.isEmpty) return;
      spans.add(TextSpan(
        text: _decode(text),
        style: TextStyle(
          fontWeight: bold > 0 ? FontWeight.w700 : null,
          fontStyle: italic > 0 ? FontStyle.italic : null,
          color: link > 0 ? AppColors.crimson : null,
          decoration: link > 0 ? TextDecoration.underline : null,
        ),
      ));
    }

    for (final m in _inline.allMatches(inner)) {
      push(inner.substring(last, m.start).replaceAll(RegExp(r'<[^>]+>'), ''));
      last = m.end;
      final closing = m.group(1) == '/';
      final d = closing ? -1 : 1;
      switch (m.group(2)!.toLowerCase()) {
        case 'strong':
        case 'b':
          bold = (bold + d).clamp(0, 9);
        case 'em':
        case 'i':
          italic = (italic + d).clamp(0, 9);
        case 'a':
          link = (link + d).clamp(0, 9);
        case 'br':
          spans.add(const TextSpan(text: '\n'));
      }
    }
    push(inner.substring(last).replaceAll(RegExp(r'<[^>]+>'), ''));
    return Text.rich(TextSpan(style: base, children: spans));
  }

  static String _decode(String s) => s
      .replaceAll(RegExp(r'\s+'), ' ')
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll('&rsquo;', '’')
      .replaceAll('&mdash;', '—');
}
