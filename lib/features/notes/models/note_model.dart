class NoteModel {
  final String id;
  final String title;
  final String content;
  final String folder;
  final List<String> tags;
  final bool isPinned;
  final bool isArchived;
  final bool isTrash;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<String> attachments;

  const NoteModel({
    required this.id,
    required this.title,
    required this.content,
    this.folder = 'Inbox',
    this.tags = const [],
    this.isPinned = false,
    this.isArchived = false,
    this.isTrash = false,
    required this.createdAt,
    required this.updatedAt,
    this.attachments = const [],
  });

  /// Extracts [[WikiLinks]] from note markdown content
  List<String> get wikiLinks {
    final regex = RegExp(r'\[\[(.*?)\]\]');
    final matches = regex.allMatches(content);
    return matches.map((m) => m.group(1)!.trim()).where((s) => s.isNotEmpty).toList();
  }

  NoteModel copyWith({
    String? id,
    String? title,
    String? content,
    String? folder,
    List<String>? tags,
    bool? isPinned,
    bool? isArchived,
    bool? isTrash,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<String>? attachments,
  }) {
    return NoteModel(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      folder: folder ?? this.folder,
      tags: tags ?? this.tags,
      isPinned: isPinned ?? this.isPinned,
      isArchived: isArchived ?? this.isArchived,
      isTrash: isTrash ?? this.isTrash,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      attachments: attachments ?? this.attachments,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'folder': folder,
      'tags': tags,
      'is_pinned': isPinned,
      'is_archived': isArchived,
      'is_trash': isTrash,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'attachments': attachments,
    };
  }

  factory NoteModel.fromMap(Map<String, dynamic> map) {
    return NoteModel(
      id: map['id'] as String,
      title: map['title'] as String,
      content: map['content'] as String,
      folder: map['folder'] as String? ?? 'Inbox',
      tags: List<String>.from(map['tags'] as List? ?? []),
      isPinned: map['is_pinned'] as bool? ?? false,
      isArchived: map['is_archived'] as bool? ?? false,
      isTrash: map['is_trash'] as bool? ?? false,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      attachments: List<String>.from(map['attachments'] as List? ?? []),
    );
  }
}
