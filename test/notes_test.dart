import 'package:flutter_test/flutter_test.dart';
import 'package:all_rounder/features/notes/models/note_model.dart';
import 'package:all_rounder/features/notes/state/notes_notifier.dart';

void main() {
  group('Notes Module Tests (Plan Section 2 & 6)', () {
    test('WikiLinks parser extracts [[Titles]] accurately', () {
      final note = NoteModel(
        id: 'test_1',
        title: 'Quantum Computing',
        content: 'Check [[Linear Algebra]] and also [[Dr. Rao Office Hours]] before exam.',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final links = note.wikiLinks;
      expect(links.length, 2);
      expect(links[0], equals('Linear Algebra'));
      expect(links[1], equals('Dr. Rao Office Hours'));
    });

    test('NotesNotifier CRUD, full-text search, and trash lifecycle', () {
      final notifier = NotesNotifier();
      final initialCount = notifier.filteredNotes.length;

      // Add Note
      final newNote = NoteModel(
        id: 'custom_1',
        title: 'Calculus Assignment',
        content: 'Integration by parts problem set',
        folder: 'Homework',
        tags: ['math', 'urgent'],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      notifier.addNote(newNote);

      expect(notifier.filteredNotes.length, initialCount + 1);

      // Search
      notifier.setSearchQuery('Integration');
      expect(notifier.filteredNotes.length, 1);
      expect(notifier.filteredNotes.first.id, equals('custom_1'));

      // Clear search
      notifier.setSearchQuery('');
      expect(notifier.filteredNotes.length, initialCount + 1);

      // Trash lifecycle
      notifier.moveToTrash('custom_1');
      expect(notifier.filteredNotes.any((n) => n.id == 'custom_1'), isFalse);

      notifier.setShowTrash(true);
      expect(notifier.trashNotes.any((n) => n.id == 'custom_1'), isTrue);

      notifier.restoreFromTrash('custom_1');
      notifier.setShowTrash(false);
      expect(notifier.filteredNotes.any((n) => n.id == 'custom_1'), isTrue);
    });
  });
}
