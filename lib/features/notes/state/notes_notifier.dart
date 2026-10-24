import 'package:flutter/foundation.dart';
import '../models/note_model.dart';

class NotesNotifier extends ChangeNotifier {
  final List<NoteModel> _notes = [];
  String _searchQuery = '';
  String _selectedFolder = 'All';
  String? _selectedTag;
  bool _showTrash = false;

  NotesNotifier() {
    _initSeedNotes();
  }

  List<NoteModel> get allNotes => List.unmodifiable(_notes);
  String get searchQuery => _searchQuery;
  String get selectedFolder => _selectedFolder;
  String? get selectedTag => _selectedTag;
  bool get showTrash => _showTrash;

  void _initSeedNotes() {
    final now = DateTime.now();
    _notes.addAll([
      NoteModel(
        id: 'note_1',
        title: 'Physics Lecture: Wave Mechanics',
        content: '''# Wave Mechanics & Quantum State

Notes from the morning lecture.

## Core Concepts
- Superposition principle: \$\$\Psi(x, t) = A e^{i(kx - \omega t)}\$\$
- Boundary conditions: Node at fixed ends.
- Energy dissipation in harmonic oscillators.

### Action Items
- [x] Read chapter 4 before lab
- [ ] Complete problem set 3 [[Timetable Slot: Friday Lab]]
- [ ] Review linked formulas in [[Quantum Overview]]

See attached diagram in attachments. Linked with 09:00 AM alarm.''',
        folder: 'Lectures',
        tags: ['physics', 'college', 'v1'],
        isPinned: true,
        isArchived: false,
        isTrash: false,
        attachments: const ['Standing_Wave_Harmonics.png', 'Lab_Distillation_Setup.jpg'],
        createdAt: now.subtract(const Duration(hours: 4)),
        updatedAt: now.subtract(const Duration(minutes: 30)),
      ),
      NoteModel(
        id: 'note_2',
        title: 'All-Rounder Product Vision',
        content: '''# All-Rounder Architecture

One private app for notes, time, health, and files.

## Three Guiding Promises
1. **Private by design**: No tracking, local storage first.
2. **Notes at the centre**: The heart of the product.
3. **Calm and minimal**: Notion-inspired aesthetics with Indigo `#4F46E5`.

## Feature Matrix
| Module | Storage | Sync |
|---|---|---|
| Notes | Local .md | Optional Drive |
| Timetable | SQLite | Local ICS/CSV |
| Health | Health Connect | On-device |
| Vault | AES-256-GCM | Encrypted Blob |

> "Notes first. Everything else orbits them."''',
        folder: 'Projects',
        tags: ['ideas', 'flutter', 'v1'],
        isPinned: true,
        isArchived: false,
        isTrash: false,
        createdAt: now.subtract(const Duration(days: 1)),
        updatedAt: now.subtract(const Duration(hours: 2)),
      ),
      NoteModel(
        id: 'note_3',
        title: 'Daily Fitness Log & Quota',
        content: '''# Daily Movement Goal

Target: 8,000 steps + 45 active minutes.

- Morning jog: 3.5 km
- Hydration check: 2.2L / 3.0L
- Health Connect synced successfully.

Linked with [[Morning Run Alarm]].''',
        folder: 'Health',
        tags: ['fitness', 'habits'],
        isPinned: false,
        isArchived: false,
        isTrash: false,
        createdAt: now.subtract(const Duration(days: 2)),
        updatedAt: now.subtract(const Duration(days: 1)),
      ),
    ]);
  }

  List<String> get folders {
    final set = {'All', 'Inbox'};
    for (final n in _notes.where((n) => !n.isTrash)) {
      set.add(n.folder);
    }
    return set.toList();
  }

  List<String> get tags {
    final set = <String>{};
    for (final n in _notes.where((n) => !n.isTrash)) {
      set.addAll(n.tags);
    }
    return set.toList();
  }

  List<NoteModel> get filteredNotes {
    return _notes.where((note) {
      if (_showTrash) {
        return note.isTrash;
      }
      if (note.isTrash || note.isArchived) {
        return false;
      }
      if (_selectedFolder != 'All' && note.folder != _selectedFolder) {
        return false;
      }
      if (_selectedTag != null && !note.tags.contains(_selectedTag)) {
        return false;
      }
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matchesTitle = note.title.toLowerCase().contains(q);
        final matchesContent = note.content.toLowerCase().contains(q);
        final matchesTag = note.tags.any((t) => t.toLowerCase().contains(q));
        if (!matchesTitle && !matchesContent && !matchesTag) {
          return false;
        }
      }
      return true;
    }).toList()
      ..sort((a, b) {
        if (a.isPinned != b.isPinned) {
          return a.isPinned ? -1 : 1;
        }
        return b.updatedAt.compareTo(a.updatedAt);
      });
  }

  List<NoteModel> get archivedNotes {
    return _notes.where((note) => note.isArchived && !note.isTrash).toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  List<NoteModel> get trashNotes {
    return _notes.where((note) => note.isTrash).toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void setSelectedFolder(String folder) {
    _selectedFolder = folder;
    notifyListeners();
  }

  void setSelectedTag(String? tag) {
    _selectedTag = tag;
    notifyListeners();
  }

  void setShowTrash(bool show) {
    _showTrash = show;
    notifyListeners();
  }

  void addNote(NoteModel note) {
    _notes.insert(0, note);
    notifyListeners();
  }

  void updateNote(NoteModel updated) {
    final index = _notes.indexWhere((n) => n.id == updated.id);
    if (index != -1) {
      _notes[index] = updated.copyWith(updatedAt: DateTime.now());
      notifyListeners();
    }
  }

  void togglePin(String id) {
    final index = _notes.indexWhere((n) => n.id == id);
    if (index != -1) {
      final note = _notes[index];
      _notes[index] = note.copyWith(isPinned: !note.isPinned);
      notifyListeners();
    }
  }

  void toggleArchive(String id) {
    final index = _notes.indexWhere((n) => n.id == id);
    if (index != -1) {
      final note = _notes[index];
      _notes[index] = note.copyWith(isArchived: !note.isArchived);
      notifyListeners();
    }
  }

  void moveToTrash(String id) {
    final index = _notes.indexWhere((n) => n.id == id);
    if (index != -1) {
      final note = _notes[index];
      _notes[index] = note.copyWith(isTrash: true);
      notifyListeners();
    }
  }

  void restoreFromTrash(String id) {
    final index = _notes.indexWhere((n) => n.id == id);
    if (index != -1) {
      final note = _notes[index];
      _notes[index] = note.copyWith(isTrash: false);
      notifyListeners();
    }
  }

  void deletePermanently(String id) {
    _notes.removeWhere((n) => n.id == id);
    notifyListeners();
  }

  void emptyTrash() {
    _notes.removeWhere((n) => n.isTrash);
    notifyListeners();
  }

  NoteModel? getNoteById(String id) {
    try {
      return _notes.firstWhere((n) => n.id == id);
    } catch (_) {
      return null;
    }
  }

  NoteModel? findNoteByTitle(String title) {
    try {
      return _notes.firstWhere(
        (n) => n.title.toLowerCase() == title.toLowerCase(),
      );
    } catch (_) {
      return null;
    }
  }
}
