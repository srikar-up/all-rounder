import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../models/file_item.dart';
import '../state/files_notifier.dart';
import 'html_viewer_screen.dart';

class FileManagerScreen extends StatefulWidget {
  final FilesNotifier filesNotifier;
  final VoidCallback? onBackToHub;
  final VoidCallback? onOpenSettings;

  const FileManagerScreen({
    super.key,
    required this.filesNotifier,
    this.onBackToHub,
    this.onOpenSettings,
  });

  @override
  State<FileManagerScreen> createState() => _FileManagerScreenState();
}

class _FileManagerScreenState extends State<FileManagerScreen> {
  void _openHtmlViewer(WorkspaceFileItem item) {
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

  void _showImageLightbox(WorkspaceFileItem item) {
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
                      '📸 Standalone Image File',
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
              // Visual simulated image preview
              Container(
                height: 190,
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6246EA), Color(0xFFFF6B57)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                alignment: Alignment.center,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.image_rounded, size: 48, color: Colors.white),
                    const SizedBox(height: 8),
                    Text(
                      item.name,
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
                item.name,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                item.content,
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

  void _showNewFolderDialog() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Create Media Folder'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(
            hintText: 'e.g. Physics Whiteboard Scans',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.iris, foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Folder "${ctrl.text}" created in local storage.')),
              );
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _showAddFileDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(22),
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark ? AppColors.surfaceDark : Colors.white,
          borderRadius: BorderRadius.circular(30),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Add to File Spaces',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 14),
            ListTile(
              leading: const Icon(Icons.add_photo_alternate_rounded, color: AppColors.bentoCoral),
              title: const Text('Upload Image / Scan', style: TextStyle(fontWeight: FontWeight.w700)),
              subtitle: const Text('Save directly to /Lecture Photos'),
              onTap: () {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Photo added to /Lecture Photos & Diagrams.')),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.code_rounded, color: AppColors.iris),
              title: const Text('New HTML Magazine Document', style: TextStyle(fontWeight: FontWeight.w700)),
              subtitle: const Text('Sandboxed .html with custom CSS'),
              onTap: () {
                Navigator.pop(ctx);
                final newDoc = WorkspaceFileItem(
                  id: 'html_${DateTime.now().millisecondsSinceEpoch}',
                  name: 'New Custom Sheet.html',
                  type: FileType.html,
                  folder: 'HTML Magazine Documents',
                  size: '4 KB',
                  updatedAt: DateTime.now(),
                  colorHex: '#6246EA',
                  content: '<h1>New Custom Magazine Page</h1><p>Edit custom CSS grid and formulas offline.</p>',
                );
                widget.filesNotifier.addFile(newDoc);
                _openHtmlViewer(newDoc);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final images = widget.filesNotifier.imageFiles;
    final htmlDocs = widget.filesNotifier.htmlDocuments;

    return Scaffold(
      backgroundColor: isDark ? AppColors.canvasDark : AppColors.canvasLight,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 110),
          children: [
            // 1. TOP BREADCRUMB & ACTION BAR (Back to Hub + New Folder + Add File)
            Row(
              children: [
                GestureDetector(
                  onTap: widget.onBackToHub,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEAE6FD),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.arrow_back_rounded, size: 14, color: AppColors.iris),
                        SizedBox(width: 4),
                        Text(
                          'Back to Hub',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: AppColors.iris,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: _showNewFolderDialog,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.surfaceDark : Colors.white,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: isDark ? AppColors.borderDark : const Color(0xFFE8E6E1)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.create_new_folder_outlined, size: 14, color: AppColors.iris),
                        SizedBox(width: 4),
                        Text('New Folder', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _showAddFileDialog,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: AppColors.iris,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.add_rounded, size: 14, color: Colors.white),
                        SizedBox(width: 3),
                        Text('Add File', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: Colors.white)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 2. STORAGE OVERVIEW HERO BANNER (Matching prototype #tab-files)
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFF141416),
                borderRadius: BorderRadius.circular(26),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(isDark ? 50 : 25),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'ON-DEVICE FILE SYSTEM',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.8,
                            color: AppColors.bentoMarigold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Folders, Images, Files & HTML',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.3,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Store any image, PDF, or .html doc without needing a Markdown file.',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.white.withAlpha(180),
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(20),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.folder_copy_rounded,
                      color: AppColors.bentoMarigold,
                      size: 24,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // 3. FOLDERS GRID (4 Bento Cards matching prototype)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Your Folders',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.3,
                    color: isDark ? AppColors.inkPrimaryDark : AppColors.inkPrimaryLight,
                  ),
                ),
                Text(
                  '4 Folders',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: isDark ? AppColors.inkSecondaryDark : AppColors.inkSecondaryLight,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // 2x2 Grid of Bento Folder Cards
            Row(
              children: [
                // Folder 1: Images
                Expanded(
                  child: _buildFolderCard(
                    title: 'Lecture Photos',
                    subtitle: 'Whiteboards & scans',
                    badge: 'Images',
                    color: AppColors.bentoCoral,
                    icon: Icons.photo_library_rounded,
                    textColor: Colors.white,
                  ),
                ),
                const SizedBox(width: 12),
                // Folder 2: HTML Zines
                Expanded(
                  child: _buildFolderCard(
                    title: 'HTML Zines',
                    subtitle: 'Rich CSS & tables',
                    badge: '.HTML',
                    color: AppColors.iris,
                    icon: Icons.code_rounded,
                    textColor: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                // Folder 3: PDFs & Handouts
                Expanded(
                  child: _buildFolderCard(
                    title: 'Handouts & PDFs',
                    subtitle: 'Syllabi & lab manuals',
                    badge: 'PDF / ZIP',
                    color: AppColors.bentoPeriwinkle,
                    icon: Icons.picture_as_pdf_rounded,
                    textColor: AppColors.inkPrimaryLight,
                  ),
                ),
                const SizedBox(width: 12),
                // Folder 4: All Workspace Files
                Expanded(
                  child: _buildFolderCard(
                    title: 'All Files',
                    subtitle: 'View every file',
                    badge: 'All',
                    color: AppColors.bentoMarigold,
                    icon: Icons.folder_shared_rounded,
                    textColor: AppColors.inkPrimaryLight,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),

            // 4. STANDALONE IMAGE GALLERY
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Standalone Images in Folder',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.3,
                    color: isDark ? AppColors.inkPrimaryDark : AppColors.inkPrimaryLight,
                  ),
                ),
                GestureDetector(
                  onTap: _showAddFileDialog,
                  child: const Text(
                    '+ Add Photo',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: AppColors.bentoCoral,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // 3-Column Image Gallery Grid
            Row(
              children: [
                ...images.take(2).map((img) => Expanded(
                      child: Container(
                        margin: const EdgeInsets.only(right: 10),
                        child: _buildImageThumbnail(img),
                      ),
                    )),
                // Add Photo Tile
                Expanded(
                  child: GestureDetector(
                    onTap: _showAddFileDialog,
                    child: Container(
                      height: 96,
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.surfaceSubtleDark : AppColors.surfaceSubtleLight,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: AppColors.iris.withAlpha(60),
                          width: 1.5,
                          style: BorderStyle.solid,
                        ),
                      ),
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_photo_alternate_outlined, size: 22, color: AppColors.iris),
                          SizedBox(height: 4),
                          Text(
                            'Add Image',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.iris),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),

            // 5. HTML DOCUMENT SYSTEM SECTION (.html)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'HTML Document System (.html)',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.3,
                        color: isDark ? AppColors.inkPrimaryDark : AppColors.inkPrimaryLight,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      'Sandboxed WebView · Custom CSS · Offline Magazine Pages',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w500,
                        color: isDark ? AppColors.inkSecondaryDark : AppColors.inkSecondaryLight,
                      ),
                    ),
                  ],
                ),
                GestureDetector(
                  onTap: _showAddFileDialog,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEAE6FD),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Text(
                      '+ New .HTML',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: AppColors.iris,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // HTML Documents List
            ...htmlDocs.map((doc) => _buildHtmlDocTile(doc, isDark)),
          ],
        ),
      ),
    );
  }

  Widget _buildFolderCard({
    required String title,
    required String subtitle,
    required String badge,
    required Color color,
    required IconData icon,
    required Color textColor,
  }) {
    return Container(
      height: 118,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: color.withAlpha(60),
            blurRadius: 14,
            offset: const Offset(0, 4),
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
              Icon(icon, color: textColor, size: 22),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(80),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  badge,
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w900,
                    color: textColor,
                  ),
                ),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: textColor,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: textColor.withAlpha(200),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildImageThumbnail(WorkspaceFileItem item) {
    return GestureDetector(
      onTap: () => _showImageLightbox(item),
      child: Container(
        height: 96,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF6246EA), Color(0xFFFF6B57)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(20),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black.withAlpha(70),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                'PNG',
                style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w900, color: Colors.white),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name.split('.').first,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
                Text(
                  item.size,
                  style: const TextStyle(
                    fontSize: 8.5,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHtmlDocTile(WorkspaceFileItem item, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(isDark ? 20 : 6),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFEAE6FD),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.web_rounded,
              color: AppColors.iris,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                    color: isDark ? AppColors.inkPrimaryDark : AppColors.inkPrimaryLight,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'CSS Grid + Formula Cards · Sandboxed',
                  style: TextStyle(
                    fontSize: 10.5,
                    color: isDark ? AppColors.inkSecondaryDark : AppColors.inkSecondaryLight,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => _openHtmlViewer(item),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.iris,
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Text(
                'Render',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
