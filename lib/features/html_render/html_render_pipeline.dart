import 'dart:isolate';
import 'package:flutter/foundation.dart';
import 'html_document_builder.dart';
import 'html_sanitizer.dart';
import 'image_inliner.dart';

class HtmlRenderPipeline {
  static const maxInputChars = 2000000;

  static Future<String> render({
    required String rawHtml,
    required String attachmentsDir,
    required bool dark,
    required bool applyAppTheme,
  }) async {
    if (rawHtml.length > maxInputChars) {
      return '<!DOCTYPE html><html><body><p>This note is too large to preview.</p></body></html>';
    }

    if (kIsWeb) {
      final s = HtmlSanitizer.sanitize(rawHtml);
      await ImageInliner.inline(s.document, attachmentsDir);
      return HtmlDocumentBuilder.build(
        sanitized: s,
        dark: dark,
        applyAppTheme: applyAppTheme,
      );
    }

    // Heavy parsing and file reads stay off the UI thread on native platforms.
    return Isolate.run(() async {
      final s = HtmlSanitizer.sanitize(rawHtml);
      await ImageInliner.inline(s.document, attachmentsDir);
      return HtmlDocumentBuilder.build(
        sanitized: s,
        dark: dark,
        applyAppTheme: applyAppTheme,
      );
    });
  }
}
