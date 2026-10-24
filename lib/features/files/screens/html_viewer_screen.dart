import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_colors.dart';
import '../../html_render/html_note_view.dart';
import '../../html_render/html_sanitizer.dart';
import '../models/file_item.dart';
import '../state/files_notifier.dart';

class HtmlViewerScreen extends StatefulWidget {
  final WorkspaceFileItem fileItem;
  final FilesNotifier filesNotifier;

  const HtmlViewerScreen({
    super.key,
    required this.fileItem,
    required this.filesNotifier,
  });

  @override
  State<HtmlViewerScreen> createState() => _HtmlViewerScreenState();
}

class _HtmlViewerScreenState extends State<HtmlViewerScreen> {
  int _viewMode = 0; // 0 = Rendered Magazine View, 1 = Edit HTML/CSS Source
  bool _applyAppTheme = true; // Phase 5: "Use app theme" toggle
  late TextEditingController _codeController;

  @override
  void initState() {
    super.initState();
    _codeController = TextEditingController(text: widget.fileItem.content);
  }

  @override
  void dispose() {
    // Auto-persist latest source edits when exiting viewer
    widget.filesNotifier.updateHtmlDoc(widget.fileItem.id, _codeController.text);
    _codeController.dispose();
    super.dispose();
  }

  void _saveChanges() {
    widget.filesNotifier.updateHtmlDoc(widget.fileItem.id, _codeController.text);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        duration: Duration(seconds: 2),
        content: Text('HTML Document saved offline.'),
      ),
    );
  }

  String _getDisplayBadge() {
    try {
      final sanitized = HtmlSanitizer.sanitize(_codeController.text);
      if (sanitized.title.isNotEmpty) {
        return sanitized.title.toUpperCase();
      }
    } catch (_) {}
    return widget.fileItem.name
        .replaceAll(RegExp(r'\.html$', caseSensitive: false), '')
        .toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.canvasDark : AppColors.canvasLight,
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.bentoMarigold,
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Text(
                '🌐 Sandboxed HTML',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  color: AppColors.inkPrimaryLight,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                widget.fileItem.name,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: isDark ? AppColors.inkPrimaryDark : AppColors.inkPrimaryLight,
                ),
              ),
            ),
          ],
        ),
        actions: [
          // Phase 5: "Use app theme" toggle
          IconButton(
            icon: Icon(
              _applyAppTheme ? Icons.palette_rounded : Icons.palette_outlined,
              color: _applyAppTheme ? AppColors.iris : (isDark ? Colors.white70 : Colors.black54),
              size: 20,
            ),
            tooltip: _applyAppTheme ? 'App Theme: Enabled' : 'App Theme: Custom (Raw CSS)',
            onPressed: () {
              setState(() => _applyAppTheme = !_applyAppTheme);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  duration: const Duration(seconds: 1),
                  content: Text(_applyAppTheme
                      ? 'App theme styles enabled.'
                      : 'Custom styles only (app theme disabled).'),
                ),
              );
            },
          ),
          if (_viewMode == 1)
            IconButton(
              icon: const Icon(Icons.check_rounded, color: AppColors.bentoEmerald),
              tooltip: 'Save Source',
              onPressed: _saveChanges,
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Mode Switcher (Rendered Magazine View vs HTML/CSS Source)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.surfaceSubtleDark : AppColors.surfaceSubtleLight,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _viewMode = 0),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: _viewMode == 0 ? AppColors.iris : Colors.transparent,
                            borderRadius: BorderRadius.circular(999),
                            boxShadow: _viewMode == 0
                                ? [
                                    BoxShadow(
                                      color: AppColors.iris.withAlpha(60),
                                      blurRadius: 10,
                                      offset: const Offset(0, 3),
                                    ),
                                  ]
                                : null,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '🎨 Rendered Magazine View',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                              color: _viewMode == 0
                                  ? Colors.white
                                  : (isDark ? AppColors.inkSecondaryDark : AppColors.inkSecondaryLight),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _viewMode = 1),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: _viewMode == 1 ? AppColors.iris : Colors.transparent,
                            borderRadius: BorderRadius.circular(999),
                            boxShadow: _viewMode == 1
                                ? [
                                    BoxShadow(
                                      color: AppColors.iris.withAlpha(60),
                                      blurRadius: 10,
                                      offset: const Offset(0, 3),
                                    ),
                                  ]
                                : null,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '💻 Edit HTML / CSS Source',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                              color: _viewMode == 1
                                  ? Colors.white
                                  : (isDark ? AppColors.inkSecondaryDark : AppColors.inkSecondaryLight),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Main Content Area
            Expanded(
              child: _viewMode == 0
                  ? _buildRenderedMagazineView(context, isDark)
                  : _buildSourceEditorView(context, isDark),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRenderedMagazineView(BuildContext context, bool isDark) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 20),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: isDark ? null : Border.all(color: AppColors.borderLight, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(isDark ? 30 : 10),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.bentoMarigold.withAlpha(30),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    _getDisplayBadge(),
                    style: const TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.8,
                      color: AppColors.bentoMarigold,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withAlpha(15) : Colors.black.withAlpha(10),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    _applyAppTheme ? 'THEME: APP' : 'THEME: RAW',
                    style: TextStyle(
                      fontSize: 9,
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white70 : Colors.black54,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: isDark ? AppColors.dividerDark : const Color(0x14000000)),
          Expanded(
            child: HtmlNoteView(
              rawHtml: _codeController.text,
              attachmentsDir: 'attachments',
              applyAppTheme: _applyAppTheme,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSourceEditorView(BuildContext context, bool isDark) {
    const editorBg = Color(0xFF0F1117);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 20),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: editorBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? AppColors.borderDark : const Color(0xFF2A2D3D),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(isDark ? 50 : 25),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Top IDE Header Bar
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 14, 10),
            decoration: const BoxDecoration(
              color: Color(0xFF161822),
              border: Border(
                bottom: BorderSide(color: Color(0x1FFFFFFF), width: 1),
              ),
            ),
            child: Row(
              children: [
                // Window traffic dots
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 9,
                      height: 9,
                      decoration: const BoxDecoration(
                        color: Color(0xFFFF5F56),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      width: 9,
                      height: 9,
                      decoration: const BoxDecoration(
                        color: Color(0xFFFFBD2E),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      width: 9,
                      height: 9,
                      decoration: const BoxDecoration(
                        color: Color(0xFF27C93F),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 12),
                // File name label
                Expanded(
                  child: Text(
                    widget.fileItem.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFCBD5E1),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Live Line Count Badge
                AnimatedBuilder(
                  animation: _codeController,
                  builder: (context, _) {
                    final lines = _codeController.text.split('\n').length;
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '$lines lines',
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 9.5,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(width: 6),
                // HTML/CSS Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                  decoration: BoxDecoration(
                    color: AppColors.iris.withAlpha(40),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppColors.iris.withAlpha(80), width: 0.8),
                  ),
                  child: const Text(
                    'HTML / CSS',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.irisLight,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                // Copy button
                IconButton(
                  icon: const Icon(Icons.copy_rounded, size: 16, color: Color(0xFF94A3B8)),
                  tooltip: 'Copy Source Code',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: _codeController.text));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        duration: Duration(seconds: 1),
                        content: Text('HTML source copied to clipboard.'),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),

          // Code Text Area with explicit border overrides preventing oval/egg clipping
          Expanded(
            child: Theme(
              data: Theme.of(context).copyWith(
                textSelectionTheme: TextSelectionThemeData(
                  cursorColor: AppColors.irisLight,
                  selectionColor: AppColors.iris.withAlpha(90),
                  selectionHandleColor: AppColors.irisLight,
                ),
              ),
              child: TextField(
                controller: _codeController,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                keyboardType: TextInputType.multiline,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12.5,
                  color: Color(0xFFE2E8F0),
                  height: 1.55,
                  letterSpacing: 0.25,
                ),
                decoration: const InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  errorBorder: InputBorder.none,
                  disabledBorder: InputBorder.none,
                  filled: false,
                  fillColor: Colors.transparent,
                  contentPadding: EdgeInsets.all(16),
                  hintText: '<!DOCTYPE html>\n<html>\n  <head>\n    <style>...</style>\n  </head>\n  <body>...</body>\n</html>',
                  hintStyle: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    color: Color(0xFF64748B),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

