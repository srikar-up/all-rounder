import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../notes/state/notes_notifier.dart';
import '../../notes/models/note_model.dart';
import '../../notes/screens/note_editor_screen.dart';
import '../../time/state/time_notifier.dart';

class LinkGraphScreen extends StatelessWidget {
  final NotesNotifier notesNotifier;
  final TimeNotifier timeNotifier;

  const LinkGraphScreen({
    super.key,
    required this.notesNotifier,
    required this.timeNotifier,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Build connections from notes and timetable
    final connections = <Map<String, dynamic>>[];

    // 1. Timetable to Notes
    for (final slot in timeNotifier.allSlots) {
      if (slot.linkedNoteId != null) {
        final note = notesNotifier.getNoteById(slot.linkedNoteId!);
        if (note != null) {
          connections.add({
            'sourceType': 'Timetable Slot',
            'sourceTitle': slot.title,
            'sourceIcon': Icons.calendar_today,
            'sourceColor': AppColors.primary,
            'targetType': 'Note',
            'targetTitle': note.title,
            'targetIcon': Icons.description,
            'targetColor': AppColors.cyan,
            'note': note,
          });
        }
      }
    }

    // 2. Alarms to Notes
    for (final alarm in timeNotifier.allAlarms) {
      if (alarm.linkedNoteId != null) {
        final note = notesNotifier.getNoteById(alarm.linkedNoteId!);
        if (note != null) {
          connections.add({
            'sourceType': alarm.isAlarm ? 'Alarm' : 'Reminder',
            'sourceTitle': '${alarm.time} ${alarm.title}',
            'sourceIcon': alarm.isAlarm ? Icons.alarm : Icons.notifications_active,
            'sourceColor': AppColors.rose,
            'targetType': 'Note',
            'targetTitle': note.title,
            'targetIcon': Icons.description,
            'targetColor': AppColors.cyan,
            'note': note,
          });
        }
      }
    }

    // 3. WikiLinks inside Notes
    for (final note in notesNotifier.allNotes) {
      for (final wiki in note.wikiLinks) {
        final target = notesNotifier.findNoteByTitle(wiki);
        connections.add({
          'sourceType': 'Note',
          'sourceTitle': note.title,
          'sourceIcon': Icons.description,
          'sourceColor': AppColors.cyan,
          'targetType': target != null ? 'Note' : 'Unresolved Link',
          'targetTitle': wiki,
          'targetIcon': target != null ? Icons.description : Icons.link_off,
          'targetColor': target != null ? AppColors.cyan : AppColors.warning,
          'note': target ?? note,
        });
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.cyan.withAlpha(25),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.hub_outlined, color: AppColors.cyan, size: 20),
            ),
            const SizedBox(width: 10),
            const Text('Link Graph & Backlinks'),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Informational Banner
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.cyan.withAlpha(20),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.cyan.withAlpha(60)),
            ),
            child: Row(
              children: [
                const Icon(Icons.account_tree_outlined, color: AppColors.cyan, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Unified Link Graph (Plan Section 7)',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'links(from_type, from_id, to_type, to_id). Connects notes, alarms, timetable slots, and reminders into a single navigable web.',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          Row(
            children: [
              Text(
                'Active Relations (${connections.length})',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 10),

          if (connections.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text('No connections linked yet.'),
              ),
            )
          else
            ...connections.map((c) {
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    if (c['note'] != null) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => NoteEditorScreen(
                            note: c['note'] as NoteModel?,
                            notesNotifier: notesNotifier,
                          ),
                        ),
                      );
                    }
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        // Source
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(c['sourceIcon'] as IconData, size: 14, color: c['sourceColor'] as Color),
                                  const SizedBox(width: 4),
                                  Text(
                                    c['sourceType'] as String,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: c['sourceColor'] as Color,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                c['sourceTitle'] as String,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),

                        // Link Arrow
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 10),
                          child: Icon(Icons.arrow_forward, size: 16, color: AppColors.cyan),
                        ),

                        // Target
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(c['targetIcon'] as IconData, size: 14, color: c['targetColor'] as Color),
                                  const SizedBox(width: 4),
                                  Text(
                                    c['targetType'] as String,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: c['targetColor'] as Color,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                c['targetTitle'] as String,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}
