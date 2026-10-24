import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class SelectionAppBar extends StatelessWidget implements PreferredSizeWidget {
  final int selectedCount;
  final VoidCallback onClear;
  final VoidCallback onSelectAll;
  final VoidCallback onMove;
  final VoidCallback onCopy;
  final VoidCallback onShare;
  final VoidCallback onDelete;
  final VoidCallback? onMoveToVault;
  final VoidCallback? onRename;
  final VoidCallback? onDetails;

  const SelectionAppBar({
    super.key,
    required this.selectedCount,
    required this.onClear,
    required this.onSelectAll,
    required this.onMove,
    required this.onCopy,
    required this.onShare,
    required this.onDelete,
    this.onMoveToVault,
    this.onRename,
    this.onDetails,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isSingle = selectedCount == 1;

    return AppBar(
      backgroundColor: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.close_rounded),
        tooltip: 'Cancel selection',
        onPressed: onClear,
      ),
      title: Text(
        '$selectedCount selected',
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: isDark ? AppColors.inkPrimaryDark : AppColors.inkPrimaryLight,
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.select_all_rounded),
          tooltip: 'Select all',
          onPressed: onSelectAll,
        ),
        if (isSingle && onRename != null)
          IconButton(
            icon: const Icon(Icons.drive_file_rename_outline_rounded),
            tooltip: 'Rename',
            onPressed: onRename,
          ),
        IconButton(
          icon: const Icon(Icons.drive_file_move_outlined),
          tooltip: 'Move',
          onPressed: onMove,
        ),
        IconButton(
          icon: const Icon(Icons.content_copy_rounded),
          tooltip: 'Copy',
          onPressed: onCopy,
        ),
        IconButton(
          icon: const Icon(Icons.share_outlined),
          tooltip: 'Share',
          onPressed: onShare,
        ),
        if (onMoveToVault != null)
          IconButton(
            icon: const Icon(Icons.shield_outlined, color: AppColors.iris),
            tooltip: 'Move to Vault',
            onPressed: onMoveToVault,
          ),
        IconButton(
          icon: const Icon(Icons.delete_outline_rounded, color: AppColors.bentoCoral),
          tooltip: 'Delete',
          onPressed: onDelete,
        ),
        if (isSingle && onDetails != null)
          IconButton(
            icon: const Icon(Icons.info_outline_rounded),
            tooltip: 'Details',
            onPressed: onDetails,
          ),
      ],
    );
  }
}
