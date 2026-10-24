import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import '../../../core/theme/app_colors.dart';
import '../../files/file_service.dart';
import '../../files/widgets/name_dialog.dart';
import '../models/vault_index.dart';
import '../services/screen_security_service.dart';
import '../services/vault_auto_lock.dart';
import '../services/vault_repository.dart';
import 'recovery_key_screen.dart';

class VaultHomeScreen extends StatefulWidget {
  final VaultRepository repository;
  final VoidCallback onLocked;

  const VaultHomeScreen({
    super.key,
    required this.repository,
    required this.onLocked,
  });

  @override
  State<VaultHomeScreen> createState() => _VaultHomeScreenState();
}

class _VaultHomeScreenState extends State<VaultHomeScreen> {
  String? _currentFolderId;
  late final VaultAutoLockObserver _autoLockObserver;

  @override
  void initState() {
    super.initState();
    ScreenSecurityService.enable();
    _autoLockObserver = VaultAutoLockObserver(
      onLock: _lockVault,
      delay: AutoLockDelay.thirtySeconds,
    );
    _autoLockObserver.start();
  }

  @override
  void dispose() {
    _autoLockObserver.stop();
    ScreenSecurityService.disable();
    super.dispose();
  }

  void _lockVault() {
    widget.repository.lock();
    widget.onLocked();
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Future<void> _openFile(VaultFileMetadata meta) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isImage = meta.mimeType.startsWith('image/');

    if (isImage) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );

      Uint8List? bytes;
      try {
        bytes = await widget.repository.readBytes(meta.id);
      } catch (e) {
        if (mounted) Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
        return;
      }

      if (mounted) Navigator.pop(context); // Dismiss loading

      if (!mounted || bytes == null) return;
      final imageBytes = bytes;
      showDialog(
        context: context,
        builder: (ctx) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black87,
            title: Text(meta.name, style: const TextStyle(color: Colors.white, fontSize: 16)),
            leading: IconButton(
              icon: const Icon(Icons.close_rounded, color: Colors.white),
              onPressed: () => Navigator.pop(ctx),
            ),
          ),
          body: Center(
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: Image.memory(imageBytes, fit: BoxFit.contain),
            ),
          ),
        ),
      );
    } else {
      showModalBottomSheet(
        context: context,
        backgroundColor: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (ctx) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
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
                        color: AppColors.iris.withAlpha(30),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.lock_outline_rounded, color: AppColors.iris),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            meta.name,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          Text(
                            '${_formatSize(meta.size)} · ${meta.mimeType}',
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
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.bentoMarigold.withAlpha(30),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline_rounded, color: AppColors.bentoMarigold, size: 20),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Exporting creates a temporary decrypted copy outside the vault.',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.iris,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    icon: const Icon(Icons.unarchive_rounded),
                    label: const Text('Restore to Files'),
                    onPressed: () async {
                      Navigator.pop(ctx);
                      try {
                        final sandboxRoot = widget.repository.vaultDir.parent.path;
                        final fileService = FileService(sandboxRoot);
                        final tmpDir = Directory(p.join(widget.repository.vaultDir.path, 'vault_tmp'));
                        await tmpDir.create(recursive: true);
                        final tmpFile = File(p.join(tmpDir.path, meta.name));
                        await widget.repository.exportTo(meta.id, tmpFile);
                        await fileService.importFile(tmpFile.path, '');
                        if (await tmpFile.exists()) await tmpFile.delete();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Restored "${meta.name}" to Files')),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Restore failed: $e')),
                          );
                        }
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
  }

  void _showSettings() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Vault Settings',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: isDark ? AppColors.inkPrimaryDark : AppColors.inkPrimaryLight,
                ),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.timer_outlined, color: AppColors.iris),
                title: const Text('Auto-Lock Delay'),
                subtitle: Text(_autoLockObserver.delay.label),
                onTap: () {
                  Navigator.pop(ctx);
                  _showAutoLockPicker();
                },
              ),
              ListTile(
                leading: const Icon(Icons.key_rounded, color: AppColors.bentoMarigold),
                title: const Text('Regenerate Recovery Key'),
                onTap: () async {
                  Navigator.pop(ctx);
                  final newCode = await widget.repository.regenerateRecoveryCode();
                  if (mounted) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => RecoveryKeyScreen(
                          recoveryCode: newCode,
                          onConfirmed: () => Navigator.pop(context),
                        ),
                      ),
                    );
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.password_rounded, color: AppColors.bentoEmerald),
                title: const Text('Change Master Passphrase'),
                onTap: () {
                  Navigator.pop(ctx);
                  _showChangePassphraseDialog();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAutoLockPicker() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Auto-Lock Delay'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: AutoLockDelay.values.map((d) {
            return RadioListTile<AutoLockDelay>(
              title: Text(d.label),
              value: d,
              groupValue: _autoLockObserver.delay,
              activeColor: AppColors.iris,
              onChanged: (val) {
                if (val != null) {
                  setState(() => _autoLockObserver.delay = val);
                  Navigator.pop(ctx);
                }
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  void _showChangePassphraseDialog() {
    final oldController = TextEditingController();
    final newController = TextEditingController();
    String? error;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: const Text('Change Passphrase'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: oldController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Current Passphrase'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: newController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'New Passphrase (10+ chars)',
                  errorText: error,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.iris),
              onPressed: () async {
                if (newController.text.length < 10) {
                  setDlgState(() => error = 'Minimum 10 characters required');
                  return;
                }
                try {
                  await widget.repository.changePassphrase(
                    oldController.text,
                    newController.text,
                  );
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Passphrase updated successfully')),
                  );
                } catch (e) {
                  setDlgState(() => error = e.toString());
                }
              },
              child: const Text('Update'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createFolder() async {
    final name = await NameDialog.show(
      context,
      title: 'New Vault Folder',
      isFolder: true,
      actionLabel: 'Create',
    );
    if (name != null && name.trim().isNotEmpty) {
      await widget.repository.createFolder(name.trim(), parentId: _currentFolderId);
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentFolders = widget.repository.index.folders
        .where((f) => f.parentId == _currentFolderId)
        .toList();
    final currentFiles = widget.repository.index.files
        .where((f) => f.folderId == _currentFolderId)
        .toList();

    return Scaffold(
      backgroundColor: isDark ? AppColors.canvasDark : AppColors.canvasLight,
      appBar: AppBar(
        backgroundColor: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        elevation: 0,
        leading: _currentFolderId != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => setState(() => _currentFolderId = null),
              )
            : null,
        title: Text(
          _currentFolderId == null ? 'Locked Vault' : 'Vault Folder',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: isDark ? AppColors.inkPrimaryDark : AppColors.inkPrimaryLight,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Vault Settings',
            onPressed: _showSettings,
          ),
          IconButton(
            icon: const Icon(Icons.lock_rounded, color: AppColors.bentoMarigold),
            tooltip: 'Lock Vault',
            onPressed: _lockVault,
          ),
        ],
      ),
      body: currentFolders.isEmpty && currentFiles.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF252834) : const Color(0xFFF1EFEA),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.shield_outlined, size: 36, color: AppColors.iris),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Vault is Empty',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: isDark ? AppColors.inkPrimaryDark : AppColors.inkPrimaryLight,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Move private notes, documents, and images here from the file manager.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? AppColors.inkSecondaryDark : AppColors.inkSecondaryLight,
                      ),
                    ),
                  ],
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.symmetric(vertical: 12),
              children: [
                ...currentFolders.map((folder) {
                  return ListTile(
                    leading: const Icon(Icons.folder_rounded, color: AppColors.bentoMarigold, size: 28),
                    title: Text(
                      folder.name,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: isDark ? AppColors.inkPrimaryDark : AppColors.inkPrimaryLight,
                      ),
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded, size: 20),
                    onTap: () => setState(() => _currentFolderId = folder.id),
                  );
                }),
                ...currentFiles.map((file) {
                  return ListTile(
                    leading: Icon(
                      file.mimeType.startsWith('image/')
                          ? Icons.image_rounded
                          : Icons.insert_drive_file_rounded,
                      color: file.mimeType.startsWith('image/')
                          ? AppColors.bentoCoral
                          : AppColors.iris,
                      size: 26,
                    ),
                    title: Text(
                      file.name,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: isDark ? AppColors.inkPrimaryDark : AppColors.inkPrimaryLight,
                      ),
                    ),
                    subtitle: Text(
                      _formatSize(file.size),
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppColors.inkSecondaryDark : AppColors.inkSecondaryLight,
                      ),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, color: AppColors.bentoCoral, size: 20),
                      onPressed: () async {
                        await widget.repository.deleteItem(file.id, isFolder: false);
                        setState(() {});
                      },
                    ),
                    onTap: () => _openFile(file),
                  );
                }),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.iris,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        onPressed: _createFolder,
        child: const Icon(Icons.create_new_folder_outlined),
      ),
    );
  }
}
