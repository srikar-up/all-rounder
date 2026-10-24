import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../core/crypto/recovery_code.dart';

abstract class KeyStorageBackend {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

class SecureKeyStorageBackend implements KeyStorageBackend {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  @override
  Future<String?> read(String key) async {
    try {
      return await _storage.read(key: key);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> write(String key, String value) async {
    await _storage.write(key: key, value: value);
  }

  @override
  Future<void> delete(String key) async {
    await _storage.delete(key: key);
  }
}

class InMemoryKeyStorageBackend implements KeyStorageBackend {
  final Map<String, String> _map = {};

  @override
  Future<String?> read(String key) async => _map[key];

  @override
  Future<void> write(String key, String value) async => _map[key] = value;

  @override
  Future<void> delete(String key) async => _map.remove(key);
}

class BackupKeyStore {
  BackupKeyStore([KeyStorageBackend? backend])
      : _backend = backend ?? SecureKeyStorageBackend();

  final KeyStorageBackend _backend;
  static const String _storageKey = 'all_rounder_backup_key_b64';

  Future<bool> hasKey() async {
    final val = await _backend.read(_storageKey);
    return val != null && val.isNotEmpty;
  }

  /// Creates a new 256-bit Backup Key, stores it, and returns the Base32 recovery code
  Future<String> createKey() async {
    final keyBytes = RecoveryCode.generateBytes(32);
    final b64 = base64Encode(keyBytes);
    await _backend.write(_storageKey, b64);
    return RecoveryCode.encode(keyBytes);
  }

  /// Imports an existing Base32 recovery code and saves it to secure storage
  Future<void> importRecoveryCode(String code) async {
    final keyBytes = RecoveryCode.decode(code);
    if (keyBytes.length != 32) {
      throw FormatException('Backup key must be 32 bytes (got ${keyBytes.length})');
    }
    final b64 = base64Encode(keyBytes);
    await _backend.write(_storageKey, b64);
  }

  /// Returns the current raw 32-byte key
  Future<Uint8List?> getKeyBytes() async {
    final b64 = await _backend.read(_storageKey);
    if (b64 == null || b64.isEmpty) return null;
    try {
      return base64Decode(b64);
    } catch (_) {
      return null;
    }
  }

  /// Returns the Base32 recovery code representation of the current key
  Future<String?> getRecoveryCode() async {
    final bytes = await getKeyBytes();
    if (bytes == null) return null;
    return RecoveryCode.encode(bytes);
  }

  /// Deletes the backup key from secure storage
  Future<void> deleteKey() async {
    await _backend.delete(_storageKey);
  }
}
