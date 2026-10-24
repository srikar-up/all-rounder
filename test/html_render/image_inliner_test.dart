import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:path/path.dart' as p;
import 'package:all_rounder/features/html_render/image_inliner.dart';

void main() {
  group('ImageInliner Tests (Phase 3)', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('all_rounder_inliner_test_');
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('inlines existing image as base64 data URI', () async {
      final imgFile = File(p.join(tempDir.path, 'valid.png'));
      imgFile.writeAsBytesSync([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);

      final doc = html_parser.parse('<img src="valid.png" alt="Test">');
      await ImageInliner.inline(doc, tempDir.path);

      final img = doc.querySelector('img')!;
      expect(img.attributes['src']?.startsWith('data:image/png;base64,'), isTrue);
      expect(img.attributes['alt'], 'Test');
    });

    test('handles URL-encoded filenames properly', () async {
      final imgFile = File(p.join(tempDir.path, 'my diagram.png'));
      imgFile.writeAsBytesSync([1, 2, 3, 4]);

      final doc = html_parser.parse('<img src="my%20diagram.png">');
      await ImageInliner.inline(doc, tempDir.path);

      final img = doc.querySelector('img')!;
      expect(img.attributes['src']?.startsWith('data:image/png;base64,'), isTrue);
    });

    test('leaves existing data: URI images unchanged', () async {
      const dataUri = 'data:image/jpeg;base64,/9j/4AAQSkZJRg==';
      final doc = html_parser.parse('<img src="$dataUri">');
      await ImageInliner.inline(doc, tempDir.path);

      final img = doc.querySelector('img')!;
      expect(img.attributes['src'], dataUri);
    });

    test('fails safely for missing file without throwing', () async {
      final doc = html_parser.parse('<img src="non_existent.jpg">');
      await ImageInliner.inline(doc, tempDir.path);

      final img = doc.querySelector('img')!;
      expect(img.attributes.containsKey('src'), isFalse);
      expect(img.attributes['alt'], 'Image unavailable');
    });

    test('fails safely for unsupported extension', () async {
      final file = File(p.join(tempDir.path, 'malicious.exe'));
      file.writeAsBytesSync([1, 2, 3, 4]);

      final doc = html_parser.parse('<img src="malicious.exe">');
      await ImageInliner.inline(doc, tempDir.path);

      final img = doc.querySelector('img')!;
      expect(img.attributes.containsKey('src'), isFalse);
      expect(img.attributes['alt'], 'Image unavailable');
    });

    test('blocks path traversal attempts (../../x.png and absolute paths)', () async {
      final outsideFile = File(p.join(tempDir.parent.path, 'outside.png'));
      outsideFile.writeAsBytesSync([1, 2, 3]);

      try {
        final doc = html_parser.parse('<img src="../outside.png"><img src="/etc/passwd">');
        await ImageInliner.inline(doc, tempDir.path);

        for (final img in doc.querySelectorAll('img')) {
          expect(img.attributes.containsKey('src'), isFalse);
          expect(img.attributes['alt'], 'Image unavailable');
        }
      } finally {
        if (outsideFile.existsSync()) outsideFile.deleteSync();
      }
    });

    test('fails safely when image exceeds maxImageBytes (2MB)', () async {
      final bigFile = File(p.join(tempDir.path, 'huge.jpg'));
      // Create a 2.5 MB file
      final bytes = List<int>.filled(2500000, 0);
      bigFile.writeAsBytesSync(bytes);

      final doc = html_parser.parse('<img src="huge.jpg">');
      await ImageInliner.inline(doc, tempDir.path);

      final img = doc.querySelector('img')!;
      expect(img.attributes.containsKey('src'), isFalse);
      expect(img.attributes['alt'], 'Image unavailable');
    });
  });
}
