import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_colors.dart';
import '../services/backup_key_store.dart';

class BackupSetupSheet extends StatefulWidget {
  final BackupKeyStore keyStore;
  final VoidCallback onSetupComplete;

  const BackupSetupSheet({
    super.key,
    required this.keyStore,
    required this.onSetupComplete,
  });

  static Future<void> show(
    BuildContext context, {
    required BackupKeyStore keyStore,
    required VoidCallback onSetupComplete,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => BackupSetupSheet(
        keyStore: keyStore,
        onSetupComplete: onSetupComplete,
      ),
    );
  }

  @override
  State<BackupSetupSheet> createState() => _BackupSetupSheetState();
}

class _BackupSetupSheetState extends State<BackupSetupSheet> {
  String? _recoveryCode;
  bool _confirmedSaved = false;
  bool _isLoading = true;
  Timer? _clipboardClearTimer;

  @override
  void initState() {
    super.initState();
    _initKey();
  }

  @override
  void dispose() {
    _clipboardClearTimer?.cancel();
    super.dispose();
  }

  Future<void> _initKey() async {
    String? code = await widget.keyStore.getRecoveryCode();
    code ??= await widget.keyStore.createKey();

    if (mounted) {
      setState(() {
        _recoveryCode = code;
        _isLoading = false;
      });
    }
  }

  void _copyToClipboard() {
    if (_recoveryCode == null) return;
    Clipboard.setData(ClipboardData(text: _recoveryCode!));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Backup key copied. Clipboard will auto-clear in 60s.'),
        duration: Duration(seconds: 4),
      ),
    );

    _clipboardClearTimer?.cancel();
    _clipboardClearTimer = Timer(const Duration(seconds: 60), () async {
      final current = await Clipboard.getData(Clipboard.kTextPlain);
      if (current?.text == _recoveryCode) {
        await Clipboard.setData(const ClipboardData(text: ''));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF252834) : AppColors.marigoldSubtle,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.key_rounded, color: AppColors.bentoMarigold),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Your Personal Backup Key',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: isDark ? AppColors.inkPrimaryDark : AppColors.inkPrimaryLight,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Keep this safe to restore your notes on other devices',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: isDark ? AppColors.inkSecondaryDark : AppColors.inkSecondaryLight,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF252834) : const Color(0xFFF1EFEA),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? Colors.transparent : AppColors.borderLight,
                  ),
                ),
                child: Column(
                  children: [
                    SelectableText(
                      _recoveryCode ?? '',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextButton.icon(
                      onPressed: _copyToClipboard,
                      icon: const Icon(Icons.copy_rounded, size: 16),
                      label: const Text('Copy to Clipboard'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF252834) : const Color(0xFFFFF4DC),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.shield_outlined, color: AppColors.bentoMarigold, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Your notes are encrypted with this key before reaching Google Drive. Without this key, restored notes cannot be decrypted.',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? AppColors.inkPrimaryDark : AppColors.inkPrimaryLight,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _confirmedSaved,
                onChanged: (val) => setState(() => _confirmedSaved = val ?? false),
                title: Text(
                  'I have securely saved this backup key',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.inkPrimaryDark : AppColors.inkPrimaryLight,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.iris,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: _confirmedSaved
                      ? () {
                          Navigator.pop(context);
                          widget.onSetupComplete();
                        }
                      : null,
                  child: const Text('Continue to Backup'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
