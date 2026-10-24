import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import '../../../core/theme/app_colors.dart';
import '../file_entry.dart';
import '../file_service.dart';
import '../widgets/name_dialog.dart';

class FolderPickerScreen extends StatefulWidget {
  final FileService service;
  final List<String> sourcePaths;
  final String actionLabel; // "Move" or "Copy"

  const FolderPickerScreen({
    super.key,
    required this.service,
    required this.sourcePaths,
    this.actionLabel = 'Move',
  });

  static Future<String?> pickDestination(
    BuildContext context, {
    required FileService service,
    required List<String> sourcePaths,
    String actionLabel = 'Move',
  }) {
    return Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => FolderPickerScreen(
          service: service,
          sourcePaths: sourcePaths,
          actionLabel: actionLabel,
        ),
      ),
    );
  }

  @override
  State<FolderPickerScreen> createState() => _FolderPickerScreenState();
}

class _FolderPickerScreenState extends State<FolderPickerScreen> {
  String _currentDir = '';
  List<FileEntry> _folders = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadFolders();
  }

  bool _isInvalidDestination(String targetRel) {
    for (final src in widget.sourcePaths) {
      if (targetRel == src) return true;
      if (p.isWithin(src, targetRel)) return true;
    }
    return false;
  }

  Future<void> _loadFolders() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final entries = await widget.service.list(_currentDir);
      setState(() {
        _folders = entries.where((e) => e.isDir).toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _navigateUp() {
    if (_currentDir.isEmpty || _currentDir == '.') return;
    final parent = p.dirname(_currentDir);
    _currentDir = (parent == '.' || parent == '/') ? '' : parent;
    _loadFolders();
  }

  Future<void> _createNewFolder() async {
    final name = await NameDialog.show(
      context,
      title: 'New Folder',
      isFolder: true,
      actionLabel: 'Create',
    );
    if (name != null && name.trim().isNotEmpty) {
      try {
        await widget.service.createFolder(_currentDir, name.trim());
        _loadFolders();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to create folder: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isAtRoot = _currentDir.isEmpty || _currentDir == '.';
    final isCurrentInvalid = _isInvalidDestination(_currentDir);

    return Scaffold(
      backgroundColor: isDark ? AppColors.canvasDark : AppColors.canvasLight,
      appBar: AppBar(
        backgroundColor: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        elevation: 0,
        leading: isAtRoot
            ? IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.pop(context),
              )
            : IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: _navigateUp,
              ),
        title: Text(
          isAtRoot ? 'Select destination' : p.basename(_currentDir),
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: isDark ? AppColors.inkPrimaryDark : AppColors.inkPrimaryLight,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.create_new_folder_outlined),
            tooltip: 'New Folder',
            onPressed: _createNewFolder,
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: isDark ? const Color(0xFF161822) : const Color(0xFFF6F4F0),
            child: Text(
              'Current: /${_currentDir.isEmpty ? "AllRounder" : _currentDir}',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? AppColors.inkSecondaryDark : AppColors.inkSecondaryLight,
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(child: Text(_error!))
                    : _folders.isEmpty
                        ? Center(
                            child: Text(
                              'No subfolders here',
                              style: TextStyle(
                                color: isDark
                                    ? AppColors.inkSecondaryDark
                                    : AppColors.inkSecondaryLight,
                              ),
                            ),
                          )
                        : ListView.builder(
                            itemCount: _folders.length,
                            itemBuilder: (context, index) {
                              final folder = _folders[index];
                              final isInvalid = _isInvalidDestination(folder.relativePath);

                              return ListTile(
                                leading: Icon(
                                  Icons.folder_rounded,
                                  color: isInvalid
                                      ? (isDark
                                          ? AppColors.inkSecondaryDark.withAlpha(80)
                                          : AppColors.inkSecondaryLight.withAlpha(80))
                                      : AppColors.bentoMarigold,
                                ),
                                title: Text(
                                  folder.name,
                                  style: TextStyle(
                                    color: isInvalid
                                        ? (isDark
                                            ? AppColors.inkSecondaryDark.withAlpha(100)
                                            : AppColors.inkSecondaryLight.withAlpha(100))
                                        : (isDark
                                            ? AppColors.inkPrimaryDark
                                            : AppColors.inkPrimaryLight),
                                  ),
                                ),
                                subtitle: isInvalid
                                    ? const Text(
                                        'Cannot move into self or child',
                                        style: TextStyle(fontSize: 11, color: AppColors.bentoCoral),
                                      )
                                    : null,
                                trailing: const Icon(Icons.chevron_right_rounded, size: 20),
                                onTap: isInvalid
                                    ? null
                                    : () {
                                        setState(() {
                                          _currentDir = folder.relativePath;
                                        });
                                        _loadFolders();
                                      },
                              );
                            },
                          ),
          ),
          SafeArea(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                border: Border(
                  top: BorderSide(
                    color: isDark ? Colors.transparent : AppColors.borderLight,
                  ),
                ),
              ),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.iris,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: isCurrentInvalid
                      ? null
                      : () => Navigator.pop(context, _currentDir),
                  child: Text(
                    '${widget.actionLabel} here',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
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
