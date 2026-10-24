import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/backup/backup_source.dart';
import '../../../core/theme/app_colors.dart';
import '../../files/sandbox.dart';
import '../../fitness/models/daily_quota.dart';
import '../../fitness/models/health_status.dart';
import '../../fitness/services/health_source.dart';
import '../services/backup_cipher.dart';
import '../services/backup_key_store.dart';
import '../services/google_account_service.dart';
import '../services/remote_store.dart';
import '../services/restore_engine.dart';
import 'backup_screen.dart';
import 'backup_setup_sheet.dart';

class ConnectedServicesScreen extends StatefulWidget {
  final GoogleAccountService accountService;
  final RemoteStore remoteStore;
  final HealthSource healthSource;
  final BackupSource vaultSource;
  final BackupSource notesSource;
  final Sandbox sandbox;
  final BackupKeyStore keyStore;

  const ConnectedServicesScreen({
    super.key,
    required this.accountService,
    required this.remoteStore,
    required this.healthSource,
    required this.vaultSource,
    required this.notesSource,
    required this.sandbox,
    required this.keyStore,
  });

  @override
  State<ConnectedServicesScreen> createState() => _ConnectedServicesScreenState();
}

class _ConnectedServicesScreenState extends State<ConnectedServicesScreen> {
  String? _lastBackupTime;
  int _lastUploadedCount = 0;
  HealthStatus _healthStatus = HealthStatus.needsPermission;
  DailyQuota _quota = const DailyQuota();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadState();
  }

  Future<void> _loadState() async {
    setState(() => _isLoading = true);
    final prefs = await SharedPreferences.getInstance();
    final timeStr = prefs.getString('all_rounder_last_backup_time');
    final count = prefs.getInt('all_rounder_last_backup_uploaded') ?? 0;
    final status = await widget.healthSource.status();
    final quota = await DailyQuota.load();

    if (mounted) {
      setState(() {
        _lastBackupTime = timeStr;
        _lastUploadedCount = count;
        _healthStatus = status;
        _quota = quota;
        _isLoading = false;
      });
    }
  }

  Future<void> _handleConnectGoogle() async {
    final success = await widget.accountService.connect();
    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Connected as ${widget.accountService.email ?? "Google User"}')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Google Sign-In was cancelled or failed.')),
        );
      }
      setState(() {});
    }
  }

  Future<void> _handleBackupNow() async {
    final hasKey = await widget.keyStore.hasKey();
    if (!hasKey && mounted) {
      BackupSetupSheet.show(
        context,
        keyStore: widget.keyStore,
        onSetupComplete: () {
          _navigateToBackupScreen();
        },
      );
    } else {
      _navigateToBackupScreen();
    }
  }

  void _navigateToBackupScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BackupScreen(
          remoteStore: widget.remoteStore,
          sources: [widget.vaultSource, widget.notesSource],
          keyStore: widget.keyStore,
        ),
      ),
    ).then((_) => _loadState());
  }

  Future<void> _handleRestore() async {
    final keyController = TextEditingController();
    final keyConfirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restore from Drive'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter your 32-character Backup Key to restore and decrypt notes and attachments (leave blank if restoring vault only):',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: keyController,
              decoration: const InputDecoration(
                hintText: 'XXXX-XXXX-XXXX-...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Start Restore')),
        ],
      ),
    );

    if (keyConfirmed != true || !mounted) return;

    BackupCipher? cipher;
    final enteredKey = keyController.text.trim();
    if (enteredKey.isNotEmpty) {
      try {
        await widget.keyStore.importRecoveryCode(enteredKey);
        final keyBytes = await widget.keyStore.getKeyBytes();
        if (keyBytes != null) cipher = BackupCipher(keyBytes);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Invalid backup key format: $e')),
          );
        }
        return;
      }
    }

    final restoreEngine = RestoreEngine(
      remote: widget.remoteStore,
      vaultSource: widget.vaultSource,
      notesSource: widget.notesSource,
      sandbox: widget.sandbox,
      backupCipher: cipher,
    );

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Restoring files from Google Drive...'),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final report = await restoreEngine.run();
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop(); // dismiss loading
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Restore Finished'),
            content: Text(
              '• Vault items restored: ${report.vaultItemsRestored}\n'
              '• Notes restored: ${report.notesRestored}\n'
              '• Conflicts preserved: ${report.conflictsResolved}\n'
              '• Skipped (identical): ${report.skipped}\n'
              '${report.failed.isNotEmpty ? "• Failed items: ${report.failed.length}" : ""}',
            ),
            actions: [
              FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Restore error: $e')),
        );
      }
    }
  }

  Future<void> _handleDeleteCloudBackup() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Cloud Backup?'),
        content: const Text(
          'This will permanently delete all encrypted backup files from your hidden Google Drive storage.\n\n'
          'Your local notes and local vault files on this phone will NOT be deleted.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.bentoCoral),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete from Drive'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      final remoteFiles = await widget.remoteStore.list();
      for (final f in remoteFiles.values) {
        await widget.remoteStore.delete(f.id);
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('all_rounder_last_backup_time');
      await prefs.remove('all_rounder_last_backup_uploaded');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cloud backup deleted successfully.')),
        );
        _loadState();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete cloud backup: $e')),
        );
      }
    }
  }

  Future<void> _handleEditQuota() async {
    final stepsCtrl = TextEditingController(text: _quota.stepsGoal.toString());
    final exerciseCtrl = TextEditingController(text: _quota.exerciseMinutesGoal.toString());

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Daily Fitness Goals'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: stepsCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Daily Steps Goal'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: exerciseCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Daily Active Minutes Goal'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
        ],
      ),
    );

    if (saved == true && mounted) {
      final newSteps = int.tryParse(stepsCtrl.text) ?? 8000;
      final newExercise = int.tryParse(exerciseCtrl.text) ?? 30;
      final updated = DailyQuota(stepsGoal: newSteps, exerciseMinutesGoal: newExercise);
      await updated.save();
      setState(() => _quota = updated);
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
          'Connected Services',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: isDark ? AppColors.inkPrimaryDark : AppColors.inkPrimaryLight,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _buildGoogleDriveCard(context, isDark),
                const SizedBox(height: 20),
                _buildHealthConnectCard(context, isDark),
              ],
            ),
    );
  }

  Widget _buildGoogleDriveCard(BuildContext context, bool isDark) {
    final isConnected = widget.accountService.isConnected;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: isDark ? Colors.transparent : AppColors.borderLight),
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
                child: const Icon(Icons.add_to_drive_rounded, color: AppColors.iris),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Google Drive Backup',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: isDark ? AppColors.inkPrimaryDark : AppColors.inkPrimaryLight,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isConnected
                          ? 'Connected as ${widget.accountService.email ?? "Google Account"}'
                          : 'Not connected (Optional)',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: isConnected ? AppColors.bentoEmerald : (isDark ? AppColors.inkSecondaryDark : AppColors.inkSecondaryLight),
                        fontWeight: isConnected ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (_lastBackupTime != null) ...[
            const SizedBox(height: 12),
            Text(
              'Last backup: ${_lastBackupTime!.substring(0, 10)} • $_lastUploadedCount uploaded',
              style: TextStyle(fontSize: 12, color: isDark ? AppColors.inkSecondaryDark : AppColors.inkSecondaryLight),
            ),
          ],
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 8),
          if (!isConnected)
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: AppColors.iris),
              onPressed: _handleConnectGoogle,
              icon: const Icon(Icons.login_rounded),
              label: const Text('Connect Google Drive'),
            )
          else ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: AppColors.iris),
                  onPressed: _handleBackupNow,
                  icon: const Icon(Icons.cloud_upload_outlined),
                  label: const Text('Back up Now'),
                ),
                OutlinedButton.icon(
                  onPressed: _handleRestore,
                  icon: const Icon(Icons.cloud_download_outlined),
                  label: const Text('Restore'),
                ),
                TextButton(
                  onPressed: () {
                    BackupSetupSheet.show(
                      context,
                      keyStore: widget.keyStore,
                      onSetupComplete: () {},
                    );
                  },
                  child: const Text('Backup Key'),
                ),
                TextButton(
                  onPressed: () async {
                    await widget.accountService.disconnect();
                    setState(() {});
                  },
                  child: const Text('Disconnect'),
                ),
                TextButton(
                  style: TextButton.styleFrom(foregroundColor: AppColors.bentoCoral),
                  onPressed: _handleDeleteCloudBackup,
                  child: const Text('Delete Cloud Backup'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHealthConnectCard(BuildContext context, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: isDark ? Colors.transparent : AppColors.borderLight),
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
                  color: isDark ? const Color(0xFF252834) : AppColors.bentoEmeraldSubtle,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.favorite_rounded, color: AppColors.bentoEmerald),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Health Connect',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: isDark ? AppColors.inkPrimaryDark : AppColors.inkPrimaryLight,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _healthStatus.description,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: _healthStatus == HealthStatus.ready
                            ? AppColors.bentoEmerald
                            : (_healthStatus == HealthStatus.notInstalled ? AppColors.bentoCoral : AppColors.bentoMarigold),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Target: ${_quota.stepsGoal} steps / ${_quota.exerciseMinutesGoal} active min daily',
            style: TextStyle(fontSize: 12, color: isDark ? AppColors.inkSecondaryDark : AppColors.inkSecondaryLight),
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (_healthStatus == HealthStatus.notInstalled)
                FilledButton.icon(
                  onPressed: () => widget.healthSource.openInstallPage(),
                  icon: const Icon(Icons.download_rounded),
                  label: const Text('Install Health Connect'),
                )
              else if (_healthStatus == HealthStatus.needsPermission)
                FilledButton.icon(
                  onPressed: () async {
                    final granted = await widget.healthSource.requestPermissions();
                    if (granted) _loadState();
                  },
                  icon: const Icon(Icons.lock_open_rounded),
                  label: const Text('Grant Permission'),
                ),
              OutlinedButton.icon(
                onPressed: _handleEditQuota,
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Edit Goals'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
