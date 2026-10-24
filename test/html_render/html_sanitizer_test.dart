import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:all_rounder/features/html_render/html_sanitizer.dart';

void main() {
  group('HtmlSanitizer Tests (Phase 2)', () {
    test('removes <script>, inline onerror handler, and onload on body', () {
      const raw = '''
        <body onload="alert(1)">
          <script>alert('pwn')</script>
          <img src="valid.png" onerror="alert(2)">
        </body>
      ''';
      final sanitized = HtmlSanitizer.sanitize(raw);
      final html = sanitized.document.body?.innerHtml ?? '';

      expect(html.contains('<script>'), isFalse);
      expect(html.contains('alert'), isFalse);
      expect(html.contains('onload'), isFalse);
      expect(html.contains('onerror'), isFalse);
      expect(sanitized.document.querySelectorAll('script').isEmpty, isTrue);
    });

    test('strips javascript: pseudo-protocols with mixed case, whitespace and newlines', () {
      const raw = '''
        <div>
          <a id="l1" href="javascript:alert(1)">Link 1</a>
          <a id="l2" href="  JaVaScRiPt:alert(2)">Link 2</a>
          <a id="l3" href="java\nscript:alert(3)">Link 3</a>
        </div>
      ''';
      final sanitized = HtmlSanitizer.sanitize(raw);
      for (final a in sanitized.document.querySelectorAll('a')) {
        expect(a.attributes.containsKey('href'), isFalse);
      }
    });

    test('removes forbidden tags: iframe, object, embed, base, form, meta, link', () {
      const raw = '''
        <head>
          <base href="https://attacker.com/">
          <meta http-equiv="refresh" content="0;url=http://attacker.com">
          <link rel="stylesheet" href="http://attacker.com/evil.css">
        </head>
        <body>
          <iframe src="http://evil.com"></iframe>
          <object data="evil.swf"></object>
          <embed src="evil.swf">
          <form action="http://evil.com/post">
            <input type="text" name="secret">
            <button>Submit</button>
          </form>
        </body>
      ''';
      final sanitized = HtmlSanitizer.sanitize(raw);
      final doc = sanitized.document;

      expect(doc.querySelectorAll('iframe').isEmpty, isTrue);
      expect(doc.querySelectorAll('object').isEmpty, isTrue);
      expect(doc.querySelectorAll('embed').isEmpty, isTrue);
      expect(doc.querySelectorAll('base').isEmpty, isTrue);
      expect(doc.querySelectorAll('meta').isEmpty, isTrue);
      expect(doc.querySelectorAll('link').isEmpty, isTrue);
      expect(doc.querySelectorAll('form').isEmpty, isTrue);
      expect(doc.querySelectorAll('input').isEmpty, isTrue);
      expect(doc.querySelectorAll('button').isEmpty, isTrue);
    });

    test('sanitizes CSS: strips @import and remote url(...)', () {
      const raw = '''
        <style>
          @import url("http://evil.com/style.css");
          body {
            background: url("http://evil.com/leak.png");
            color: expression(alert('ie'));
          }
        </style>
        <div style="background: url('http://evil.com/tracker.png'); color: expression(alert(1));">
          Text
        </div>
      ''';
      final sanitized = HtmlSanitizer.sanitize(raw);
      expect(sanitized.styles.length, 1);
      final styleText = sanitized.styles.first;

      expect(styleText.contains('@import'), isFalse);
      expect(styleText.contains('http://evil.com'), isFalse);
      expect(styleText.contains('blocked('), isTrue);

      final div = sanitized.document.querySelector('div')!;
      final inlineStyle = div.attributes['style']!;
      expect(inlineStyle.contains('http://evil.com'), isFalse);
      expect(inlineStyle.contains('none'), isTrue);
      expect(inlineStyle.contains('blocked('), isTrue);
    });

    test('blocks remote images (http:// and //) while allowing relative paths and data: URIs', () {
      const raw = '''
        <div>
          <img id="img1" src="http://example.com/remote.png">
          <img id="img2" src="//example.com/relative_scheme.png">
          <img id="img3" src="images/local.png">
          <img id="img4" src="data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==">
        </div>
      ''';
      final sanitized = HtmlSanitizer.sanitize(raw);

      final img1 = sanitized.document.querySelector('#img1')!;
      final img2 = sanitized.document.querySelector('#img2')!;
      final img3 = sanitized.document.querySelector('#img3')!;
      final img4 = sanitized.document.querySelector('#img4')!;

      expect(img1.attributes.containsKey('src'), isFalse);
      expect(img2.attributes.containsKey('src'), isFalse);
      expect(img3.attributes['src'], 'images/local.png');
      expect(img4.attributes['src']?.startsWith('data:image/png'), isTrue);
    });

    test('cleans svg: removes event handlers, keeps svg markup', () {
      const raw = '''
        <svg onload="alert('svg')">
          <circle cx="50" cy="50" r="40" stroke="green" fill="yellow" />
        </svg>
      ''';
      final sanitized = HtmlSanitizer.sanitize(raw);
      final svg = sanitized.document.querySelector('svg')!;

      expect(svg.attributes.containsKey('onload'), isFalse);
      expect(svg.querySelector('circle'), isNotNull);
    });

    test('preserves legitimate safe content: headings, tables, lists, links, data-URIs', () {
      const raw = '''
        <!DOCTYPE html>
        <html>
        <head><title>Quantum Notes</title></head>
        <body>
          <h1>Heading 1</h1>
          <p>Paragraph with <a href="https://example.com">https link</a> and <a href="#anchor">anchor</a>.</p>
          <table>
            <tr><th>Header</th></tr>
            <tr><td>Cell</td></tr>
          </table>
          <ul>
            <li>Item 1</li>
          </ul>
        </body>
        </html>
      ''';
      final sanitized = HtmlSanitizer.sanitize(raw);
      expect(sanitized.title, 'Quantum Notes');
      expect(sanitized.document.querySelector('h1')?.text, 'Heading 1');
      expect(sanitized.document.querySelectorAll('a').length, 2);
      expect(sanitized.document.querySelector('table'), isNotNull);
      expect(sanitized.document.querySelectorAll('li').length, 1);
    });

    test('handles malformed HTML, empty input, and multilingual text correctly', () {
      // Empty input
      final empty = HtmlSanitizer.sanitize('');
      expect(empty.title, '');
      expect(empty.styles.isEmpty, isTrue);

      // Multilingual (Hindi, Punjabi, Arabic, emoji)
      const multi = '<div>नमस्ते ਸ਼੍ਰੀ ਅਕਾਲ مرحبا 🌟🚀🧪</div>';
      final sanitizedMulti = HtmlSanitizer.sanitize(multi);
      final bodyText = sanitizedMulti.document.body?.text ?? '';
      expect(bodyText.contains('नमस्ते'), isTrue);
      expect(bodyText.contains('ਸ਼੍ਰੀ ਅਕਾਲ'), isTrue);
      expect(bodyText.contains('مرحبا'), isTrue);
      expect(bodyText.contains('🌟🚀🧪'), isTrue);

      // Malformed HTML (unclosed tags)
      const malformed = '<div><p>Unclosed paragraph <b>bold text';
      final sanitizedMalformed = HtmlSanitizer.sanitize(malformed);
      expect(sanitizedMalformed.document.querySelector('b')?.text, 'bold text');
    });

    test('processes full malicious fixture safely', () {
      final file = File('test/fixtures/malicious_sample.html');
      if (file.existsSync()) {
        final content = file.readAsStringSync();
        final sanitized = HtmlSanitizer.sanitize(content);
        final inner = sanitized.document.body?.innerHtml ?? '';

        expect(inner.contains('<script>'), isFalse);
        expect(inner.contains('iframe'), isFalse);
        expect(inner.contains('object'), isFalse);
        expect(inner.contains('embed'), isFalse);
        expect(inner.contains('javascript:'), isFalse);
        expect(inner.contains('onload'), isFalse);
        expect(inner.contains('onerror'), isFalse);
      }
    });
  });
}
