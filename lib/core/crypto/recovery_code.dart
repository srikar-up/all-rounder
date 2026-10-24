import 'dart:math';
import 'dart:typed_data';

/// RFC 4648 Base32 encoder/decoder for 32-byte recovery keys grouped in 4-character blocks
class RecoveryCode {
  static const String alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';

  static Uint8List generateBytes([int length = 32]) {
    final rnd = Random.secure();
    final bytes = Uint8List(length);
    for (var i = 0; i < length; i++) {
      bytes[i] = rnd.nextInt(256);
    }
    return bytes;
  }

  /// Encodes [bytes] to RFC 4648 Base32 grouped by 4 characters with delimiter
  static String encode(List<int> bytes, {String delimiter = '-'}) {
    final sb = StringBuffer();
    var buffer = 0;
    var bitsLeft = 0;
    var charCount = 0;

    for (final b in bytes) {
      buffer = (buffer << 8) | (b & 0xFF);
      bitsLeft += 8;
      while (bitsLeft >= 5) {
        bitsLeft -= 5;
        final idx = (buffer >> bitsLeft) & 0x1F;
        if (charCount > 0 && charCount % 4 == 0) {
          sb.write(delimiter);
        }
        sb.write(alphabet[idx]);
        charCount++;
      }
    }

    if (bitsLeft > 0) {
      final idx = (buffer << (5 - bitsLeft)) & 0x1F;
      if (charCount > 0 && charCount % 4 == 0) {
        sb.write(delimiter);
      }
      sb.write(alphabet[idx]);
    }

    return sb.toString();
  }

  /// Decodes a grouped or raw Base32 string, tolerant of whitespace, dashes, and casing
  static Uint8List decode(String code) {
    final clean = code
        .replaceAll(RegExp(r'[\s\-_]+'), '')
        .toUpperCase();

    if (clean.isEmpty) return Uint8List(0);

    final out = <int>[];
    var buffer = 0;
    var bitsLeft = 0;

    for (var i = 0; i < clean.length; i++) {
      final char = clean[i];
      final val = alphabet.indexOf(char);
      if (val == -1) {
        throw FormatException('Invalid Base32 character: "$char"');
      }

      buffer = (buffer << 5) | val;
      bitsLeft += 5;

      if (bitsLeft >= 8) {
        bitsLeft -= 8;
        out.add((buffer >> bitsLeft) & 0xFF);
      }
    }

    return Uint8List.fromList(out);
  }
}
