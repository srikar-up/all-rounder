import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:all_rounder/features/files/controllers/file_browser_controller.dart';
import 'package:all_rounder/features/files/file_entry.dart';
import 'package:all_rounder/features/files/file_service.dart';

void main() {
  group('FileBrowserController Tests (Phase 3)', () {
    late Directory tempDir;
    late FileService service;
    late FileBrowserController controller;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('all_rounder_ctrl_test_');
      service = FileService(tempDir.path);
      await service.initRoot();
      controller = FileBrowserController(service);
      await controller.refresh();
    });

    tearDown(() async {
      controller.dispose();
      service.dispose();
      if (await tempDir.exists()) {
        try {
          await tempDir.delete(recursive: true);
        } catch (_) {}
      }
    });

    test('Initial state is at root with empty selection and breadcrumbs', () {
      expect(controller.isAtRoot, isTrue);
      expect(controller.currentDir, '');
      expect(controller.selection.isEmpty, isTrue);
      expect(controller.isSelectionMode, isFalse);
      expect(controller.breadcrumbs.length, 1);
      expect(controller.breadcrumbs.first.key, 'Files');
    });

    test('Navigation open and up update currentDir and breadcrumbs correctly', () async {
      final folder = await controller.createFolder('Projects');
      expect(folder, isNotNull);

      await controller.open('Projects');
      expect(controller.isAtRoot, isFalse);
      expect(controller.currentDir, 'Projects');
      expect(controller.breadcrumbs.length, 2);
      expect(controller.breadcrumbs[1].key, 'Projects');
      expect(controller.breadcrumbs[1].value, 'Projects');

      // Subfolder
      await controller.createFolder('Sub');
      await controller.open('Projects/Sub');
      expect(controller.breadcrumbs.length, 3);
      expect(controller.breadcrumbs[2].key, 'Sub');
      expect(controller.breadcrumbs[2].value.replaceAll(r'\', '/'), 'Projects/Sub');

      // Up one level
      await controller.up();
      expect(controller.currentDir.replaceAll(r'\', '/'), 'Projects');

      // Up to root
      await controller.up();
      expect(controller.isAtRoot, isTrue);
      expect(controller.currentDir, '');
    });

    test('Selection mode: toggleSelect, selectAll, clearSelection', () async {
      await controller.createNote('Doc1', FileKind.note);
      await controller.createNote('Doc2', FileKind.note);

      expect(controller.entries.length, greaterThanOrEqualTo(2));

      controller.toggleSelect(controller.entries[0].relativePath);
      expect(controller.isSelectionMode, isTrue);
      expect(controller.selection.length, 1);

      controller.selectAll();
      expect(controller.selection.length, controller.entries.length);

      controller.clearSelection();
      expect(controller.isSelectionMode, isFalse);
      expect(controller.selection.isEmpty, isTrue);
    });

    test('Sort options change ordering of entries while keeping folders first', () async {
      await controller.createNote('Zebra.md', FileKind.note);
      await controller.createNote('Apple.md', FileKind.note);
      await controller.createFolder('MyFolder');

      controller.setSort(FileSortOption.name, ascending: true);
      // Folder should be first
      expect(controller.entries.first.name, 'attachments');
      expect(controller.entries.any((e) => e.name == 'MyFolder'), isTrue);

      final fileEntries = controller.entries.where((e) => !e.isDir).toList();
      expect(fileEntries.first.name, 'Apple.md');
      expect(fileEntries.last.name, 'Zebra.md');

      // Descending
      controller.setSort(FileSortOption.name, ascending: false);
      final descFileEntries = controller.entries.where((e) => !e.isDir).toList();
      expect(descFileEntries.first.name, 'Zebra.md');
      expect(descFileEntries.last.name, 'Apple.md');
    });

    test('ViewMode toggling works', () {
      expect(controller.viewMode, FileViewMode.list);
      controller.setViewMode(FileViewMode.grid);
      expect(controller.viewMode, FileViewMode.grid);
      controller.setViewMode(FileViewMode.list);
      expect(controller.viewMode, FileViewMode.list);
    });

    test('Delete selected and undo restores entries', () async {
      final note = await controller.createNote('DeleteMe', FileKind.note);
      expect(note, isNotNull);

      controller.toggleSelect(note!.relativePath);
      final groupId = await controller.deleteSelected();
      expect(groupId.isNotEmpty, isTrue);
      expect(controller.selection.isEmpty, isTrue);

      // Verify note is gone
      expect(controller.entries.any((e) => e.name == 'DeleteMe.md'), isFalse);

      // Restore
      await controller.restore(groupId);
      expect(controller.entries.any((e) => e.name == 'DeleteMe.md'), isTrue);
    });
  });
}
