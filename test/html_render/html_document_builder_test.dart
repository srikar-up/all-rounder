import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:all_rounder/features/html_render/html_document_builder.dart';
import 'package:all_rounder/features/html_render/html_sanitizer.dart';

void main() {
  group('HtmlDocumentBuilder Tests (Phase 3)', () {
    test('builds full HTML page with strict CSP and viewport tags', () {
      final doc = html_parser.parse('<h1>Quantum</h1><p>Body</p>');
      final sanitized = SanitizedHtml(
        document: doc,
        styles: ['.custom { color: red; }'],
        title: 'Notes & Formula <Test>',
      );

      final result = HtmlDocumentBuilder.build(
        sanitized: sanitized,
        dark: false,
        applyAppTheme: true,
      );

      expect(result.contains('<!DOCTYPE html>'), isTrue);
      expect(result.contains(HtmlDocumentBuilder.csp), isTrue);
      expect(result.contains('viewport-fit=cover'), isTrue);
      // Title escaped
      expect(result.contains('<title>Notes &amp; Formula &lt;Test&gt;</title>'), isTrue);
      // User styles come after base CSS
      expect(result.indexOf('.custom { color: red; }') > result.indexOf('<style>'), isTrue);
      expect(result.contains('<h1>Quantum</h1>'), isTrue);
    });

    test('generates different background and text styles for dark and light themes', () {
      final doc = html_parser.parse('<p>Test</p>');
      final sanitized = SanitizedHtml(document: doc, styles: [], title: 'Title');

      final lightResult = HtmlDocumentBuilder.build(
        sanitized: sanitized,
        dark: false,
        applyAppTheme: true,
      );

      final darkResult = HtmlDocumentBuilder.build(
        sanitized: sanitized,
        dark: true,
        applyAppTheme: true,
      );

      expect(lightResult.contains('color-scheme" content="light"'), isTrue);
      expect(darkResult.contains('color-scheme" content="dark"'), isTrue);
      expect(lightResult != darkResult, isTrue);
    });

    test('applies minimal CSS when applyAppTheme is false', () {
      final doc = html_parser.parse('<p>Raw</p>');
      final sanitized = SanitizedHtml(document: doc, styles: [], title: 'Title');

      final result = HtmlDocumentBuilder.build(
        sanitized: sanitized,
        dark: false,
        applyAppTheme: false,
      );

      expect(result.contains('word-wrap:break-word'), isTrue);
      expect(result.contains('border-collapse'), isFalse);
    });
  });
}
