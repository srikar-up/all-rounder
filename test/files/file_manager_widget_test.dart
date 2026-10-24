import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:all_rounder/features/files/controllers/file_browser_controller.dart';
import 'package:all_rounder/features/files/file_entry.dart';
import 'package:all_rounder/features/files/file_service.dart';
import 'package:all_rounder/features/files/screens/folder_browser_screen.dart';
import 'package:all_rounder/features/files/widgets/empty_state.dart';
import 'package:all_rounder/features/files/widgets/file_tile.dart';
import 'package:all_rounder/features/files/widgets/selection_app_bar.dart';

void main() {
  group('File Manager Widget Tests (Phase 4)', () {
    late Directory tempDir;
    late FileService service;
    late FileBrowserController controller;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('all_rounder_widget_test_');
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

    Widget buildTestWidget() {
      return MaterialApp(
        home: FolderBrowserScreen(controller: controller),
      );
    }

    testWidgets('1. List renders entries correctly', (WidgetTester tester) async {
      await controller.createNote('Lecture_Notes', FileKind.note);
      await controller.createFolder('Math');
      await controller.refresh();

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.byType(FileTile), findsWidgets);
      expect(find.text('Lecture_Notes.md'), findsOneWidget);
      expect(find.text('Math'), findsOneWidget);
    });

    testWidgets('2. Long-press enters selection mode and shows SelectionAppBar', (WidgetTester tester) async {
      await controller.createNote('SelectMe', FileKind.note);
      await controller.refresh();

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.byType(SelectionAppBar), findsNothing);

      // Long press the note
      await tester.longPress(find.text('SelectMe.md'));
      await tester.pumpAndSettle();

      expect(find.byType(SelectionAppBar), findsOneWidget);
      expect(find.text('1 selected'), findsOneWidget);
    });

    testWidgets('3. Delete shows Undo snackbar and Undo restores', (WidgetTester tester) async {
      final note = await controller.createNote('TrashMe', FileKind.note);
      expect(note, isNotNull);
      await controller.refresh();

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Long press to select
      await tester.longPress(find.text('TrashMe.md'));
      await tester.pumpAndSettle();

      // Tap delete in SelectionAppBar
      await tester.tap(find.byTooltip('Delete'));
      await tester.pumpAndSettle();

      // Confirm delete dialog
      expect(find.text('Delete 1 item?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();

      // Verify Undo snackbar appears
      expect(find.text('1 item moved to trash'), findsOneWidget);
      expect(find.text('Undo'), findsOneWidget);

      // Tap Undo
      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();

      // Verify item returned
      expect(find.text('TrashMe.md'), findsOneWidget);
    });

    testWidgets('4. Empty state appears when directory has no entries', (WidgetTester tester) async {
      // Create empty folder and open it
      final folder = await controller.createFolder('EmptyFolder');
      await controller.open(folder!.relativePath);

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.byType(EmptyState), findsOneWidget);
      expect(find.text('Folder is empty'), findsOneWidget);
      expect(find.text('New Note'), findsOneWidget);
    });

    testWidgets('5. Back button navigates up one level in subfolder', (WidgetTester tester) async {
      await controller.createFolder('FolderA');
      await controller.open('FolderA');
      await controller.createFolder('SubFolderB');
      await controller.open('FolderA/SubFolderB');

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(controller.currentDir.replaceAll(r'\', '/'), 'FolderA/SubFolderB');
      expect(controller.isAtRoot, isFalse);

      // Tap Back icon button in AppBar
      await tester.tap(find.byTooltip('Up one level'));
      await tester.pumpAndSettle();

      expect(controller.currentDir.replaceAll(r'\', '/'), 'FolderA');
      expect(controller.isAtRoot, isFalse);

      // Tap Back icon button again
      await tester.tap(find.byTooltip('Up one level'));
      await tester.pumpAndSettle();

      expect(controller.isAtRoot, isTrue);
      expect(controller.currentDir, '');
    });
  });
}
