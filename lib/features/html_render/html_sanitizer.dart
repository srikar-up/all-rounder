import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;

class SanitizedHtml {
  const SanitizedHtml({
    required this.document,
    required this.styles,
    required this.title,
  });
  final Document document;
  final List<String> styles;
  final String title;
}

class HtmlSanitizer {
  static const _blockedTags = <String>{
    'script', 'noscript', 'iframe', 'frame', 'frameset', 'object', 'embed',
    'applet', 'base', 'form', 'input', 'button', 'textarea', 'select',
    'link', 'meta', 'audio', 'video', 'source', 'track', 'canvas',
  };

  static const _urlAttrs = <String>{
    'href', 'src', 'xlink:href', 'action', 'formaction', 'poster',
    'background', 'data', 'srcset', 'ping',
  };

  static final _scheme = RegExp(r'^[a-z][a-z0-9+.\-]*:');

  static SanitizedHtml sanitize(String raw) {
    final doc = html_parser.parse(raw);
    final title = doc.querySelector('title')?.text.trim() ?? '';

    final styles = <String>[];
    for (final s in doc.querySelectorAll('style').toList()) {
      styles.add(sanitizeCss(s.text));
      s.remove();
    }

    for (final el in doc.querySelectorAll('*').toList()) {
      final tag = (el.localName ?? '').toLowerCase();
      if (_blockedTags.contains(tag)) {
        el.remove();
        continue;
      }
      _cleanAttributes(el);
    }
    return SanitizedHtml(document: doc, styles: styles, title: title);
  }

  static void _cleanAttributes(Element el) {
    for (final key in el.attributes.keys.toList()) {
      final name = key.toString().toLowerCase();
      final value = el.attributes[key] ?? '';
      if (name.startsWith('on')) {
        el.attributes.remove(key);
      } else if (name == 'style') {
        el.attributes[key] = sanitizeCss(value);
      } else if (_urlAttrs.contains(name) && !_isSafeUrl(name, value)) {
        el.attributes.remove(key);
      }
    }
  }

  static bool _isSafeUrl(String attr, String value) {
    // Strip whitespace/control characters so "java\nscript:" can't sneak by.
    final v = value
        .replaceAll(RegExp(r'[\u0000-\u0020\u007f]'), '')
        .toLowerCase();
    if (v.isEmpty) return false;
    if (const {'srcset', 'ping', 'action', 'formaction', 'poster',
        'background', 'data'}.contains(attr)) {
      return false;
    }
    if (v.startsWith('#')) return true;
    if (v.startsWith('data:image/')) return true;
    if (attr == 'href' || attr == 'xlink:href') {
      return v.startsWith('http:') || v.startsWith('https:') ||
          v.startsWith('mailto:') || v.startsWith('tel:');
    }
    // src: only relative paths (resolved later by the inliner).
    if (v.startsWith('//')) return false;
    return !_scheme.hasMatch(v);
  }

  static String sanitizeCss(String css) {
    var out = css.replaceAll(
        RegExp(r'@import[^;{]*;?', caseSensitive: false), '');
    out = out.replaceAll(
        RegExp(r'expression\s*\(', caseSensitive: false), 'blocked(');
    out = out.replaceAll(
        RegExp(r'''url\(\s*(?!['"]?\s*data:(image|font)/)[^)]*\)''',
            caseSensitive: false),
        'none');
    return out;
  }
}
