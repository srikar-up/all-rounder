import 'dart:typed_data';
import '../models/vault_index.dart';

class VaultSession {
  Uint8List? _vmk;
  VaultIndex _index = const VaultIndex();

  bool get isUnlocked => _vmk != null;

  Uint8List get vmk {
    if (_vmk == null) {
      throw StateError('Vault is locked. Unlock before accessing master key.');
    }
    return _vmk!;
  }

  VaultIndex get index => _index;

  void setUnlocked(Uint8List masterKey, VaultIndex loadedIndex) {
    _vmk = Uint8List.fromList(masterKey);
    _index = loadedIndex;
  }

  void updateIndex(VaultIndex newIndex) {
    if (!isUnlocked) {
      throw StateError('Cannot update index while vault is locked.');
    }
    _index = newIndex;
  }

  /// Locks the vault session and wipes key from memory.
  /// NOTE: While Dart's garbage collector and memory layout cannot strictly guarantee
  /// immediate physical zeroing in RAM, we explicitly overwrite the buffer with zeros
  /// as a best-effort defense-in-depth measure before dropping the reference.
  void lock() {
    if (_vmk != null) {
      _vmk!.fillRange(0, _vmk!.length, 0);
      _vmk = null;
    }
    _index = const VaultIndex();
  }
}
