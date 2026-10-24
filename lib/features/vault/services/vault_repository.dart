import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path/path.dart' as p;
import '../../../core/crypto/aead_box.dart';
import '../../../core/crypto/kdf.dart';
import '../../../core/crypto/recovery_code.dart';
import '../../../core/crypto/vault_file_crypto.dart';
import '../models/vault_header.dart';
import '../models/vault_index.dart';
import 'vault_session.dart';

class VaultRepository {
  static final Map<String, VaultRepository> _instances = {};

  factory VaultRepository(String rootPath, {KdfParams? customKdfParams}) {
    final norm = p.normalize(rootPath);
    if (customKdfParams != null) {
      return VaultRepository._internal(norm, customKdfParams: customKdfParams);
    }
    return _instances.putIfAbsent(norm, () => VaultRepository._internal(norm));
  }

  VaultRepository._internal(String rootPath, {this.customKdfParams})
      : vaultDir = Directory(p.normalize(p.join(rootPath, 'vault')));

  static void resetInstances() {
    _instances.clear();
  }

  final Directory vaultDir;
  final KdfParams? customKdfParams;
  final VaultSession session = VaultSession();

  File get _headerFile => File(p.join(vaultDir.path, 'vault.header'));
  File get _indexEncFile => File(p.join(vaultDir.path, 'index.enc'));
  File get _indexBakFile => File(p.join(vaultDir.path, 'index.enc.bak'));
  Directory get _dataDir => Directory(p.join(vaultDir.path, 'data'));
  Directory get _tempDir => Directory(p.join(vaultDir.path, 'vault_tmp'));

  bool get exists => _headerFile.existsSync();
  bool get isUnlocked => session.isUnlocked;
  VaultIndex get index => session.index;

  /// Creates a new vault, initializes vault.header, writes empty encrypted index,
  /// and returns the Base32 formatted recovery code.
  Future<String> create(String passphrase) async {
    if (await _headerFile.exists()) {
      throw const VaultCryptoException('Vault already exists');
    }

    await vaultDir.create(recursive: true);
    await _dataDir.create(recursive: true);
    await _tempDir.create(recursive: true);

    final vmk = RecoveryCode.generateBytes(32);
    final recoveryKeyBytes = RecoveryCode.generateBytes(32);
    final recoveryCode = RecoveryCode.encode(recoveryKeyBytes);

    final saltBytes = RecoveryCode.generateBytes(16);
    final saltB64 = base64Encode(saltBytes);

    final kdfParams = customKdfParams ?? KdfParams(salt: saltB64);
    final kdfParamsRaw = kdfParams.serialize();
    final headerAad = utf8.encode('ARV1|$kdfParamsRaw');

    // Derive passphrase KEK
    final passKek = await _derivePassphraseKek(passphrase, kdfParams);
    final wrapPassphraseBytes = await AeadBox.seal(passKek, vmk, aad: headerAad);

    // Derive recovery KEK
    final recoverySaltBytes = RecoveryCode.generateBytes(16);
    final recoveryKek = await Kdf.hkdf(
      recoveryKeyBytes,
      salt: recoverySaltBytes,
      info: 'arv1/recovery',
    );
    final wrapRecoveryBytes = await AeadBox.seal(recoveryKek, vmk, aad: headerAad);

    final header = VaultHeader(
      kdfParamsRaw: kdfParamsRaw,
      wrapPassphrase: base64Encode(wrapPassphraseBytes),
      wrapRecovery: base64Encode(wrapRecoveryBytes),
      recoverySalt: base64Encode(recoverySaltBytes),
    );

    await _headerFile.writeAsString(header.serialize());

    // Initialize session and write empty index
    session.setUnlocked(vmk, const VaultIndex());
    await _saveIndex(const VaultIndex());

    return recoveryCode;
  }

  /// Unlocks the vault using the user passphrase
  Future<void> unlockWithPassphrase(String passphrase) async {
    final header = await _readHeader();
    final headerAad = header.aad;
    final passKek = await _derivePassphraseKek(passphrase, header.kdfParams);

    Uint8List vmk;
    try {
      final sealedWrap = base64Decode(header.wrapPassphrase);
      vmk = await AeadBox.open(passKek, sealedWrap, aad: headerAad);
    } catch (_) {
      throw const VaultCryptoException('Incorrect passphrase');
    }

    await _loadVaultWithVmk(vmk);
  }

  /// Unlocks the vault using the Base32 recovery code
  Future<void> unlockWithRecoveryCode(String code) async {
    final header = await _readHeader();
    final headerAad = header.aad;

    Uint8List recoveryKeyBytes;
    try {
      recoveryKeyBytes = RecoveryCode.decode(code);
    } catch (_) {
      throw const VaultCryptoException('Invalid recovery code format');
    }

    final recoverySalt = base64Decode(header.recoverySalt);
    final recoveryKek = await Kdf.hkdf(
      recoveryKeyBytes,
      salt: recoverySalt,
      info: 'arv1/recovery',
    );

    Uint8List vmk;
    try {
      final sealedWrap = base64Decode(header.wrapRecovery);
      vmk = await AeadBox.open(recoveryKek, sealedWrap, aad: headerAad);
    } catch (_) {
      throw const VaultCryptoException('Incorrect recovery code');
    }

    await _loadVaultWithVmk(vmk);
  }

  /// Direct VMK unlock used by biometric storage
  Future<void> unlockWithVmk(Uint8List vmk) async {
    await _loadVaultWithVmk(vmk);
  }

  /// Locks the vault session and wipes temporary files
  void lock() {
    session.lock();
    wipeTemp();
  }

  /// Adds a physical file into encrypted storage with atomic index update
  Future<VaultFileMetadata> addFile(File source, {String? folderId, String? customName}) async {
    _ensureUnlocked();
    if (!await source.exists()) {
      throw const VaultCryptoException('Source file does not exist');
    }

    final originalName = customName ?? p.basename(source.path);
    final fileId = RecoveryCode.generateBytes(16);
    final fileIdHex = fileId.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    final blobUuid = '${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(999999)}';
    final blobName = '$blobUuid.bin';
    final targetBlobFile = File(p.join(_dataDir.path, blobName));

    final fileKey = await _deriveFileKey(session.vmk, fileId);

    // 1. Encrypt file to data/<uuid>.bin
    await VaultFileCrypto.encryptFile(
      source: source,
      target: targetBlobFile,
      fileKey: fileKey,
      fileId: fileId,
    );

    // 2. Verify integrity by decrypting the first chunk
    try {
      await VaultFileCrypto.decryptToStream(
        source: targetBlobFile,
        fileKey: fileKey,
        fileId: fileId,
      ).first;
    } catch (e) {
      if (await targetBlobFile.exists()) {
        await targetBlobFile.delete();
      }
      throw VaultCryptoException('Encryption verification failed: $e');
    }

    // 3. Atomically update index
    final metadata = VaultFileMetadata(
      id: blobUuid,
      name: originalName,
      folderId: folderId,
      size: await source.length(),
      mimeType: _guessMimeType(originalName),
      modified: DateTime.now(),
      blobId: blobName,
      fileIdHex: fileIdHex,
    );

    final updatedFiles = List<VaultFileMetadata>.from(session.index.files)..add(metadata);
    final updatedIndex = session.index.copyWith(files: updatedFiles);
    await _saveIndex(updatedIndex);

    return metadata;
  }

  /// Creates a folder in the vault index
  Future<VaultFolder> createFolder(String name, {String? parentId}) async {
    _ensureUnlocked();
    final folderId = '${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(999999)}';
    final folder = VaultFolder(
      id: folderId,
      name: name,
      parentId: parentId,
    );
    final updatedFolders = List<VaultFolder>.from(session.index.folders)..add(folder);
    await _saveIndex(session.index.copyWith(folders: updatedFolders));
    return folder;
  }

  /// Reads decrypted file bytes into memory with a maximum safety cap (default 25 MB)
  Future<Uint8List> readBytes(String fileId, {int maxBytes = 25 * 1024 * 1024}) async {
    _ensureUnlocked();
    final meta = _findFile(fileId);
    if (meta.size > maxBytes) {
      throw const VaultCryptoException('File exceeds in-memory size cap');
    }

    final blobFile = File(p.join(_dataDir.path, meta.blobId));
    if (!await blobFile.exists()) {
      throw const VaultCryptoException('Encrypted blob missing on disk');
    }

    final fileIdBytes = _hexToBytes(meta.fileIdHex);
    final fileKey = await _deriveFileKey(session.vmk, fileIdBytes);

    final builder = BytesBuilder();
    await for (final chunk in VaultFileCrypto.decryptToStream(
      source: blobFile,
      fileKey: fileKey,
      fileId: fileIdBytes,
    )) {
      builder.add(chunk);
    }

    return builder.takeBytes();
  }

  /// Decrypts file to target physical destination atomically via temp file
  Future<void> exportTo(String fileId, File target) async {
    _ensureUnlocked();
    final meta = _findFile(fileId);
    final blobFile = File(p.join(_dataDir.path, meta.blobId));
    if (!await blobFile.exists()) {
      throw const VaultCryptoException('Encrypted blob missing on disk');
    }

    final fileIdBytes = _hexToBytes(meta.fileIdHex);
    final fileKey = await _deriveFileKey(session.vmk, fileIdBytes);

    await _tempDir.create(recursive: true);
    final tmpFile = File(p.join(_tempDir.path, '${p.basename(target.path)}.tmp'));
    if (await tmpFile.exists()) await tmpFile.delete();

    final raf = await tmpFile.open(mode: FileMode.write);
    try {
      await for (final chunk in VaultFileCrypto.decryptToStream(
        source: blobFile,
        fileKey: fileKey,
        fileId: fileIdBytes,
      )) {
        await raf.writeFrom(chunk);
      }
      await raf.flush();
      await raf.close();

      await tmpFile.rename(target.path);
    } catch (_) {
      try {
        await raf.close();
      } catch (_) {}
      if (await tmpFile.exists()) await tmpFile.delete();
      rethrow;
    }
  }


  /// Renames a file or folder in the index
  Future<void> renameItem(String id, String newName, {required bool isFolder}) async {
    _ensureUnlocked();
    if (isFolder) {
      final updated = session.index.folders.map((f) {
        return f.id == id ? VaultFolder(id: f.id, name: newName.trim(), parentId: f.parentId) : f;
      }).toList();
      await _saveIndex(session.index.copyWith(folders: updated));
    } else {
      final updated = session.index.files.map((f) {
        return f.id == id
            ? VaultFileMetadata(
                id: f.id,
                name: newName.trim(),
                folderId: f.folderId,
                size: f.size,
                mimeType: f.mimeType,
                modified: DateTime.now(),
                blobId: f.blobId,
                fileIdHex: f.fileIdHex,
              )
            : f;
      }).toList();
      await _saveIndex(session.index.copyWith(files: updated));
    }
  }

  /// Moves an item to another folder in the index
  Future<void> moveItem(String id, String? targetFolderId, {required bool isFolder}) async {
    _ensureUnlocked();
    if (isFolder) {
      final updated = session.index.folders.map((f) {
        return f.id == id ? VaultFolder(id: f.id, name: f.name, parentId: targetFolderId) : f;
      }).toList();
      await _saveIndex(session.index.copyWith(folders: updated));
    } else {
      final updated = session.index.files.map((f) {
        return f.id == id
            ? VaultFileMetadata(
                id: f.id,
                name: f.name,
                folderId: targetFolderId,
                size: f.size,
                mimeType: f.mimeType,
                modified: DateTime.now(),
                blobId: f.blobId,
                fileIdHex: f.fileIdHex,
              )
            : f;
      }).toList();
      await _saveIndex(session.index.copyWith(files: updated));
    }
  }

  /// Deletes an item from the vault. For files, immediately deletes the blob from disk.
  Future<void> deleteItem(String id, {required bool isFolder}) async {
    _ensureUnlocked();
    if (isFolder) {
      final updatedFolders = session.index.folders.where((f) => f.id != id).toList();
      await _saveIndex(session.index.copyWith(folders: updatedFolders));
    } else {
      final meta = session.index.files.firstWhere(
        (f) => f.id == id,
        orElse: () => throw const VaultCryptoException('Item not found'),
      );

      final blobFile = File(p.join(_dataDir.path, meta.blobId));
      if (await blobFile.exists()) {
        await blobFile.delete();
      }

      final updatedFiles = session.index.files.where((f) => f.id != id).toList();
      await _saveIndex(session.index.copyWith(files: updatedFiles));
    }
  }

  /// Changes the vault passphrase by rewrapping the VMK without re-encrypting files
  Future<void> changePassphrase(String oldPassphrase, String newPassphrase) async {
    _ensureUnlocked();
    final header = await _readHeader();
    final headerAad = header.aad;

    // Verify old passphrase derives the current VMK
    final oldKek = await _derivePassphraseKek(oldPassphrase, header.kdfParams);
    try {
      final sealed = base64Decode(header.wrapPassphrase);
      await AeadBox.open(oldKek, sealed, aad: headerAad);
    } catch (_) {
      throw const VaultCryptoException('Current passphrase is incorrect');
    }

    // Wrap with new passphrase
    final newKek = await _derivePassphraseKek(newPassphrase, header.kdfParams);
    final newWrap = await AeadBox.seal(newKek, session.vmk, aad: headerAad);

    final updatedHeader = VaultHeader(
      format: header.format,
      version: header.version,
      kdfParamsRaw: header.kdfParamsRaw,
      wrapPassphrase: base64Encode(newWrap),
      wrapRecovery: header.wrapRecovery,
      recoverySalt: header.recoverySalt,
    );

    await _headerFile.writeAsString(updatedHeader.serialize());
  }

  /// Generates a new recovery code and rewraps the VMK
  Future<String> regenerateRecoveryCode() async {
    _ensureUnlocked();
    final header = await _readHeader();
    final headerAad = header.aad;

    final newRecoveryKeyBytes = RecoveryCode.generateBytes(32);
    final newRecoveryCode = RecoveryCode.encode(newRecoveryKeyBytes);

    final newRecoverySalt = RecoveryCode.generateBytes(16);
    final recoveryKek = await Kdf.hkdf(
      newRecoveryKeyBytes,
      salt: newRecoverySalt,
      info: 'arv1/recovery',
    );
    final newRecoveryWrap = await AeadBox.seal(recoveryKek, session.vmk, aad: headerAad);

    final updatedHeader = VaultHeader(
      format: header.format,
      version: header.version,
      kdfParamsRaw: header.kdfParamsRaw,
      wrapPassphrase: header.wrapPassphrase,
      wrapRecovery: base64Encode(newRecoveryWrap),
      recoverySalt: base64Encode(newRecoverySalt),
    );

    await _headerFile.writeAsString(updatedHeader.serialize());
    return newRecoveryCode;
  }

  /// Wipes the temporary plaintext directory
  void wipeTemp() {
    if (_tempDir.existsSync()) {
      try {
        _tempDir.deleteSync(recursive: true);
      } catch (_) {}
    }
  }

  // --- Internal Helpers ---

  void _ensureUnlocked() {
    if (!isUnlocked) {
      throw const VaultCryptoException('Vault is locked. Unlock required.');
    }
  }

  VaultFileMetadata _findFile(String fileId) {
    return session.index.files.firstWhere(
      (f) => f.id == fileId,
      orElse: () => throw const VaultCryptoException('File not found in vault index'),
    );
  }

  Future<VaultHeader> _readHeader() async {
    if (!await _headerFile.exists()) {
      throw const VaultCryptoException('Vault header not found. Setup required.');
    }
    return VaultHeader.fromJson(await _headerFile.readAsString());
  }

  Future<void> _loadVaultWithVmk(Uint8List vmk) async {
    final indexKey = await _deriveIndexKey(vmk);
    VaultIndex loadedIndex = const VaultIndex();

    // 1. Try primary index.enc
    if (await _indexEncFile.exists()) {
      try {
        final sealed = await _indexEncFile.readAsBytes();
        final clearBytes = await AeadBox.open(indexKey, sealed, aad: utf8.encode('arv1/index'));
        loadedIndex = VaultIndex.fromJson(utf8.decode(clearBytes));
      } catch (_) {
        // 2. Fall back to index.enc.bak
        if (await _indexBakFile.exists()) {
          final sealedBak = await _indexBakFile.readAsBytes();
          final clearBytes = await AeadBox.open(indexKey, sealedBak, aad: utf8.encode('arv1/index'));
          loadedIndex = VaultIndex.fromJson(utf8.decode(clearBytes));
        } else {
          throw const VaultCryptoException('Vault index corrupted and no backup found');
        }
      }
    }

    session.setUnlocked(vmk, loadedIndex);

    // Clean up temporary files on unlock
    _cleanTempFiles();
  }

  Future<void> _saveIndex(VaultIndex newIndex) async {
    final indexKey = await _deriveIndexKey(session.vmk);
    final plainBytes = utf8.encode(newIndex.serialize());
    final sealed = await AeadBox.seal(indexKey, plainBytes, aad: utf8.encode('arv1/index'));

    final tmpFile = File('${_indexEncFile.path}.tmp');
    await tmpFile.writeAsBytes(sealed, flush: true);

    if (await _indexEncFile.exists()) {
      if (await _indexBakFile.exists()) {
        await _indexBakFile.delete();
      }
      await _indexEncFile.rename(_indexBakFile.path);
    }

    await tmpFile.rename(_indexEncFile.path);
    session.updateIndex(newIndex);
  }

  void _cleanTempFiles() {
    if (vaultDir.existsSync()) {
      for (final entity in vaultDir.listSync()) {
        if (entity is File && entity.path.endsWith('.tmp')) {
          try {
            entity.deleteSync();
          } catch (_) {}
        }
      }
    }
  }

  static Future<Uint8List> _derivePassphraseKek(String passphrase, KdfParams params) async {
    final salt = base64Decode(params.salt);
    if (kIsWeb) {
      return Kdf.argon2id(
        passphrase,
        salt: salt,
        memoryKiB: params.memoryKiB,
        iterations: params.iterations,
        parallelism: params.parallelism,
      );
    }
    return Isolate.run(() => Kdf.argon2id(
      passphrase,
      salt: salt,
      memoryKiB: params.memoryKiB,
      iterations: params.iterations,
      parallelism: params.parallelism,
    ));
  }

  static Future<Uint8List> _deriveIndexKey(Uint8List vmk) async {
    final zeroSalt = Uint8List(16);
    return Kdf.hkdf(vmk, salt: zeroSalt, info: 'arv1/index');
  }

  static Future<Uint8List> _deriveFileKey(Uint8List vmk, Uint8List fileId) async {
    return Kdf.hkdf(vmk, salt: fileId, info: 'arv1/file');
  }

  static Uint8List _hexToBytes(String hex) {
    final result = Uint8List(hex.length ~/ 2);
    for (var i = 0; i < result.length; i++) {
      result[i] = int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16);
    }
    return result;
  }

  static String _guessMimeType(String name) {
    final ext = p.extension(name).toLowerCase();
    switch (ext) {
      case '.png': return 'image/png';
      case '.jpg':
      case '.jpeg': return 'image/jpeg';
      case '.pdf': return 'application/pdf';
      case '.txt': return 'text/plain';
      case '.md': return 'text/markdown';
      case '.html': return 'text/html';
      default: return 'application/octet-stream';
    }
  }
}
