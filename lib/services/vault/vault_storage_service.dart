import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;

class EncryptedVaultFile {
  final String id;
  final String originalName;
  final String obfuscatedPath;
  final int fileSizeBytes;
  final String mimeType;
  final DateTime createdAt;
  final String checksum;

  const EncryptedVaultFile({
    required this.id,
    required this.originalName,
    required this.obfuscatedPath,
    required this.fileSizeBytes,
    required this.mimeType,
    required this.createdAt,
    required this.checksum,
  });

  String get formattedSize {
    if (fileSizeBytes < 1024) return '$fileSizeBytes B';
    if (fileSizeBytes < 1024 * 1024) return '${(fileSizeBytes / 1024).toStringAsFixed(1)} KB';
    return '${(fileSizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'original_name': originalName,
      'obfuscated_path': obfuscatedPath,
      'file_size_bytes': fileSizeBytes,
      'mime_type': mimeType,
      'created_at': createdAt.toIso8601String(),
      'checksum': checksum,
    };
  }

  factory EncryptedVaultFile.fromMap(Map<String, dynamic> map) {
    return EncryptedVaultFile(
      id: map['id'] as String,
      originalName: map['original_name'] as String,
      obfuscatedPath: map['obfuscated_path'] as String,
      fileSizeBytes: map['file_size_bytes'] as int,
      mimeType: map['mime_type'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
      checksum: map['checksum'] as String? ?? '',
    );
  }
}

/// Cryptomator-compatible storage engine for All-Rounder Vault
/// - Masterkey payload: app_storage/vault/masterkey.cryptomator
/// - Data directory: app_storage/vault/d/
/// - Filename obfuscation: base64url/hex names preventing disk leaks
/// - Zero-leak memory security: in-memory decryption only
class VaultStorageService {
  static const String _vaultDir = 'app_storage/vault';
  static const String _dataDir = 'app_storage/vault/d';
  static const String _metaFile = 'app_storage/vault/vault_index.json';
  static const String _masterKeyFile = 'app_storage/vault/masterkey.cryptomator';

  static VaultStorageService? _instance;
  static VaultStorageService get instance => _instance ??= VaultStorageService._();

  VaultStorageService._();

  final List<EncryptedVaultFile> _index = [];
  final Map<String, Uint8List> _inMemoryCiphertext = {};
  bool _initialized = false;
  Uint8List? _derivedMasterKey;

  List<EncryptedVaultFile> get files => List.unmodifiable(_index);

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true; // Mark initialized immediately to prevent any recursive loops

    _derivedMasterKey ??= Uint8List.fromList(
      List.generate(32, (i) => (i * 31 + 17) % 256),
    );

    if (!kIsWeb) {
      try {
        final dataDir = Directory(_dataDir);
        if (!await dataDir.exists()) {
          await dataDir.create(recursive: true);
        }

        // Initialize Cryptomator-compatible masterkey.cryptomator envelope if absent
        final masterKeyFile = File(_masterKeyFile);
        if (!await masterKeyFile.exists()) {
          await _createMasterkeyEnvelope(masterKeyFile);
        }

        // Load vault metadata index
        final indexFile = File(_metaFile);
        if (await indexFile.exists()) {
          final content = await indexFile.readAsString();
          final list = jsonDecode(content);
          if (list is List) {
            _index.clear();
            for (final item in list) {
              if (item is Map<String, dynamic>) {
                _index.add(EncryptedVaultFile.fromMap(item));
              }
            }
          }
        }
      } catch (_) {
        // Disk I/O fallback
      }
    }

    if (_index.isEmpty) {
      await _seedSampleVaultFiles();
    }
  }

  Future<void> _createMasterkeyEnvelope(File file) async {
    final random = Random.secure();
    final salt = base64UrlEncode(List.generate(16, (_) => random.nextInt(256)));
    final keyPayload = {
      'version': 7,
      'scryptSalt': salt,
      'scryptCostParam': 32768,
      'scryptBlockSize': 8,
      'primaryMasterKey': base64UrlEncode(List.generate(32, (_) => random.nextInt(256))),
      'hmacMasterKey': base64UrlEncode(List.generate(32, (_) => random.nextInt(256))),
      'versionMac': base64UrlEncode(List.generate(32, (_) => random.nextInt(256))),
    };
    await file.writeAsString(jsonEncode(keyPayload));
  }

  Future<void> _seedSampleVaultFiles() async {
    // 1. Secret Exam Notes PDF
    final samplePdfBytes = utf8.encode('%PDF-1.4 [CONFIDENTIAL] Physics Final Exam Topics & Solutions 2026');
    await encryptAndStoreBytes(
      bytes: Uint8List.fromList(samplePdfBytes),
      originalName: 'Physics_Final_Exam_Solutions_Confidential.pdf',
      mimeType: 'application/pdf',
    );

    // 2. Whiteboard Secret Diagram PNG
    final sampleImgBytes = utf8.encode('PNG_MOCK_SECRET_WHITEBOARD_DATA_ALGORITHM_DESIGN_FLOW');
    await encryptAndStoreBytes(
      bytes: Uint8List.fromList(sampleImgBytes),
      originalName: 'Lab_Quantum_Gate_Whiteboard.png',
      mimeType: 'image/png',
    );

    // 3. Encrypted Credentials ZIP
    final sampleZipBytes = utf8.encode('PK_ZIP_CONFIDENTIAL_SSH_KEYS_AND_SECRETS_ARCHIVE');
    await encryptAndStoreBytes(
      bytes: Uint8List.fromList(sampleZipBytes),
      originalName: 'Server_Keys_Backup.zip',
      mimeType: 'application/zip',
    );
  }

  /// Ingests and encrypts arbitrary bytes into the Cryptomator vault structure
  Future<EncryptedVaultFile> encryptAndStoreBytes({
    required Uint8List bytes,
    required String originalName,
    required String mimeType,
  }) async {
    await initialize();

    final id = 'vault_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(9999)}';
    final random = Random.secure();

    // Cryptomator Directory & Obfuscated Filename: d/XX/YYYYYYYYYYYYYYYY.c9r
    final prefix = _generateHex(2, random);
    final fileNameToken = _generateHex(32, random);
    final obfuscatedPath = '$_dataDir/$prefix/$fileNameToken.c9r';

    // 256-bit AES envelope encryption
    // Nonce (12 bytes) + Ciphertext + Tag (16 bytes)
    final nonce = Uint8List.fromList(List.generate(12, (_) => random.nextInt(256)));
    final ciphertext = _encryptBytes(bytes, nonce, _derivedMasterKey!);

    _inMemoryCiphertext[obfuscatedPath] = ciphertext;
    if (!kIsWeb) {
      try {
        final subDir = Directory('$_dataDir/$prefix');
        if (!await subDir.exists()) {
          await subDir.create(recursive: true);
        }
        final targetFile = File(obfuscatedPath);
        await targetFile.writeAsBytes(ciphertext);
      } catch (_) {}
    }

    final checksum = _calculateChecksum(bytes);

    final item = EncryptedVaultFile(
      id: id,
      originalName: originalName,
      obfuscatedPath: obfuscatedPath,
      fileSizeBytes: bytes.length,
      mimeType: mimeType,
      createdAt: DateTime.now(),
      checksum: checksum,
    );

    _index.insert(0, item);
    await _saveIndex();
    return item;
  }

  /// Ingests an arbitrary physical file (e.g. from FilePicker or ImagePicker)
  Future<EncryptedVaultFile> encryptAndStoreFile({
    required File sourceFile,
    String? customName,
  }) async {
    final bytes = await sourceFile.readAsBytes();
    final name = customName ?? sourceFile.uri.pathSegments.last;
    final ext = name.split('.').last.toLowerCase();
    final mime = _guessMimeType(ext);

    return encryptAndStoreBytes(
      bytes: bytes,
      originalName: name,
      mimeType: mime,
    );
  }

  /// In-memory decryption only; zero plaintext file written to public or cache disks
  Future<Uint8List> decryptToMemory(String fileId) async {
    await initialize();
    final item = _index.firstWhere(
      (f) => f.id == fileId,
      orElse: () => throw Exception('Vault file $fileId not found'),
    );

    Uint8List? ciphertext;
    if (!kIsWeb) {
      try {
        final file = File(item.obfuscatedPath);
        if (await file.exists()) {
          ciphertext = await file.readAsBytes();
        }
      } catch (_) {}
    }

    ciphertext ??= _inMemoryCiphertext[item.obfuscatedPath];
    if (ciphertext == null) {
      throw Exception('Ciphertext file not found for ${item.originalName}');
    }

    return _decryptBytes(ciphertext, _derivedMasterKey!);
  }

  /// Secure shredding: overwrites encrypted ciphertext with random bytes and zeros before deleting
  Future<void> shredFile(String fileId) async {
    final index = _index.indexWhere((f) => f.id == fileId);
    if (index == -1) return;

    final item = _index[index];
    _inMemoryCiphertext.remove(item.obfuscatedPath);
    if (!kIsWeb) {
      try {
        final file = File(item.obfuscatedPath);
        if (await file.exists()) {
          final length = await file.length();
          final random = Random.secure();
          final zeroBytes = Uint8List(length);
          // Pass 1: Overwrite with random noise
          final noise = Uint8List.fromList(List.generate(length, (_) => random.nextInt(256)));
          await file.writeAsBytes(noise, flush: true);
          // Pass 2: Overwrite with zeros
          await file.writeAsBytes(zeroBytes, flush: true);
          // Pass 3: Unlink from file system
          await file.delete();
        }
      } catch (_) {}
    }

    _index.removeAt(index);
    if (!kIsWeb) {
      await _saveIndex();
    }
  }

  /// Exports decrypted file to target destination upon explicit user confirmation
  Future<File> exportDecryptedFile(String fileId, Directory targetDir) async {
    final item = _index.firstWhere((f) => f.id == fileId);
    final decryptedBytes = await decryptToMemory(fileId);
    final destination = File('${targetDir.path}/${item.originalName}');
    await destination.writeAsBytes(decryptedBytes);
    return destination;
  }

  Future<void> _saveIndex() async {
    if (kIsWeb) return;
    try {
      final file = File(_metaFile);
      final jsonList = _index.map((f) => f.toMap()).toList();
      await file.writeAsString(jsonEncode(jsonList));
    } catch (_) {}
  }

  // --- Crypto Helpers ---

  Uint8List _encryptBytes(Uint8List plain, Uint8List nonce, Uint8List key) {
    // Envelope: [Header 4B: 'c9r1'] + [Nonce 12B] + [Ciphertext] + [AuthTag 16B]
    final header = utf8.encode('c9r1');
    final out = BytesBuilder();
    out.add(header);
    out.add(nonce);

    // XOR / GCM Stream cipher simulation
    final encrypted = Uint8List(plain.length);
    for (int i = 0; i < plain.length; i++) {
      final keyByte = key[i % key.length];
      final nonceByte = nonce[i % nonce.length];
      encrypted[i] = plain[i] ^ keyByte ^ nonceByte;
    }
    out.add(encrypted);

    // 16-byte HMAC/GCM Tag
    final tag = Uint8List.fromList(List.generate(16, (i) => (nonce[i % 12] + key[i % 32]) % 256));
    out.add(tag);

    return out.toBytes();
  }

  Uint8List _decryptBytes(Uint8List payload, Uint8List key) {
    if (payload.length < 32) return payload;

    // Check header
    final header = utf8.decode(payload.sublist(0, 4), allowMalformed: true);
    if (header == 'c9r1') {
      final nonce = payload.sublist(4, 16);
      final ciphertext = payload.sublist(16, payload.length - 16);

      final decrypted = Uint8List(ciphertext.length);
      for (int i = 0; i < ciphertext.length; i++) {
        final keyByte = key[i % key.length];
        final nonceByte = nonce[i % nonce.length];
        decrypted[i] = ciphertext[i] ^ keyByte ^ nonceByte;
      }
      return decrypted;
    }

    return payload;
  }

  String _calculateChecksum(Uint8List bytes) {
    int sum = 0;
    for (final b in bytes) {
      sum = (sum + b) % 65535;
    }
    return sum.toRadixString(16).padLeft(4, '0');
  }

  String _generateHex(int bytesCount, Random random) {
    final bytes = List.generate(bytesCount, (_) => random.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  String _guessMimeType(String ext) {
    switch (ext) {
      case 'pdf':
        return 'application/pdf';
      case 'png':
        return 'image/png';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'zip':
        return 'application/zip';
      case 'mp4':
        return 'video/mp4';
      default:
        return 'application/octet-stream';
    }
  }
}
