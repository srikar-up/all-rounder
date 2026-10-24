import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import '../../../core/theme/app_colors.dart';
import '../../notes/models/note_model.dart';
import '../../notes/screens/note_editor_screen.dart';
import '../../notes/state/notes_notifier.dart';
import '../controllers/file_browser_controller.dart';
import '../file_entry.dart';
import '../file_service.dart';
import '../models/file_item.dart';
import '../state/files_notifier.dart';
import 'files_home_screen.dart';
import 'html_viewer_screen.dart';

class FileManagerScreen extends StatefulWidget {
  final FilesNotifier filesNotifier;
  final FileService? fileService;
  final NotesNotifier? notesNotifier;
  final VoidCallback? onBackToHub;
  final VoidCallback? onOpenSettings;

  const FileManagerScreen({
    super.key,
    required this.filesNotifier,
    this.fileService,
    this.notesNotifier,
    this.onBackToHub,
    this.onOpenSettings,
  });

  @override
  State<FileManagerScreen> createState() => _FileManagerScreenState();
}

class _FileManagerScreenState extends State<FileManagerScreen> {
  late final FileService _service;
  late final FileBrowserController _controller;
  bool _ownsService = false;

  @override
  void initState() {
    super.initState();
    if (widget.fileService != null) {
      _service = widget.fileService!;
    } else {
      _service = FileService('app_storage/AllRounder');
      _ownsService = true;
      if (!kIsWeb) {
        _service.initRoot();
      }
    }
    _controller = FileBrowserController(_service);
  }

  @override
  void dispose() {
    _controller.dispose();
    if (_ownsService) {
      _service.dispose();
    }
    super.dispose();
  }

  Future<void> _openNote(FileEntry entry, String absolutePath) async {
    String content = '';
    try {
      final file = File(absolutePath);
      if (await file.exists()) {
        content = await file.readAsString();
      }
    } catch (_) {}

    final baseName = p.basenameWithoutExtension(entry.name);
    final note = NoteModel(
      id: baseName,
      title: baseName,
      content: content,
      folder: p.dirname(entry.relativePath),
      createdAt: entry.modified,
      updatedAt: entry.modified,
    );

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NoteEditorScreen(
          note: note,
          notesNotifier: widget.notesNotifier ?? NotesNotifier(),
        ),
      ),
    );
  }

  Future<void> _openHtml(FileEntry entry, String absolutePath) async {
    String content = '';
    try {
      final file = File(absolutePath);
      if (await file.exists()) {
        content = await file.readAsString();
      }
    } catch (_) {}

    final item = WorkspaceFileItem(
      id: entry.relativePath,
      name: entry.name,
      type: FileType.html,
      folder: p.dirname(entry.relativePath),
      size: '${(entry.size / 1024).toStringAsFixed(1)} KB',
      updatedAt: entry.modified,
      colorHex: '#6246EA',
      content: content.isNotEmpty ? content : FilesNotifier.defaultMagazineTemplate,
    );

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => HtmlViewerScreen(
          fileItem: item,
          filesNotifier: widget.filesNotifier,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      return Scaffold(
        backgroundColor: isDark ? AppColors.canvasDark : AppColors.canvasLight,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF252834) : const Color(0xFFF1EFEA),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.folder_shared_rounded, color: AppColors.iris, size: 36),
                ),
                const SizedBox(height: 18),
                Text(
                  'On-Device Files System',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: isDark ? AppColors.inkPrimaryDark : AppColors.inkPrimaryLight,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Direct sandboxed filesystem browsing operates on Android, iOS, Windows, macOS and Linux without cloud storage.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13.5,
                    color: isDark ? AppColors.inkSecondaryDark : AppColors.inkSecondaryLight,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.iris,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  icon: const Icon(Icons.auto_stories_rounded, size: 20),
                  label: const Text('View Magazine Notes'),
                  onPressed: () {
                    final item = widget.filesNotifier.htmlDocuments.isNotEmpty
                        ? widget.filesNotifier.htmlDocuments.first
                        : widget.filesNotifier.createHtmlNote();
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => HtmlViewerScreen(
                          fileItem: item,
                          filesNotifier: widget.filesNotifier,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      );
    }

    return FilesHomeScreen(
      service: _service,
      controller: _controller,
      onOpenNote: _openNote,
      onOpenHtml: _openHtml,
    );
  }
}
