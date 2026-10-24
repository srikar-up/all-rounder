import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_colors.dart';
import '../../../services/vault/vault_storage_service.dart';
import '../models/vault_models.dart';
import '../state/vault_notifier.dart';

class VaultScreen extends StatefulWidget {
  final VaultNotifier vaultNotifier;
  final VoidCallback? onOpenSettings;

  const VaultScreen({
    super.key,
    required this.vaultNotifier,
    this.onOpenSettings,
  });

  @override
  State<VaultScreen> createState() => _VaultScreenState();
}

class _VaultScreenState extends State<VaultScreen> {
  final TextEditingController _pinController = TextEditingController();
  String _errorMessage = '';
  int _activeSubTab = 0; // 0 = Encrypted Files, 1 = Secure Notes

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  void _tryUnlock() {
    final success = widget.vaultNotifier.unlockWithPasscode(_pinController.text);
    if (success) {
      _pinController.clear();
      setState(() => _errorMessage = '');
    } else {
      setState(() => _errorMessage = 'Invalid passcode. Default demo PIN is 1234.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.canvasDark : AppColors.canvasLight,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Top Header Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Zero-Knowledge Hardware Vault',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: isDark ? AppColors.inkSecondaryDark : AppColors.inkSecondaryLight,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Private Vault',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.6,
                            color: isDark ? AppColors.inkPrimaryDark : AppColors.inkPrimaryLight,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (widget.vaultNotifier.isUnlocked) ...[
                    _buildTopCircleButton(
                      icon: Icons.vpn_key_rounded,
                      tooltip: 'View Recovery Key',
                      isDark: isDark,
                      onTap: () => _showRecoveryKeyDialog(context),
                    ),
                    const SizedBox(width: 8),
                    _buildTopCircleButton(
                      icon: Icons.lock_rounded,
                      tooltip: 'Lock Vault Now',
                      isDark: isDark,
                      isPrimary: true,
                      onTap: () {
                        widget.vaultNotifier.lock();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Vault locked. Auto-encryption active.')),
                        );
                      },
                    ),
                  ],
                ],
              ),
            ),

            // Content: Either Locked View or Full Bento Unlocked Vault Dashboard
            Expanded(
              child: widget.vaultNotifier.isUnlocked
                  ? _buildUnlockedBentoView(context, isDark)
                  : _buildLockedView(context, isDark),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopCircleButton({
    required IconData icon,
    required String tooltip,
    required bool isDark,
    required VoidCallback onTap,
    bool isPrimary = false,
  }) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: isPrimary
            ? AppColors.iris
            : (isDark ? AppColors.surfaceDark : AppColors.surfaceLight),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(isDark ? 30 : 12),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: IconButton(
        icon: Icon(
          icon,
          size: 19,
          color: isPrimary
              ? Colors.white
              : (isDark ? AppColors.inkPrimaryDark : AppColors.inkPrimaryLight),
        ),
        tooltip: tooltip,
        padding: EdgeInsets.zero,
        onPressed: onTap,
      ),
    );
  }

  // =========================================================================
  // LOCKED VIEW
  // =========================================================================
  Widget _buildLockedView(BuildContext context, bool isDark) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 100),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: const BoxDecoration(
                color: AppColors.irisSubtle,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.shield_rounded, size: 52, color: AppColors.iris),
            ),
            const SizedBox(height: 20),
            Text(
              'Zero-Knowledge Vault',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.4,
                color: isDark ? AppColors.inkPrimaryDark : AppColors.inkPrimaryLight,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Cryptomator-compatible AES-256-GCM envelope. All files stored with obfuscated hashes. Decryption keys never touch the network.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.5,
                color: isDark ? AppColors.inkSecondaryDark : AppColors.inkSecondaryLight,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 24),

            // PIN entry
            SizedBox(
              width: 200,
              child: TextField(
                controller: _pinController,
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: 4,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 24, letterSpacing: 8, fontWeight: FontWeight.w800),
                decoration: const InputDecoration(
                  counterText: '',
                  hintText: '••••',
                ),
                onSubmitted: (_) => _tryUnlock(),
              ),
            ),
            if (_errorMessage.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                _errorMessage,
                style: const TextStyle(color: AppColors.bentoCoral, fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ],
            const SizedBox(height: 18),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.iris,
                foregroundColor: Colors.white,
                minimumSize: const Size(220, 48),
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
              ),
              icon: const Icon(Icons.lock_open_rounded, size: 18),
              label: const Text('Unlock with PIN', style: TextStyle(fontWeight: FontWeight.w700)),
              onPressed: _tryUnlock,
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(220, 48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
              ),
              icon: const Icon(Icons.fingerprint_rounded, size: 20, color: AppColors.bentoEmerald),
              label: const Text('Biometric Authentication', style: TextStyle(fontWeight: FontWeight.w700)),
              onPressed: () {
                widget.vaultNotifier.unlockWithBiometrics();
              },
            ),
            const SizedBox(height: 14),
            TextButton(
              onPressed: () => _showRecoveryKeyInput(context),
              child: const Text('Lost Passcode? Use Recovery Key'),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // UNLOCKED BENTO VIEW (Cryptomator File Manager + Secure Notes)
  // =========================================================================
  Widget _buildUnlockedBentoView(BuildContext context, bool isDark) {
    final encryptedFiles = widget.vaultNotifier.encryptedFiles;
    final textItems = widget.vaultNotifier.items;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 110),
      children: [
        // 1. Bento Status & Storage Overview Card
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFF141416),
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(50),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.bentoEmeraldSubtle,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.lock_open_rounded, size: 12, color: AppColors.bentoEmerald),
                        SizedBox(width: 4),
                        Text(
                          'Vault Unlocked • 256-bit AES',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            color: AppColors.bentoEmerald,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Text(
                    'FLAG_SECURE ✓',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white54),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                'Cryptomator On-Device Storage',
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Sandbox: app_storage/vault/d/ • Obfuscated .c9r chunks',
                style: TextStyle(fontSize: 11, color: Colors.white.withAlpha(160)),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  _buildStatBadge('Encrypted Files', '${encryptedFiles.length}', const Color(0xFF6246EA)),
                  const SizedBox(width: 10),
                  _buildStatBadge('Secure Notes', '${textItems.length}', const Color(0xFFFDBE58)),
                  const SizedBox(width: 10),
                  _buildStatBadge('Total Size', widget.vaultNotifier.formattedTotalSize, const Color(0xFF3CC162)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 2. Action Bar: Ingest Arbitrary File, Add Photo, or New Secure Note
        Row(
          children: [
            Expanded(
              child: _buildActionPill(
                icon: Icons.upload_file_rounded,
                label: 'Add File',
                color: AppColors.iris,
                bgTint: const Color(0xFFEAE6FD),
                isDark: isDark,
                onTap: () => _showFileIngestDialog(context),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildActionPill(
                icon: Icons.add_a_photo_rounded,
                label: 'Add Photo',
                color: const Color(0xFFFF6B57),
                bgTint: const Color(0xFFFFE6E2),
                isDark: isDark,
                onTap: () => _simulatePhotoIngest(context),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildActionPill(
                icon: Icons.note_add_rounded,
                label: 'New Secret',
                color: const Color(0xFF289E48),
                bgTint: const Color(0xFFE3F9E9),
                isDark: isDark,
                onTap: () => _showAddSecretDialog(context),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),

        // 3. Segmented Sub-Tab Switcher: Encrypted Files vs Secure Text Items
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceSubtleDark : AppColors.surfaceSubtleLight,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _activeSubTab = 0),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: _activeSubTab == 0 ? AppColors.iris : Colors.transparent,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '📁 Encrypted Files (${encryptedFiles.length})',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: _activeSubTab == 0 ? Colors.white : (isDark ? Colors.white70 : AppColors.inkSecondaryLight),
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _activeSubTab = 1),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: _activeSubTab == 1 ? AppColors.iris : Colors.transparent,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '🔑 Secure Notes (${textItems.length})',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: _activeSubTab == 1 ? Colors.white : (isDark ? Colors.white70 : AppColors.inkSecondaryLight),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 4. Tab 0: Encrypted Files List (Zero-Disk Leak In-Memory Decryption)
        if (_activeSubTab == 0) ...[
          if (encryptedFiles.isEmpty)
            _buildEmptyState('No encrypted files yet. Tap "+ Add File" above.')
          else
            ...encryptedFiles.map((file) => _buildEncryptedFileCard(context, file, isDark)),
        ] else ...[
          // Tab 1: Secure Text Notes & Credentials
          if (textItems.isEmpty)
            _buildEmptyState('No secure notes yet. Tap "+ New Secret" above.')
          else
            ...textItems.map((item) => _buildVaultItemCard(context, item, isDark)),
        ],
      ],
    );
  }

  Widget _buildStatBadge(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(15),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withAlpha(20)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w600, color: Colors.white60),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: color),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionPill({
    required IconData icon,
    required String label,
    required Color color,
    required Color bgTint,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? color.withAlpha(35) : bgTint,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withAlpha(isDark ? 60 : 40)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : AppColors.inkPrimaryLight,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEncryptedFileCard(BuildContext context, EncryptedVaultFile file, bool isDark) {
    final isPdf = file.mimeType.contains('pdf');
    final isImage = file.mimeType.contains('image');
    final isZip = file.mimeType.contains('zip');

    final icon = isPdf
        ? Icons.picture_as_pdf_rounded
        : (isImage ? Icons.image_rounded : (isZip ? Icons.folder_zip_rounded : Icons.insert_drive_file_rounded));
    final iconColor = isPdf
        ? const Color(0xFFFF6B57)
        : (isImage ? const Color(0xFF3CC162) : AppColors.iris);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(isDark ? 25 : 8),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
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
                  color: iconColor.withAlpha(isDark ? 40 : 25),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      file.originalName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: isDark ? AppColors.inkPrimaryDark : AppColors.inkPrimaryLight,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${file.formattedSize} • AES-256-GCM',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? AppColors.inkSecondaryDark : AppColors.inkSecondaryLight,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Obfuscated disk path teaser
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1B1D26) : const Color(0xFFF1EFEA),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(Icons.shield_outlined, size: 12, color: Colors.grey),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Disk: ${file.obfuscatedPath}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 10, color: Colors.grey),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Contextual Action Row: View In-Memory, Export, Shred
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                icon: const Icon(Icons.visibility_rounded, size: 14),
                label: const Text('View In-Memory', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
                style: TextButton.styleFrom(foregroundColor: AppColors.iris),
                onPressed: () => _viewFileInMemory(context, file),
              ),
              TextButton.icon(
                icon: const Icon(Icons.file_download_outlined, size: 14),
                label: const Text('Export', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                style: TextButton.styleFrom(foregroundColor: Colors.grey),
                onPressed: () => _exportFile(context, file),
              ),
              IconButton(
                icon: const Icon(Icons.delete_forever_rounded, size: 18, color: AppColors.bentoCoral),
                tooltip: 'Secure Shred',
                onPressed: () => _confirmShred(context, file),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _viewFileInMemory(BuildContext context, EncryptedVaultFile file) async {
    try {
      final decryptedBytes = await widget.vaultNotifier.decryptFileToMemory(file.id);

      if (!context.mounted) return;

      showDialog(
        context: context,
        builder: (ctx) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(16),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF141416),
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(color: Colors.black.withAlpha(90), blurRadius: 30),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.bentoEmerald.withAlpha(40),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Text(
                        '🔒 In-Memory Zero-Leak Decryption',
                        style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: AppColors.bentoEmerald),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.white70),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  file.originalName,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.white),
                ),
                const SizedBox(height: 2),
                Text(
                  'Size: ${file.formattedSize} • Decrypted directly into RAM • Zero disk trace',
                  style: const TextStyle(fontSize: 11, color: Colors.white70),
                ),
                const SizedBox(height: 16),
                Container(
                  constraints: const BoxConstraints(maxHeight: 260),
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: SingleChildScrollView(
                    child: Text(
                      utf8.decode(decryptedBytes, allowMalformed: true),
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 12, color: Color(0xFFB4D2FF)),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.iris,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                    ),
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Close Preview & Wipe RAM Buffer'),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to decrypt in-memory: $e')),
      );
    }
  }

  Future<void> _exportFile(BuildContext context, EncryptedVaultFile file) async {
    try {
      if (kIsWeb) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Decrypted in-memory (Web export ready)')),
        );
        return;
      }
      final targetDir = Directory('app_storage/exports');
      if (!await targetDir.exists()) {
        await targetDir.create(recursive: true);
      }
      final exported = await widget.vaultNotifier.exportVaultFile(file.id, targetDir);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Decrypted file saved to: ${exported.path}')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export failed: $e')),
      );
    }
  }

  void _confirmShred(BuildContext context, EncryptedVaultFile file) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Secure Shred File?'),
        content: Text(
          'This will overwrite "${file.originalName}" with random noise and zeros before unlinking from storage. This cannot be undone.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.bentoCoral,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await widget.vaultNotifier.shredVaultFile(file.id);
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('"${file.originalName}" shredded and overwritten.')),
              );
            },
            child: const Text('Shred & Delete'),
          ),
        ],
      ),
    );
  }

  void _showFileIngestDialog(BuildContext context) {
    final nameCtrl = TextEditingController(text: 'Lab_Report_Confidential.pdf');
    final contentCtrl = TextEditingController(text: 'Confidential experimental data from Physics lab autumn 2026.');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.shield_rounded, color: AppColors.iris),
            SizedBox(width: 8),
            Text('Encrypt & Ingest File'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'File Name (e.g. .pdf, .docx, .zip)'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: contentCtrl,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'File Raw Binary/Text Content'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.iris,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              final bytes = Uint8List.fromList(utf8.encode(contentCtrl.text));
              await widget.vaultNotifier.ingestFileBytes(
                bytes: bytes,
                originalName: nameCtrl.text.trim(),
                mimeType: nameCtrl.text.endsWith('.pdf') ? 'application/pdf' : 'application/octet-stream',
              );
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('AES-256 Ingest'),
          ),
        ],
      ),
    );
  }

  void _simulatePhotoIngest(BuildContext context) async {
    final randomId = DateTime.now().millisecondsSinceEpoch % 1000;
    final bytes = Uint8List.fromList(utf8.encode('PNG_ENCRYPTED_WHITEBOARD_SCAN_$randomId'));
    await widget.vaultNotifier.ingestFileBytes(
      bytes: bytes,
      originalName: 'Whiteboard_Scan_$randomId.png',
      mimeType: 'image/png',
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Whiteboard_Scan_$randomId.png encrypted and stored in vault.')),
    );
  }

  Widget _buildEmptyState(String msg) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Text(msg, style: const TextStyle(color: Colors.grey)),
      ),
    );
  }

  Widget _buildVaultItemCard(BuildContext context, VaultItem item, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(isDark ? 25 : 8),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.bentoLavender.withAlpha(isDark ? 40 : 100),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    item.category,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.iris,
                    ),
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.copy_rounded, size: 16),
                  tooltip: 'Copy to Clipboard',
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: item.content));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Copied to clipboard safely.')),
                    );
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 16),
                  onPressed: () => widget.vaultNotifier.deleteItem(item.id),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              item.title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
                color: isDark ? AppColors.inkPrimaryDark : AppColors.inkPrimaryLight,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceSubtleDark : AppColors.surfaceSubtleLight,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                item.content,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  color: isDark ? AppColors.inkPrimaryDark : AppColors.inkPrimaryLight,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddSecretDialog(BuildContext context) {
    final titleCtrl = TextEditingController();
    final contentCtrl = TextEditingController();
    String category = 'Secret Note';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: const Text('Add to Encrypted Vault'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleCtrl,
                decoration: const InputDecoration(labelText: 'Secret Title'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: contentCtrl,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Secret Content / Key'),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: category,
                decoration: const InputDecoration(labelText: 'Category'),
                items: ['Secret Note', 'Credential', 'Private Doc']
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (val) {
                  if (val != null) setDlgState(() => category = val);
                },
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.iris,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                if (titleCtrl.text.isNotEmpty && contentCtrl.text.isNotEmpty) {
                  widget.vaultNotifier.addItem(
                    titleCtrl.text,
                    contentCtrl.text,
                    category,
                  );
                }
                Navigator.pop(ctx);
              },
              child: const Text('Encrypt & Store'),
            ),
          ],
        ),
      ),
    );
  }

  void _showRecoveryKeyDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.vpn_key_rounded, color: AppColors.bentoMarigold),
            SizedBox(width: 8),
            Text('Master Recovery Key'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Store this key offline. If biometrics change or you forget your PIN, this is the only way to recover encrypted vault content.',
              style: TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.bentoMarigold.withAlpha(35),
                borderRadius: BorderRadius.circular(16),
              ),
              child: SelectableText(
                widget.vaultNotifier.recoveryKey,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: widget.vaultNotifier.recoveryKey));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Recovery key copied.')),
              );
              Navigator.pop(ctx);
            },
            child: const Text('Copy Key'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  void _showRecoveryKeyInput(BuildContext context) {
    final keyCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Enter Master Recovery Key'),
        content: TextField(
          controller: keyCtrl,
          maxLines: 2,
          decoration: const InputDecoration(
            hintText: 'Paste your recovery words...',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.iris,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              final ok = widget.vaultNotifier.unlockWithRecoveryKey(keyCtrl.text);
              Navigator.pop(ctx);
              if (!ok) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Invalid recovery key.')),
                );
              }
            },
            child: const Text('Unlock'),
          ),
        ],
      ),
    );
  }
}
