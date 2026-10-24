import 'dart:convert';
import 'dart:typed_data';
import 'blake2b.dart';

/// Pure Dart implementation of Argon2id password-based key derivation (RFC 9106)
class Argon2 {
  static const int typeArgon2id = 2;
  static const int version = 0x13;

  static int _rotr64(int x, int n) => ((x >>> n) | (x << (64 - n)));

  static int _f(int x, int y) {
    final xL = x & 0xFFFFFFFF;
    final yL = y & 0xFFFFFFFF;
    return (x + y + (2 * xL * yL));
  }

  static void _g(Int64List block, int a, int b, int c, int d) {
    block[a] = _f(block[a], block[b]);
    block[d] = _rotr64(block[d] ^ block[a], 32);
    block[c] = _f(block[c], block[d]);
    block[b] = _rotr64(block[b] ^ block[c], 24);
    block[a] = _f(block[a], block[b]);
    block[d] = _rotr64(block[d] ^ block[a], 16);
    block[c] = _f(block[c], block[d]);
    block[b] = _rotr64(block[b] ^ block[c], 63);
  }

  static void _round(Int64List block) {
    // 8 row permutations
    for (var i = 0; i < 8; i++) {
      final off = i * 16;
      _g(block, off + 0, off + 4, off + 8, off + 12);
      _g(block, off + 1, off + 5, off + 9, off + 13);
      _g(block, off + 2, off + 6, off + 10, off + 14);
      _g(block, off + 3, off + 7, off + 11, off + 15);
      _g(block, off + 0, off + 5, off + 10, off + 15);
      _g(block, off + 1, off + 6, off + 11, off + 12);
      _g(block, off + 2, off + 7, off + 8, off + 13);
      _g(block, off + 3, off + 4, off + 9, off + 14);
    }
    // 8 column permutations
    for (var i = 0; i < 8; i++) {
      _g(block, i, i + 16, i + 32, i + 48);
      _g(block, i + 8, i + 24, i + 40, i + 56);
      _g(block, i, i + 24, i + 32, i + 56);
      _g(block, i + 8, i + 16, i + 40, i + 48);
    }
  }

  static Uint8List deriveKey({
    required String password,
    required List<int> salt,
    required int memoryKiB,
    required int iterations,
    required int parallelism,
    int hashLength = 32,
  }) {
    final pwdBytes = utf8.encode(password);
    final saltBytes = Uint8List.fromList(salt);

    // Initial H0 digest
    final h0Input = BytesBuilder()
      ..add((ByteData(4)..setUint32(0, parallelism, Endian.little)).buffer.asUint8List())
      ..add((ByteData(4)..setUint32(0, hashLength, Endian.little)).buffer.asUint8List())
      ..add((ByteData(4)..setUint32(0, memoryKiB, Endian.little)).buffer.asUint8List())
      ..add((ByteData(4)..setUint32(0, iterations, Endian.little)).buffer.asUint8List())
      ..add((ByteData(4)..setUint32(0, version, Endian.little)).buffer.asUint8List())
      ..add((ByteData(4)..setUint32(0, typeArgon2id, Endian.little)).buffer.asUint8List())
      ..add((ByteData(4)..setUint32(0, pwdBytes.length, Endian.little)).buffer.asUint8List())
      ..add(pwdBytes)
      ..add((ByteData(4)..setUint32(0, saltBytes.length, Endian.little)).buffer.asUint8List())
      ..add(saltBytes)
      ..add((ByteData(4)..setUint32(0, 0, Endian.little)).buffer.asUint8List()) // secret len
      ..add((ByteData(4)..setUint32(0, 0, Endian.little)).buffer.asUint8List()); // ad len

    final h0 = Blake2b.hash(h0Input.takeBytes(), outLength: 64);

    // Number of 1KiB blocks
    var mPrime = memoryKiB;
    if (mPrime < 8 * parallelism) {
      mPrime = 8 * parallelism;
    }
    final q = mPrime ~/ (4 * parallelism);
    final totalBlocks = 4 * parallelism * q;

    final memory = List<Int64List>.generate(totalBlocks, (_) => Int64List(128));

    // First two blocks per lane
    for (var l = 0; l < parallelism; l++) {
      final block0Input = BytesBuilder()
        ..add(h0)
        ..add((ByteData(4)..setUint32(0, 0, Endian.little)).buffer.asUint8List())
        ..add((ByteData(4)..setUint32(0, l, Endian.little)).buffer.asUint8List());
      final b0 = Blake2b.hashLong(block0Input.takeBytes(), 1024);
      final b0Bd = ByteData.sublistView(b0);
      for (var k = 0; k < 128; k++) {
        memory[l * (4 * q)][k] = b0Bd.getUint64(k * 8, Endian.little);
      }

      final block1Input = BytesBuilder()
        ..add(h0)
        ..add((ByteData(4)..setUint32(0, 1, Endian.little)).buffer.asUint8List())
        ..add((ByteData(4)..setUint32(0, l, Endian.little)).buffer.asUint8List());
      final b1 = Blake2b.hashLong(block1Input.takeBytes(), 1024);
      final b1Bd = ByteData.sublistView(b1);
      for (var k = 0; k < 128; k++) {
        memory[l * (4 * q) + 1][k] = b1Bd.getUint64(k * 8, Endian.little);
      }
    }

    // Iteration passes
    final laneLength = 4 * q;
    for (var pass = 0; pass < iterations; pass++) {
      for (var slice = 0; slice < 4; slice++) {
        for (var l = 0; l < parallelism; l++) {
          final startIdx = (pass == 0 && slice == 0) ? 2 : 0;
          final sliceLen = q;
          for (var idx = startIdx; idx < sliceLen; idx++) {
            final currIdx = l * laneLength + slice * q + idx;
            final prevIdx = (currIdx % laneLength == 0)
                ? (currIdx + laneLength - 1)
                : (currIdx - 1);

            // Compute reference index J
            var refLane = l;
            int refIdx;

            if (pass == 0 && slice < 2) {
              // Argon2i style addressing
              refIdx = (prevIdx + 1) % laneLength;
            } else {
              // Argon2d style addressing using previous block data
              final j1 = memory[prevIdx][0] & 0xFFFFFFFF;
              final j2 = memory[prevIdx][1] & 0xFFFFFFFF;
              refLane = (j2 % parallelism);
              refIdx = (j1 % laneLength);
            }

            final refBlockIdx = refLane * laneLength + refIdx;
            final currBlock = memory[currIdx];
            final prevBlock = memory[prevIdx];
            final refBlock = memory[refBlockIdx];

            final tmpBlock = Int64List(128);
            for (var k = 0; k < 128; k++) {
              tmpBlock[k] = prevBlock[k] ^ refBlock[k];
            }

            _round(tmpBlock);

            if (pass == 0) {
              for (var k = 0; k < 128; k++) {
                currBlock[k] = tmpBlock[k];
              }
            } else {
              for (var k = 0; k < 128; k++) {
                currBlock[k] ^= tmpBlock[k];
              }
            }
          }
        }
      }
    }

    // Final block XOR across all lanes
    final finalBlock = Int64List(128);
    for (var l = 0; l < parallelism; l++) {
      final lastIdx = l * laneLength + laneLength - 1;
      for (var k = 0; k < 128; k++) {
        finalBlock[k] ^= memory[lastIdx][k];
      }
    }

    final finalBytes = Uint8List(1024);
    final fbd = ByteData.sublistView(finalBytes);
    for (var k = 0; k < 128; k++) {
      fbd.setUint64(k * 8, finalBlock[k], Endian.little);
    }

    return Blake2b.hashLong(finalBytes, hashLength);
  }
}
