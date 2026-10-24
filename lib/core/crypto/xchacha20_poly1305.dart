import 'dart:typed_data';

/// Pure Dart implementation of XChaCha20-Poly1305 Authenticated Encryption (RFC 8439 & draft-arciszewski-xchacha)
class XChaCha20Poly1305 {
  static const int nonceLength = 24;
  static const int tagLength = 16;

  static const List<int> _sigma = [
    0x61707865, 0x3320646e, 0x79622d32, 0x6b206574,
  ];

  static int _rotl32(int x, int n) => ((x << n) | (x >>> (32 - n))) & 0xFFFFFFFF;

  static void _quarterRound(Int32List s, int a, int b, int c, int d) {
    s[a] = (s[a] + s[b]) & 0xFFFFFFFF;
    s[d] = _rotl32(s[d] ^ s[a], 16);
    s[c] = (s[c] + s[d]) & 0xFFFFFFFF;
    s[b] = _rotl32(s[b] ^ s[c], 12);
    s[a] = (s[a] + s[b]) & 0xFFFFFFFF;
    s[d] = _rotl32(s[d] ^ s[a], 8);
    s[c] = (s[c] + s[d]) & 0xFFFFFFFF;
    s[b] = _rotl32(s[b] ^ s[c], 7);
  }

  /// HChaCha20 derives a 32-byte subkey from a 32-byte key and 16-byte nonce
  static Uint8List hchacha20(List<int> key, List<int> nonce16) {
    assert(key.length == 32);
    assert(nonce16.length == 16);

    final s = Int32List(16);
    s.setRange(0, 4, _sigma);

    final keyBd = ByteData.sublistView(Uint8List.fromList(key));
    for (var i = 0; i < 8; i++) {
      s[4 + i] = keyBd.getUint32(i * 4, Endian.little);
    }

    final nonceBd = ByteData.sublistView(Uint8List.fromList(nonce16));
    for (var i = 0; i < 4; i++) {
      s[12 + i] = nonceBd.getUint32(i * 4, Endian.little);
    }

    for (var r = 0; r < 10; r++) {
      // Column rounds
      _quarterRound(s, 0, 4, 8, 12);
      _quarterRound(s, 1, 5, 9, 13);
      _quarterRound(s, 2, 6, 10, 14);
      _quarterRound(s, 3, 7, 11, 15);
      // Diagonal rounds
      _quarterRound(s, 0, 5, 10, 15);
      _quarterRound(s, 1, 6, 11, 12);
      _quarterRound(s, 2, 7, 8, 13);
      _quarterRound(s, 3, 4, 9, 14);
    }

    final out = Uint8List(32);
    final outBd = ByteData.sublistView(out);
    for (var i = 0; i < 4; i++) {
      outBd.setUint32(i * 4, s[i], Endian.little);
    }
    for (var i = 0; i < 4; i++) {
      outBd.setUint32(16 + (i * 4), s[12 + i], Endian.little);
    }
    return out;
  }

  /// ChaCha20 block function generating 64 bytes of keystream
  static Uint8List chacha20Block(List<int> key, int counter, List<int> nonce12) {
    assert(key.length == 32);
    assert(nonce12.length == 12);

    final s = Int32List(16);
    s.setRange(0, 4, _sigma);

    final keyBd = ByteData.sublistView(Uint8List.fromList(key));
    for (var i = 0; i < 8; i++) {
      s[4 + i] = keyBd.getUint32(i * 4, Endian.little);
    }

    s[12] = counter & 0xFFFFFFFF;

    final nonceBd = ByteData.sublistView(Uint8List.fromList(nonce12));
    for (var i = 0; i < 3; i++) {
      s[13 + i] = nonceBd.getUint32(i * 4, Endian.little);
    }

    final working = Int32List.fromList(s);
    for (var r = 0; r < 10; r++) {
      _quarterRound(working, 0, 4, 8, 12);
      _quarterRound(working, 1, 5, 9, 13);
      _quarterRound(working, 2, 6, 10, 14);
      _quarterRound(working, 3, 7, 11, 15);
      _quarterRound(working, 0, 5, 10, 15);
      _quarterRound(working, 1, 6, 11, 12);
      _quarterRound(working, 2, 7, 8, 13);
      _quarterRound(working, 3, 4, 9, 14);
    }

    final out = Uint8List(64);
    final outBd = ByteData.sublistView(out);
    for (var i = 0; i < 16; i++) {
      outBd.setUint32(i * 4, (working[i] + s[i]) & 0xFFFFFFFF, Endian.little);
    }
    return out;
  }

  /// ChaCha20 stream cipher XOR
  static Uint8List chacha20Encrypt(List<int> key, int initialCounter, List<int> nonce12, List<int> input) {
    final output = Uint8List(input.length);
    var counter = initialCounter;
    var offset = 0;

    while (offset < input.length) {
      final block = chacha20Block(key, counter, nonce12);
      counter = (counter + 1) & 0xFFFFFFFF;
      final chunkSize = (offset + 64 <= input.length) ? 64 : (input.length - offset);
      for (var i = 0; i < chunkSize; i++) {
        output[offset + i] = input[offset + i] ^ block[i];
      }
      offset += chunkSize;
    }

    return output;
  }

  /// Poly1305 MAC (RFC 8439) evaluated modulo 2^130 - 5
  static Uint8List poly1305(List<int> key32, List<int> message) {
    assert(key32.length == 32);

    // Clamp r
    final rBytes = Uint8List.fromList(key32.sublist(0, 16));
    rBytes[3] &= 15;
    rBytes[7] &= 15;
    rBytes[11] &= 15;
    rBytes[15] &= 15;
    rBytes[4] &= 252;
    rBytes[8] &= 252;
    rBytes[12] &= 252;

    BigInt r = BigInt.zero;
    for (var i = 15; i >= 0; i--) {
      r = (r << 8) | BigInt.from(rBytes[i]);
    }

    BigInt s = BigInt.zero;
    for (var i = 31; i >= 16; i--) {
      s = (s << 8) | BigInt.from(key32[i]);
    }

    final p = (BigInt.one << 130) - BigInt.from(5);
    BigInt a = BigInt.zero;

    var offset = 0;
    while (offset < message.length) {
      final chunkSize = (offset + 16 <= message.length) ? 16 : (message.length - offset);
      BigInt n = BigInt.zero;
      for (var i = chunkSize - 1; i >= 0; i--) {
        n = (n << 8) | BigInt.from(message[offset + i]);
      }
      // Add high 1-bit
      n |= (BigInt.one << (chunkSize * 8));

      a = ((a + n) * r) % p;
      offset += chunkSize;
    }

    a = (a + s) % (BigInt.one << 128);

    final tag = Uint8List(16);
    for (var i = 0; i < 16; i++) {
      tag[i] = ((a >> (i * 8)) & BigInt.from(0xFF)).toInt();
    }
    return tag;
  }

  /// XChaCha20-Poly1305 Seal
  static Uint8List seal({
    required List<int> key,
    required List<int> nonce,
    required List<int> plaintext,
    List<int> aad = const [],
  }) {
    assert(key.length == 32);
    assert(nonce.length == 24);

    // 1. Derive subkey with HChaCha20
    final subkey = hchacha20(key, nonce.sublist(0, 16));

    // 2. Build 12-byte subnonce: 4 zero bytes + last 8 bytes of nonce
    final subnonce = Uint8List(12);
    subnonce.setRange(4, 12, nonce.sublist(16, 24));

    // 3. Generate Poly1305 one-time key from counter 0 block
    final firstBlock = chacha20Block(subkey, 0, subnonce);
    final polyKey = firstBlock.sublist(0, 32);

    // 4. Encrypt plaintext starting at counter 1
    final ciphertext = chacha20Encrypt(subkey, 1, subnonce, plaintext);

    // 5. Construct Poly1305 input:
    // AAD | pad16(AAD) | Ciphertext | pad16(Ciphertext) | len(AAD) u64 LE | len(Ciphertext) u64 LE
    final macData = BytesBuilder();
    macData.add(aad);
    final aadPad = (16 - (aad.length % 16)) % 16;
    if (aadPad > 0) macData.add(Uint8List(aadPad));

    macData.add(ciphertext);
    final ctPad = (16 - (ciphertext.length % 16)) % 16;
    if (ctPad > 0) macData.add(Uint8List(ctPad));

    final lens = ByteData(16);
    lens.setUint64(0, aad.length, Endian.little);
    lens.setUint64(8, ciphertext.length, Endian.little);
    macData.add(lens.buffer.asUint8List());

    final tag = poly1305(polyKey, macData.takeBytes());

    // 6. Return nonce(24) | ciphertext | tag(16)
    final result = Uint8List(nonceLength + ciphertext.length + tagLength);
    result.setRange(0, nonceLength, nonce);
    result.setRange(nonceLength, nonceLength + ciphertext.length, ciphertext);
    result.setRange(nonceLength + ciphertext.length, result.length, tag);
    return result;
  }

  /// XChaCha20-Poly1305 Open
  static Uint8List open({
    required List<int> key,
    required List<int> sealed,
    List<int> aad = const [],
  }) {
    if (sealed.length < nonceLength + tagLength) {
      throw const FormatException('Ciphertext is too short');
    }

    final nonce = sealed.sublist(0, nonceLength);
    final tag = sealed.sublist(sealed.length - tagLength);
    final ciphertext = sealed.sublist(nonceLength, sealed.length - tagLength);

    // 1. Derive subkey
    final subkey = hchacha20(key, nonce.sublist(0, 16));

    // 2. Build subnonce
    final subnonce = Uint8List(12);
    subnonce.setRange(4, 12, nonce.sublist(16, 24));

    // 3. Generate Poly1305 key
    final firstBlock = chacha20Block(subkey, 0, subnonce);
    final polyKey = firstBlock.sublist(0, 32);

    // 4. Construct Poly1305 input
    final macData = BytesBuilder();
    macData.add(aad);
    final aadPad = (16 - (aad.length % 16)) % 16;
    if (aadPad > 0) macData.add(Uint8List(aadPad));

    macData.add(ciphertext);
    final ctPad = (16 - (ciphertext.length % 16)) % 16;
    if (ctPad > 0) macData.add(Uint8List(ctPad));

    final lens = ByteData(16);
    lens.setUint64(0, aad.length, Endian.little);
    lens.setUint64(8, ciphertext.length, Endian.little);
    macData.add(lens.buffer.asUint8List());

    final expectedTag = poly1305(polyKey, macData.takeBytes());

    // Constant-time tag check
    var diff = 0;
    for (var i = 0; i < 16; i++) {
      diff |= tag[i] ^ expectedTag[i];
    }
    if (diff != 0) {
      throw const FormatException('Authentication tag mismatch');
    }

    // 5. Decrypt
    return chacha20Encrypt(subkey, 1, subnonce, ciphertext);
  }
}
