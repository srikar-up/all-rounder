import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import '../../../core/theme/app_colors.dart';
import '../../vault/services/vault_repository.dart';
import '../../vault/ui/vault_gate_screen.dart';
import '../controllers/file_browser_controller.dart';
import '../file_entry.dart';
import '../widgets/breadcrumb_bar.dart';
import '../widgets/details_sheet.dart';
import '../widgets/empty_state.dart';
import '../widgets/file_grid_card.dart';
import '../widgets/file_tile.dart';
import '../widgets/name_dialog.dart';
import '../widgets/selection_app_bar.dart';
import 'folder_picker_screen.dart';
import 'image_viewer_screen.dart';

class FolderBrowserScreen extends StatefulWidget {
  final FileBrowserController controller;
  final void Function(FileEntry entry, String absolutePath)? onOpenNote;
  final void Function(FileEntry entry, String absolutePath)? onOpenHtml;

  const FolderBrowserScreen({
    super.key,
    required this.controller,
    this.onOpenNote,
    this.onOpenHtml,
  });

  @override
  State<FolderBrowserScreen> createState() => _FolderBrowserScreenState();
}

class _FolderBrowserScreenState extends State<FolderBrowserScreen> {
  bool _isSearchOpen = false;
  final TextEditingController _searchFieldController = TextEditingController();

  @override
  void dispose() {
    _searchFieldController.dispose();
    super.dispose();
  }

  void _onEntryTap(FileEntry entry) {
    if (widget.controller.isSelectionMode) {
      widget.controller.toggleSelect(entry.relativePath);
      return;
    }

    if (entry.isDir) {
      widget.controller.open(entry.relativePath);
      return;
    }

    final absPath = widget.controller.service.sandbox.resolve(entry.relativePath);

    switch (entry.kind) {
      case FileKind.note:
        if (widget.onOpenNote != null) {
          widget.onOpenNote!(entry, absPath);
        } else {
          DetailsSheet.show(context, entry: entry, absolutePath: absPath);
        }
        break;
      case FileKind.html:
        if (widget.onOpenHtml != null) {
          widget.onOpenHtml!(entry, absPath);
        } else {
          DetailsSheet.show(context, entry: entry, absolutePath: absPath);
        }
        break;
      case FileKind.image:
        ImageViewerScreen.open(context, title: entry.name, absolutePath: absPath);
        break;
      case FileKind.other:
      case FileKind.folder:
        DetailsSheet.show(context, entry: entry, absolutePath: absPath);
        break;
    }
  }

  void _showSortSheet() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Sort by',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: isDark ? AppColors.inkPrimaryDark : AppColors.inkPrimaryLight,
                ),
              ),
              const SizedBox(height: 12),
              ...FileSortOption.values.map((opt) {
                final isSelected = widget.controller.sort == opt;
                final label = opt.name[0].toUpperCase() + opt.name.substring(1);
                return ListTile(
                  leading: Icon(
                    isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                    color: isSelected ? AppColors.iris : Colors.grey,
                  ),
                  title: Text(
                    label,
                    style: TextStyle(
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isDark ? AppColors.inkPrimaryDark : AppColors.inkPrimaryLight,
                    ),
                  ),
                  onTap: () {
                    widget.controller.setSort(opt);
                    Navigator.pop(ctx);
                  },
                );
              }),
              const Divider(),
              SwitchListTile(
                title: Text(
                  'Ascending order',
                  style: TextStyle(
                    color: isDark ? AppColors.inkPrimaryDark : AppColors.inkPrimaryLight,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                value: widget.controller.sortAscending,
                activeColor: AppColors.iris,
                onChanged: (val) {
                  widget.controller.setSort(widget.controller.sort, ascending: val);
                  Navigator.pop(ctx);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleDelete() async {
    final count = widget.controller.selection.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete $count item${count > 1 ? "s" : ""}?'),
        content: const Text('Items will be moved to the Trash and can be restored within 30 days.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.bentoCoral),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        final groupId = await widget.controller.deleteSelected();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$count item${count > 1 ? "s" : ""} moved to trash'),
              action: SnackBarAction(
                label: 'Undo',
                onPressed: () {
                  widget.controller.restore(groupId);
                },
              ),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Delete failed: $e')),
          );
        }
      }
    }
  }

  Future<void> _handleMove() async {
    final dest = await FolderPickerScreen.pickDestination(
      context,
      service: widget.controller.service,
      sourcePaths: widget.controller.selection.toList(),
      actionLabel: 'Move',
    );

    if (dest != null && mounted) {
      try {
        await widget.controller.moveSelected(dest);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Items moved successfully')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Move failed: $e')),
          );
        }
      }
    }
  }

  Future<void> _handleCopy() async {
    final dest = await FolderPickerScreen.pickDestination(
      context,
      service: widget.controller.service,
      sourcePaths: widget.controller.selection.toList(),
      actionLabel: 'Copy',
    );

    if (dest != null && mounted) {
      try {
        await widget.controller.copySelected(dest);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Items copied successfully')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Copy failed: $e')),
          );
        }
      }
    }
  }

  Future<void> _handleMoveToVault() async {
    final selection = widget.controller.selection.toList();
    if (selection.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Move to Encrypted Vault?'),
        content: Text(
          'Move ${selection.length} item${selection.length > 1 ? "s" : ""} to encrypted vault?\n\n'
          'Original files will be encrypted with your master key and permanently deleted from device storage.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.iris),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Move to Vault'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final repo = VaultRepository(widget.controller.service.sandbox.root);
    if (!repo.exists || !repo.isUnlocked) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => VaultGateScreen(repository: repo),
        ),
      );
    }

    if (!mounted) return;
    if (!repo.isUnlocked) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vault is locked. Cannot move items.')),
      );
      return;
    }

    int successCount = 0;
    int failCount = 0;

    Future<void> moveFileToVault(File file, String? folderId) async {
      final meta = await repo.addFile(file, folderId: folderId);
      final verified = repo.index.files.any((f) => f.id == meta.id);
      final blobFile = File(p.join(repo.vaultDir.path, 'data', meta.blobId));
      if (!verified || !blobFile.existsSync() || blobFile.lengthSync() == 0) {
        throw StateError('Integrity verification failed for ${meta.name}');
      }
      await file.delete();
      successCount++;
    }

    Future<void> moveDirToVault(Directory dir, String? parentFolderId) async {
      final folderName = p.basename(dir.path);
      final vaultFolder = await repo.createFolder(folderName, parentId: parentFolderId);
      for (final entity in dir.listSync()) {
        if (entity is File) {
          await moveFileToVault(entity, vaultFolder.id);
        } else if (entity is Directory) {
          await moveDirToVault(entity, vaultFolder.id);
        }
      }
      await dir.delete(recursive: true);
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Encrypting and securing files...'),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      for (final rel in selection) {
        try {
          final absPath = widget.controller.service.sandbox.resolve(rel);
          final stat = await FileStat.stat(absPath);
          if (stat.type == FileSystemEntityType.directory) {
            await moveDirToVault(Directory(absPath), null);
          } else {
            await moveFileToVault(File(absPath), null);
          }
        } catch (_) {
          failCount++;
        }
      }
    } finally {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
    }

    if (mounted) {
      widget.controller.clearSelection();
      await widget.controller.refresh();

      final message = failCount > 0
          ? 'Moved $successCount item(s) to vault ($failCount failed)'
          : 'Successfully moved $successCount item(s) to vault';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _handleRename() async {
    if (widget.controller.selection.length != 1) return;
    final rel = widget.controller.selection.first;
    final name = p.basename(rel);
    final isFolder = widget.controller.entries.any((e) => e.relativePath == rel && e.isDir);

    final newName = await NameDialog.show(
      context,
      title: 'Rename ${isFolder ? "Folder" : "File"}',
      initialValue: name,
      isFolder: isFolder,
      actionLabel: 'Rename',
    );

    if (newName != null && newName != name && mounted) {
      try {
        await widget.controller.rename(rel, newName);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Rename failed: $e')),
          );
        }
      }
    }
  }

  void _handleShare() {
    final paths = widget.controller.selection.map((rel) {
      return widget.controller.service.sandbox.resolve(rel);
    }).join('\n');

    Clipboard.setData(ClipboardData(text: paths));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Copied ${widget.controller.selection.length} path(s) to clipboard')),
    );
  }

  void _handleDetails() {
    if (widget.controller.selection.length != 1) return;
    final rel = widget.controller.selection.first;
    final entry = widget.controller.entries.firstWhere((e) => e.relativePath == rel);
    final absPath = widget.controller.service.sandbox.resolve(rel);
    DetailsSheet.show(context, entry: entry, absolutePath: absPath);
  }

  void _showAddMenu() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF252834) : const Color(0xFFFFF4DC),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.create_new_folder_outlined, color: AppColors.bentoMarigold),
                ),
                title: const Text('New Folder'),
                onTap: () async {
                  Navigator.pop(ctx);
                  final name = await NameDialog.show(
                    context,
                    title: 'New Folder',
                    isFolder: true,
                    actionLabel: 'Create',
                  );
                  if (name != null) {
                    await widget.controller.createFolder(name);
                  }
                },
              ),
              ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF252834) : AppColors.bentoEmeraldSubtle,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.note_add_outlined, color: AppColors.bentoEmerald),
                ),
                title: const Text('New Markdown Note (.md)'),
                onTap: () async {
                  Navigator.pop(ctx);
                  final name = await NameDialog.show(
                    context,
                    title: 'New Note',
                    isFolder: false,
                    actionLabel: 'Create',
                  );
                  if (name != null) {
                    await widget.controller.createNote(name, FileKind.note);
                  }
                },
              ),
              ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF252834) : AppColors.irisSubtle,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.language_rounded, color: AppColors.iris),
                ),
                title: const Text('New Magazine Note (.html)'),
                onTap: () async {
                  Navigator.pop(ctx);
                  final name = await NameDialog.show(
                    context,
                    title: 'New Magazine Note',
                    isFolder: false,
                    actionLabel: 'Create',
                  );
                  if (name != null) {
                    await widget.controller.createNote(name, FileKind.html);
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final ctrl = widget.controller;

        return PopScope(
          canPop: ctrl.isAtRoot,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) ctrl.up();
          },
          child: Scaffold(
            backgroundColor: isDark ? AppColors.canvasDark : AppColors.canvasLight,
            appBar: ctrl.isSelectionMode
                ? SelectionAppBar(
                    selectedCount: ctrl.selection.length,
                    onClear: ctrl.clearSelection,
                    onSelectAll: ctrl.selectAll,
                    onMove: _handleMove,
                    onCopy: _handleCopy,
                    onShare: _handleShare,
                    onDelete: _handleDelete,
                    onMoveToVault: _handleMoveToVault,
                    onRename: ctrl.selection.length == 1 ? _handleRename : null,
                    onDetails: ctrl.selection.length == 1 ? _handleDetails : null,
                  )
                : AppBar(
                    backgroundColor: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                    elevation: 0,
                    leading: ctrl.isAtRoot
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.arrow_back_rounded),
                            tooltip: 'Up one level',
                            onPressed: ctrl.up,
                          ),
                    title: Text(
                      ctrl.isAtRoot ? 'Files' : p.basename(ctrl.currentDir),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: isDark ? AppColors.inkPrimaryDark : AppColors.inkPrimaryLight,
                      ),
                    ),
                    actions: [
                      IconButton(
                        icon: Icon(_isSearchOpen ? Icons.close_rounded : Icons.search_rounded),
                        tooltip: 'Search files',
                        onPressed: () {
                          setState(() {
                            _isSearchOpen = !_isSearchOpen;
                            if (!_isSearchOpen) {
                              _searchFieldController.clear();
                              ctrl.clearSearch();
                            }
                          });
                        },
                      ),
                      IconButton(
                        icon: Icon(
                          ctrl.viewMode == FileViewMode.list
                              ? Icons.grid_view_rounded
                              : Icons.view_list_rounded,
                        ),
                        tooltip: 'Toggle list/grid',
                        onPressed: () {
                          ctrl.setViewMode(
                            ctrl.viewMode == FileViewMode.list
                                ? FileViewMode.grid
                                : FileViewMode.list,
                          );
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.sort_rounded),
                        tooltip: 'Sort files',
                        onPressed: _showSortSheet,
                      ),
                    ],
                  ),
            body: Column(
              children: [
                if (_isSearchOpen)
                  Container(
                    color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: TextField(
                      controller: _searchFieldController,
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: 'Search files in folder...',
                        filled: true,
                        fillColor: isDark ? AppColors.surfaceSubtleDark : AppColors.surfaceSubtleLight,
                        prefixIcon: const Icon(Icons.search_rounded, size: 20),
                        suffixIcon: _searchFieldController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear_rounded, size: 18),
                                onPressed: () {
                                  _searchFieldController.clear();
                                  ctrl.clearSearch();
                                },
                              )
                            : null,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: AppColors.iris, width: 1.5),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      ),
                      onChanged: (val) {
                        ctrl.setQuery(val);
                      },
                    ),
                  ),
                BreadcrumbBar(
                  breadcrumbs: ctrl.breadcrumbs,
                  onSegmentTap: (rel) => ctrl.open(rel),
                ),
                Expanded(
                  child: ctrl.isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : ctrl.error != null
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    ctrl.error!,
                                    style: const TextStyle(color: AppColors.bentoCoral),
                                  ),
                                  const SizedBox(height: 12),
                                  FilledButton(
                                    onPressed: ctrl.refresh,
                                    child: const Text('Retry'),
                                  ),
                                ],
                              ),
                            )
                          : ctrl.entries.isEmpty
                              ? EmptyState(
                                  icon: Icons.folder_open_rounded,
                                  title: ctrl.isSearching ? 'No matching files' : 'Folder is empty',
                                  description: ctrl.isSearching
                                      ? 'Try searching with a different term'
                                      : 'Add new notes or folders using the + button below',
                                  actionLabel: ctrl.isSearching ? null : 'New Note',
                                  onAction: ctrl.isSearching
                                      ? null
                                      : () async {
                                          final name = await NameDialog.show(
                                            context,
                                            title: 'New Note',
                                            isFolder: false,
                                            actionLabel: 'Create',
                                          );
                                          if (name != null) {
                                            await ctrl.createNote(name, FileKind.note);
                                          }
                                        },
                                )
                              : RefreshIndicator(
                                  onRefresh: ctrl.refresh,
                                  child: ctrl.viewMode == FileViewMode.list
                                      ? ListView.builder(
                                          itemCount: ctrl.entries.length,
                                          padding: const EdgeInsets.only(top: 8, bottom: 88),
                                          itemBuilder: (context, index) {
                                            final entry = ctrl.entries[index];
                                            final absPath = ctrl.service.sandbox.resolve(entry.relativePath);
                                            final isSelected = ctrl.selection.contains(entry.relativePath);

                                            return FileTile(
                                              entry: entry,
                                              absolutePath: absPath,
                                              isSelected: isSelected,
                                              isSelectionMode: ctrl.isSelectionMode,
                                              onTap: () => _onEntryTap(entry),
                                              onLongPress: () => ctrl.toggleSelect(entry.relativePath),
                                              onMoreTap: () => DetailsSheet.show(
                                                context,
                                                entry: entry,
                                                absolutePath: absPath,
                                              ),
                                            );
                                          },
                                        )
                                      : GridView.builder(
                                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
                                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                            crossAxisCount: 2,
                                            childAspectRatio: 0.88,
                                            crossAxisSpacing: 12,
                                            mainAxisSpacing: 12,
                                          ),
                                          itemCount: ctrl.entries.length,
                                          itemBuilder: (context, index) {
                                            final entry = ctrl.entries[index];
                                            final absPath = ctrl.service.sandbox.resolve(entry.relativePath);
                                            final isSelected = ctrl.selection.contains(entry.relativePath);

                                            return FileGridCard(
                                              entry: entry,
                                              absolutePath: absPath,
                                              isSelected: isSelected,
                                              isSelectionMode: ctrl.isSelectionMode,
                                              onTap: () => _onEntryTap(entry),
                                              onLongPress: () => ctrl.toggleSelect(entry.relativePath),
                                            );
                                          },
                                        ),
                                ),
                ),
              ],
            ),
            floatingActionButton: ctrl.isSelectionMode
                ? null
                : FloatingActionButton(
                    backgroundColor: AppColors.iris,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                    onPressed: _showAddMenu,
                    child: const Icon(Icons.add_rounded, size: 28),
                  ),
          ),
        );
      },
    );
  }
}
