import 'dart:convert';

class VaultFolder {
  final String id;
  final String name;
  final String? parentId;

  const VaultFolder({
    required this.id,
    required this.name,
    this.parentId,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'parentId': parentId,
  };

  factory VaultFolder.fromMap(Map<String, dynamic> map) => VaultFolder(
    id: map['id'] as String,
    name: map['name'] as String,
    parentId: map['parentId'] as String?,
  );
}

class VaultFileMetadata {
  final String id;
  final String name;
  final String? folderId;
  final int size;
  final String mimeType;
  final DateTime modified;
  final String blobId;
  final String fileIdHex;

  const VaultFileMetadata({
    required this.id,
    required this.name,
    this.folderId,
    required this.size,
    required this.mimeType,
    required this.modified,
    required this.blobId,
    required this.fileIdHex,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'folderId': folderId,
    'size': size,
    'mimeType': mimeType,
    'modified': modified.toIso8601String(),
    'blobId': blobId,
    'fileIdHex': fileIdHex,
  };

  factory VaultFileMetadata.fromMap(Map<String, dynamic> map) => VaultFileMetadata(
    id: map['id'] as String,
    name: map['name'] as String,
    folderId: map['folderId'] as String?,
    size: map['size'] as int,
    mimeType: map['mimeType'] as String? ?? 'application/octet-stream',
    modified: DateTime.parse(map['modified'] as String),
    blobId: map['blobId'] as String,
    fileIdHex: map['fileIdHex'] as String,
  );
}

class VaultIndex {
  final List<VaultFolder> folders;
  final List<VaultFileMetadata> files;

  const VaultIndex({
    this.folders = const [],
    this.files = const [],
  });

  Map<String, dynamic> toMap() => {
    'folders': folders.map((f) => f.toMap()).toList(),
    'files': files.map((f) => f.toMap()).toList(),
  };

  String serialize() => jsonEncode(toMap());

  factory VaultIndex.fromJson(String jsonStr) {
    final map = jsonDecode(jsonStr) as Map<String, dynamic>;
    final folderList = (map['folders'] as List? ?? [])
        .map((f) => VaultFolder.fromMap(f as Map<String, dynamic>))
        .toList();
    final fileList = (map['files'] as List? ?? [])
        .map((f) => VaultFileMetadata.fromMap(f as Map<String, dynamic>))
        .toList();
    return VaultIndex(folders: folderList, files: fileList);
  }

  VaultIndex copyWith({
    List<VaultFolder>? folders,
    List<VaultFileMetadata>? files,
  }) {
    return VaultIndex(
      folders: folders ?? this.folders,
      files: files ?? this.files,
    );
  }
}
