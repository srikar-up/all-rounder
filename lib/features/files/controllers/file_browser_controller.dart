import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import '../file_entry.dart';
import '../file_service.dart';

enum FileViewMode { list, grid }

enum FileSortOption { name, modified, size, type }

class FileBrowserController extends ChangeNotifier {
  FileBrowserController(this.service) {
    _fsSubscription = service.events.listen((_) {
      refresh();
    });
    _loadPreferences().then((_) => refresh());
  }

  final FileService service;
  StreamSubscription<FsEvent>? _fsSubscription;

  String _currentDir = '';
  List<FileEntry> _entries = [];
  bool _isLoading = false;
  String? _error;
  FileViewMode _viewMode = FileViewMode.list;
  FileSortOption _sort = FileSortOption.name;
  bool _sortAscending = true;
  final Set<String> _selection = <String>{};
  String _query = '';
  int _requestCounter = 0;

  // Getters
  String get currentDir => _currentDir;
  bool get isAtRoot => _currentDir.isEmpty || _currentDir == '.';
  List<FileEntry> get entries => List.unmodifiable(_entries);
  bool get isLoading => _isLoading;
  String? get error => _error;
  FileViewMode get viewMode => _viewMode;
  FileSortOption get sort => _sort;
  bool get sortAscending => _sortAscending;
  Set<String> get selection => Set.unmodifiable(_selection);
  bool get isSelectionMode => _selection.isNotEmpty;
  String get query => _query;
  bool get isSearching => _query.trim().isNotEmpty;

  /// Breadcrumbs breakdown: list of MapEntry(displayName, relativePath)
  List<MapEntry<String, String>> get breadcrumbs {
    final crumbs = <MapEntry<String, String>>[
      const MapEntry('Files', ''),
    ];
    if (isAtRoot) return crumbs;

    final parts = p.split(p.normalize(_currentDir));
    var accum = '';
    for (final part in parts) {
      if (part.isEmpty || part == '.') continue;
      accum = accum.isEmpty ? part : p.join(accum, part);
      crumbs.add(MapEntry(part, accum));
    }
    return crumbs;
  }

  /// Opens a subdirectory
  Future<void> open(String dirRel) async {
    _currentDir = p.normalize(dirRel);
    if (_currentDir == '.') _currentDir = '';
    _selection.clear();
    _query = '';
    await refresh();
  }

  /// Navigates up one folder level
  Future<void> up() async {
    if (isAtRoot) return;
    final parent = p.dirname(_currentDir);
    _currentDir = (parent == '.' || parent == '/') ? '' : parent;
    _selection.clear();
    _query = '';
    await refresh();
  }

  /// Sets search query
  Future<void> setQuery(String q) async {
    _query = q;
    _selection.clear();
    await refresh();
  }

  /// Clears active search
  Future<void> clearSearch() async {
    _query = '';
    await refresh();
  }

  /// Refreshes the entry list, guarded against race conditions with _requestCounter
  Future<void> refresh() async {
    final requestId = ++_requestCounter;
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      List<FileEntry> rawEntries;
      if (isSearching) {
        rawEntries = await service.search(_query, dirRel: _currentDir);
      } else {
        rawEntries = await service.list(_currentDir);
      }

      if (requestId != _requestCounter) return;

      _entries = _applySort(rawEntries);
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      if (requestId != _requestCounter) return;
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Toggles selection of an entry
  void toggleSelect(String relativePath) {
    if (_selection.contains(relativePath)) {
      _selection.remove(relativePath);
    } else {
      _selection.add(relativePath);
    }
    notifyListeners();
  }

  /// Selects all entries in current view
  void selectAll() {
    _selection.clear();
    for (final entry in _entries) {
      _selection.add(entry.relativePath);
    }
    notifyListeners();
  }

  /// Clears active selection
  void clearSelection() {
    _selection.clear();
    notifyListeners();
  }

  /// Sets view mode (list / grid)
  void setViewMode(FileViewMode mode) {
    if (_viewMode == mode) return;
    _viewMode = mode;
    _savePreferences();
    notifyListeners();
  }

  /// Sets sort criteria
  void setSort(FileSortOption option, {bool? ascending}) {
    _sort = option;
    if (ascending != null) {
      _sortAscending = ascending;
    }
    _entries = _applySort(_entries);
    _savePreferences();
    notifyListeners();
  }

  List<FileEntry> _applySort(List<FileEntry> items) {
    final sorted = List<FileEntry>.from(items);
    sorted.sort((a, b) {
      // Folders always come first
      if (a.isDir != b.isDir) {
        return a.isDir ? -1 : 1;
      }

      int comparison;
      switch (_sort) {
        case FileSortOption.name:
          comparison = a.name.toLowerCase().compareTo(b.name.toLowerCase());
          break;
        case FileSortOption.modified:
          comparison = a.modified.compareTo(b.modified);
          break;
        case FileSortOption.size:
          comparison = a.size.compareTo(b.size);
          break;
        case FileSortOption.type:
          comparison = a.kind.name.compareTo(b.kind.name);
          break;
      }

      return _sortAscending ? comparison : -comparison;
    });
    return sorted;
  }

  // --- File Service Wrappers ---

  Future<FileEntry?> createFolder(String name) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final entry = await service.createFolder(_currentDir, name);
      await refresh();
      return entry;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<FileEntry?> createNote(String name, FileKind kind) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final entry = await service.createNote(_currentDir, name, kind);
      await refresh();
      return entry;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<String> rename(String rel, String newName) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final result = await service.rename(rel, newName);
      _selection.clear();
      await refresh();
      return result;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<List<String>> moveSelected(String destDirRel) async {
    if (_selection.isEmpty) return [];
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final moved = await service.move(_selection.toList(), destDirRel);
      _selection.clear();
      await refresh();
      return moved;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<List<String>> copySelected(String destDirRel) async {
    if (_selection.isEmpty) return [];
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final copied = await service.copy(_selection.toList(), destDirRel);
      _selection.clear();
      await refresh();
      return copied;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  /// Deletes selected items to trash and returns groupId for Undo
  Future<String> deleteSelected() async {
    if (_selection.isEmpty) return '';
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final groupId = await service.delete(_selection.toList());
      _selection.clear();
      await refresh();
      return groupId;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> restore(String groupId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      await service.restore(groupId);
      await refresh();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> deleteForever(String groupId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      await service.deleteForever(groupId);
      await refresh();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> emptyTrash() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      await service.emptyTrash();
      await refresh();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> importFiles(List<String> sourcePaths) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      for (final src in sourcePaths) {
        await service.importFile(src, _currentDir);
      }
      await refresh();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  // --- Preference Persistence ---

  Future<void> _loadPreferences() async {
    try {
      final file = File(p.join(service.sandbox.root, '.settings.json'));
      if (await file.exists()) {
        final data = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
        if (data['viewMode'] == 'grid') _viewMode = FileViewMode.grid;
        if (data['sort'] != null) {
          _sort = FileSortOption.values.firstWhere(
            (e) => e.name == data['sort'],
            orElse: () => FileSortOption.name,
          );
        }
        if (data['sortAscending'] is bool) {
          _sortAscending = data['sortAscending'] as bool;
        }
      }
    } catch (_) {}
  }

  Future<void> _savePreferences() async {
    try {
      final file = File(p.join(service.sandbox.root, '.settings.json'));
      await file.writeAsString(jsonEncode({
        'viewMode': _viewMode.name,
        'sort': _sort.name,
        'sortAscending': _sortAscending,
      }));
    } catch (_) {}
  }

  @override
  void dispose() {
    _fsSubscription?.cancel();
    super.dispose();
  }
}
