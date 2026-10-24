import 'dart:io';
import 'dart:typed_data';
import 'aead_box.dart';

class VaultFileCrypto {
  static const List<int> magicHeader = [0x41, 0x52, 0x56, 0x31]; // "ARV1"
  static const int chunkSize = 64 * 1024; // 64 KiB
  static const int fileIdLength = 16;

  /// Helper to read exactly [length] bytes or until EOF
  static Future<Uint8List> _readExact(RandomAccessFile raf, int length) async {
    final buffer = Uint8List(length);
    var totalRead = 0;
    while (totalRead < length) {
      final read = await raf.readInto(buffer, totalRead, length);
      if (read == 0) break;
      totalRead += read;
    }
    return (totalRead == length) ? buffer : Uint8List.sublistView(buffer, 0, totalRead);
  }

  /// Encrypts [source] to [target] atomically using ARV1 chunked format
  static Future<void> encryptFile({
    required File source,
    required File target,
    required Uint8List fileKey,
    required Uint8List fileId,
  }) async {
    assert(fileId.length == fileIdLength);
    final tmpFile = File('${target.path}.tmp');
    if (await tmpFile.exists()) {
      await tmpFile.delete();
    }

    RandomAccessFile? srcRaf;
    RandomAccessFile? dstRaf;

    try {
      srcRaf = await source.open(mode: FileMode.read);
      dstRaf = await tmpFile.open(mode: FileMode.write);

      // Write "ARV1" (4 bytes) | fileId (16 bytes)
      await dstRaf.writeFrom(magicHeader);
      await dstRaf.writeFrom(fileId);

      var chunkIndex = 0;
      var currentChunk = await _readExact(srcRaf, chunkSize);

      while (true) {
        final nextChunk = await _readExact(srcRaf, chunkSize);
        final isLast = nextChunk.isEmpty;

        // AAD = "ARV1" | fileId | chunkIndex u64 BE | isLast (1 byte)
        final aad = BytesBuilder();
        aad.add(magicHeader);
        aad.add(fileId);
        final idxData = ByteData(8)..setUint64(0, chunkIndex, Endian.big);
        aad.add(idxData.buffer.asUint8List());
        aad.add([isLast ? 1 : 0]);

        final sealed = await AeadBox.seal(fileKey, currentChunk, aad: aad.takeBytes());

        // Write length u32 BE | sealed chunk
        final lenData = ByteData(4)..setUint32(0, sealed.length, Endian.big);
        await dstRaf.writeFrom(lenData.buffer.asUint8List());
        await dstRaf.writeFrom(sealed);

        if (isLast) break;

        currentChunk = nextChunk;
        chunkIndex++;
      }

      await dstRaf.flush();
      await dstRaf.close();
      dstRaf = null;

      await srcRaf.close();
      srcRaf = null;

      // Atomic rename
      await tmpFile.rename(target.path);
    } catch (e) {
      if (dstRaf != null) {
        try {
          await dstRaf.close();
        } catch (_) {}
      }
      if (srcRaf != null) {
        try {
          await srcRaf.close();
        } catch (_) {}
      }
      if (await tmpFile.exists()) {
        try {
          await tmpFile.delete();
        } catch (_) {}
      }
      rethrow;
    }
  }

  /// Decrypts [source] to a chunked byte stream with cryptographic authentication
  static Stream<List<int>> decryptToStream({
    required File source,
    required Uint8List fileKey,
    required Uint8List fileId,
  }) async* {
    assert(fileId.length == fileIdLength);
    final raf = await source.open(mode: FileMode.read);

    try {
      final fileLength = await raf.length();
      if (fileLength < magicHeader.length + fileIdLength) {
        throw const VaultCryptoException('Encrypted file is corrupt or truncated');
      }

      final header = await _readExact(raf, magicHeader.length);
      for (var i = 0; i < magicHeader.length; i++) {
        if (header[i] != magicHeader[i]) {
          throw const VaultCryptoException('Invalid file format header');
        }
      }

      final storedFileId = await _readExact(raf, fileIdLength);
      var idMismatch = false;
      for (var i = 0; i < fileIdLength; i++) {
        if (storedFileId[i] != fileId[i]) {
          idMismatch = true;
          break;
        }
      }
      if (idMismatch) {
        throw const VaultCryptoException('File ID mismatch or tampered blob');
      }

      var chunkIndex = 0;
      var foundLast = false;

      while (await raf.position() < fileLength) {
        final lenBytes = await _readExact(raf, 4);
        if (lenBytes.length < 4) {
          throw const VaultCryptoException('Truncated chunk header');
        }
        final chunkLen = ByteData.sublistView(lenBytes).getUint32(0, Endian.big);

        final sealed = await _readExact(raf, chunkLen);
        if (sealed.length < chunkLen) {
          throw const VaultCryptoException('Truncated chunk payload');
        }

        final pos = await raf.position();
        final isLast = (pos == fileLength);

        if (foundLast) {
          throw const VaultCryptoException('Extra data after final chunk');
        }

        // AAD = "ARV1" | fileId | chunkIndex u64 BE | isLast (1 byte)
        final aad = BytesBuilder();
        aad.add(magicHeader);
        aad.add(fileId);
        final idxData = ByteData(8)..setUint64(0, chunkIndex, Endian.big);
        aad.add(idxData.buffer.asUint8List());
        aad.add([isLast ? 1 : 0]);

        final plain = await AeadBox.open(fileKey, sealed, aad: aad.takeBytes());
        yield plain;

        if (isLast) {
          foundLast = true;
        }
        chunkIndex++;
      }

      if (!foundLast) {
        throw const VaultCryptoException('File ended before last chunk marker');
      }
    } finally {
      await raf.close();
    }
  }
}
