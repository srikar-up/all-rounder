import 'dart:typed_data';

/// Pure Dart Blake2b (RFC 7693) for Argon2id and cryptographic hashing
class Blake2b {
  static final List<int> _iv = [
    BigInt.parse('6a09e667f3bcc908', radix: 16).toInt(),
    BigInt.parse('bb67ae8584caa73b', radix: 16).toInt(),
    BigInt.parse('3c6ef372fe94f82b', radix: 16).toInt(),
    BigInt.parse('a54ff53a5f1d36f1', radix: 16).toInt(),
    BigInt.parse('510e527fade682d1', radix: 16).toInt(),
    BigInt.parse('9b05688c2b3e6c1f', radix: 16).toInt(),
    BigInt.parse('1f83d9abfb41bd6b', radix: 16).toInt(),
    BigInt.parse('5be0cd19137e2179', radix: 16).toInt(),
  ];

  static const List<List<int>> _sigma = [
    [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15],
    [14, 10, 4, 8, 9, 15, 13, 6, 1, 12, 0, 2, 11, 7, 5, 3],
    [11, 8, 12, 0, 5, 2, 15, 13, 10, 14, 3, 6, 7, 1, 9, 4],
    [7, 9, 3, 1, 13, 12, 11, 14, 2, 6, 5, 10, 4, 0, 15, 8],
    [9, 0, 5, 7, 2, 4, 10, 15, 14, 1, 11, 12, 6, 8, 3, 13],
    [2, 12, 6, 10, 0, 11, 8, 3, 4, 13, 7, 5, 15, 14, 1, 9],
    [12, 5, 1, 15, 14, 13, 4, 10, 0, 7, 6, 3, 9, 2, 8, 11],
    [13, 11, 7, 14, 12, 1, 3, 9, 5, 0, 15, 4, 8, 6, 2, 10],
    [6, 15, 14, 9, 11, 3, 0, 8, 12, 2, 13, 7, 1, 4, 10, 5],
    [10, 2, 8, 4, 7, 6, 1, 5, 15, 11, 9, 14, 3, 12, 13, 0],
    [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15],
    [14, 10, 4, 8, 9, 15, 13, 6, 1, 12, 0, 2, 11, 7, 5, 3],
  ];

  static int _rotr64(int x, int n) => ((x >>> n) | (x << (64 - n)));

  /// Computes Blake2b hash of arbitrary output length up to 64 bytes
  static Uint8List hash(List<int> data, {int outLength = 32, List<int> key = const []}) {
    assert(outLength > 0 && outLength <= 64);
    assert(key.length <= 64);

    final h = Int64List.fromList(_iv);
    // XOR parameter block: outlen | keylen | fanout(1) | depth(1)
    h[0] ^= 0x01010000 ^ (key.length << 8) ^ outLength;

    final buf = Uint8List(128);
    var bufLen = 0;
    var t0 = 0;
    var t1 = 0;

    void compress(Uint8List block, bool isLast) {
      t0 = (t0 + block.length);
      final v = Int64List(16);
      for (var i = 0; i < 8; i++) {
        v[i] = h[i];
        v[i + 8] = _iv[i];
      }
      v[12] ^= t0;
      v[13] ^= t1;
      if (isLast) {
        v[14] ^= -1;
      }

      final m = Int64List(16);
      final bd = ByteData.sublistView(block);
      for (var i = 0; i < 16; i++) {
        m[i] = bd.getUint64(i * 8, Endian.little);
      }

      void g(int a, int b, int c, int d, int x, int y) {
        v[a] = (v[a] + v[b] + x);
        v[d] = _rotr64(v[d] ^ v[a], 32);
        v[c] = (v[c] + v[d]);
        v[b] = _rotr64(v[b] ^ v[c], 24);
        v[a] = (v[a] + v[b] + y);
        v[d] = _rotr64(v[d] ^ v[a], 16);
        v[c] = (v[c] + v[d]);
        v[b] = _rotr64(v[b] ^ v[c], 63);
      }

      for (var r = 0; r < 12; r++) {
        final s = _sigma[r];
        g(0, 4, 8, 12, m[s[0]], m[s[1]]);
        g(1, 5, 9, 13, m[s[2]], m[s[3]]);
        g(2, 6, 10, 14, m[s[4]], m[s[5]]);
        g(3, 7, 11, 15, m[s[6]], m[s[7]]);
        g(0, 5, 10, 15, m[s[8]], m[s[9]]);
        g(1, 6, 11, 12, m[s[10]], m[s[11]]);
        g(2, 7, 8, 13, m[s[12]], m[s[13]]);
        g(3, 4, 9, 14, m[s[14]], m[s[15]]);
      }

      for (var i = 0; i < 8; i++) {
        h[i] ^= v[i] ^ v[i + 8];
      }
    }

    if (key.isNotEmpty) {
      buf.setRange(0, key.length, key);
      bufLen = 128;
    }

    for (var i = 0; i < data.length; i++) {
      if (bufLen == 128) {
        compress(buf, false);
        buf.fillRange(0, 128, 0);
        bufLen = 0;
      }
      buf[bufLen++] = data[i];
    }

    // Final compression
    final lastBlock = Uint8List(bufLen);
    lastBlock.setRange(0, bufLen, buf);
    compress(buf, true);

    final out = Uint8List(64);
    final outBd = ByteData.sublistView(out);
    for (var i = 0; i < 8; i++) {
      outBd.setUint64(i * 8, h[i], Endian.little);
    }
    return Uint8List.sublistView(out, 0, outLength);
  }

  /// Variable-length Blake2b output generator for Argon2 H' function
  static Uint8List hashLong(List<int> input, int outLen) {
    if (outLen <= 64) {
      final prefix = ByteData(4)..setUint32(0, outLen, Endian.little);
      return hash([...prefix.buffer.asUint8List(), ...input], outLength: outLen);
    }

    final out = Uint8List(outLen);
    final r = (outLen + 31) ~/ 32 - 2;
    var v = hash(input, outLength: 64);
    out.setRange(0, 32, v);

    for (var i = 1; i <= r; i++) {
      v = hash(v, outLength: 64);
      final destOffset = i * 32;
      final copyLen = (destOffset + 32 <= outLen) ? 32 : (outLen - destOffset);
      out.setRange(destOffset, destOffset + copyLen, v);
    }

    final remaining = outLen - (r + 1) * 32;
    if (remaining > 0) {
      v = hash(v, outLength: remaining);
      out.setRange((r + 1) * 32, outLen, v);
    }

    return out;
  }
}
