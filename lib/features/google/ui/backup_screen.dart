import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/backup/backup_source.dart';
import '../../../core/theme/app_colors.dart';
import '../models/backup_report.dart';
import '../services/backup_cipher.dart';
import '../services/backup_engine.dart';
import '../services/backup_key_store.dart';
import '../services/remote_store.dart';

class BackupScreen extends StatefulWidget {
  final RemoteStore remoteStore;
  final List<BackupSource> sources;
  final BackupKeyStore keyStore;

  const BackupScreen({
    super.key,
    required this.remoteStore,
    required this.sources,
    required this.keyStore,
  });

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  bool _includeNotes = true;
  bool _isRunning = false;
  BackupEngine? _engine;
  StreamSubscription<BackupProgress>? _progressSub;
  BackupProgress _currentProgress = const BackupProgress(0, 0);
  BackupReport? _finalReport;

  @override
  void dispose() {
    _progressSub?.cancel();
    _engine?.cancel();
    super.dispose();
  }

  Future<void> _startBackup() async {
    setState(() {
      _isRunning = true;
      _finalReport = null;
      _currentProgress = const BackupProgress(0, 0);
    });

    final keyBytes = await widget.keyStore.getKeyBytes();
    final cipher = keyBytes != null ? BackupCipher(keyBytes) : null;

    final engine = BackupEngine(
      remote: widget.remoteStore,
      sources: widget.sources,
      backupCipher: cipher,
      includeNotes: _includeNotes,
    );
    _engine = engine;

    _progressSub = engine.progress.listen((p) {
      if (mounted) setState(() => _currentProgress = p);
    });

    try {
      final report = await engine.run();
      if (mounted) {
        setState(() {
          _isRunning = false;
          _finalReport = report;
        });
        _showSummary(report);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isRunning = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Backup encountered an error: $e')),
        );
      }
    }
  }

  void _showSummary(BackupReport report) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        title: Row(
          children: [
            Icon(
              report.isSuccess ? Icons.check_circle_rounded : Icons.warning_rounded,
              color: report.isSuccess ? AppColors.bentoEmerald : AppColors.bentoCoral,
            ),
            const SizedBox(width: 10),
            Text(report.cancelled ? 'Backup Cancelled' : (report.isSuccess ? 'Backup Complete' : 'Backup Finished with Warnings')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('• Uploaded: ${report.uploaded} file(s)'),
            Text('• Skipped (unchanged): ${report.skipped} file(s)'),
            if (report.tooLarge > 0)
              Text('• Skipped (exceeds 25 MB): ${report.tooLarge} file(s)', style: const TextStyle(color: AppColors.bentoMarigold)),
            if (report.failed.isNotEmpty)
              Text('• Failed: ${report.failed.length} file(s)', style: const TextStyle(color: AppColors.bentoCoral)),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Done'),
          ),
        ],
      ),
    );
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
          'Google Drive Backup',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: isDark ? AppColors.inkPrimaryDark : AppColors.inkPrimaryLight,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isDark ? Colors.transparent : AppColors.borderLight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF252834) : AppColors.irisSubtle,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.cloud_upload_outlined, color: AppColors.iris),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Client-Side Encrypted',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: isDark ? AppColors.inkPrimaryDark : AppColors.inkPrimaryLight,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Your data is private. Google cannot read your backup.',
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
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),
                _buildBulletPoint(
                  icon: Icons.shield_rounded,
                  color: AppColors.iris,
                  title: 'Encrypted Vault',
                  subtitle: 'Blobs remain encrypted with your master vault key and are uploaded unchanged.',
                  isDark: isDark,
                ),
                const SizedBox(height: 12),
                _buildBulletPoint(
                  icon: Icons.note_outlined,
                  color: AppColors.bentoEmerald,
                  title: 'Notes & Attachments',
                  subtitle: 'Sealed with your 256-bit Backup Key (XChaCha20-Poly1305) before leaving device.',
                  isDark: isDark,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(20),
            ),
            child: SwitchListTile(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              value: _includeNotes,
              onChanged: _isRunning ? null : (val) => setState(() => _includeNotes = val),
              title: const Text('Include Notes & Attachments', style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text('Encrypt and upload notes alongside vault', style: TextStyle(fontSize: 12)),
            ),
          ),
          const SizedBox(height: 24),
          if (_isRunning) ...[
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Uploading backup...', style: TextStyle(fontWeight: FontWeight.w600)),
                      Text('${_currentProgress.done} / ${_currentProgress.total}'),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: _currentProgress.fraction,
                      minHeight: 10,
                      backgroundColor: isDark ? const Color(0xFF252834) : const Color(0xFFE5E2DC),
                      valueColor: const AlwaysStoppedAnimation<Color>(AppColors.iris),
                    ),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton(
                    onPressed: () {
                      _engine?.cancel();
                    },
                    child: const Text('Cancel Backup'),
                  ),
                ],
              ),
            ),
          ] else ...[
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.iris,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: _startBackup,
              icon: const Icon(Icons.cloud_upload_rounded),
              label: const Text('Back up Now', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBulletPoint({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required bool isDark,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5, color: isDark ? AppColors.inkPrimaryDark : AppColors.inkPrimaryLight)),
              const SizedBox(height: 2),
              Text(subtitle, style: TextStyle(fontSize: 12, color: isDark ? AppColors.inkSecondaryDark : AppColors.inkSecondaryLight)),
            ],
          ),
        ),
      ],
    );
  }
}
