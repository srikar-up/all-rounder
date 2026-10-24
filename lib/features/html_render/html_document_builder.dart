import 'dart:convert';
import 'html_sanitizer.dart';

class HtmlDocumentBuilder {
  static const csp = "default-src 'none'; img-src data:; "
      "style-src 'unsafe-inline'; font-src data:; "
      "base-uri 'none'; form-action 'none'";

  static String build({
    required SanitizedHtml sanitized,
    required bool dark,
    required bool applyAppTheme,
  }) {
    final title = const HtmlEscape().convert(sanitized.title);
    final base = applyAppTheme ? _themeCss(dark) : _minimalCss;
    final userStyles = sanitized.styles.map((c) => '<style>$c</style>').join();
    final body = sanitized.document.body?.innerHtml ?? '';
    return '<!DOCTYPE html><html lang="en"><head>'
        '<meta charset="utf-8">'
        '<meta http-equiv="Content-Security-Policy" content="$csp">'
        '<meta name="viewport" '
        'content="width=device-width, initial-scale=1, viewport-fit=cover">'
        '<meta name="color-scheme" content="${dark ? 'dark' : 'light'}">'
        '<title>$title</title><style>$base</style>$userStyles'
        '</head><body>$body</body></html>';
  }

  static const _minimalCss =
      'body{margin:16px;font-family:sans-serif;word-wrap:break-word}'
      'img,svg,table{max-width:100%}';

  // Aligned with All-Rounder's Bento theme tokens
  static String _themeCss(bool dark) {
    final bg = dark ? '#0F1015' : '#FAF8F5';
    final surface = dark ? '#1A1C24' : '#F1EFEA';
    final text = dark ? '#F5F6FA' : '#141416';
    const primary = '#6246EA';
    return 'body{margin:16px;background:$bg;color:$text;'
        'font:16px/1.6 sans-serif;word-wrap:break-word}'
        'a{color:$primary}img,svg,video{max-width:100%;height:auto}'
        'table{border-collapse:collapse;max-width:100%}'
        'td,th{border:1px solid $surface;padding:6px 10px}'
        'pre,code{background:$surface;border-radius:6px}'
        'pre{padding:12px;overflow-x:auto}';
  }
}
