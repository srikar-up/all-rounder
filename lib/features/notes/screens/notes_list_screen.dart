import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../files/models/file_item.dart';
import '../../files/screens/html_viewer_screen.dart';
import '../../files/state/files_notifier.dart';
import '../models/note_model.dart';
import '../state/notes_notifier.dart';
import 'note_editor_screen.dart';

class NotesListScreen extends StatefulWidget {
  final NotesNotifier notesNotifier;
  final FilesNotifier? filesNotifier;
  final VoidCallback? onOpenSettings;
  final VoidCallback? onOpenFileManager;

  const NotesListScreen({
    super.key,
    required this.notesNotifier,
    this.filesNotifier,
    this.onOpenSettings,
    this.onOpenFileManager,
  });

  @override
  State<NotesListScreen> createState() => _NotesListScreenState();
}

class _NotesListScreenState extends State<NotesListScreen> {
  bool _isSearchOpen = false;
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  String _getDateSubtitle() {
    final now = DateTime.now();
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final greeting = now.hour < 12 ? 'Good morning' : (now.hour < 17 ? 'Good afternoon' : 'Good evening');
    return '$greeting · ${weekdays[now.weekday - 1]}, ${now.day} ${months[now.month - 1]}';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final notes = widget.notesNotifier.filteredNotes;

    return Scaffold(
      backgroundColor: isDark ? AppColors.canvasDark : AppColors.canvasLight,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 110),
          children: [
            // 1. TOP HEADER (Avatar + laddu! + Search + Sliders exactly matching Image 1)
            Row(
              children: [
                // Avatar with initials LA and green online dot
                GestureDetector(
                  onTap: () {
                    if (widget.onOpenSettings != null) {
                      widget.onOpenSettings!();
                    }
                  },
                  child: Stack(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: AppColors.bentoMarigold,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withAlpha(isDark ? 30 : 15),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: const Text(
                          'LA',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            color: AppColors.inkPrimaryLight,
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: const Color(0xFF3CC162),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isDark ? AppColors.canvasDark : AppColors.canvasLight,
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),

                // Greeting & Name
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _getDateSubtitle(),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isDark ? AppColors.inkSecondaryDark : AppColors.inkSecondaryLight,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        widget.notesNotifier.showTrash ? 'Trash Bin' : 'laddu!',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.6,
                          color: isDark ? AppColors.inkPrimaryDark : AppColors.inkPrimaryLight,
                        ),
                      ),
                    ],
                  ),
                ),

                // Folder & Media Hub Quick Shortcut
                _buildCircleButton(
                  icon: Icons.folder_open_rounded,
                  tooltip: 'Folders & Media',
                  isDark: isDark,
                  onTap: () {
                    if (widget.onOpenFileManager != null) {
                      widget.onOpenFileManager!();
                    }
                  },
                ),
                const SizedBox(width: 8),

                // Search & Filter Circle Buttons
                _buildCircleButton(
                  icon: _isSearchOpen ? Icons.close_rounded : Icons.search_rounded,
                  tooltip: 'Search',
                  isDark: isDark,
                  onTap: () {
                    setState(() {
                      _isSearchOpen = !_isSearchOpen;
                      if (!_isSearchOpen) {
                        _searchCtrl.clear();
                        widget.notesNotifier.setSearchQuery('');
                      }
                    });
                  },
                ),
                const SizedBox(width: 8),
                _buildCircleButton(
                  icon: Icons.tune_rounded,
                  tooltip: 'Settings',
                  isDark: isDark,
                  onTap: () {
                    if (widget.onOpenSettings != null) {
                      widget.onOpenSettings!();
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Search input field when open
            if (_isSearchOpen) ...[
              TextField(
                controller: _searchCtrl,
                autofocus: true,
                style: const TextStyle(fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Search notes, tags, or markdown content...',
                  prefixIcon: const Icon(Icons.search, size: 20, color: AppColors.iris),
                  suffixIcon: _searchCtrl.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            _searchCtrl.clear();
                            widget.notesNotifier.setSearchQuery('');
                          },
                        )
                      : null,
                ),
                onChanged: (val) => widget.notesNotifier.setSearchQuery(val),
              ),
              const SizedBox(height: 16),
            ],

            // 2. HORIZONTAL FILTER PILLS (All Spaces, Folders & Media, Lectures, Projects, #fitness matching Prototype)
            SizedBox(
              height: 38,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _buildPill(
                    label: 'All Spaces',
                    isSelected: widget.notesNotifier.selectedFolder == 'All' && !widget.notesNotifier.showTrash,
                    isDark: isDark,
                    onTap: () {
                      widget.notesNotifier.setShowTrash(false);
                      widget.notesNotifier.setSelectedFolder('All');
                      widget.notesNotifier.setSelectedTag(null);
                    },
                  ),
                  const SizedBox(width: 8),
                  _buildPill(
                    label: '📁 Folders & Media',
                    isSelected: false,
                    isDark: isDark,
                    onTap: () {
                      if (widget.onOpenFileManager != null) {
                        widget.onOpenFileManager!();
                      }
                    },
                  ),
                  const SizedBox(width: 8),
                  _buildPill(
                    label: 'Lectures',
                    isSelected: widget.notesNotifier.selectedFolder == 'Lectures',
                    isDark: isDark,
                    onTap: () {
                      widget.notesNotifier.setShowTrash(false);
                      widget.notesNotifier.setSelectedFolder('Lectures');
                      widget.notesNotifier.setSelectedTag(null);
                    },
                  ),
                  const SizedBox(width: 8),
                  _buildPill(
                    label: 'Projects',
                    isSelected: widget.notesNotifier.selectedFolder == 'Projects',
                    isDark: isDark,
                    onTap: () {
                      widget.notesNotifier.setShowTrash(false);
                      widget.notesNotifier.setSelectedFolder('Projects');
                      widget.notesNotifier.setSelectedTag(null);
                    },
                  ),
                  const SizedBox(width: 8),
                  _buildPill(
                    label: '#fitness',
                    isSelected: widget.notesNotifier.selectedTag == 'fitness',
                    isDark: isDark,
                    onTap: () {
                      widget.notesNotifier.setShowTrash(false);
                      widget.notesNotifier.setSelectedFolder('All');
                      widget.notesNotifier.setSelectedTag('fitness');
                    },
                  ),
                  const SizedBox(width: 8),
                  _buildPill(
                    label: 'Trash',
                    isSelected: widget.notesNotifier.showTrash,
                    isDark: isDark,
                    onTap: () {
                      widget.notesNotifier.setShowTrash(!widget.notesNotifier.showTrash);
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // 3. HERO BANNER: Morning Focus & Plan + Quota 78% (Matching Image 1 & 2)
            if (!widget.notesNotifier.showTrash && !_isSearchOpen) ...[
              _buildHeroMorningFocus(context, isDark),
              const SizedBox(height: 22),
            ],

            // 3.5. FOLDERS & FILE SPACES (Prototype lines 521-570)
            if (!widget.notesNotifier.showTrash && !_isSearchOpen) ...[
              _buildFoldersAndFileSpaces(context, isDark),
              const SizedBox(height: 22),
            ],

            // 4. PINNED NOTES HEADER + BENTO VIEW
            if (!widget.notesNotifier.showTrash && !_isSearchOpen) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Pinned Notes',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.4,
                      color: isDark ? AppColors.inkPrimaryDark : AppColors.inkPrimaryLight,
                    ),
                  ),
                  const Text(
                    'Bento View',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: AppColors.iris,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // 5. ASYMMETRIC 2-COLUMN BENTO GRID (Image 1 Exact Layout)
              _buildAsymmetricBentoGrid(context, isDark),
              const SizedBox(height: 24),
            ],

            // 6. RECENT FILES & DOCUMENTS (Matching Prototype lines 652-700 & Screenshot 1)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.notesNotifier.showTrash ? 'Trash Files' : 'Recent Files & Documents',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                    color: isDark ? AppColors.inkPrimaryDark : AppColors.inkPrimaryLight,
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    if (widget.onOpenFileManager != null) {
                      widget.onOpenFileManager!();
                    }
                  },
                  child: Text(
                    widget.notesNotifier.showTrash ? 'Deleted' : '+ Upload File/Image',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: widget.notesNotifier.showTrash
                          ? (isDark ? AppColors.inkSecondaryDark : AppColors.inkSecondaryLight)
                          : AppColors.iris,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // When in normal mode and not filtering, show featured recent documents matching Screenshot 1
            if (!widget.notesNotifier.showTrash && !_isSearchOpen && widget.notesNotifier.selectedFolder == 'All' && widget.notesNotifier.selectedTag == null) ...[
              // Item 1: HTML Document (Periodic Table Reference.html)
              _buildRecentFileItemCard(
                context: context,
                title: 'Periodic Table Reference.html',
                subtitle: 'Sandboxed HTML/CSS grid · Offline ready',
                badgeText: '.html',
                iconBg: isDark ? const Color(0xFF2C2415) : const Color(0xFFFFF4DC),
                iconColor: const Color(0xFFD98200),
                icon: Icons.language_rounded,
                iconLabel: 'HTML',
                badgeBg: isDark ? const Color(0xFF2C2415) : const Color(0xFFFFF4DC),
                badgeTextColor: const Color(0xFFB86B00),
                isDark: isDark,
                onTap: () {
                  final htmlDocs = widget.filesNotifier?.htmlDocuments;
                  if (htmlDocs != null && htmlDocs.isNotEmpty) {
                    final targetDoc = htmlDocs.firstWhere(
                      (d) => d.name.contains('Periodic Table'),
                      orElse: () => htmlDocs.first,
                    );
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => HtmlViewerScreen(
                          fileItem: targetDoc,
                          filesNotifier: widget.filesNotifier!,
                        ),
                      ),
                    );
                  }
                },
              ),

              // Item 2: Standalone Image File (Whiteboard_Schrodinger_Eq.png)
              _buildRecentFileItemCard(
                context: context,
                title: 'Whiteboard_Schrodinger_Eq.png',
                subtitle: 'Folder: /Lectures/Images · 1.8 MB',
                badgeText: 'Image',
                iconBg: isDark ? const Color(0xFF331F1C) : const Color(0xFFFFE6E2),
                iconColor: AppColors.bentoCoral,
                icon: Icons.image_outlined,
                iconLabel: 'PNG',
                badgeBg: isDark ? const Color(0xFF331F1C) : const Color(0xFFFFE6E2),
                badgeTextColor: AppColors.bentoCoral,
                isDark: isDark,
                onTap: () {
                  _showImageLightboxDialog(
                    context,
                    'Whiteboard_Schrodinger_Eq.png',
                    'Folder: /Lectures/Images · 1.8 MB PNG',
                  );
                },
              ),

              // Item 3: Standalone PDF (Syllabus_Autumn_2026.pdf)
              _buildRecentFileItemCard(
                context: context,
                title: 'Syllabus_Autumn_2026.pdf',
                subtitle: 'Folder: /Lectures/Handouts · 4.2 MB',
                badgeText: '.pdf',
                iconBg: isDark ? const Color(0xFF222038) : const Color(0xFFEAE6FD),
                iconColor: AppColors.iris,
                icon: Icons.description_outlined,
                iconLabel: 'PDF',
                badgeBg: isDark ? const Color(0xFF222038) : const Color(0xFFEAE6FD),
                badgeTextColor: AppColors.iris,
                isDark: isDark,
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Opening Syllabus_Autumn_2026.pdf from /Handouts...')),
                  );
                },
              ),
            ] else ...[
              // Recent Notes List Cards when searching, filtering or in trash
              if (notes.isEmpty)
                _buildEmptyState(context, isDark)
              else
                ...notes.map((note) => _buildRecentNoteCard(context, note, isDark)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCircleButton({
    required IconData icon,
    required String tooltip,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(isDark ? 35 : 12),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: IconButton(
        icon: Icon(
          icon,
          size: 19,
          color: isDark ? AppColors.inkPrimaryDark : AppColors.inkPrimaryLight,
        ),
        tooltip: tooltip,
        padding: EdgeInsets.zero,
        onPressed: onTap,
      ),
    );
  }

  Widget _buildPill({
    required String label,
    required bool isSelected,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.iris
              : (isDark ? AppColors.surfaceSubtleDark : AppColors.surfaceSubtleLight),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            color: isSelected
                ? Colors.white
                : (isDark ? AppColors.inkSecondaryDark : AppColors.inkSecondaryLight),
          ),
        ),
      ),
    );
  }

  Widget _buildHeroMorningFocus(BuildContext context, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bentoLavender,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: AppColors.bentoLavender.withAlpha(70),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 110, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(120),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Text(
                      '✨ Daily Note · Oct 23',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: AppColors.inkPrimaryLight,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Title
                  const Text(
                    'Morning Focus &\nPlan',
                    style: TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                      color: AppColors.inkPrimaryLight,
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 4),

                  // Subtitle
                  const Text(
                    '2 linked lectures · 08:30 alarm active',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF3B2F5E),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Links row (Wrap prevents 68px horizontal overflow on narrow screens)
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: AppColors.inkPrimaryLight,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.link_rounded, size: 12, color: Colors.white),
                            SizedBox(width: 4),
                            Text(
                              '08:30 Physics',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(140),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Text(
                          '+3 links',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: AppColors.inkPrimaryLight,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          if (widget.onOpenFileManager != null) {
                            widget.onOpenFileManager!();
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.white.withAlpha(180),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.folder_open_rounded, size: 12, color: AppColors.inkPrimaryLight),
                              SizedBox(width: 4),
                              Text(
                                '+Add Media',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.inkPrimaryLight,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Right side 3D Accent Card: Quota 78% (Matching Image 1)
            Positioned(
              right: -8,
              bottom: -6,
              child: Transform.rotate(
                angle: 0.14,
                child: Container(
                  width: 105,
                  height: 105,
                  decoration: BoxDecoration(
                    color: AppColors.bentoMarigold,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.white.withAlpha(100), width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(30),
                        blurRadius: 14,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'QUOTA',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.8,
                          color: Color(0xFF6E4E06),
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        '78%',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: AppColors.inkPrimaryLight,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 3.5. FOLDERS & FILE SPACES (Prototype lines 521-570)
  Widget _buildFoldersAndFileSpaces(BuildContext context, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Folders & File Spaces',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.4,
                color: isDark ? AppColors.inkPrimaryDark : AppColors.inkPrimaryLight,
              ),
            ),
            GestureDetector(
              onTap: () {
                if (widget.onOpenFileManager != null) {
                  widget.onOpenFileManager!();
                }
              },
              child: const Row(
                children: [
                  Text(
                    'Open File Manager',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: AppColors.iris,
                    ),
                  ),
                  SizedBox(width: 4),
                  Icon(Icons.arrow_forward_rounded, size: 14, color: AppColors.iris),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // 2-Column Notched Folder Grid (Prototype lines 533-569)
        Row(
          children: [
            // Folder 1: Whiteboard & Photos (Coral Sunset #FF6B57)
            Expanded(
              child: GestureDetector(
                onTap: () {
                  if (widget.onOpenFileManager != null) {
                    widget.onOpenFileManager!();
                  }
                },
                child: Container(
                  height: 138,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.bentoCoral,
                    borderRadius: BorderRadius.circular(26),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.bentoCoral.withAlpha(70),
                        blurRadius: 16,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: Colors.white.withAlpha(50),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.image_outlined, color: Colors.white, size: 19),
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.black.withAlpha(50),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: const Text(
                                '8 Images',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Whiteboard & Photos',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              height: 1.15,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Standalone PNG, JPG & scans',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w600,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Folder 2: HTML Magazine Documents (Royal Iris #6246EA)
            Expanded(
              child: GestureDetector(
                onTap: () {
                  if (widget.onOpenFileManager != null) {
                    widget.onOpenFileManager!();
                  }
                },
                child: Container(
                  height: 138,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.iris,
                    borderRadius: BorderRadius.circular(26),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.iris.withAlpha(70),
                        blurRadius: 16,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: Colors.white.withAlpha(50),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.code_rounded, color: Colors.white, size: 19),
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.white.withAlpha(60),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: const Text(
                                '3 .HTML',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'HTML Documents',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              height: 1.15,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Custom CSS zines & sheets',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w600,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAsymmetricBentoGrid(BuildContext context, bool isDark) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // LEFT COLUMN: Tall Bento Card - Quantum Wave Interactive Sheet (Marigold #FDBE58)
        Expanded(
          child: GestureDetector(
            onTap: () {
              final htmlDocs = widget.filesNotifier?.htmlDocuments;
              if (htmlDocs != null && htmlDocs.isNotEmpty) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => HtmlViewerScreen(
                      fileItem: htmlDocs.first,
                      filesNotifier: widget.filesNotifier!,
                    ),
                  ),
                );
              } else {
                final note = widget.notesNotifier.getNoteById('note_1');
                if (note != null) _navigateToEditor(context, note);
              }
            },
            child: Container(
              height: 226,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.bentoMarigold,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.bentoMarigold.withAlpha(80),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF141416),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: const Text(
                              '🌐 HTML Doc',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const Icon(Icons.auto_awesome_rounded, size: 16, color: AppColors.inkPrimaryLight),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Quantum Wave\nInteractive Sheet',
                        style: TextStyle(
                          fontSize: 16.5,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.4,
                          color: AppColors.inkPrimaryLight,
                          height: 1.15,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Magazine-style HTML/CSS visual layout with custom cards, dark grid & offline formulas.',
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF4A3805),
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),

                  // Bottom pill row (Custom CSS + Render)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.black.withAlpha(20),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Text(
                          '🎨 CSS',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: AppColors.inkPrimaryLight,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Flexible(
                        child: Text(
                          'Render →',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF6E5510),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 14),

        // RIGHT COLUMN: 2 Stacked Cards (Periwinkle .MD + Pink Standalone Image)
        Expanded(
          child: Column(
            children: [
              // Top Right Card: Periwinkle (#B4D2FF) - Physics Lecture Notes .MD
              GestureDetector(
                onTap: () {
                  final note = widget.notesNotifier.getNoteById('note_1');
                  if (note != null) _navigateToEditor(context, note);
                },
                child: Container(
                  height: 107,
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                  decoration: BoxDecoration(
                    color: AppColors.bentoPeriwinkle,
                    borderRadius: BorderRadius.circular(26),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.bentoPeriwinkle.withAlpha(70),
                        blurRadius: 14,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '📝 .MD Note',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: AppColors.inkPrimaryLight,
                            ),
                          ),
                          Text(
                            '31m ago',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF384968),
                            ),
                          ),
                        ],
                      ),
                      Text(
                        'Physics Lecture\nNotes',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.3,
                          color: AppColors.inkPrimaryLight,
                          height: 1.15,
                        ),
                      ),
                      Text(
                        '🔗 2 links · #physics',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF2C3E5A),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Bottom Right Card: Soft Rose / Pink (#FF9CE9) - Standalone Image File
              GestureDetector(
                onTap: () {
                  _showImageLightboxDialog(
                    context,
                    'Lab_Distillation_Setup.jpg',
                    'In folder: /Lectures/Lab Photos · 2.4 MB JPG',
                  );
                },
                child: Container(
                  height: 107,
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFA3EC),
                    borderRadius: BorderRadius.circular(26),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFFA3EC).withAlpha(70),
                        blurRadius: 14,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '🖼️ Image File',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: AppColors.inkPrimaryLight,
                            ),
                          ),
                          Icon(Icons.fullscreen_rounded, size: 16, color: AppColors.inkPrimaryLight),
                        ],
                      ),
                      Text(
                        'Lab_Distillation_\nSetup.jpg',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.3,
                          color: AppColors.inkPrimaryLight,
                          height: 1.15,
                        ),
                      ),
                      Text(
                        'In folder: /Lab Photos',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF6B1D58),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showImageLightboxDialog(BuildContext context, String filename, String subtitle) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF141416),
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(80),
                blurRadius: 30,
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
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.bentoCoral.withAlpha(40),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Text(
                      '🖼️ Standalone Folder Image',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.bentoCoral,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white70),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                height: 190,
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFDBE58), Color(0xFFFF6B57)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                alignment: Alignment.center,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.image_rounded, size: 52, color: Colors.white),
                    const SizedBox(height: 8),
                    Text(
                      filename,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Text(
                filename,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.white70,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecentFileItemCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required String badgeText,
    required Color iconBg,
    required Color iconColor,
    required IconData icon,
    required String iconLabel,
    required Color badgeBg,
    required Color badgeTextColor,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: isDark ? null : Border.all(
          color: AppColors.borderLight,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(isDark ? 20 : 6),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, size: 20, color: iconColor),
                    const SizedBox(height: 1),
                    Text(
                      iconLabel,
                      style: TextStyle(
                        fontSize: 8.5,
                        fontWeight: FontWeight.w900,
                        color: iconColor,
                        height: 1.0,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                        color: isDark ? AppColors.inkPrimaryDark : AppColors.inkPrimaryLight,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: isDark ? AppColors.inkSecondaryDark : AppColors.inkSecondaryLight,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  badgeText,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: badgeTextColor,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecentNoteCard(BuildContext context, NoteModel note, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: isDark ? null : Border.all(
          color: AppColors.borderLight,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(isDark ? 20 : 6),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () => _navigateToEditor(context, note),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              // Date Badge on Left (Target Image 2 style)
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: note.folder == 'Lectures'
                      ? (isDark ? const Color(0xFF331F1C) : AppColors.bentoCoralSubtle)
                      : (isDark ? const Color(0xFF1B2E22) : AppColors.bentoEmeraldSubtle),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '${note.updatedAt.day}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: note.folder == 'Lectures' ? AppColors.bentoCoral : AppColors.bentoEmerald,
                        height: 1.0,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      'OCT',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: note.folder == 'Lectures' ? AppColors.bentoCoral : AppColors.bentoEmerald,
                        height: 1.0,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),

              // Title and snippet
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      note.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: isDark ? AppColors.inkPrimaryDark : AppColors.inkPrimaryLight,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      note.content
                          .replaceAll(RegExp(r'[#*`_\[\]]'), '')
                          .split('\n')
                          .firstWhere((l) => l.trim().isNotEmpty, orElse: () => ''),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? AppColors.inkSecondaryDark : AppColors.inkSecondaryLight,
                      ),
                    ),
                  ],
                ),
              ),

              // Link badge or tag
              if (note.wikiLinks.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.irisSubtle,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.link_rounded, size: 11, color: AppColors.iris),
                      const SizedBox(width: 3),
                      Text(
                        '${note.wikiLinks.length}',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: AppColors.iris,
                        ),
                      ),
                    ],
                  ),
                ),
              ] else if (note.tags.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.surfaceSubtleDark : AppColors.surfaceSubtleLight,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '#${note.tags.first}',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: isDark ? AppColors.inkSecondaryDark : AppColors.inkSecondaryLight,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(
          children: [
            Icon(
              widget.notesNotifier.showTrash ? Icons.delete_sweep_rounded : Icons.note_alt_outlined,
              size: 44,
              color: isDark ? AppColors.inkSecondaryDark : AppColors.inkSecondaryLight,
            ),
            const SizedBox(height: 10),
            Text(
              widget.notesNotifier.showTrash ? 'Trash is empty' : 'No notes found',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToEditor(BuildContext context, NoteModel? note) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => NoteEditorScreen(
          note: note,
          notesNotifier: widget.notesNotifier,
        ),
      ),
    );
  }
}
