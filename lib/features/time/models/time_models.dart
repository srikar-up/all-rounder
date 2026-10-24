class TimetableSlot {
  final String id;
  final int dayOfWeek; // 1 = Monday, 7 = Sunday
  final String startTime; // "09:00"
  final String endTime; // "10:30"
  final String title;
  final String room;
  final String instructor;
  final String? linkedNoteId;
  final int colorValue;

  const TimetableSlot({
    required this.id,
    required this.dayOfWeek,
    required this.startTime,
    required this.endTime,
    required this.title,
    this.room = '',
    this.instructor = '',
    this.linkedNoteId,
    this.colorValue = 0xFF4F46E5,
  });

  TimetableSlot copyWith({
    String? id,
    int? dayOfWeek,
    String? startTime,
    String? endTime,
    String? title,
    String? room,
    String? instructor,
    String? linkedNoteId,
    int? colorValue,
  }) {
    return TimetableSlot(
      id: id ?? this.id,
      dayOfWeek: dayOfWeek ?? this.dayOfWeek,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      title: title ?? this.title,
      room: room ?? this.room,
      instructor: instructor ?? this.instructor,
      linkedNoteId: linkedNoteId ?? this.linkedNoteId,
      colorValue: colorValue ?? this.colorValue,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'day_of_week': dayOfWeek,
      'start_time': startTime,
      'end_time': endTime,
      'title': title,
      'room': room,
      'instructor': instructor,
      'linked_note_id': linkedNoteId,
      'color_value': colorValue,
    };
  }

  factory TimetableSlot.fromMap(Map<String, dynamic> map) {
    return TimetableSlot(
      id: map['id'] as String,
      dayOfWeek: map['day_of_week'] as int,
      startTime: map['start_time'] as String,
      endTime: map['end_time'] as String,
      title: map['title'] as String,
      room: map['room'] as String? ?? '',
      instructor: map['instructor'] as String? ?? '',
      linkedNoteId: map['linked_note_id'] as String?,
      colorValue: map['color_value'] as int? ?? 0xFF4F46E5,
    );
  }
}

class AlarmReminderItem {
  final String id;
  final String title;
  final String time; // "07:30"
  final bool isAlarm; // true = Alarm, false = Reminder
  final bool isRepeating;
  final List<int> repeatDays; // [1, 2, 3, 4, 5]
  final String? linkedNoteId;
  final bool isEnabled;

  const AlarmReminderItem({
    required this.id,
    required this.title,
    required this.time,
    this.isAlarm = true,
    this.isRepeating = false,
    this.repeatDays = const [],
    this.linkedNoteId,
    this.isEnabled = true,
  });

  AlarmReminderItem copyWith({
    String? id,
    String? title,
    String? time,
    bool? isAlarm,
    bool? isRepeating,
    List<int>? repeatDays,
    String? linkedNoteId,
    bool? isEnabled,
  }) {
    return AlarmReminderItem(
      id: id ?? this.id,
      title: title ?? this.title,
      time: time ?? this.time,
      isAlarm: isAlarm ?? this.isAlarm,
      isRepeating: isRepeating ?? this.isRepeating,
      repeatDays: repeatDays ?? this.repeatDays,
      linkedNoteId: linkedNoteId ?? this.linkedNoteId,
      isEnabled: isEnabled ?? this.isEnabled,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'time': time,
      'is_alarm': isAlarm,
      'is_repeating': isRepeating,
      'repeat_days': repeatDays,
      'linked_note_id': linkedNoteId,
      'is_enabled': isEnabled,
    };
  }

  factory AlarmReminderItem.fromMap(Map<String, dynamic> map) {
    return AlarmReminderItem(
      id: map['id'] as String,
      title: map['title'] as String,
      time: map['time'] as String,
      isAlarm: map['is_alarm'] as bool? ?? true,
      isRepeating: map['is_repeating'] as bool? ?? false,
      repeatDays: List<int>.from(map['repeat_days'] as List? ?? []),
      linkedNoteId: map['linked_note_id'] as String?,
      isEnabled: map['is_enabled'] as bool? ?? true,
    );
  }
}
