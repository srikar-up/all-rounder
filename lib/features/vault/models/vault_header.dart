import 'dart:convert';

class KdfParams {
  final String alg;
  final int memoryKiB;
  final int iterations;
  final int parallelism;
  final String salt;

  const KdfParams({
    this.alg = 'argon2id',
    this.memoryKiB = 19456,
    this.iterations = 2,
    this.parallelism = 1,
    required this.salt,
  });

  /// Fast parameters for unit tests
  static const test = KdfParams(
    alg: 'argon2id',
    memoryKiB: 64,
    iterations: 1,
    parallelism: 1,
    salt: 'dGVzdHNhbHR0ZXN0c2FsdA==',
  );

  Map<String, dynamic> toMap() => {
    'alg': alg,
    'memoryKiB': memoryKiB,
    'iterations': iterations,
    'parallelism': parallelism,
    'salt': salt,
  };

  factory KdfParams.fromMap(Map<String, dynamic> map) => KdfParams(
    alg: map['alg'] as String? ?? 'argon2id',
    memoryKiB: map['memoryKiB'] as int? ?? 19456,
    iterations: map['iterations'] as int? ?? 2,
    parallelism: map['parallelism'] as int? ?? 1,
    salt: map['salt'] as String,
  );

  String serialize() => jsonEncode(toMap());
}

class VaultHeader {
  static const String expectedFormat = 'all-rounder-vault';
  static const int currentVersion = 1;

  final String format;
  final int version;
  final String kdfParamsRaw;
  final String wrapPassphrase;
  final String wrapRecovery;
  final String recoverySalt;

  const VaultHeader({
    this.format = expectedFormat,
    this.version = currentVersion,
    required this.kdfParamsRaw,
    required this.wrapPassphrase,
    required this.wrapRecovery,
    required this.recoverySalt,
  });

  KdfParams get kdfParams => KdfParams.fromMap(jsonDecode(kdfParamsRaw));

  List<int> get aad => utf8.encode('ARV1|$kdfParamsRaw');

  Map<String, dynamic> toMap() => {
    'format': format,
    'version': version,
    'kdfParams': kdfParamsRaw,
    'wrapPassphrase': wrapPassphrase,
    'wrapRecovery': wrapRecovery,
    'recoverySalt': recoverySalt,
  };

  String serialize() => const JsonEncoder.withIndent('  ').convert(toMap());

  factory VaultHeader.fromJson(String jsonStr) {
    final map = jsonDecode(jsonStr) as Map<String, dynamic>;
    final format = map['format'] as String?;
    final version = map['version'] as int?;

    if (format != expectedFormat) {
      throw const FormatException('Unrecognised vault format');
    }
    if (version != currentVersion) {
      throw FormatException('Unsupported vault version: $version');
    }

    return VaultHeader(
      format: format!,
      version: version!,
      kdfParamsRaw: map['kdfParams'] as String,
      wrapPassphrase: map['wrapPassphrase'] as String,
      wrapRecovery: map['wrapRecovery'] as String,
      recoverySalt: map['recoverySalt'] as String,
    );
  }
}
