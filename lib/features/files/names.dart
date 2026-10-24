import 'dart:io';
import 'package:path/path.dart' as p;

String? validateName(String name) {
  final n = name.trim();
  if (n.isEmpty) return 'Name cannot be empty';
  if (n.length > 120) return 'Name is too long';
  if (n == '.' || n == '..') return 'Invalid name';
  if (n.startsWith('.')) return 'Name cannot start with a dot';
  if (RegExp(r'[\\/:*?"<>|\u0000-\u001f]').hasMatch(n)) {
    return 'Name contains invalid characters';
  }
  return null;
}

/// Returns a path in [dir] that does not exist yet: "name", "name (1)", ...
Future<String> uniquePath(String dir, String name, {required bool isDir}) async {
  final base = isDir ? name : p.basenameWithoutExtension(name);
  final ext = isDir ? '' : p.extension(name);
  var candidate = p.join(dir, name);
  var i = 1;
  while (await FileSystemEntity.type(candidate, followLinks: false) !=
      FileSystemEntityType.notFound) {
    candidate = p.join(dir, '$base ($i)$ext');
    i++;
  }
  return candidate;
}
