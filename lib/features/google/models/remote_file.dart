class RemoteFile {
  const RemoteFile({
    required this.id,
    required this.name,
    required this.size,
    required this.modified,
    required this.properties,
  });

  final String id;
  final String name;
  final int size;
  final DateTime modified;
  final Map<String, String> properties;
}
