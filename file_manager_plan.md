# File Manager: Implementation Plan (Agent Prompt)

**Project:** All-Rounder (`srikar-up/all-rounder`, Flutter, Android first)
**Goal:** A Google Files-style manager for the folders where the app stores its notes, attachments and imports: browse, create, rename, move, copy, delete with undo, trash, search, share, and storage usage. It must be safe, fast and free of runtime errors.

> Execute this file phase by phase. After every phase run `flutter analyze` and `flutter test`; both must be clean before continuing. Commit after each phase.

---

## 0. Context the agent must know

- Read `lib/` first and follow its existing theme, navigation and state approach. If something here conflicts with existing code, keep the existing pattern and report it.
- Follow `plan.md` and any rules in `.agents/skills/gravitas` if they apply.
- The manager works **only inside the app's private storage**. It never browses the phone's shared storage.
  - Consequence: **no storage permissions are needed.** Do not request `READ/WRITE_EXTERNAL_STORAGE` or `MANAGE_EXTERNAL_STORAGE`.
- Notes are plain files (`.md`, `.html`) per `plan.md`. The file manager is therefore a real view of the real data, not a copy.
- Android and iOS are the targets. The repo also contains web and desktop folders; `dart:io` file access does not work on web, so guard with `kIsWeb` and show a "not supported" message there.

## 1. Storage layout

Root: `<getApplicationDocumentsDirectory()>/AllRounder/`

```
AllRounder/
  notes/                 # protected system folder (cannot be renamed or deleted)
  attachments/           # protected; one subfolder per note id: attachments/<note-id>/
  vault/                 # protected and HIDDEN from the file manager (vault screen only)
  .trash/                # hidden; deleted items and their metadata
  <user folders...>      # anything the user creates under the root, or under notes/
```

Rules:

- Entries whose name starts with `.` are hidden. The `vault/` folder is hidden from the browser, search, storage breakdown and move targets.
- Protected folders (`notes`, `attachments`) can be browsed and can contain new subfolders, but cannot be renamed, moved or deleted.
- Attachments are keyed by note **id**, not by path, so moving a note never breaks its images.

## 2. Features (Google Files style)

**Home screen**

- Storage card: total used by the app, with a segmented bar by category (Notes, HTML, Images, Other).
- Category tiles: Notes, HTML notes, Images, Documents, Trash.
- Recent files: horizontal list of the last 10 modified files.
- Folders: the top-level folders.

**Folder browser**

- Breadcrumb path bar; tapping a segment jumps there.
- List and grid view toggle (remember the choice).
- Sort: name, date modified, size, type; ascending or descending. Folders always first.
- Image thumbnails in the list and grid.
- Pull to refresh; clear empty states with a helpful action.
- Search by file name in the current folder, with an option to search everywhere.
- Floating "+" menu: New folder, New note (.md), New HTML note, Import file.

**Selection mode** (long-press to start)

- Contextual app bar with the selected count, Select all, and actions: **Move, Copy, Share, Delete**; **Rename** and **Details** only when exactly one item is selected.

**Delete and trash**

- Delete moves items to the trash and shows a snackbar with **Undo**.
- Trash screen: restore, delete forever, empty trash. Items older than 30 days are purged at app start.
- If a note is deleted, its attachment folder is trashed in the same group and restored with it.

**Move and copy**

- A folder picker screen showing only valid destinations. Moving a folder into itself or its own child is blocked.
- Name conflicts auto-rename to `name (1).ext`; nothing is ever silently overwritten.

**Open behaviour**

| File type | Opens in |
|---|---|
| `.md` | The existing note editor |
| `.html` | The HTML note screen (see `html_rendering_plan.md`) |
| Images | A simple viewer with pinch-to-zoom (`InteractiveViewer`) |
| Anything else | Details sheet plus Share |

**Import and export**

- Import copies files from the system picker into the current folder.
- Share/export sends a copy through the system share sheet. The original is never altered.

---

## Phase 1: Dependencies

```bash
flutter pub add path_provider path file_picker share_plus
flutter pub get
flutter analyze
```

- Do not add other packages. Use `dart:io` directly for file operations, and write a small extension-to-type map by hand instead of adding a MIME package.
- Do not add storage permissions to the manifest.

**Done when:** pub get and analyze pass, and the app still launches.

---

## Phase 2: Core file service (pure Dart, test-first)

Everything below is pure Dart with no widget imports, so it can be unit-tested with a temporary directory (`Directory.systemTemp.createTemp()`).

### 2.1 Sandbox: every path goes through this

```dart
// lib/features/files/sandbox.dart
import 'package:path/path.dart' as p;

class SandboxViolation implements Exception {
  const SandboxViolation();
  @override
  String toString() => 'Path is outside the app storage folder.';
}

class Sandbox {
  Sandbox(String rootPath) : root = p.normalize(p.absolute(rootPath));
  final String root;

  /// Turns a root-relative path into an absolute path, or throws.
  String resolve(String relative) {
    final full = p.normalize(p.join(root, relative));
    if (full != root && !p.isWithin(root, full)) {
      throw const SandboxViolation();
    }
    return full;
  }

  String relativeOf(String absolute) => p.relative(absolute, from: root);

  bool isProtected(String relative) {
    final n = p.normalize(relative);
    return n == 'notes' || n == 'attachments' || n == 'vault' || n == '.trash';
  }

  bool isHidden(String relative) {
    final first = p.split(p.normalize(relative)).first;
    return first.startsWith('.') || first == 'vault';
  }
}
```

An absolute input such as `/etc/passwd` or a `../..` path must throw. Never build a path from user input any other way.

### 2.2 Name validation and unique names

```dart
// lib/features/files/names.dart
import 'dart:io';
import 'package:path/path.dart' as p;

String? validateName(String name) {
  final n = name.trim();
  if (n.isEmpty) return 'Name cannot be empty';
  if (n.length > 120) return 'Name is too long';
  if (n == '.' || n == '..') return 'Invalid name';
  if (n.startsWith('.')) return 'Name cannot start with a dot';
  if (RegExp(r'[\\/:*?"<>|\u0000-\u001f]').hasMatch(n)) {
    return 'Name contains invalid characters';
  }
  return null;
}

/// Returns a path in [dir] that does not exist yet: "name", "name (1)", ...
Future<String> uniquePath(String dir, String name, {required bool isDir}) async {
  final base = isDir ? name : p.basenameWithoutExtension(name);
  final ext = isDir ? '' : p.extension(name);
  var candidate = p.join(dir, name);
  var i = 1;
  while (await FileSystemEntity.type(candidate, followLinks: false) !=
      FileSystemEntityType.notFound) {
    candidate = p.join(dir, '$base ($i)$ext');
    i++;
  }
  return candidate;
}
```

### 2.3 Models

```dart
// lib/features/files/file_entry.dart
enum FileKind { folder, note, html, image, other }

class FileEntry {
  const FileEntry({
    required this.relativePath,
    required this.name,
    required this.isDir,
    required this.size,
    required this.modified,
    required this.kind,
  });
  final String relativePath;
  final String name;
  final bool isDir;
  final int size; // bytes; 0 for folders in listings
  final DateTime modified;
  final FileKind kind;
}
```

Use plain fields only, so entries can be returned from a background isolate.

### 2.4 Operations (`FileService`)

Implement these methods. Each one takes **relative** paths, resolves them through `Sandbox`, and throws a clear `FileOpException(message)` on failure. The UI shows that message.

| Method | Requirements |
|---|---|
| `list(dirRel, {showHidden=false})` | Use `Directory.list(followLinks: false)`; never follow symlinks; skip hidden and `vault`; run in `Isolate.run`; return `List<FileEntry>` |
| `createFolder(dirRel, name)` | Validate name; use `uniquePath` |
| `createNote(dirRel, name, type)` | Create an empty `.md` or a starter `.html`; return the new entry |
| `rename(rel, newName)` | Validate; refuse protected paths; refuse if the target exists (do not overwrite); keep the extension unless the user changes it |
| `move(relList, destDirRel)` | Refuse protected sources; refuse moving a folder into itself or a child (`p.isWithin`); use `uniquePath`; try `rename`, and on `FileSystemException` fall back to copy then delete |
| `copy(relList, destDirRel)` | Recursive for folders; `uniquePath`; do not follow symlinks |
| `delete(relList)` | Move to trash (see below), return the trash group id for Undo |
| `restore(groupId)` / `deleteForever(groupId)` / `emptyTrash()` / `purgeOld(days: 30)` | See trash design |
| `search(query, {dirRel, recursive})` | Case-insensitive name match; run in `Isolate.run` |
| `usage()` | Recursive sizes grouped by `FileKind`; run in `Isolate.run`; cache and recompute after changes (debounced) |
| `importFile(sourceAbsPath, destDirRel)` | Copy into the sandbox with `uniquePath`; the source is never modified |

All methods publish a change event so other parts of the app can react:

```dart
sealed class FsEvent { const FsEvent(); }
class FsCreated extends FsEvent { const FsCreated(this.rel); final String rel; }
class FsMoved extends FsEvent { const FsMoved(this.from, this.to); final String from, to; }
class FsDeleted extends FsEvent { const FsDeleted(this.rel); final String rel; }
// FileService exposes: Stream<FsEvent> get events  (broadcast StreamController)
```

The notes index (when it exists) must subscribe to `events`, so renamed, moved or deleted notes never leave stale search results.

### 2.5 Trash design

```
.trash/
  <groupId>/
    items/<storedName>        # the moved file or folder
    meta.json                 # {"deletedAt": "...", "items":[{"originalRel":"notes/a.md","storedName":"a.md"}]}
```

- `groupId` = timestamp plus a short random suffix.
- Delete: create the group folder, `rename` each item into `items/` (same filesystem, so atomic). If a note is deleted, add its `attachments/<note-id>/` folder to the **same group**.
- Restore: move each item back to `originalRel`; if the original parent no longer exists, recreate it; if the name is taken, use `uniquePath`. Remove the group after success.
- Write `meta.json` **before** moving files, and make restore tolerant of a missing meta (skip and report).
- Never delete anything outside `.trash/` when purging.

### 2.6 Required tests

Using a temp directory for each test:

- Sandbox: `../x`, `a/../../x`, `/etc/passwd` all throw; normal nested paths resolve.
- `validateName`: empty, long, slashes, colon, control characters, leading dot, plain and non-Latin names (Hindi, Punjabi, emoji) accepted.
- `uniquePath`: `a.md` -> `a (1).md` -> `a (2).md`; folders `Notes` -> `Notes (1)`.
- list: hidden and `vault` skipped, folders first, symlink not followed.
- rename: conflict refused, protected refused, extension handling.
- move: into itself refused, into child refused, conflict auto-renamed, cross-folder works.
- copy: recursive folder copy preserves structure and contents.
- delete, undo, restore, empty trash, purge old; restore when the original folder is gone.
- A note deleted with its attachments restores both together.
- search and usage return correct counts and sizes.
- Every operation emits the expected `FsEvent`.

**Done when:** all of these pass and analyze is clean.

---

## Phase 3: State controller

Create a `FileBrowserController` (use the app's existing state approach; if none, use `ChangeNotifier`) with:

- `currentDir`, `entries`, `isLoading`, `error`, `viewMode` (list/grid), `sort`, `selection` (set of relative paths), `query`.
- Methods: `open(dirRel)`, `up()`, `refresh()`, `toggleSelect(rel)`, `selectAll()`, `clearSelection()`, plus a thin wrapper for each service operation that sets `isLoading`, catches `FileOpException`, stores the message in `error`, and refreshes.
- Subscribe to `service.events` and refresh when the current folder is affected. Cancel the subscription in `dispose`.
- Guard against stale results: use a request counter so a slow listing never overwrites a newer one.
- Persist `viewMode` and `sort` with the app's existing settings storage (do not add a package for this).

**Done when:** controller unit tests pass using a fake or temp-directory service.

---

## Phase 4: UI

Create `lib/features/files/` screens and widgets, using the app's existing theme tokens.

- `FilesHomeScreen`: storage card, category tiles, recent files, folders.
- `FolderBrowserScreen`: breadcrumb, list/grid, sort sheet, search field, "+" menu, selection bar.
- `FolderPickerScreen`: used by Move and Copy; disables invalid destinations.
- `TrashScreen`: list with restore, delete forever and empty trash.
- Widgets: `FileTile`, `FileGridCard`, `BreadcrumbBar`, `SelectionAppBar`, `DetailsSheet`, `NameDialog` (shared by New folder and Rename, shows the `validateName` error live), `EmptyState`.

Rules:

- Use `ListView.builder` and `GridView.builder`. Never build all rows eagerly.
- Image thumbnails: `Image.file(file, cacheWidth: 160, errorBuilder: ...)` with an icon fallback for broken images.
- **Back button:** use `PopScope` so Back goes up one folder and only leaves the screen at the top level:

```dart
PopScope(
  canPop: controller.isAtRoot,
  onPopInvokedWithResult: (didPop, _) {
    if (!didPop) controller.up();
  },
  child: ...,
)
```

- Delete: show the Undo snackbar, and make sure Undo restores the whole group.
- Never use a `BuildContext` after an `await` without checking `mounted`.
- Dialogs and sheets must dispose their `TextEditingController`s.
- Large touch targets (at least 48 dp), TalkBack labels on icon buttons, and a visible selection state that does not rely on colour alone.
- No WebViews anywhere in the file manager.

**Done when:** analyze is clean and widget tests cover: list renders entries, long-press enters selection mode, delete shows Undo, empty state appears, and the Back button navigates up.

---

## Phase 5: Open, import, share

- Tap routing follows the table in section 2. Add the routes without changing existing screens beyond the minimum.
- Import: `FilePicker.platform.pickFiles(allowMultiple: true)`; for each result with a `path`, call `importFile`. Handle `null` (user cancelled) and files without a path. Show a summary snackbar ("3 files imported, 1 failed").
- Share: use `share_plus` with the actual file paths. Folders cannot be shared directly; for a folder, show a message (zip export is a later task).
- Image viewer: `InteractiveViewer` with an error fallback.

**Done when:** each action works on a real device and handles cancel and error paths without exceptions.

---

## Phase 6: Integration with the rest of the app

1. The notes screen and the file manager use the **same** `FileService` instance (provide it once at the app root).
2. Creating, renaming, moving or deleting a note anywhere in the app goes through `FileService`, so events and trash behave consistently.
3. The vault never appears in the file manager. Its own screen (later task) manages `vault/`.
4. Launch task: call `purgeOld(days: 30)` once at startup, without blocking the first frame.
5. Make sure root folders (`notes`, `attachments`) are created on first launch if missing.

---

## Phase 7: Verification

```bash
flutter analyze
flutter test
flutter run
flutter build apk --release
```

### Manual test matrix (real Android phone)

| Case | Expected |
|---|---|
| First launch | Root folders created, home screen shows zero usage |
| Create folder, note, HTML note | Appear immediately, correct icons |
| Rename to an existing name | Clear error, nothing overwritten |
| Rename with `/` or empty name | Live validation message |
| Move a folder into itself | Blocked with a message |
| Copy a folder with nested files | Complete copy, original untouched |
| Delete then Undo | Item and its attachments return together |
| Delete, close app, reopen, restore from Trash | Works |
| Empty trash | Space freed, usage updates |
| Open `.md`, `.html`, image | Correct viewer each time |
| Import 3 files including a duplicate name | Duplicate becomes `name (1)` |
| Share a file | System share sheet shows it |
| Sort by size and date | Order correct, folders first |
| Folder with 1,000+ files | Scrolls smoothly, no jank |
| Hindi, Punjabi, emoji file names | Display and operate correctly |
| Back button inside nested folders | Goes up one level, then leaves |
| Airplane mode | Everything works |
| Web or desktop run | Friendly "not supported" message, no exception |

---

## Known pitfalls

| Pitfall | What to do |
|---|---|
| `File.rename` can fail across different volumes | Fall back to copy then delete (already specified in `move`) |
| Using a `BuildContext` after `await` | Check `mounted` first |
| Slow listing finishing after the user navigated | Request counter in the controller |
| Symlinks leading outside the sandbox | Never follow links; the sandbox check also blocks escapes |
| Stale search index after file operations | The index must subscribe to `FileService.events` |
| Large recursive operations freezing the UI | Run listing, search, copy and usage in `Isolate.run` |
| Android back gesture closing the app from a subfolder | `PopScope` as shown in Phase 4 |

## Out of scope for this task

Cloud sync, zip export/import, duplicate finder, browsing phone shared storage, file previews for PDFs and Office files, vault management, and bulk rename. Add them later as separate reviewed tasks.

## Definition of done

- [ ] All phases complete, one commit per phase
- [ ] `flutter analyze`: no issues
- [ ] `flutter test`: all passing, including every Phase 2 case
- [ ] `flutter build apk --release`: succeeds
- [ ] Manual matrix passed on a real Android device
- [ ] No storage permissions added to the manifest
- [ ] No `// ignore` comments added to hide warnings
- [ ] A short report of what changed, what was tested, and any deviation from this plan
