import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_colors.dart';
import '../file_entry.dart';

class DetailsSheet extends StatelessWidget {
  final FileEntry entry;
  final String absolutePath;

  const DetailsSheet({
    super.key,
    required this.entry,
    required this.absolutePath,
  });

  static Future<void> show(
    BuildContext context, {
    required FileEntry entry,
    required String absolutePath,
  }) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => DetailsSheet(
        entry: entry,
        absolutePath: absolutePath,
      ),
    );
  }

  String _formatSize(int bytes) {
    if (bytes <= 0) return '0 B';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF34384A) : const Color(0xFFDDD9D0),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: isDark ? AppColors.surfaceSubtleDark : AppColors.surfaceSubtleLight,
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: Icon(
                  entry.isDir ? Icons.folder_rounded : Icons.insert_drive_file_rounded,
                  color: entry.isDir ? AppColors.bentoMarigold : AppColors.iris,
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.name,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: isDark ? AppColors.inkPrimaryDark : AppColors.inkPrimaryLight,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      entry.isDir ? 'Folder' : entry.kind.name.toUpperCase(),
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppColors.inkSecondaryDark : AppColors.inkSecondaryLight,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildInfoRow('Path', entry.relativePath, isDark),
          _buildInfoRow('Size', entry.isDir ? '—' : _formatSize(entry.size), isDark),
          _buildInfoRow('Modified', entry.modified.toString().split('.')[0], isDark),
          const SizedBox(height: 24),
          if (!entry.isDir)
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.iris,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                icon: const Icon(Icons.share_rounded, size: 20),
                label: const Text('Share File'),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: absolutePath));
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('File path copied to clipboard: ${entry.name}'),
                      action: SnackBarAction(label: 'OK', onPressed: () {}),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: isDark ? AppColors.inkSecondaryDark : AppColors.inkSecondaryLight,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isDark ? AppColors.inkPrimaryDark : AppColors.inkPrimaryLight,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
