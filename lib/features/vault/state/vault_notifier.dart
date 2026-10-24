import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import '../../../services/vault/vault_storage_service.dart';
import '../models/vault_models.dart';
import '../services/vault_crypto_service.dart';

class VaultNotifier extends ChangeNotifier {
  bool _isUnlocked = false;
  bool _isConfigured = true;
  String _passcode = '1234';
  String _recoveryKey = '';
  final List<VaultItem> _items = [];

  VaultNotifier() {
    _recoveryKey = VaultCryptoService.generateRecoveryKey();
    _initSeeds();
  }

  bool get isUnlocked => _isUnlocked;
  bool get isConfigured => _isConfigured;
  String get recoveryKey => _recoveryKey;
  List<VaultItem> get items => List.unmodifiable(_items);
  List<EncryptedVaultFile> get encryptedFiles => VaultStorageService.instance.files;

  int get totalEncryptedBytes =>
      encryptedFiles.fold<int>(0, (sum, f) => sum + f.fileSizeBytes);

  String get formattedTotalSize {
    final bytes = totalEncryptedBytes;
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Future<void> _initSeeds() async {
    await VaultStorageService.instance.initialize();
    _items.addAll([
      VaultItem(
        id: 'vault_1',
        title: 'Master Recovery Passphrase',
        content: 'Seed phrase: ocean drift echo velvet marble silver pulse quantum',
        category: 'Secret Note',
        createdAt: DateTime.now().subtract(const Duration(days: 10)),
        updatedAt: DateTime.now().subtract(const Duration(days: 10)),
      ),
      VaultItem(
        id: 'vault_2',
        title: 'Server SSH Credentials',
        content: 'Host: 192.168.1.100\nUser: admin\nKey: id_ed25519_vault',
        category: 'Credential',
        createdAt: DateTime.now().subtract(const Duration(days: 5)),
        updatedAt: DateTime.now().subtract(const Duration(days: 1)),
      ),
    ]);
    notifyListeners();
  }

  bool unlockWithPasscode(String entered) {
    if (entered == _passcode) {
      _isUnlocked = true;
      notifyListeners();
      return true;
    }
    return false;
  }

  bool unlockWithBiometrics() {
    // Simulates biometric prompt success
    _isUnlocked = true;
    notifyListeners();
    return true;
  }

  bool unlockWithRecoveryKey(String enteredKey) {
    if (enteredKey.trim().toLowerCase() == _recoveryKey.trim().toLowerCase()) {
      _isUnlocked = true;
      notifyListeners();
      return true;
    }
    return false;
  }

  void lock() {
    _isUnlocked = false;
    notifyListeners();
  }

  void setPasscode(String newPasscode) {
    _passcode = newPasscode;
    _isConfigured = true;
    notifyListeners();
  }

  void addItem(String title, String content, String category) {
    _items.insert(
      0,
      VaultItem(
        id: 'vault_${DateTime.now().millisecondsSinceEpoch}',
        title: title,
        content: content,
        category: category,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );
    notifyListeners();
  }

  void deleteItem(String id) {
    _items.removeWhere((i) => i.id == id);
    notifyListeners();
  }

  // --- Cryptomator Arbitrary File Storage APIs ---

  Future<EncryptedVaultFile> ingestFileBytes({
    required Uint8List bytes,
    required String originalName,
    required String mimeType,
  }) async {
    final item = await VaultStorageService.instance.encryptAndStoreBytes(
      bytes: bytes,
      originalName: originalName,
      mimeType: mimeType,
    );
    notifyListeners();
    return item;
  }

  Future<EncryptedVaultFile> ingestPhysicalFile(File file, {String? customName}) async {
    final item = await VaultStorageService.instance.encryptAndStoreFile(
      sourceFile: file,
      customName: customName,
    );
    notifyListeners();
    return item;
  }

  Future<Uint8List> decryptFileToMemory(String fileId) async {
    return VaultStorageService.instance.decryptToMemory(fileId);
  }

  Future<void> shredVaultFile(String fileId) async {
    await VaultStorageService.instance.shredFile(fileId);
    notifyListeners();
  }

  Future<File> exportVaultFile(String fileId, Directory targetDir) async {
    return VaultStorageService.instance.exportDecryptedFile(fileId, targetDir);
  }
}
