import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../models/note_model.dart';
import '../state/notes_notifier.dart';

class NoteEditorScreen extends StatefulWidget {
  final NoteModel? note;
  final NotesNotifier notesNotifier;

  const NoteEditorScreen({super.key, this.note, required this.notesNotifier});

  @override
  State<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends State<NoteEditorScreen> {
  late TextEditingController _titleController;
  late TextEditingController _contentController;
  late TextEditingController _folderController;
  late TextEditingController _tagsController;
  bool _isPreviewMode = false;
  bool _isPinned = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.note?.title ?? '');
    _contentController = TextEditingController(text: widget.note?.content ?? '');
    _folderController = TextEditingController(text: widget.note?.folder ?? 'Inbox');
    _tagsController = TextEditingController(text: widget.note?.tags.join(', ') ?? '');
    _isPinned = widget.note?.isPinned ?? false;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _folderController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  void _saveNote() {
    final title = _titleController.text.trim();
    final content = _contentController.text;
    final folder = _folderController.text.trim().isEmpty ? 'Inbox' : _folderController.text.trim();
    final tags = _tagsController.text
        .split(',')
        .map((t) => t.trim().replaceAll('#', ''))
        .where((t) => t.isNotEmpty)
        .toList();

    if (title.isEmpty && content.trim().isEmpty) {
      Navigator.pop(context);
      return;
    }

    if (widget.note != null) {
      final updated = widget.note!.copyWith(
        title: title.isEmpty ? 'Untitled Note' : title,
        content: content,
        folder: folder,
        tags: tags,
        isPinned: _isPinned,
      );
      widget.notesNotifier.updateNote(updated);
    } else {
      final newNote = NoteModel(
        id: 'note_${DateTime.now().millisecondsSinceEpoch}',
        title: title.isEmpty ? 'Untitled Note' : title,
        content: content,
        folder: folder,
        tags: tags,
        isPinned: _isPinned,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      widget.notesNotifier.addNote(newNote);
    }

    Navigator.pop(context);
  }

  void _insertMarkdown(String prefix, [String suffix = '']) {
    final text = _contentController.text;
    final selection = _contentController.selection;
    final start = selection.start >= 0 ? selection.start : text.length;
    final end = selection.end >= 0 ? selection.end : text.length;
    final selectedText = text.substring(start, end);

    final replacement = '$prefix$selectedText$suffix';
    final newText = text.replaceRange(start, end, replacement);
    _contentController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: start + prefix.length + selectedText.length),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) return;
        // Auto-save if title or content changed
        final title = _titleController.text.trim();
        final content = _contentController.text.trim();
        if (title.isNotEmpty || content.isNotEmpty) {
          if (widget.note == null ||
              widget.note!.title != title ||
              widget.note!.content != content) {
            // Background save
            final folder = _folderController.text.trim().isEmpty ? 'Inbox' : _folderController.text.trim();
            final tags = _tagsController.text
                .split(',')
                .map((t) => t.trim().replaceAll('#', ''))
                .where((t) => t.isNotEmpty)
                .toList();

            if (widget.note != null) {
              widget.notesNotifier.updateNote(
                widget.note!.copyWith(
                  title: title.isEmpty ? 'Untitled Note' : title,
                  content: _contentController.text,
                  folder: folder,
                  tags: tags,
                  isPinned: _isPinned,
                ),
              );
            } else {
              widget.notesNotifier.addNote(
                NoteModel(
                  id: 'note_${DateTime.now().millisecondsSinceEpoch}',
                  title: title.isEmpty ? 'Untitled Note' : title,
                  content: _contentController.text,
                  folder: folder,
                  tags: tags,
                  isPinned: _isPinned,
                  createdAt: DateTime.now(),
                  updatedAt: DateTime.now(),
                ),
              );
            }
          }
        }
      },
      child: Scaffold(
        appBar: AppBar(
          actions: [
            IconButton(
              tooltip: _isPinned ? 'Unpin' : 'Pin Note',
              icon: Icon(
                _isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                color: _isPinned ? AppColors.primary : null,
              ),
              onPressed: () {
                setState(() => _isPinned = !_isPinned);
              },
            ),
            IconButton(
              tooltip: _isPreviewMode ? 'Edit Mode' : 'Markdown Preview',
              icon: Icon(
                _isPreviewMode ? Icons.edit_outlined : Icons.remove_red_eye_outlined,
                color: _isPreviewMode ? AppColors.primary : null,
              ),
              onPressed: () {
                setState(() => _isPreviewMode = !_isPreviewMode);
              },
            ),
            TextButton.icon(
              icon: const Icon(Icons.check, size: 18),
              label: const Text('Save'),
              onPressed: _saveNote,
            ),
          ],
        ),
        body: Column(
          children: [
            // Metadata header (Folder, Tags)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                border: Border(
                  bottom: BorderSide(
                    color: isDark ? AppColors.borderDark : AppColors.borderLight,
                  ),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.folder_open, size: 16, color: AppColors.primary),
                  const SizedBox(width: 6),
                  SizedBox(
                    width: 90,
                    child: TextField(
                      controller: _folderController,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      decoration: const InputDecoration(
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        fillColor: Colors.transparent,
                        hintText: 'Folder',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Icon(Icons.tag, size: 16, color: AppColors.textMutedLight),
                  const SizedBox(width: 4),
                  Expanded(
                    child: TextField(
                      controller: _tagsController,
                      style: const TextStyle(fontSize: 12),
                      decoration: const InputDecoration(
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        fillColor: Colors.transparent,
                        hintText: 'tags separated by commas',
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Note Title
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: TextField(
                controller: _titleController,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                decoration: const InputDecoration(
                  hintText: 'Note Title',
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  fillColor: Colors.transparent,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),

            const Divider(height: 1),

            // Content Area: Either Editor or Preview
            Expanded(
              child: _isPreviewMode
                  ? _buildMarkdownPreview(context)
                  : Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: TextField(
                        controller: _contentController,
                        maxLines: null,
                        expands: true,
                        textAlignVertical: TextAlignVertical.top,
                        style: const TextStyle(
                          fontSize: 15,
                          height: 1.5,
                          fontFamily: 'sans-serif',
                        ),
                        decoration: const InputDecoration(
                          hintText: 'Write in markdown...\nUse [[Note Title]] to link another note or timetable slot.',
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          fillColor: Colors.transparent,
                          contentPadding: EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
            ),

            // Markdown Formatting Toolbar (Only in edit mode)
            if (!_isPreviewMode)
              Container(
                height: 48,
                decoration: BoxDecoration(
                  color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                  border: Border(
                    top: BorderSide(
                      color: isDark ? AppColors.borderDark : AppColors.borderLight,
                    ),
                  ),
                ),
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  children: [
                    _toolBtn('H1', () => _insertMarkdown('# ')),
                    _toolBtn('H2', () => _insertMarkdown('## ')),
                    _toolBtn('B', () => _insertMarkdown('**', '**'), isBold: true),
                    _toolBtn('I', () => _insertMarkdown('*', '*'), isItalic: true),
                    _toolIconBtn(Icons.checklist, () => _insertMarkdown('- [ ] ')),
                    _toolIconBtn(Icons.format_list_bulleted, () => _insertMarkdown('- ')),
                    _toolIconBtn(Icons.code, () => _insertMarkdown('`', '`')),
                    _toolIconBtn(Icons.table_chart_outlined, () => _insertMarkdown('\n| Column 1 | Column 2 |\n|---|---|\n| Item 1 | Item 2 |\n')),
                    _toolIconBtn(Icons.link, () => _insertMarkdown('[[', ']]')),
                    _toolIconBtn(Icons.format_quote, () => _insertMarkdown('> ')),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _toolBtn(String label, VoidCallback onPressed, {bool isBold = false, bool isItalic = false}) {
    return TextButton(
      style: TextButton.styleFrom(
        minimumSize: const Size(40, 36),
        padding: const EdgeInsets.symmetric(horizontal: 10),
      ),
      onPressed: onPressed,
      child: Text(
        label,
        style: TextStyle(
          fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
          fontStyle: isItalic ? FontStyle.italic : FontStyle.normal,
          fontSize: 14,
        ),
      ),
    );
  }

  Widget _toolIconBtn(IconData icon, VoidCallback onPressed) {
    return IconButton(
      icon: Icon(icon, size: 20),
      visualDensity: VisualDensity.compact,
      onPressed: onPressed,
    );
  }

  Widget _buildMarkdownPreview(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final lines = _contentController.text.split('\n');

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: lines.length,
      itemBuilder: (ctx, i) {
        final line = lines[i];

        // Heading 1
        if (line.startsWith('# ')) {
          return Padding(
            padding: const EdgeInsets.only(top: 14, bottom: 6),
            child: Text(
              line.substring(2),
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: isDark ? AppColors.textDark : AppColors.textLight,
              ),
            ),
          );
        }

        // Heading 2
        if (line.startsWith('## ')) {
          return Padding(
            padding: const EdgeInsets.only(top: 10, bottom: 4),
            child: Text(
              line.substring(3),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: isDark ? AppColors.textDark : AppColors.textLight,
              ),
            ),
          );
        }

        // Heading 3
        if (line.startsWith('### ')) {
          return Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 4),
            child: Text(
              line.substring(4),
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: isDark ? AppColors.textDark : AppColors.textLight,
              ),
            ),
          );
        }

        // Checklist items
        if (line.startsWith('- [ ] ') || line.startsWith('- [x] ') || line.startsWith('- [X] ')) {
          final isChecked = !line.startsWith('- [ ] ');
          final itemText = line.substring(6);
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Checkbox(
                value: isChecked,
                visualDensity: VisualDensity.compact,
                activeColor: AppColors.primary,
                onChanged: (val) {
                  // Toggle in text
                  setState(() {
                    final replacement = val == true ? '- [x] $itemText' : '- [ ] $itemText';
                    lines[i] = replacement;
                    _contentController.text = lines.join('\n');
                  });
                },
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: _renderTextWithWikiLinks(itemText, isDark, isStrikethrough: isChecked),
                ),
              ),
            ],
          );
        }

        // Bullet point
        if (line.startsWith('- ') || line.startsWith('* ')) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 6, right: 8, left: 4),
                  child: Icon(Icons.circle, size: 6, color: AppColors.primary),
                ),
                Expanded(
                  child: _renderTextWithWikiLinks(line.substring(2), isDark),
                ),
              ],
            ),
          );
        }

        // Blockquote
        if (line.startsWith('> ')) {
          return Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.primary.withAlpha(15),
              border: const Border(
                left: BorderSide(color: AppColors.primary, width: 3),
              ),
              borderRadius: const BorderRadius.horizontal(right: Radius.circular(6)),
            ),
            child: Text(
              line.substring(2),
              style: TextStyle(
                fontStyle: FontStyle.italic,
                color: isDark ? AppColors.textDark : AppColors.textLight,
              ),
            ),
          );
        }

        // Empty line
        if (line.trim().isEmpty) {
          return const SizedBox(height: 8);
        }

        // Normal paragraph with wiki link parser
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: _renderTextWithWikiLinks(line, isDark),
        );
      },
    );
  }

  Widget _renderTextWithWikiLinks(String text, bool isDark, {bool isStrikethrough = false}) {
    final spans = <InlineSpan>[];
    final regex = RegExp(r'\[\[(.*?)\]\]');
    int lastMatchEnd = 0;

    for (final match in regex.allMatches(text)) {
      if (match.start > lastMatchEnd) {
        spans.add(
          TextSpan(
            text: text.substring(lastMatchEnd, match.start),
            style: TextStyle(
              fontSize: 14,
              color: isDark ? AppColors.textDark : AppColors.textLight,
              decoration: isStrikethrough ? TextDecoration.lineThrough : null,
            ),
          ),
        );
      }

      final linkTitle = match.group(1)!;
      spans.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: InkWell(
            onTap: () {
              final linkedNote = widget.notesNotifier.findNoteByTitle(linkTitle);
              if (linkedNote != null) {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => NoteEditorScreen(
                      note: linkedNote,
                      notesNotifier: widget.notesNotifier,
                    ),
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Linked note "$linkTitle" not found. Create it?'),
                    action: SnackBarAction(
                      label: 'Create',
                      onPressed: () {
                        final newNote = NoteModel(
                          id: 'note_${DateTime.now().millisecondsSinceEpoch}',
                          title: linkTitle,
                          content: '# $linkTitle\n\nLinked from [[${_titleController.text}]].',
                          folder: _folderController.text,
                          createdAt: DateTime.now(),
                          updatedAt: DateTime.now(),
                        );
                        widget.notesNotifier.addNote(newNote);
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => NoteEditorScreen(
                              note: newNote,
                              notesNotifier: widget.notesNotifier,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                );
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                color: AppColors.cyan.withAlpha(25),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: AppColors.cyan.withAlpha(80)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.link, size: 12, color: AppColors.cyan),
                  const SizedBox(width: 3),
                  Text(
                    linkTitle,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.cyan,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      lastMatchEnd = match.end;
    }

    if (lastMatchEnd < text.length) {
      spans.add(
        TextSpan(
          text: text.substring(lastMatchEnd),
          style: TextStyle(
            fontSize: 14,
            color: isDark ? AppColors.textDark : AppColors.textLight,
            decoration: isStrikethrough ? TextDecoration.lineThrough : null,
          ),
        ),
      );
    }

    return RichText(text: TextSpan(children: spans));
  }
}
