import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_colors.dart';

class ImageViewerScreen extends StatelessWidget {
  final String title;
  final String absolutePath;

  const ImageViewerScreen({
    super.key,
    required this.title,
    required this.absolutePath,
  });

  static void open(BuildContext context, {required String title, required String absolutePath}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ImageViewerScreen(title: title, absolutePath: absolutePath),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final file = File(absolutePath);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black.withAlpha(200),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy_rounded),
            tooltip: 'Copy path',
            onPressed: () {
              Clipboard.setData(ClipboardData(text: absolutePath));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Image path copied to clipboard')),
              );
            },
          ),
        ],
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 4.0,
          child: file.existsSync()
              ? Image.file(
                  file,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.broken_image_rounded, color: AppColors.bentoCoral, size: 48),
                        SizedBox(height: 12),
                        Text(
                          'Unable to load image file',
                          style: TextStyle(color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                )
              : const Center(
                  child: Text(
                    'File not found',
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
        ),
      ),
    );
  }
}
