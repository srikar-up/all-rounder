import 'dart:typed_data';

/// Pure Dart SHA-256, HMAC-SHA-256 and HKDF-SHA-256 (RFC 5869 / FIPS 180-4)
class Sha256 {
  static const List<int> _k = [
    0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5,
    0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
    0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3,
    0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
    0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc,
    0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
    0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7,
    0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
    0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13,
    0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
    0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3,
    0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
    0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5,
    0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
    0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208,
    0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2,
  ];

  static int _rotr(int x, int n) => ((x >>> n) | (x << (32 - n))) & 0xFFFFFFFF;

  static Uint8List digest(List<int> data) {
    final acc = Sha256Accumulator();
    acc.update(data);
    return acc.finish();
  }

  static Future<Uint8List> digestStream(Stream<List<int>> stream) async {
    final acc = Sha256Accumulator();
    await for (final chunk in stream) {
      acc.update(chunk);
    }
    return acc.finish();
  }

  static String hex(List<int> bytes) {
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  static Uint8List hmac(List<int> key, List<int> message) {
    var k = Uint8List.fromList(key);
    if (k.length > 64) {
      k = digest(k);
    }
    if (k.length < 64) {
      final paddedKey = Uint8List(64);
      paddedKey.setRange(0, k.length, k);
      k = paddedKey;
    }

    final ipad = Uint8List(64);
    final opad = Uint8List(64);
    for (var i = 0; i < 64; i++) {
      ipad[i] = k[i] ^ 0x36;
      opad[i] = k[i] ^ 0x5c;
    }

    final inner = digest([...ipad, ...message]);
    return digest([...opad, ...inner]);
  }

  /// HKDF-Extract and HKDF-Expand (RFC 5869)
  static Uint8List hkdf({
    required List<int> secret,
    required List<int> salt,
    required List<int> info,
    int length = 32,
  }) {
    // 1. Extract
    final actualSalt = salt.isEmpty ? Uint8List(32) : salt;
    final prk = hmac(actualSalt, secret);

    // 2. Expand
    final n = (length + 31) ~/ 32;
    final result = BytesBuilder();
    var t = <int>[];

    for (var i = 1; i <= n; i++) {
      t = hmac(prk, [...t, ...info, i]);
      result.add(t);
    }

    return Uint8List.sublistView(result.takeBytes(), 0, length);
  }
}

class Sha256Accumulator {
  var _h0 = 0x6a09e667;
  var _h1 = 0xbb67ae85;
  var _h2 = 0x3c6ef372;
  var _h3 = 0xa54ff53a;
  var _h4 = 0x510e527f;
  var _h5 = 0x9b05688c;
  var _h6 = 0x1f83d9ab;
  var _h7 = 0x5be0cd19;

  final Uint8List _buffer = Uint8List(64);
  int _bufferLen = 0;
  int _totalBytes = 0;
  final Int32List _w = Int32List(64);

  void update(List<int> chunk) {
    var offset = 0;
    while (offset < chunk.length) {
      final needed = 64 - _bufferLen;
      final available = chunk.length - offset;
      final toCopy = available < needed ? available : needed;
      _buffer.setRange(_bufferLen, _bufferLen + toCopy, chunk, offset);
      _bufferLen += toCopy;
      offset += toCopy;
      _totalBytes += toCopy;

      if (_bufferLen == 64) {
        _compress(_buffer, 0);
        _bufferLen = 0;
      }
    }
  }

  void _compress(Uint8List block, int blockOffset) {
    final byteData = ByteData.sublistView(block, blockOffset, blockOffset + 64);
    for (var t = 0; t < 16; t++) {
      _w[t] = byteData.getUint32(t * 4, Endian.big);
    }
    for (var t = 16; t < 64; t++) {
      final s0 = Sha256._rotr(_w[t - 15], 7) ^ Sha256._rotr(_w[t - 15], 18) ^ (_w[t - 15] >>> 3);
      final s1 = Sha256._rotr(_w[t - 2], 17) ^ Sha256._rotr(_w[t - 2], 19) ^ (_w[t - 2] >>> 10);
      _w[t] = (_w[t - 16] + s0 + _w[t - 7] + s1) & 0xFFFFFFFF;
    }

    var a = _h0;
    var b = _h1;
    var c = _h2;
    var d = _h3;
    var e = _h4;
    var f = _h5;
    var g = _h6;
    var h = _h7;

    for (var t = 0; t < 64; t++) {
      final s1 = Sha256._rotr(e, 6) ^ Sha256._rotr(e, 11) ^ Sha256._rotr(e, 25);
      final ch = (e & f) ^ ((~e) & g);
      final temp1 = (h + s1 + ch + Sha256._k[t] + _w[t]) & 0xFFFFFFFF;
      final s0 = Sha256._rotr(a, 2) ^ Sha256._rotr(a, 13) ^ Sha256._rotr(a, 22);
      final maj = (a & b) ^ (a & c) ^ (b & c);
      final temp2 = (s0 + maj) & 0xFFFFFFFF;

      h = g;
      g = f;
      f = e;
      e = (d + temp1) & 0xFFFFFFFF;
      d = c;
      c = b;
      b = a;
      a = (temp1 + temp2) & 0xFFFFFFFF;
    }

    _h0 = (_h0 + a) & 0xFFFFFFFF;
    _h1 = (_h1 + b) & 0xFFFFFFFF;
    _h2 = (_h2 + c) & 0xFFFFFFFF;
    _h3 = (_h3 + d) & 0xFFFFFFFF;
    _h4 = (_h4 + e) & 0xFFFFFFFF;
    _h5 = (_h5 + f) & 0xFFFFFFFF;
    _h6 = (_h6 + g) & 0xFFFFFFFF;
    _h7 = (_h7 + h) & 0xFFFFFFFF;
  }

  Uint8List finish() {
    final bitLength = _totalBytes * 8;
    _buffer[_bufferLen++] = 0x80;

    if (_bufferLen > 56) {
      _buffer.fillRange(_bufferLen, 64, 0);
      _compress(_buffer, 0);
      _bufferLen = 0;
    }

    _buffer.fillRange(_bufferLen, 56, 0);
    final byteData = ByteData.sublistView(_buffer);
    byteData.setUint64(56, bitLength, Endian.big);
    _compress(_buffer, 0);

    final out = Uint8List(32);
    final outView = ByteData.sublistView(out);
    outView.setUint32(0, _h0, Endian.big);
    outView.setUint32(4, _h1, Endian.big);
    outView.setUint32(8, _h2, Endian.big);
    outView.setUint32(12, _h3, Endian.big);
    outView.setUint32(16, _h4, Endian.big);
    outView.setUint32(20, _h5, Endian.big);
    outView.setUint32(24, _h6, Endian.big);
    outView.setUint32(28, _h7, Endian.big);
    return out;
  }


}
