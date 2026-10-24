import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_colors.dart';

class RecoveryKeyScreen extends StatefulWidget {
  final String recoveryCode;
  final VoidCallback onConfirmed;

  const RecoveryKeyScreen({
    super.key,
    required this.recoveryCode,
    required this.onConfirmed,
  });

  @override
  State<RecoveryKeyScreen> createState() => _RecoveryKeyScreenState();
}

class _RecoveryKeyScreenState extends State<RecoveryKeyScreen> {
  final TextEditingController _confirmController = TextEditingController();
  bool _hasCopied = false;
  String? _error;
  Timer? _clipboardClearTimer;

  String get _lastGroup {
    final parts = widget.recoveryCode.split('-');
    return parts.isNotEmpty ? parts.last.trim().toUpperCase() : '';
  }

  @override
  void dispose() {
    _confirmController.dispose();
    _clipboardClearTimer?.cancel();
    super.dispose();
  }

  void _copyToClipboard() {
    Clipboard.setData(ClipboardData(text: widget.recoveryCode));
    setState(() => _hasCopied = true);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Recovery key copied. Clipboard will auto-clear in 60s.'),
        duration: Duration(seconds: 4),
      ),
    );

    // Auto-clear clipboard after 60 seconds for security
    _clipboardClearTimer?.cancel();
    _clipboardClearTimer = Timer(const Duration(seconds: 60), () async {
      final current = await Clipboard.getData(Clipboard.kTextPlain);
      if (current?.text == widget.recoveryCode) {
        await Clipboard.setData(const ClipboardData(text: ''));
      }
    });
  }

  void _verifyAndProceed() {
    final entered = _confirmController.text.trim().toUpperCase();
    if (entered.isEmpty) {
      setState(() => _error = 'Please enter the last group to verify');
      return;
    }
    if (entered != _lastGroup) {
      setState(() => _error = 'Does not match the last group ($_lastGroup)');
      return;
    }

    widget.onConfirmed();
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
          'Save Recovery Key',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: isDark ? AppColors.inkPrimaryDark : AppColors.inkPrimaryLight,
          ),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF252834) : const Color(0xFFFFF4DC),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  const Icon(Icons.key_rounded, color: AppColors.bentoMarigold, size: 28),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      'This recovery key is your ONLY way back into your vault if you ever forget your passphrase.',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isDark ? AppColors.inkPrimaryDark : AppColors.inkPrimaryLight,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Your 32-Byte Master Recovery Key',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: isDark ? AppColors.inkSecondaryDark : AppColors.inkSecondaryLight,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: isDark ? Colors.transparent : AppColors.borderLight,
                ),
              ),
              child: SelectableText(
                widget.recoveryCode,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                  height: 1.6,
                ),
              ),
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              icon: Icon(_hasCopied ? Icons.check_rounded : Icons.copy_rounded, size: 18),
              label: Text(_hasCopied ? 'Copied to Clipboard' : 'Copy Key'),
              onPressed: _copyToClipboard,
            ),
            const SizedBox(height: 32),
            Text(
              'Confirm Verification',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: isDark ? AppColors.inkPrimaryDark : AppColors.inkPrimaryLight,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'To ensure you have written down or saved this key, please re-type the LAST group of 4 characters:',
              style: TextStyle(
                fontSize: 13,
                color: isDark ? AppColors.inkSecondaryDark : AppColors.inkSecondaryLight,
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _confirmController,
              textCapitalization: TextCapitalization.characters,
              maxLength: 4,
              style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                hintText: 'e.g. $_lastGroup',
                filled: true,
                fillColor: isDark ? AppColors.surfaceSubtleDark : AppColors.surfaceSubtleLight,
                errorText: _error,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
              onSubmitted: (_) => _verifyAndProceed(),
            ),
            const SizedBox(height: 24),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.iris,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: _verifyAndProceed,
              child: const Text('Confirm & Enter Vault', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}
