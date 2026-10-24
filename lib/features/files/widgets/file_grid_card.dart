import 'dart:io';
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../file_entry.dart';

class FileGridCard extends StatelessWidget {
  final FileEntry entry;
  final String absolutePath;
  final bool isSelected;
  final bool isSelectionMode;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const FileGridCard({
    super.key,
    required this.entry,
    required this.absolutePath,
    required this.isSelected,
    required this.isSelectionMode,
    required this.onTap,
    required this.onLongPress,
  });

  String _formatSize(int bytes) {
    if (bytes <= 0) return '';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Widget _buildPreview(BuildContext context, bool isDark) {
    if (entry.isDir) {
      return Container(
        color: isDark ? const Color(0xFF252834) : const Color(0xFFFFF4DC),
        child: const Center(
          child: Icon(
            Icons.folder_rounded,
            color: AppColors.bentoMarigold,
            size: 44,
          ),
        ),
      );
    }

    if (entry.kind == FileKind.image) {
      final file = File(absolutePath);
      return Image.file(
        file,
        cacheWidth: 240,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          color: isDark ? const Color(0xFF252834) : const Color(0xFFF1EFEA),
          child: const Center(
            child: Icon(Icons.broken_image_rounded, color: AppColors.bentoCoral, size: 36),
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
      color: bgTint,
      child: Center(
        child: Icon(icon, color: iconColor, size: 36),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isSelected
        ? (isDark
            ? AppColors.iris.withAlpha(50)
            : AppColors.irisSubtle)
        : (isDark ? AppColors.surfaceDark : AppColors.surfaceLight);

    final sizeStr = _formatSize(entry.size);

    return Semantics(
      label: '${entry.isDir ? "Folder" : "File"}: ${entry.name}',
      selected: isSelected,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isSelected
                    ? AppColors.iris
                    : (isDark ? Colors.transparent : AppColors.borderLight),
                width: isSelected ? 2.0 : 1.0,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(17)),
                        child: _buildPreview(context, isDark),
                      ),
                      if (isSelectionMode)
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Container(
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white,
                            ),
                            child: Icon(
                              isSelected
                                  ? Icons.check_circle_rounded
                                  : Icons.radio_button_unchecked_rounded,
                              color: isSelected
                                  ? AppColors.iris
                                  : const Color(0xFF9CA0AB),
                              size: 24,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        entry.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? AppColors.inkPrimaryDark
                              : AppColors.inkPrimaryLight,
                        ),
                      ),
                      if (sizeStr.isNotEmpty || entry.isDir)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            entry.isDir ? 'Folder' : sizeStr,
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark
                                  ? AppColors.inkSecondaryDark
                                  : AppColors.inkSecondaryLight,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
