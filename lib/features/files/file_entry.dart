enum FileKind { folder, note, html, image, other }

class FileEntry {
  const FileEntry({
    required this.relativePath,
    required this.name,
    required this.isDir,
    required this.size,
    required this.modified,
    required this.kind,
  });

  final String relativePath;
  final String name;
  final bool isDir;
  final int size; // bytes; 0 for folders in listings
  final DateTime modified;
  final FileKind kind;

  static FileKind kindFromExtension(String ext) {
    switch (ext.toLowerCase()) {
      case '.md':
      case '.markdown':
      case '.txt':
        return FileKind.note;
      case '.html':
      case '.htm':
        return FileKind.html;
      case '.png':
      case '.jpg':
      case '.jpeg':
      case '.gif':
      case '.webp':
      case '.svg':
        return FileKind.image;
      default:
        return FileKind.other;
    }
  }
}
