import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import '../../../core/theme/app_colors.dart';
import '../../fitness/services/fake_health_source.dart';
import '../../fitness/services/health_plugin_source.dart';
import '../../fitness/ui/quota_progress_widget.dart';
import '../../google/services/backup_key_store.dart';
import '../../google/services/drive_remote_store.dart';
import '../../google/services/fake_remote_store.dart';
import '../../google/services/google_account_service.dart';
import '../../google/services/notes_backup_source.dart';
import '../../google/ui/connected_services_screen.dart';
import '../../vault/services/vault_backup_source.dart';
import '../../vault/services/vault_repository.dart';
import '../../vault/ui/vault_gate_screen.dart';
import '../controllers/file_browser_controller.dart';
import '../file_entry.dart';
import '../file_service.dart';
import 'folder_browser_screen.dart';
import 'image_viewer_screen.dart';
import 'trash_screen.dart';

class FilesHomeScreen extends StatefulWidget {
  final FileService service;
  final FileBrowserController controller;
  final void Function(FileEntry entry, String absolutePath)? onOpenNote;
  final void Function(FileEntry entry, String absolutePath)? onOpenHtml;

  const FilesHomeScreen({
    super.key,
    required this.service,
    required this.controller,
    this.onOpenNote,
    this.onOpenHtml,
  });

  @override
  State<FilesHomeScreen> createState() => _FilesHomeScreenState();
}

class _FilesHomeScreenState extends State<FilesHomeScreen> {
  StorageUsage _usage = const StorageUsage();
  List<FileEntry> _recentFiles = [];
  List<FileEntry> _topFolders = [];
  bool _isLoading = true;
  StreamSubscription? _eventsSub;

  @override
  void initState() {
    super.initState();
    _loadData();
    _eventsSub = widget.service.events.listen((_) {
      if (mounted) _loadData();
    });
  }

  @override
  void dispose() {
    _eventsSub?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (mounted && !_isLoading) {
      setState(() => _isLoading = true);
    }
    try {
      final usage = await widget.service.usage();
      final rootEntries = await widget.service.list('');

      // Top level folders
      final folders = rootEntries.where((e) => e.isDir).toList();

      // Recent files (search non-folders across all directories)
      final allFiles = await widget.service.search('', recursive: true);
      final filesOnly = allFiles.where((e) => !e.isDir).toList();
      filesOnly.sort((a, b) => b.modified.compareTo(a.modified));
      final recents = filesOnly.take(10).toList();

      if (mounted) {
        setState(() {
          _usage = usage;
          _topFolders = folders;
          _recentFiles = recents;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  void _openFolder(String dirRel) {
    widget.controller.open(dirRel);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FolderBrowserScreen(
          controller: widget.controller,
          onOpenNote: widget.onOpenNote,
          onOpenHtml: widget.onOpenHtml,
        ),
      ),
    );
  }

  void _openFile(FileEntry entry) {
    final absPath = widget.service.sandbox.resolve(entry.relativePath);
    if (entry.kind == FileKind.note && widget.onOpenNote != null) {
      widget.onOpenNote!(entry, absPath);
    } else if (entry.kind == FileKind.html && widget.onOpenHtml != null) {
      widget.onOpenHtml!(entry, absPath);
    } else if (entry.kind == FileKind.image) {
      ImageViewerScreen.open(context, title: entry.name, absolutePath: absPath);
    }
  }

  Widget _buildStorageCard(BuildContext context, bool isDark) {
    final total = _usage.totalBytes;
    final totalStr = _formatBytes(total);

    double nFrac = total > 0 ? _usage.notesBytes / total : 0;
    double hFrac = total > 0 ? _usage.htmlBytes / total : 0;
    double iFrac = total > 0 ? _usage.imagesBytes / total : 0;
    double oFrac = total > 0 ? _usage.otherBytes / total : 0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? Colors.transparent : AppColors.borderLight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Storage Used',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppColors.inkSecondaryDark : AppColors.inkSecondaryLight,
                ),
              ),
              Text(
                totalStr,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: isDark ? AppColors.inkPrimaryDark : AppColors.inkPrimaryLight,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Segmented progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: SizedBox(
              height: 10,
              child: total == 0
                  ? Container(color: isDark ? const Color(0xFF252834) : const Color(0xFFE5E2DC))
                  : Row(
                      children: [
                        if (nFrac > 0)
                          Expanded(
                            flex: (nFrac * 1000).toInt().clamp(1, 1000),
                            child: Container(color: AppColors.bentoEmerald),
                          ),
                        if (hFrac > 0)
                          Expanded(
                            flex: (hFrac * 1000).toInt().clamp(1, 1000),
                            child: Container(color: AppColors.iris),
                          ),
                        if (iFrac > 0)
                          Expanded(
                            flex: (iFrac * 1000).toInt().clamp(1, 1000),
                            child: Container(color: AppColors.bentoCoral),
                          ),
                        if (oFrac > 0)
                          Expanded(
                            flex: (oFrac * 1000).toInt().clamp(1, 1000),
                            child: Container(color: AppColors.bentoMarigold),
                          ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 16),
          // Category legend breakdown
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              _buildLegend('Notes', AppColors.bentoEmerald, _usage.notesBytes, isDark),
              _buildLegend('HTML', AppColors.iris, _usage.htmlBytes, isDark),
              _buildLegend('Images', AppColors.bentoCoral, _usage.imagesBytes, isDark),
              _buildLegend('Other', AppColors.bentoMarigold, _usage.otherBytes, isDark),
              if (_usage.vaultBytes > 0)
                _buildLegend('Vault', const Color(0xFF6366F1), _usage.vaultBytes, isDark),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegend(String label, Color color, int bytes, bool isDark) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          '$label (${_formatBytes(bytes)})',
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w500,
            color: isDark ? AppColors.inkSecondaryDark : AppColors.inkSecondaryLight,
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryTiles(BuildContext context, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Categories',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: isDark ? AppColors.inkPrimaryDark : AppColors.inkPrimaryLight,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildCategoryCard(
                  'Notes',
                  Icons.article_rounded,
                  AppColors.bentoEmerald,
                  () => _openFolder('notes'),
                  isDark,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildCategoryCard(
                  'HTML Notes',
                  Icons.language_rounded,
                  AppColors.iris,
                  () => _openFolder('notes'),
                  isDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildCategoryCard(
                  'Attachments',
                  Icons.image_rounded,
                  AppColors.bentoCoral,
                  () => _openFolder('attachments'),
                  isDark,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildCategoryCard(
                  'Trash',
                  Icons.delete_outline_rounded,
                  AppColors.marigoldDark,
                  () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => TrashScreen(service: widget.service)),
                    );
                  },
                  isDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildCategoryCard(
            'Encrypted Vault',
            Icons.shield_rounded,
            AppColors.iris,
            () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => VaultGateScreen(
                    repository: VaultRepository(widget.service.sandbox.root),
                  ),
                ),
              );
            },
            isDark,
          ),
          const SizedBox(height: 12),
          _buildCategoryCard(
            'Connected Services (Drive & Health)',
            Icons.cloud_sync_rounded,
            AppColors.bentoEmerald,
            () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) {
                    final accountService = GoogleAccountService();
                    final remoteStore = kIsWeb ? FakeRemoteStore() : DriveRemoteStore(accountService);
                    final healthSource = kIsWeb ? FakeHealthSource() : HealthPluginSource();
                    final vaultRepo = VaultRepository(widget.service.sandbox.root);
                    final vaultSource = VaultBackupSource(vaultRepo.vaultDir);
                    final notesSource = NotesBackupSource(widget.service.sandbox);
                    final keyStore = BackupKeyStore();

                    return ConnectedServicesScreen(
                      accountService: accountService,
                      remoteStore: remoteStore,
                      healthSource: healthSource,
                      vaultSource: vaultSource,
                      notesSource: notesSource,
                      sandbox: widget.service.sandbox,
                      keyStore: keyStore,
                    );
                  },
                ),
              );
            },
            isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryCard(
    String label,
    IconData icon,
    Color color,
    VoidCallback onTap,
    bool isDark,
  ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isDark ? Colors.transparent : AppColors.borderLight,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: color.withAlpha(isDark ? 50 : 30),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: isDark ? AppColors.inkPrimaryDark : AppColors.inkPrimaryLight,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecentFiles(BuildContext context, bool isDark) {
    if (_recentFiles.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
          child: Text(
            'Recent Files',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: isDark ? AppColors.inkPrimaryDark : AppColors.inkPrimaryLight,
            ),
          ),
        ),
        SizedBox(
          height: 120,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _recentFiles.length,
            itemBuilder: (context, index) {
              final file = _recentFiles[index];
              return Container(
                width: 130,
                margin: const EdgeInsets.only(right: 12),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _openFile(file),
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark ? Colors.transparent : AppColors.borderLight,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            file.kind == FileKind.html
                                ? Icons.language_rounded
                                : file.kind == FileKind.image
                                    ? Icons.image_rounded
                                    : Icons.article_rounded,
                            color: file.kind == FileKind.html
                                ? AppColors.iris
                                : file.kind == FileKind.image
                                    ? AppColors.bentoCoral
                                    : AppColors.bentoEmerald,
                            size: 24,
                          ),
                          const Spacer(),
                          Text(
                            file.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: isDark ? AppColors.inkPrimaryDark : AppColors.inkPrimaryLight,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _formatBytes(file.size),
                            style: TextStyle(
                              fontSize: 10.5,
                              color: isDark ? AppColors.inkSecondaryDark : AppColors.inkSecondaryLight,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTopFolders(BuildContext context, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Folders',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: isDark ? AppColors.inkPrimaryDark : AppColors.inkPrimaryLight,
                ),
              ),
              TextButton(
                onPressed: () => _openFolder(''),
                child: const Text('Browse all'),
              ),
            ],
          ),
        ),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _topFolders.length,
          itemBuilder: (context, index) {
            final folder = _topFolders[index];
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _openFolder(folder.relativePath),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark ? Colors.transparent : AppColors.borderLight,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF252834) : const Color(0xFFFFF4DC),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.folder_rounded,
                            color: AppColors.bentoMarigold,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            folder.name,
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w600,
                              color: isDark ? AppColors.inkPrimaryDark : AppColors.inkPrimaryLight,
                            ),
                          ),
                        ),
                        const Icon(Icons.chevron_right_rounded, size: 20),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.canvasDark : AppColors.canvasLight,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadData,
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.only(bottom: 96),
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Files & Storage',
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                    color: isDark ? AppColors.inkPrimaryDark : AppColors.inkPrimaryLight,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Sandboxed private app storage',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    color: isDark ? AppColors.inkSecondaryDark : AppColors.inkSecondaryLight,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.search_rounded),
                            tooltip: 'Browse all files',
                            onPressed: () => _openFolder(''),
                          ),
                        ],
                      ),
                    ),
                    _buildStorageCard(context, isDark),
                    QuotaProgressWidget(
                      healthSource: kIsWeb ? FakeHealthSource() : HealthPluginSource(),
                      onOpenSettings: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) {
                              final accountService = GoogleAccountService();
                              final remoteStore = kIsWeb ? FakeRemoteStore() : DriveRemoteStore(accountService);
                              final healthSource = kIsWeb ? FakeHealthSource() : HealthPluginSource();
                              final vaultRepo = VaultRepository(widget.service.sandbox.root);
                              final vaultSource = VaultBackupSource(vaultRepo.vaultDir);
                              final notesSource = NotesBackupSource(widget.service.sandbox);
                              final keyStore = BackupKeyStore();

                              return ConnectedServicesScreen(
                                accountService: accountService,
                                remoteStore: remoteStore,
                                healthSource: healthSource,
                                vaultSource: vaultSource,
                                notesSource: notesSource,
                                sandbox: widget.service.sandbox,
                                keyStore: keyStore,
                              );
                            },
                          ),
                        );
                      },
                    ),
                    _buildCategoryTiles(context, isDark),
                    _buildRecentFiles(context, isDark),
                    _buildTopFolders(context, isDark),
                  ],
                ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.iris,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        icon: const Icon(Icons.folder_open_rounded, size: 20),
        label: const Text('Browse Files'),
        onPressed: () => _openFolder(''),
      ),
    );
  }
}
