import 'item_type.dart';

/// Representation of the unified Link Graph relation:
/// links(from_type, from_id, to_type, to_id, created_at)
class LinkItem {
  final String id;
  final ItemType fromType;
  final String fromId;
  final ItemType toType;
  final String toId;
  final String? label;
  final DateTime createdAt;

  const LinkItem({
    required this.id,
    required this.fromType,
    required this.fromId,
    required this.toType,
    required this.toId,
    this.label,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'from_type': fromType.name,
      'from_id': fromId,
      'to_type': toType.name,
      'to_id': toId,
      'label': label,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory LinkItem.fromMap(Map<String, dynamic> map) {
    return LinkItem(
      id: map['id'] as String,
      fromType: ItemType.values.byName(map['from_type'] as String),
      fromId: map['from_id'] as String,
      toType: ItemType.values.byName(map['to_type'] as String),
      toId: map['to_id'] as String,
      label: map['label'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}
