import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
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
  late TextEditingController _codeController;

  @override
  void initState() {
    super.initState();
    _codeController = TextEditingController(text: widget.fileItem.content);
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  void _saveChanges() {
    widget.filesNotifier.updateHtmlDoc(widget.fileItem.id, _codeController.text);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('HTML Document saved offline.')),
    );
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
                            '🎨 Rendered Magazine',
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
                            '💻 Edit HTML / CSS',
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
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF141416),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(45),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ListView(
        children: [
          // Top metadata
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.bentoMarigold.withAlpha(30),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  'PHYS-301 · VISUAL ZINE',
                  style: TextStyle(
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
                  color: Colors.white.withAlpha(20),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'JS: OFF · OFFLINE',
                  style: TextStyle(
                    fontSize: 9,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.bold,
                    color: Colors.white70,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Magazine Headline
          const Text(
            'Schrödinger Wave Equation & Probability Density',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              height: 1.2,
              letterSpacing: -0.4,
              color: Color(0xFFB4D2FF),
            ),
          ),
          const SizedBox(height: 10),

          // Paragraph
          Text(
            'Unlike plain Markdown, this sandboxed .html document renders custom CSS grid cards, magazine typography, and formulas right inside your workspace.',
            style: TextStyle(
              fontSize: 12.5,
              height: 1.5,
              color: Colors.white.withAlpha(210),
            ),
          ),
          const SizedBox(height: 20),

          // 2 Formula Bento Cards (CSS Grid representation)
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(18),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Colors.white.withAlpha(25), width: 1.5),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Time-Dependent',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: AppColors.bentoMarigold,
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        'iℏ ∂Ψ/∂t = ĤΨ',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          fontFamily: 'monospace',
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(18),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Colors.white.withAlpha(25), width: 1.5),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Born Rule',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF3CC162),
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        'P(x) = |Ψ(x,t)|²',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          fontFamily: 'monospace',
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Linked Folder Image Box
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.iris.withAlpha(35),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.iris.withAlpha(120), width: 1.5),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Linked Folder Image',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white),
                    ),
                    SizedBox(height: 2),
                    Text(
                      '/Lectures/Images/Quantum_Well.png',
                      style: TextStyle(fontSize: 10.5, color: Colors.white70),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text(
                    'View Image',
                    style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w900, color: AppColors.inkPrimaryLight),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSourceEditorView(BuildContext context, bool isDark) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 20),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1015),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withAlpha(20), width: 1.5),
      ),
      child: TextField(
        controller: _codeController,
        maxLines: null,
        expands: true,
        style: const TextStyle(
          fontFamily: 'monospace',
          fontSize: 12,
          color: Color(0xFFE2E8F0),
          height: 1.45,
        ),
        decoration: const InputDecoration(
          border: InputBorder.none,
          hintText: '<html>\n  <style>...</style>\n  <body>...</body>\n</html>',
        ),
      ),
    );
  }
}
