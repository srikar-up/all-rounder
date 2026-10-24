enum ItemType {
  note,
  alarm,
  timetable,
  reminder,
  photo,
  vault,
}

extension ItemTypeExtension on ItemType {
  String get displayName {
    switch (this) {
      case ItemType.note:
        return 'Note';
      case ItemType.alarm:
        return 'Alarm';
      case ItemType.timetable:
        return 'Timetable Slot';
      case ItemType.reminder:
        return 'Reminder';
      case ItemType.photo:
        return 'Photo';
      case ItemType.vault:
        return 'Vault Item';
    }
  }
}
