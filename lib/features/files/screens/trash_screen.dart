import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import '../../../core/theme/app_colors.dart';
import '../file_service.dart';
import '../widgets/empty_state.dart';

class TrashItem {
  final String groupId;
  final DateTime deletedAt;
  final List<Map<String, dynamic>> items;

  const TrashItem({
    required this.groupId,
    required this.deletedAt,
    required this.items,
  });
}

class TrashScreen extends StatefulWidget {
  final FileService service;

  const TrashScreen({super.key, required this.service});

  @override
  State<TrashScreen> createState() => _TrashScreenState();
}

class _TrashScreenState extends State<TrashScreen> {
  List<TrashItem> _groups = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTrash();
  }

  Future<void> _loadTrash() async {
    setState(() => _isLoading = true);

    final trashDir = Directory(p.join(widget.service.sandbox.root, '.trash'));
    final groups = <TrashItem>[];

    if (await trashDir.exists()) {
      await for (final entity in trashDir.list(followLinks: false)) {
        if (entity is Directory) {
          final groupId = p.basename(entity.path);
          final metaFile = File(p.join(entity.path, 'meta.json'));
          DateTime deletedAt = DateTime.now();
          List<Map<String, dynamic>> items = [];

          if (await metaFile.exists()) {
            try {
              final meta = jsonDecode(await metaFile.readAsString());
              if (meta['deletedAt'] != null) {
                deletedAt = DateTime.parse(meta['deletedAt']);
              }
              if (meta['items'] is List) {
                items = (meta['items'] as List).cast<Map<String, dynamic>>();
              }
            } catch (_) {}
          }

          groups.add(TrashItem(
            groupId: groupId,
            deletedAt: deletedAt,
            items: items,
          ));
        }
      }
    }

    groups.sort((a, b) => b.deletedAt.compareTo(a.deletedAt));

    setState(() {
      _groups = groups;
      _isLoading = false;
    });
  }

  Future<void> _restoreGroup(TrashItem group) async {
    try {
      await widget.service.restore(group.groupId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Items restored to original location')),
        );
      }
      _loadTrash();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to restore: $e')),
        );
      }
    }
  }

  Future<void> _deleteForever(TrashItem group) async {
    try {
      await widget.service.deleteForever(group.groupId);
      _loadTrash();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete: $e')),
        );
      }
    }
  }

  Future<void> _confirmEmptyTrash() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Empty Trash?'),
        content: const Text('All items in the trash will be permanently deleted. This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.bentoCoral),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Empty Trash'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await widget.service.emptyTrash();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Trash emptied')),
          );
        }
        _loadTrash();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error emptying trash: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.canvasDark : AppColors.canvasLight,
      appBar: AppBar(
        backgroundColor: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        elevation: 0,
        title: Text(
          'Trash',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: isDark ? AppColors.inkPrimaryDark : AppColors.inkPrimaryLight,
          ),
        ),
        actions: [
          if (_groups.isNotEmpty)
            TextButton.icon(
              icon: const Icon(Icons.delete_sweep_rounded, size: 20, color: AppColors.bentoCoral),
              label: const Text('Empty', style: TextStyle(color: AppColors.bentoCoral)),
              onPressed: _confirmEmptyTrash,
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _groups.isEmpty
              ? const EmptyState(
                  icon: Icons.delete_outline_rounded,
                  title: 'Trash is empty',
                  description: 'Items deleted from your workspace will stay here for 30 days before being permanently removed.',
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  itemCount: _groups.length,
                  itemBuilder: (context, index) {
                    final group = _groups[index];
                    final names = group.items.map((i) => p.basename(i['originalRel'] ?? '')).where((s) => s.isNotEmpty).join(', ');

                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      padding: const EdgeInsets.all(14),
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
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF252834) : const Color(0xFFFFE6E2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            alignment: Alignment.center,
                            child: const Icon(
                              Icons.delete_outline_rounded,
                              color: AppColors.bentoCoral,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  names.isEmpty ? 'Deleted item' : names,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? AppColors.inkPrimaryDark : AppColors.inkPrimaryLight,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  'Deleted ${group.deletedAt.day}/${group.deletedAt.month}/${group.deletedAt.year}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark ? AppColors.inkSecondaryDark : AppColors.inkSecondaryLight,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.restore_rounded),
                            tooltip: 'Restore',
                            onPressed: () => _restoreGroup(group),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_forever_rounded, color: AppColors.bentoCoral),
                            tooltip: 'Delete permanently',
                            onPressed: () => _deleteForever(group),
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}
