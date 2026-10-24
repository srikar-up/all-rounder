import 'dart:io';
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../file_entry.dart';

class FileTile extends StatelessWidget {
  final FileEntry entry;
  final String absolutePath;
  final bool isSelected;
  final bool isSelectionMode;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback? onMoreTap;

  const FileTile({
    super.key,
    required this.entry,
    required this.absolutePath,
    required this.isSelected,
    required this.isSelectionMode,
    required this.onTap,
    required this.onLongPress,
    this.onMoreTap,
  });

  String _formatSize(int bytes) {
    if (bytes <= 0) return '';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}d ago';
    }
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  Widget _buildLeading(BuildContext context, bool isDark) {
    if (entry.isDir) {
      return Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF252834) : const Color(0xFFFFF4DC),
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.center,
        child: const Icon(
          Icons.folder_rounded,
          color: AppColors.bentoMarigold,
          size: 24,
        ),
      );
    }

    if (entry.kind == FileKind.image) {
      final file = File(absolutePath);
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 44,
          height: 44,
          color: isDark ? const Color(0xFF252834) : const Color(0xFFF1EFEA),
          child: Image.file(
            file,
            cacheWidth: 160,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const Icon(
              Icons.image_outlined,
              color: AppColors.bentoCoral,
              size: 22,
            ),
          ),
        ),
      );
    }

    IconData icon;
    Color iconColor;
    Color bgTint;

    switch (entry.kind) {
      case FileKind.html:
        icon = Icons.language_rounded;
        iconColor = AppColors.iris;
        bgTint = isDark ? const Color(0xFF252834) : AppColors.irisSubtle;
        break;
      case FileKind.note:
        icon = Icons.article_rounded;
        iconColor = AppColors.bentoEmerald;
        bgTint = isDark ? const Color(0xFF252834) : AppColors.bentoEmeraldSubtle;
        break;
      case FileKind.folder:
        icon = Icons.folder_rounded;
        iconColor = AppColors.bentoMarigold;
        bgTint = isDark ? const Color(0xFF252834) : AppColors.marigoldSubtle;
        break;
      case FileKind.image:
        icon = Icons.image_rounded;
        iconColor = AppColors.bentoCoral;
        bgTint = isDark ? const Color(0xFF252834) : AppColors.bentoCoralSubtle;
        break;
      case FileKind.other:
        icon = Icons.insert_drive_file_rounded;
        iconColor = isDark ? AppColors.inkSecondaryDark : AppColors.inkSecondaryLight;
        bgTint = isDark ? const Color(0xFF252834) : const Color(0xFFF1EFEA);
        break;
    }

    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: bgTint,
        borderRadius: BorderRadius.circular(12),
      ),
      alignment: Alignment.center,
      child: Icon(icon, color: iconColor, size: 22),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sizeStr = _formatSize(entry.size);
    final dateStr = _formatDate(entry.modified);
    final subtitle = [if (sizeStr.isNotEmpty) sizeStr, dateStr].join(' · ');

    final cardBg = isSelected
        ? (isDark
            ? AppColors.iris.withAlpha(50)
            : AppColors.irisSubtle)
        : (isDark ? AppColors.surfaceDark : AppColors.surfaceLight);

    return Semantics(
      label: '${entry.isDir ? "Folder" : "File"}: ${entry.name}, $subtitle',
      selected: isSelected,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected
                    ? AppColors.iris
                    : (isDark ? Colors.transparent : AppColors.borderLight),
                width: isSelected ? 1.5 : 1.0,
              ),
            ),
            child: Row(
              children: [
                if (isSelectionMode)
                  Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: Icon(
                      isSelected
                          ? Icons.check_circle_rounded
                          : Icons.radio_button_unchecked_rounded,
                      color: isSelected
                          ? AppColors.iris
                          : (isDark
                              ? AppColors.inkSecondaryDark
                              : AppColors.inkSecondaryLight),
                      size: 24,
                    ),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: _buildLeading(context, isDark),
                  ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        entry.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? AppColors.inkPrimaryDark
                              : AppColors.inkPrimaryLight,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark
                              ? AppColors.inkSecondaryDark
                              : AppColors.inkSecondaryLight,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!isSelectionMode && onMoreTap != null)
                  IconButton(
                    icon: const Icon(Icons.more_vert_rounded, size: 20),
                    color: isDark
                        ? AppColors.inkSecondaryDark
                        : AppColors.inkSecondaryLight,
                    tooltip: 'More actions',
                    onPressed: onMoreTap,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
