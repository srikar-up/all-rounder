import 'package:flutter/foundation.dart';
import '../models/time_models.dart';

class TimeNotifier extends ChangeNotifier {
  final List<TimetableSlot> _slots = [];
  final List<AlarmReminderItem> _alarms = [];
  int _selectedDay = 1; // 1 = Monday

  TimeNotifier() {
    _initSeeds();
  }

  List<TimetableSlot> get allSlots => List.unmodifiable(_slots);
  List<AlarmReminderItem> get allAlarms => List.unmodifiable(_alarms);
  int get selectedDay => _selectedDay;

  void setSelectedDay(int day) {
    _selectedDay = day;
    notifyListeners();
  }

  void _initSeeds() {
    // Mon - Fri college slots
    _slots.addAll([
      const TimetableSlot(
        id: 'slot_1',
        dayOfWeek: 1, // Mon
        startTime: '09:00',
        endTime: '10:30',
        title: 'Physics Lecture',
        room: 'Hall 302',
        instructor: 'Prof. Miller',
        linkedNoteId: 'note_1',
        colorValue: 0xFF4F46E5,
      ),
      const TimetableSlot(
        id: 'slot_2',
        dayOfWeek: 1, // Mon
        startTime: '11:00',
        endTime: '12:30',
        title: 'Computer Architecture',
        room: 'Lab 2',
        instructor: 'Dr. Evans',
        colorValue: 0xFF06B6D4,
      ),
      const TimetableSlot(
        id: 'slot_3',
        dayOfWeek: 2, // Tue
        startTime: '10:00',
        endTime: '11:30',
        title: 'Linear Algebra',
        room: 'Hall 101',
        instructor: 'Prof. Zhang',
        colorValue: 0xFF8B5CF6,
      ),
      const TimetableSlot(
        id: 'slot_4',
        dayOfWeek: 3, // Wed
        startTime: '09:00',
        endTime: '10:30',
        title: 'Physics Lab',
        room: 'Physics Lab B',
        instructor: 'Prof. Miller',
        linkedNoteId: 'note_1',
        colorValue: 0xFF4F46E5,
      ),
      const TimetableSlot(
        id: 'slot_5',
        dayOfWeek: 4, // Thu
        startTime: '14:00',
        endTime: '16:00',
        title: 'Embedded Systems Project',
        room: 'Innovation Hub',
        instructor: 'Prof. Sharma',
        colorValue: 0xFFF59E0B,
      ),
      const TimetableSlot(
        id: 'slot_6',
        dayOfWeek: 5, // Fri
        startTime: '09:00',
        endTime: '11:00',
        title: 'Seminar & Code Review',
        room: 'Auditorium',
        instructor: 'Dean Adams',
        colorValue: 0xFF10B981,
      ),
    ]);

    // Alarms and Reminders
    _alarms.addAll([
      const AlarmReminderItem(
        id: 'alarm_1',
        title: 'Wake Up & Morning Routine',
        time: '06:30',
        isAlarm: true,
        isRepeating: true,
        repeatDays: [1, 2, 3, 4, 5],
        isEnabled: true,
      ),
      const AlarmReminderItem(
        id: 'alarm_2',
        title: 'Prep for Physics Lecture',
        time: '08:30',
        isAlarm: false,
        isRepeating: true,
        repeatDays: [1, 3],
        linkedNoteId: 'note_1',
        isEnabled: true,
      ),
      const AlarmReminderItem(
        id: 'alarm_3',
        title: 'Daily Exercise Quota Check',
        time: '18:00',
        isAlarm: false,
        isRepeating: true,
        repeatDays: [1, 2, 3, 4, 5, 6, 7],
        linkedNoteId: 'note_3',
        isEnabled: true,
      ),
    ]);
  }

  List<TimetableSlot> get slotsForSelectedDay {
    return _slots.where((s) => s.dayOfWeek == _selectedDay).toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));
  }

  void addSlot(TimetableSlot slot) {
    _slots.add(slot);
    notifyListeners();
  }

  void updateSlot(TimetableSlot slot) {
    final index = _slots.indexWhere((s) => s.id == slot.id);
    if (index != -1) {
      _slots[index] = slot;
      notifyListeners();
    }
  }

  void deleteSlot(String id) {
    _slots.removeWhere((s) => s.id == id);
    notifyListeners();
  }

  void addAlarm(AlarmReminderItem item) {
    _alarms.add(item);
    notifyListeners();
  }

  void toggleAlarm(String id) {
    final index = _alarms.indexWhere((a) => a.id == id);
    if (index != -1) {
      _alarms[index] = _alarms[index].copyWith(isEnabled: !_alarms[index].isEnabled);
      notifyListeners();
    }
  }

  void deleteAlarm(String id) {
    _alarms.removeWhere((a) => a.id == id);
    notifyListeners();
  }

  void importMockSchedule(String source) {
    // Simulates CSV or ICS import mentioned in Section 8
    final sampleSlots = [
      TimetableSlot(
        id: 'imported_${DateTime.now().millisecondsSinceEpoch}_1',
        dayOfWeek: 1,
        startTime: '13:30',
        endTime: '15:00',
        title: 'Machine Learning',
        room: 'CS Hall 4',
        instructor: 'Dr. Turing',
        colorValue: 0xFF8B5CF6,
      ),
      TimetableSlot(
        id: 'imported_${DateTime.now().millisecondsSinceEpoch}_2',
        dayOfWeek: 3,
        startTime: '11:00',
        endTime: '12:30',
        title: 'Operating Systems',
        room: 'Lab 1',
        instructor: 'Prof. Ritchie',
        colorValue: 0xFF10B981,
      ),
    ];
    _slots.addAll(sampleSlots);
    notifyListeners();
  }
}
