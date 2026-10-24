import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import '../../../core/theme/app_colors.dart';
import '../names.dart';

class NameDialog extends StatefulWidget {
  final String title;
  final String initialValue;
  final bool isFolder;
  final String actionLabel;

  const NameDialog({
    super.key,
    required this.title,
    this.initialValue = '',
    this.isFolder = false,
    this.actionLabel = 'Save',
  });

  static Future<String?> show(
    BuildContext context, {
    required String title,
    String initialValue = '',
    bool isFolder = false,
    String actionLabel = 'Save',
  }) {
    return showDialog<String>(
      context: context,
      builder: (_) => NameDialog(
        title: title,
        initialValue: initialValue,
        isFolder: isFolder,
        actionLabel: actionLabel,
      ),
    );
  }

  @override
  State<NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<NameDialog> {
  late final TextEditingController _controller;
  String? _validationError;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
    // If it's a file, preselect just the base name without extension
    if (!widget.isFolder && widget.initialValue.isNotEmpty) {
      final base = p.basenameWithoutExtension(widget.initialValue);
      _controller.selection = TextSelection(baseOffset: 0, extentOffset: base.length);
    } else {
      _controller.selection = TextSelection(
        baseOffset: 0,
        extentOffset: widget.initialValue.length,
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String text) {
    setState(() {
      _validationError = validateName(text);
    });
  }

  void _submit() {
    final text = _controller.text.trim();
    final err = validateName(text);
    if (err != null) {
      setState(() => _validationError = err);
      return;
    }
    Navigator.of(context).pop(text);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AlertDialog(
      backgroundColor: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Text(
        widget.title,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: isDark ? AppColors.inkPrimaryDark : AppColors.inkPrimaryLight,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _controller,
            autofocus: true,
            style: TextStyle(
              fontSize: 15,
              color: isDark ? AppColors.inkPrimaryDark : AppColors.inkPrimaryLight,
            ),
            decoration: InputDecoration(
              filled: true,
              fillColor: isDark ? AppColors.surfaceSubtleDark : AppColors.surfaceSubtleLight,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppColors.iris, width: 1.5),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppColors.bentoCoral, width: 1.5),
              ),
              errorText: _validationError,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
            onChanged: _onChanged,
            onSubmitted: (_) => _submit(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            'Cancel',
            style: TextStyle(
              color: isDark ? AppColors.inkSecondaryDark : AppColors.inkSecondaryLight,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.iris,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: _validationError == null && _controller.text.trim().isNotEmpty
              ? _submit
              : null,
          child: Text(widget.actionLabel),
        ),
      ],
    );
  }
}
