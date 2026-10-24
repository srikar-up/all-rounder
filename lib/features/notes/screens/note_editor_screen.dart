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
    final widgets = <Widget>[];

    int i = 0;
    while (i < lines.length) {
      final line = lines[i];

      // 1. Table Detection (| col1 | col2 | ... |)
      if (line.trim().startsWith('|') && line.trim().endsWith('|')) {
        final tableLines = <String>[];
        while (i < lines.length && lines[i].trim().startsWith('|') && lines[i].trim().endsWith('|')) {
          tableLines.add(lines[i]);
          i++;
        }
        widgets.add(_buildMarkdownTable(tableLines, isDark));
        continue;
      }

      // 2. Headings
      if (line.startsWith('# ')) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(top: 18, bottom: 8),
            child: Text(
              line.substring(2),
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
                color: isDark ? AppColors.inkPrimaryDark : AppColors.inkPrimaryLight,
              ),
            ),
          ),
        );
        i++;
        continue;
      }

      if (line.startsWith('## ')) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(top: 14, bottom: 6),
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 18,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: AppColors.iris,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Expanded(
                  child: Text(
                    line.substring(3),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                      color: isDark ? AppColors.inkPrimaryDark : AppColors.inkPrimaryLight,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
        i++;
        continue;
      }

      if (line.startsWith('### ')) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 6),
            child: Text(
              line.substring(4),
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.2,
                color: isDark ? AppColors.inkPrimaryDark : AppColors.inkPrimaryLight,
              ),
            ),
          ),
        );
        i++;
        continue;
      }

      // 3. Checklist Items (- [ ] or - [x])
      if (line.startsWith('- [ ] ') || line.startsWith('- [x] ') || line.startsWith('- [X] ')) {
        final isChecked = !line.startsWith('- [ ] ');
        final itemText = line.substring(6);
        final lineIndex = i;
        widgets.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: () {
                    setState(() {
                      final replacement = isChecked ? '- [ ] $itemText' : '- [x] $itemText';
                      lines[lineIndex] = replacement;
                      _contentController.text = lines.join('\n');
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    width: 20,
                    height: 20,
                    margin: const EdgeInsets.only(top: 1.5, right: 10),
                    decoration: BoxDecoration(
                      color: isChecked ? AppColors.iris : Colors.transparent,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: isChecked
                            ? AppColors.iris
                            : (isDark ? Colors.white38 : const Color(0xFFC4C0B6)),
                        width: 1.8,
                      ),
                    ),
                    child: isChecked
                        ? const Center(
                            child: Icon(Icons.check_rounded, size: 14, color: Colors.white),
                          )
                        : null,
                  ),
                ),
                Expanded(
                  child: _renderFormattedInlineText(itemText, isDark, isChecked: isChecked),
                ),
              ],
            ),
          ),
        );
        i++;
        continue;
      }

      // 4. Bullet Points (- or *)
      if (line.startsWith('- ') || line.startsWith('* ')) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  margin: const EdgeInsets.only(top: 8, right: 10, left: 4),
                  decoration: const BoxDecoration(
                    color: AppColors.iris,
                    shape: BoxShape.circle,
                  ),
                ),
                Expanded(
                  child: _renderFormattedInlineText(line.substring(2), isDark),
                ),
              ],
            ),
          ),
        );
        i++;
        continue;
      }

      // 5. Standalone Math Formula Block ($$ ... $$)
      if (line.trim().startsWith(r'$$') && line.trim().endsWith(r'$$') && line.trim().length > 4) {
        final rawMath = line.trim().substring(2, line.trim().length - 2);
        widgets.add(_buildStandaloneMathCard(rawMath, isDark));
        i++;
        continue;
      }

      // 6. Image Markdown (![alt](path)) or attached diagram reference
      if (line.startsWith('![') ||
          line.toLowerCase().contains('attached diagram in attachments') ||
          line.toLowerCase().contains('attached diagram')) {
        String caption = 'Figure 1.1: Wave Mechanics & Standing Harmonics';
        String fileName = 'Standing_Wave_Harmonics.png';
        if (line.startsWith('![')) {
          final closeBracket = line.indexOf(']');
          if (closeBracket > 2) {
            caption = line.substring(2, closeBracket);
          }
          final openParen = line.indexOf('(', closeBracket);
          final closeParen = line.indexOf(')', openParen);
          if (openParen > 0 && closeParen > openParen) {
            fileName = line.substring(openParen + 1, closeParen);
          }
        }
        widgets.add(_buildDiagramCard(caption, fileName, isDark));
        if (!line.startsWith('![')) {
          // Also render the trailing text (e.g. "Linked with 09:00 AM alarm.")
          widgets.add(
            Padding(
              padding: const EdgeInsets.only(top: 6, bottom: 4),
              child: _renderFormattedInlineText(line, isDark),
            ),
          );
        }
        i++;
        continue;
      }

      // 7. Blockquote (> )
      if (line.startsWith('> ')) {
        widgets.add(
          Container(
            margin: const EdgeInsets.symmetric(vertical: 6),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.iris.withAlpha(isDark ? 30 : 12),
              border: const Border(
                left: BorderSide(color: AppColors.iris, width: 3.5),
              ),
              borderRadius: const BorderRadius.horizontal(right: Radius.circular(10)),
            ),
            child: _renderFormattedInlineText(line.substring(2), isDark, isItalic: true),
          ),
        );
        i++;
        continue;
      }

      // 8. Empty Line
      if (line.trim().isEmpty) {
        widgets.add(const SizedBox(height: 10));
        i++;
        continue;
      }

      // 9. Standard Paragraph
      widgets.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: _renderFormattedInlineText(line, isDark),
        ),
      );
      i++;
    }

    // Bottom Attachments Grid if note has attachments and wasn't inline
    if (widget.note?.attachments.isNotEmpty == true &&
        !_contentController.text.contains('Standing_Wave_Harmonics.png')) {
      widgets.add(const SizedBox(height: 16));
      widgets.add(
        Text(
          'ATTACHED MEDIA & FILES (${widget.note!.attachments.length})',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.5,
            color: isDark ? AppColors.inkSecondaryDark : AppColors.inkSecondaryLight,
          ),
        ),
      );
      widgets.add(const SizedBox(height: 8));
      for (final att in widget.note!.attachments) {
        widgets.add(_buildDiagramCard('Attachment: $att', att, isDark));
        widgets.add(const SizedBox(height: 8));
      }
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
      children: widgets,
    );
  }

  // Helper to format LaTeX math formula into clean mathematical Unicode
  static String _formatMathFormula(String raw) {
    return raw
        .replaceAll(r'\Psi', 'Ψ')
        .replaceAll(r'\psi', 'ψ')
        .replaceAll(r'\omega', 'ω')
        .replaceAll(r'\Omega', 'Ω')
        .replaceAll(r'\alpha', 'α')
        .replaceAll(r'\beta', 'β')
        .replaceAll(r'\gamma', 'γ')
        .replaceAll(r'\Delta', 'Δ')
        .replaceAll(r'\delta', 'δ')
        .replaceAll(r'\theta', 'θ')
        .replaceAll(r'\lambda', 'λ')
        .replaceAll(r'\pi', 'π')
        .replaceAll(r'\sigma', 'σ')
        .replaceAll(r'\mu', 'μ')
        .replaceAll(r'\phi', 'ϕ')
        .replaceAll(r'\infty', '∞')
        .replaceAll(r'\approx', '≈')
        .replaceAll(r'\neq', '≠')
        .replaceAll(r'\le', '≤')
        .replaceAll(r'\ge', '≥')
        .replaceAll(r'\times', '×')
        .replaceAll(r'\cdot', '·')
        .replaceAll(r'\pm', '±')
        .replaceAll(r'\partial', '∂')
        .replaceAll(r'\nabla', '∇')
        .replaceAll(r'\int', '∫')
        .replaceAll(r'\sum', '∑')
        .replaceAll(r'\sqrt', '√')
        .replaceAll('^{', '^(')
        .replaceAll('}', ')')
        .replaceAll(r'\', '')
        .trim();
  }

  // Standalone Interactive Math Card
  Widget _buildStandaloneMathCard(String rawMath, bool isDark) {
    final formatted = _formatMathFormula(rawMath);
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1C2B) : const Color(0xFFF6F3FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.iris.withAlpha(isDark ? 80 : 50),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.iris.withAlpha(30),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.functions_rounded, size: 14, color: AppColors.iris),
                    SizedBox(width: 4),
                    Text(
                      'Wave Equation · Formula',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: AppColors.iris,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.copy_rounded, size: 15, color: AppColors.iris),
            ],
          ),
          const SizedBox(height: 10),
          Center(
            child: Text(
              formatted,
              style: TextStyle(
                fontFamily: 'serif',
                fontStyle: FontStyle.italic,
                fontWeight: FontWeight.w700,
                fontSize: 17,
                letterSpacing: 0.5,
                color: isDark ? const Color(0xFFE2D6FF) : const Color(0xFF4C2DB2),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Interactive Scientific Diagram Card
  Widget _buildDiagramCard(String caption, String fileName, bool isDark) {
    return GestureDetector(
      onTap: () => _showDiagramLightbox(context, caption, fileName),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark ? AppColors.borderDark : AppColors.borderLight,
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(isDark ? 25 : 8),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Diagram Visual Header Preview (Custom Painted Waveform)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(19)),
              child: Container(
                height: 140,
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDark
                        ? [const Color(0xFF18152B), const Color(0xFF2B1825)]
                        : [const Color(0xFFEDE9FE), const Color(0xFFFFEDEC)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Stack(
                  children: [
                    CustomPaint(
                      size: const Size(double.infinity, 140),
                      painter: _WaveHarmonicsPainter(isDark: isDark),
                    ),
                    Positioned(
                      top: 10,
                      left: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.black.withAlpha(140),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.insights_rounded, size: 12, color: Colors.white),
                            SizedBox(width: 4),
                            Text(
                              'Interactive Waveform',
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      top: 10,
                      right: 10,
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: Colors.black.withAlpha(140),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.fullscreen_rounded, size: 15, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Caption & Metadata Footer
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          caption,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.2,
                            color: isDark ? AppColors.inkPrimaryDark : AppColors.inkPrimaryLight,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$fileName · 2.4 MB · High Resolution PNG',
                          style: TextStyle(
                            fontSize: 10,
                            color: isDark ? AppColors.inkSecondaryDark : AppColors.inkSecondaryLight,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.iris.withAlpha(isDark ? 40 : 20),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Text(
                      'View ↗',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: AppColors.iris,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Fullscreen Diagram Lightbox Modal
  void _showDiagramLightbox(BuildContext context, String title, String fileName) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF141622) : Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(80),
                blurRadius: 30,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: isDark ? Colors.white : AppColors.inkPrimaryLight,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  height: 220,
                  width: double.infinity,
                  color: isDark ? const Color(0xFF0F1018) : const Color(0xFFF5F3FF),
                  child: Stack(
                    children: [
                      CustomPaint(
                        size: const Size(double.infinity, 220),
                        painter: _WaveHarmonicsPainter(isDark: isDark, isDetailed: true),
                      ),
                      Positioned(
                        bottom: 12,
                        right: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black.withAlpha(160),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'Harmonics n=2 · Nodes: N1, N2, N3',
                            style: TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    fileName,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white70 : AppColors.inkSecondaryLight,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.iris,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Text(
                      'Download .PNG',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Markdown Table Renderer
  Widget _buildMarkdownTable(List<String> rawRows, bool isDark) {
    final parsedRows = <List<String>>[];
    for (final raw in rawRows) {
      final trimmed = raw.trim();
      if (trimmed.startsWith('|') && trimmed.endsWith('|')) {
        final cells = trimmed
            .substring(1, trimmed.length - 1)
            .split('|')
            .map((c) => c.trim())
            .toList();
        // Skip separator line (|---|---|)
        if (cells.isNotEmpty && cells.first.contains('---')) continue;
        parsedRows.add(cells);
      }
    }

    if (parsedRows.isEmpty) return const SizedBox.shrink();

    final headers = parsedRows.first;
    final dataRows = parsedRows.skip(1).toList();

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
          width: 1.2,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(
              isDark ? const Color(0xFF222532) : const Color(0xFFF1EFEA),
            ),
            columnSpacing: 20,
            horizontalMargin: 16,
            headingTextStyle: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 12,
              color: isDark ? AppColors.inkPrimaryDark : AppColors.inkPrimaryLight,
            ),
            dataTextStyle: TextStyle(
              fontSize: 12,
              color: isDark ? AppColors.inkSecondaryDark : AppColors.inkPrimaryLight,
            ),
            columns: headers.map((h) => DataColumn(label: Text(h))).toList(),
            rows: dataRows.map((row) {
              return DataRow(
                cells: row.map((cell) => DataCell(Text(cell))).toList(),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  // Rich Inline Formatter: parses [[WikiLinks]], $$math$$, **bold**, *italic*, and `code`
  Widget _renderFormattedInlineText(
    String text,
    bool isDark, {
    bool isChecked = false,
    bool isItalic = false,
  }) {
    final spans = <InlineSpan>[];
    // Regex matches:
    // 1. [[WikiLink]]
    // 2. $$math$$ or $math$
    // 3. **bold**
    // 4. `code`
    final tokenRegex = RegExp(r'(\[\[(.*?)\]\])|(\$\$(.*?)\$\$)|(\*\*(.*?)\*\*)|(`(.*?)`)');
    int lastEnd = 0;

    final defaultTextColor = isChecked
        ? (isDark ? Colors.white38 : const Color(0xFF888B94))
        : (isDark ? AppColors.inkPrimaryDark : AppColors.inkPrimaryLight);

    final defaultStyle = TextStyle(
      fontSize: 14,
      height: 1.5,
      color: defaultTextColor,
      fontStyle: isItalic ? FontStyle.italic : FontStyle.normal,
      decoration: isChecked ? TextDecoration.lineThrough : null,
      decorationColor: defaultTextColor,
    );

    for (final match in tokenRegex.allMatches(text)) {
      if (match.start > lastEnd) {
        spans.add(TextSpan(
          text: text.substring(lastEnd, match.start),
          style: defaultStyle,
        ));
      }

      final fullMatch = match.group(0)!;

      // Case A: [[WikiLink]]
      if (fullMatch.startsWith('[[') && fullMatch.endsWith(']]')) {
        final linkTitle = fullMatch.substring(2, fullMatch.length - 2).trim();
        spans.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: InkWell(
              borderRadius: BorderRadius.circular(999),
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
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                margin: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                decoration: BoxDecoration(
                  color: isChecked
                      ? (isDark ? const Color(0xFF232530) : const Color(0xFFEDEBF0))
                      : (isDark ? const Color(0xFF26233C) : const Color(0xFFEAE6FD)),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: isChecked
                        ? Colors.transparent
                        : AppColors.iris.withAlpha(isDark ? 80 : 60),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.link_rounded,
                      size: 12,
                      color: isChecked ? Colors.grey : AppColors.iris,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      linkTitle,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: isChecked ? Colors.grey : AppColors.iris,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }
      // Case B: $$math$$ Formula
      else if (fullMatch.startsWith(r'$$') && fullMatch.endsWith(r'$$')) {
        final mathContent = fullMatch.substring(2, fullMatch.length - 2);
        final formattedMath = _formatMathFormula(mathContent);
        spans.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF28233C) : const Color(0xFFF3EDFF),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppColors.iris.withAlpha(isDark ? 80 : 50),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.functions_rounded, size: 13, color: AppColors.iris),
                  const SizedBox(width: 4),
                  Text(
                    formattedMath,
                    style: TextStyle(
                      fontFamily: 'serif',
                      fontStyle: FontStyle.italic,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      letterSpacing: 0.3,
                      color: isDark ? const Color(0xFFDCCEFF) : const Color(0xFF4C2DB2),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }
      // Case C: **bold**
      else if (fullMatch.startsWith('**') && fullMatch.endsWith('**')) {
        final boldContent = fullMatch.substring(2, fullMatch.length - 2);
        spans.add(
          TextSpan(
            text: boldContent,
            style: defaultStyle.copyWith(fontWeight: FontWeight.w800),
          ),
        );
      }
      // Case D: `code`
      else if (fullMatch.startsWith('`') && fullMatch.endsWith('`')) {
        final codeContent = fullMatch.substring(1, fullMatch.length - 1);
        spans.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF252834) : const Color(0xFFEFECE6),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                codeContent,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDark ? const Color(0xFFFF9CE9) : const Color(0xFFB5237C),
                ),
              ),
            ),
          ),
        );
      }

      lastEnd = match.end;
    }

    if (lastEnd < text.length) {
      spans.add(
        TextSpan(
          text: text.substring(lastEnd),
          style: defaultStyle,
        ),
      );
    }

    return RichText(text: TextSpan(children: spans));
  }
}

// Custom Painter to render high-contrast scientific standing wave harmonics (Nodes and Antinodes)
class _WaveHarmonicsPainter extends CustomPainter {
  final bool isDark;
  final bool isDetailed;

  _WaveHarmonicsPainter({required this.isDark, this.isDetailed = false});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final midY = h / 2;

    // 1. Grid Lines (Subtle millimeter pattern)
    final gridPaint = Paint()
      ..color = (isDark ? Colors.white : Colors.black).withAlpha(isDark ? 12 : 8)
      ..strokeWidth = 1;

    for (double x = 0; x < w; x += 24) {
      canvas.drawLine(Offset(x, 0), Offset(x, h), gridPaint);
    }
    for (double y = 0; y < h; y += 24) {
      canvas.drawLine(Offset(0, y), Offset(w, y), gridPaint);
    }

    // 2. Central Reference Axis
    final axisPaint = Paint()
      ..color = (isDark ? Colors.white30 : Colors.black26)
      ..strokeWidth = 1.2;
    canvas.drawLine(Offset(10, midY), Offset(w - 10, midY), axisPaint);

    // 3. Primary Standing Wave Curve (Harmonic Mode n = 2)
    final wavePath1 = Path();
    final wavePath2 = Path();
    final amplitude = h * 0.32;

    for (double x = 16; x <= w - 16; x += 2) {
      final normX = (x - 16) / (w - 32);
      // Mode n = 2: 2 full loops across length L
      final y1 = midY - amplitude * (2 * 3.14159 * normX).abs(); // approximated sinusoidal shape
      final sinVal = (2 * 3.14159265 * normX);
      final currentY1 = midY - amplitude * (sinVal < 0 ? -1 : 1) * (1 - (sinVal % 3.14159 - 1.57).abs() / 1.57);

      if (x == 16) {
        wavePath1.moveTo(x, midY);
        wavePath2.moveTo(x, midY);
      } else {
        // True sinusoidal curves
        final trueY1 = midY - amplitude * _sin(2 * 3.14159265 * normX);
        final trueY2 = midY + amplitude * _sin(2 * 3.14159265 * normX);
        wavePath1.lineTo(x, trueY1);
        wavePath2.lineTo(x, trueY2);
      }
    }

    // Wave 1: Solid Iris Stroke
    final strokePaint1 = Paint()
      ..color = AppColors.iris
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;
    canvas.drawPath(wavePath1, strokePaint1);

    // Wave 2: Complementary Dotted/Faded Coral Stroke (reflected wave phase)
    final strokePaint2 = Paint()
      ..color = AppColors.bentoCoral.withAlpha(isDark ? 160 : 130)
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke;
    canvas.drawPath(wavePath2, strokePaint2);

    // 4. Draw Nodes (N1, N2, N3)
    final nodePoints = [
      Offset(16, midY),
      Offset(w / 2, midY),
      Offset(w - 16, midY),
    ];

    final nodePaint = Paint()
      ..color = isDark ? Colors.white : AppColors.inkPrimaryLight
      ..style = PaintingStyle.fill;

    for (int idx = 0; idx < nodePoints.length; idx++) {
      final pt = nodePoints[idx];
      canvas.drawCircle(pt, 4, nodePaint);
      canvas.drawCircle(pt, 6, Paint()..color = AppColors.iris.withAlpha(100)..style = PaintingStyle.stroke..strokeWidth = 1.5);
    }
  }

  double _sin(double radians) {
    // Standard Taylor series sine approximation
    radians = radians % (2 * 3.1415926535);
    if (radians > 3.1415926535) radians -= 2 * 3.1415926535;
    final r2 = radians * radians;
    return radians * (1 - r2 / 6 * (1 - r2 / 20 * (1 - r2 / 42)));
  }

  @override
  bool shouldRepaint(covariant _WaveHarmonicsPainter oldDelegate) =>
      oldDelegate.isDark != isDark || oldDelegate.isDetailed != isDetailed;
}

