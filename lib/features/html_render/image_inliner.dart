import 'dart:convert';
import 'dart:io';
import 'package:html/dom.dart';
import 'package:path/path.dart' as p;

class ImageInliner {
  static const maxImageBytes = 2 * 1024 * 1024;
  static const maxTotalBytes = 10 * 1024 * 1024;
  static const _mime = <String, String>{
    '.png': 'image/png',
    '.jpg': 'image/jpeg',
    '.jpeg': 'image/jpeg',
    '.gif': 'image/gif',
    '.webp': 'image/webp',
    '.svg': 'image/svg+xml',
  };

  static Future<void> inline(Document doc, String baseDir) async {
    var total = 0;
    for (final img in doc.querySelectorAll('img').toList()) {
      final src = img.attributes['src'];
      if (src == null || src.isEmpty) continue;
      if (src.toLowerCase().startsWith('data:')) continue;
      try {
        final rel = Uri.decodeComponent(Uri.parse(src).path);
        final resolved = p.normalize(p.join(baseDir, rel));
        // Path-traversal guard: must stay inside the attachments folder.
        if (!p.isWithin(baseDir, resolved)) {
          _fail(img);
          continue;
        }
        final mime = _mime[p.extension(resolved).toLowerCase()];
        final file = File(resolved);
        if (mime == null || !await file.exists()) {
          _fail(img);
          continue;
        }
        final len = await file.length();
        if (len > maxImageBytes || total + len > maxTotalBytes) {
          _fail(img);
          continue;
        }
        total += len;
        final bytes = await file.readAsBytes();
        img.attributes['src'] = 'data:$mime;base64,${base64Encode(bytes)}';
      } catch (_) {
        _fail(img);
      }
    }
  }

  static void _fail(Element img) {
    img.attributes.remove('src');
    img.attributes['alt'] = img.attributes['alt'] ?? 'Image unavailable';
  }
}
