import 'package:path/path.dart' as p;

class SandboxViolation implements Exception {
  const SandboxViolation();
  @override
  String toString() => 'Path is outside the app storage folder.';
}

class Sandbox {
  Sandbox(String rootPath) : root = p.normalize(p.absolute(rootPath));
  final String root;

  /// Turns a root-relative path into an absolute path, or throws.
  String resolve(String relative) {
    if (p.isAbsolute(relative)) {
      final norm = p.normalize(relative);
      if (norm != root && !p.isWithin(root, norm)) {
        throw const SandboxViolation();
      }
      return norm;
    }
    final full = p.normalize(p.join(root, relative));
    if (full != root && !p.isWithin(root, full)) {
      throw const SandboxViolation();
    }
    return full;
  }

  String relativeOf(String absolute) => p.relative(absolute, from: root);

  bool isProtected(String relative) {
    final n = p.normalize(relative);
    return n == 'notes' || n == 'attachments' || n == 'vault' || n == '.trash';
  }

  bool isHidden(String relative) {
    final parts = p.split(p.normalize(relative));
    if (parts.isEmpty) return false;
    final first = parts.first;
    return first.startsWith('.') || first == 'vault';
  }
}
