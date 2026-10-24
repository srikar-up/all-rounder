import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:all_rounder/features/files/file_entry.dart';
import 'package:all_rounder/features/files/file_service.dart';
import 'package:all_rounder/features/files/names.dart';
import 'package:all_rounder/features/files/sandbox.dart';

void main() {
  group('File Manager - Phase 2 Core Tests', () {
    late Directory tempDir;
    late FileService service;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('all_rounder_test_');
      service = FileService(tempDir.path);
      await service.initRoot();
    });

    tearDown(() async {
      service.dispose();
      if (await tempDir.exists()) {
        try {
          await tempDir.delete(recursive: true);
        } catch (_) {}
      }
    });

    test('2.1 Sandbox throws on escaping paths and resolves valid paths', () {
      final sandbox = Sandbox(tempDir.path);

      // Escapes throw SandboxViolation
      expect(() => sandbox.resolve('../x'), throwsA(isA<SandboxViolation>()));
      expect(() => sandbox.resolve('a/../../x'), throwsA(isA<SandboxViolation>()));
      expect(() => sandbox.resolve('/etc/passwd'), throwsA(isA<SandboxViolation>()));
      expect(() => sandbox.resolve(r'\etc\passwd'), throwsA(isA<SandboxViolation>()));
      expect(() => sandbox.resolve(r'C:\Windows\System32'), throwsA(isA<SandboxViolation>()));

      // Normal valid paths resolve
      final resolvedNotes = sandbox.resolve('notes');
      expect(p.isWithin(tempDir.path, resolvedNotes), isTrue);
      expect(sandbox.relativeOf(resolvedNotes), 'notes');

      final resolvedNested = sandbox.resolve('notes/sub/file.md');
      expect(p.isWithin(tempDir.path, resolvedNested), isTrue);

      // Root path itself resolves
      expect(sandbox.resolve(''), p.normalize(tempDir.path));
      expect(sandbox.resolve('.'), p.normalize(tempDir.path));

      // Protected checking
      expect(sandbox.isProtected('notes'), isTrue);
      expect(sandbox.isProtected('attachments'), isTrue);
      expect(sandbox.isProtected('vault'), isTrue);
      expect(sandbox.isProtected('.trash'), isTrue);
      expect(sandbox.isProtected('notes/sub'), isFalse);
      expect(sandbox.isProtected('my_folder'), isFalse);

      // Hidden checking
      expect(sandbox.isHidden('.trash'), isTrue);
      expect(sandbox.isHidden('.hidden_file'), isTrue);
      expect(sandbox.isHidden('vault'), isTrue);
      expect(sandbox.isHidden('notes'), isFalse);
    });

    test('2.2 validateName accepts valid names and rejects invalid names', () {
      // Rejections
      expect(validateName(''), isNotNull);
      expect(validateName('   '), isNotNull);
      expect(validateName('.' * 121), isNotNull);
      expect(validateName('.'), isNotNull);
      expect(validateName('..'), isNotNull);
      expect(validateName('.hidden'), isNotNull);
      expect(validateName('bad/name'), isNotNull);
      expect(validateName(r'bad\name'), isNotNull);
      expect(validateName('bad:name'), isNotNull);
      expect(validateName('bad*name'), isNotNull);
      expect(validateName('bad?name'), isNotNull);
      expect(validateName('bad"name'), isNotNull);
      expect(validateName('bad<name'), isNotNull);
      expect(validateName('bad>name'), isNotNull);
      expect(validateName('bad|name'), isNotNull);
      expect(validateName('bad\u0000name'), isNotNull);

      // Acceptances
      expect(validateName('normal_file.md'), isNull);
      expect(validateName('Physics Notes 2026'), isNull);
      expect(validateName('नोट्स'), isNull); // Hindi
      expect(validateName('ਨੋਟਸ'), isNull); // Punjabi
      expect(validateName('🌟 Rocket 🚀 Notes'), isNull); // Emojis
    });

    test('2.2 uniquePath generates incremented names on collision', () async {
      final f1 = File(p.join(tempDir.path, 'note.md'));
      await f1.writeAsString('content');

      final p1 = await uniquePath(tempDir.path, 'note.md', isDir: false);
      expect(p.basename(p1), 'note (1).md');

      final f2 = File(p1);
      await f2.writeAsString('content 2');

      final p2 = await uniquePath(tempDir.path, 'note.md', isDir: false);
      expect(p.basename(p2), 'note (2).md');

      // Directories
      final d1 = Directory(p.join(tempDir.path, 'Docs'));
      await d1.create();

      final dp1 = await uniquePath(tempDir.path, 'Docs', isDir: true);
      expect(p.basename(dp1), 'Docs (1)');
    });

    test('2.4 list skips hidden items & vault, sorts folders first', () async {
      // Create test items
      await service.createFolder('', 'ZebraFolder');
      await service.createFolder('', 'AlphaFolder');
      await service.createNote('', 'NotesDoc.md', FileKind.note);
      await service.createNote('', 'BetaDoc.html', FileKind.html);

      // Create hidden folder and vault folder
      final hiddenDir = Directory(p.join(tempDir.path, '.secret'));
      await hiddenDir.create();
      final vaultDir = Directory(p.join(tempDir.path, 'vault'));
      await vaultDir.create();

      final entries = await service.list('');
      final names = entries.map((e) => e.name).toList();

      expect(names.contains('.secret'), isFalse);
      expect(names.contains('vault'), isFalse);

      // Check folders are first
      final folderNames = entries.where((e) => e.isDir).map((e) => e.name).toList();
      final fileNames = entries.where((e) => !e.isDir).map((e) => e.name).toList();

      expect(folderNames.contains('AlphaFolder'), isTrue);
      expect(folderNames.contains('ZebraFolder'), isTrue);
      expect(folderNames.contains('notes'), isTrue);
      expect(folderNames.contains('attachments'), isTrue);

      expect(fileNames.contains('BetaDoc.html'), isTrue);
      expect(fileNames.contains('NotesDoc.md'), isTrue);

      // Alphabetical order among folders
      expect(entries.first.isDir, isTrue);
    });

    test('2.4 rename enforces validations, conflict avoidance, and extension preservation', () async {
      final note = await service.createNote('notes', 'Draft', FileKind.note);
      expect(note.name, 'Draft.md');

      // Renaming without changing extension retains .md
      final renamedRel = await service.rename(note.relativePath, 'Final');
      expect(renamedRel, p.normalize('notes/Final.md'));

      // Protected folder rename throws
      expect(() => service.rename('notes', 'my_notes'), throwsA(isA<FileOpException>()));

      // Conflict throws
      await service.createNote('notes', 'Other.md', FileKind.note);
      expect(() => service.rename(renamedRel, 'Other.md'), throwsA(isA<FileOpException>()));
    });

    test('2.4 move blocks moving into self/child, auto-renames conflicts', () async {
      final parentFolder = await service.createFolder('', 'Parent');
      final childFolder = await service.createFolder(parentFolder.relativePath, 'Child');

      // Moving folder into self throws
      expect(() => service.move([parentFolder.relativePath], parentFolder.relativePath),
          throwsA(isA<FileOpException>()));

      // Moving folder into child throws
      expect(() => service.move([parentFolder.relativePath], childFolder.relativePath),
          throwsA(isA<FileOpException>()));

      // Moving note into another folder with conflict
      final note1 = await service.createNote('notes', 'Report.md', FileKind.note);
      final destFolder = await service.createFolder('', 'Archive');
      await service.createNote(destFolder.relativePath, 'Report.md', FileKind.note);

      final moved = await service.move([note1.relativePath], destFolder.relativePath);
      expect(moved.length, 1);
      expect(p.basename(moved.first), 'Report (1).md');
    });

    test('2.4 copy recursively preserves structure and handles conflicts', () async {
      final srcDir = await service.createFolder('', 'SourceDir');
      await service.createNote(srcDir.relativePath, 'inner.md', FileKind.note);
      final sub = await service.createFolder(srcDir.relativePath, 'SubDir');
      await service.createNote(sub.relativePath, 'deep.html', FileKind.html);

      final destDir = await service.createFolder('', 'DestDir');
      final copied = await service.copy([srcDir.relativePath], destDir.relativePath);
      expect(copied.length, 1);

      final copyEntries = await service.list(copied.first);
      expect(copyEntries.any((e) => e.name == 'inner.md'), isTrue);
      expect(copyEntries.any((e) => e.name == 'SubDir' && e.isDir), isTrue);
    });

    test('2.5 delete, undo/restore, and group attachment preservation', () async {
      // Create note in notes/ and attachment in attachments/<noteName>
      final note = await service.createNote('notes', 'Quantum', FileKind.note);
      final baseName = p.basenameWithoutExtension(note.name);

      final attDir = Directory(p.join(tempDir.path, 'attachments', baseName));
      await attDir.create(recursive: true);
      final attFile = File(p.join(attDir.path, 'wave.png'));
      await attFile.writeAsString('image_data');

      // Delete note
      final groupId = await service.delete([note.relativePath]);

      // Both note and attachment directory should be gone from their original spots
      expect(await File(p.join(tempDir.path, note.relativePath)).exists(), isFalse);
      expect(await Directory(attDir.path).exists(), isFalse);

      // Restore using groupId
      await service.restore(groupId);

      // Both should be restored
      expect(await File(p.join(tempDir.path, note.relativePath)).exists(), isTrue);
      expect(await Directory(attDir.path).exists(), isTrue);
      expect(await File(p.join(attDir.path, 'wave.png')).exists(), isTrue);
    });

    test('2.5 trash purgeOld and emptyTrash work properly', () async {
      final note1 = await service.createNote('notes', 'Trash1', FileKind.note);
      final g1 = await service.delete([note1.relativePath]);

      final note2 = await service.createNote('notes', 'Trash2', FileKind.note);
      await service.delete([note2.relativePath]);

      // Verify trash group exists
      final trashDir = Directory(p.join(tempDir.path, '.trash'));
      expect((await trashDir.list().toList()).length, 2);

      // Manually backdate g1's meta.json to 40 days ago
      final metaFile = File(p.join(tempDir.path, '.trash', g1, 'meta.json'));
      final oldDate = DateTime.now().subtract(const Duration(days: 40)).toIso8601String();
      await metaFile.writeAsString('{"deletedAt":"$oldDate","items":[]}');

      // Purge older than 30 days
      await service.purgeOld(days: 30);
      expect(await Directory(p.join(tempDir.path, '.trash', g1)).exists(), isFalse);

      // Empty remaining trash
      await service.emptyTrash();
      expect((await trashDir.list().toList()).isEmpty, isTrue);
    });

    test('2.4 search and usage calculate accurate results', () async {
      await service.createNote('notes', 'SearchMe.md', FileKind.note);
      await service.createNote('notes', 'OtherDoc.html', FileKind.html);

      final searchResults = await service.search('searchme');
      expect(searchResults.length, 1);
      expect(searchResults.first.name, 'SearchMe.md');

      final usage = await service.usage();
      expect(usage.totalBytes, greaterThan(0));
      expect(usage.notesBytes, greaterThan(0));
      expect(usage.htmlBytes, greaterThan(0));
    });

    test('2.4 FsEvents are broadcast during operations', () async {
      final events = <FsEvent>[];
      final sub = service.events.listen(events.add);

      final folder = await service.createFolder('', 'EventTestFolder');
      final note = await service.createNote(folder.relativePath, 'EventNote', FileKind.note);
      final renamed = await service.rename(note.relativePath, 'RenamedNote');
      final groupId = await service.delete([renamed]);
      await service.restore(groupId);

      await Future.delayed(const Duration(milliseconds: 50));
      await sub.cancel();

      expect(events.any((e) => e is FsCreated && e.rel == folder.relativePath), isTrue);
      expect(events.any((e) => e is FsMoved), isTrue);
      expect(events.any((e) => e is FsDeleted), isTrue);
    });
  });
}
