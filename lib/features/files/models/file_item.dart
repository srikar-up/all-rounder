enum FileType {
  markdown,
  html,
  image,
  pdf,
  folder,
}

class WorkspaceFileItem {
  final String id;
  final String name;
  final FileType type;
  final String folder;
  final String size;
  final DateTime updatedAt;
  final String content; // HTML content, note markdown, or image asset/description
  final String? linkedAlarmOrNote;
  final String colorHex;

  const WorkspaceFileItem({
    required this.id,
    required this.name,
    required this.type,
    required this.folder,
    required this.size,
    required this.updatedAt,
    required this.content,
    this.linkedAlarmOrNote,
    this.colorHex = '#6246EA',
  });

  WorkspaceFileItem copyWith({
    String? id,
    String? name,
    FileType? type,
    String? folder,
    String? size,
    DateTime? updatedAt,
    String? content,
    String? linkedAlarmOrNote,
    String? colorHex,
  }) {
    return WorkspaceFileItem(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      folder: folder ?? this.folder,
      size: size ?? this.size,
      updatedAt: updatedAt ?? this.updatedAt,
      content: content ?? this.content,
      linkedAlarmOrNote: linkedAlarmOrNote ?? this.linkedAlarmOrNote,
      colorHex: colorHex ?? this.colorHex,
    );
  }
}
