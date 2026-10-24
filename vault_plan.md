# Encrypted Vault: Implementation Plan (Agent Prompt) · Task A

**Project:** All-Rounder (`srikar-up/all-rounder`, Flutter, Android first)
**Goal:** A locked, encrypted storage area inside the file manager. Files go in encrypted, stay encrypted on disk, and open only after fingerprint or passphrase unlock. Its encrypted files can later be uploaded to Google Drive without Drive ever seeing readable content.

> This is **Task A of two**. Task B is `google_integrations_plan.md` (Drive backup and health connection). The two can be built in parallel; read section 1 first.
> Execute phase by phase. After every phase run `flutter analyze` and `flutter test`; both must be clean. Commit after each phase.

---

## 0. Context the agent must know

- Read `lib/` first and follow its existing theme, navigation and state approach. If this plan conflicts with existing code, keep the existing pattern and report it.
- The file manager already hides the `vault/` folder from browsing, search and storage totals (see `file_manager_plan.md`). The vault is its own screen, reached from a "Vault" tile on the Files home.
- Follow `plan.md` and any rules in `.agents/skills/gravitas` if they apply.
- **Do not invent cryptography.** Use only the primitives named here, from the `cryptography` package. No custom ciphers, no home-made key derivation.
- Honest limits (put these in the in-app help text too): the vault protects files **at rest** on a locked or stolen phone and in the cloud. It does not protect against malware on an unlocked phone or a rooted device where the user is already logged in.

## 1. Parallel work contract (read before starting)

| Item | Owner | Rule |
|---|---|---|
| `lib/core/crypto/` (AEAD box, HKDF helper, Base32 recovery code) | **Task A (this file), Phase 1** | Task B uses it only after Phase 1 is merged. Do not change its public API without telling Task B. |
| `lib/core/backup/backup_source.dart` | Whoever starts first creates it **exactly as below** | Do not edit after creation without agreement. |
| `android/.../MainActivity.kt` | **Task A** | Must extend `FlutterFragmentActivity` (also needed by the health plugin). |
| `AndroidManifest.xml` | Shared | Task A adds `USE_BIOMETRIC` and `allowBackup="false"`; Task B adds Health Connect entries. Make small separate commits and rebase carefully. |
| `pubspec.yaml` | Shared | Each task adds only its own packages. Resolve conflicts by keeping both sets. |

```dart
// lib/core/backup/backup_source.dart
class BackupItem {
  const BackupItem({
    required this.id,        // stable, opaque, e.g. "vault/data/<uuid>.bin"
    required this.size,      // bytes that will be uploaded
    required this.sha256,    // hex SHA-256 of the bytes that will be uploaded
    required this.modified,
    required this.openRead,  // opens a fresh byte stream each call
  });
  final String id;
  final int size;
  final String sha256;
  final DateTime modified;
  final Stream<List<int>> Function() openRead;
}

abstract class BackupSource {
  Future<List<BackupItem>> listItems();
  /// Writes restored bytes to the item's place atomically (temp file, then rename).
  Future<void> restoreItem(String id, Stream<List<int>> bytes);
}
```

Task A implements `VaultBackupSource implements BackupSource` in Phase 6. It exposes **ciphertext only**; it never needs the vault to be unlocked.

---

## 2. Security design

### Keys

```
VMK (Vault Master Key, 32 random bytes)  ← never stored in plain form
 ├─ wrapped by passphrase KEK   = Argon2id(passphrase, salt)       → stored in vault.header
 ├─ wrapped by recovery KEK     = HKDF(recoveryKey, salt)          → stored in vault.header
 └─ copy in biometric-bound Android Keystore storage (device only) → NOT in vault.header, NOT backed up
File key  = HKDF(VMK, salt = fileId, info = "arv1/file")
Index key = HKDF(VMK, salt = 16 zero bytes, info = "arv1/index")
```

- **Cipher everywhere: XChaCha20-Poly1305** (`Xchacha20.poly1305Aead()`), which uses a 24-byte random nonce, so random nonces are safe.
- **Passphrase KDF: Argon2id**. Start from memory 19,456 KiB, iterations 2, parallelism 1, output 32 bytes. These values are stored in the header so they can be raised later. Benchmark on a mid-range phone and tune so unlock takes roughly one second. Run Argon2id in `Isolate.run`, never on the UI thread.
- **Recovery key:** 32 random bytes shown once as Base32 (RFC 4648 alphabet, no padding) in groups of four characters. The user must confirm they saved it (ask them to re-type the last group).
- **Lost passphrase and lost recovery key means the data is gone.** Say so plainly at setup.

### On-disk layout

```
vault/
  vault.header        # JSON, see below
  index.enc           # encrypted JSON: folders and file names, sizes, mime types
  index.enc.bak       # previous index, kept for crash recovery
  data/<uuid>.bin     # one encrypted blob per file; the name reveals nothing
```

`vault.header`:

```json
{
  "format": "all-rounder-vault",
  "version": 1,
  "kdfParams": "{\"alg\":\"argon2id\",\"memoryKiB\":19456,\"iterations\":2,\"parallelism\":1,\"salt\":\"<b64>\"}",
  "wrapPassphrase": "<b64 sealed VMK>",
  "wrapRecovery": "<b64 sealed VMK>",
  "recoverySalt": "<b64>"
}
```

Both wraps are sealed with AAD = `utf8("ARV1|") + utf8(kdfParams)` so any header tampering fails authentication. The `kdfParams` string is stored and used verbatim, never re-serialised.

### Blob format (`data/<uuid>.bin`)

```
"ARV1" (4 bytes) | fileId (16 bytes) | repeated chunks: [length u32 BE][sealed chunk]
sealed chunk = nonce(24) | ciphertext | tag(16)        chunk plaintext size ≤ 64 KiB
AAD per chunk = "ARV1" | fileId | chunkIndex u64 BE | isLast (1 byte)
```

This detects modified chunks, reordered chunks, truncation (the last-chunk flag will not match) and swapping a chunk in from another file. An empty file is one empty chunk marked last.

### Plaintext-exposure rules

- Prefer viewing images **from memory** (`Image.memory`), with a size cap (for example 25 MB).
- Anything else is decrypted to `<temp>/vault_tmp/` only for **Export / Share**, then deleted. Wipe `vault_tmp` on lock and on every app start.
- "Move to vault" **permanently deletes** the original after the encrypted copy is verified. Do **not** send it to the file-manager trash, because the trash would keep a readable copy. Tell the user that flash storage cannot guarantee a secure wipe.
- Block screenshots and the recent-apps preview on all vault screens (`FLAG_SECURE`, Phase 3).
- Never log filenames, keys or passphrases. Strip them from error messages.

---

## Phase 1: Crypto core (pure Dart, test-first)

```bash
flutter pub add cryptography crypto
flutter analyze
```

Add **no** other crypto package. Do not add `cryptography_flutter` (its native path does not mix well with background isolates).

```dart
// lib/core/crypto/aead_box.dart
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';

class VaultCryptoException implements Exception {
  const VaultCryptoException(this.message);
  final String message;
  @override
  String toString() => message;
}

class AeadBox {
  static const nonceLength = 24;
  static const tagLength = 16;
  static final _cipher = Xchacha20.poly1305Aead();

  /// Returns nonce(24) | ciphertext | tag(16).
  static Future<Uint8List> seal(List<int> key, List<int> plain,
      {List<int> aad = const []}) async {
    final box = await _cipher.encrypt(plain, secretKey: SecretKey(key), aad: aad);
    return Uint8List.fromList([...box.nonce, ...box.cipherText, ...box.mac.bytes]);
  }

  static Future<Uint8List> open(List<int> key, List<int> sealed,
      {List<int> aad = const []}) async {
    if (sealed.length < nonceLength + tagLength) {
      throw const VaultCryptoException('Data is too short');
    }
    final nonce = sealed.sublist(0, nonceLength);
    final mac = Mac(sealed.sublist(sealed.length - tagLength));
    final cipherText = sealed.sublist(nonceLength, sealed.length - tagLength);
    try {
      final clear = await _cipher.decrypt(
        SecretBox(cipherText, nonce: nonce, mac: mac),
        secretKey: SecretKey(key),
        aad: aad,
      );
      return Uint8List.fromList(clear);
    } on SecretBoxAuthenticationError {
      throw const VaultCryptoException('Wrong key, or the data was modified');
    }
  }
}
```

```dart
// lib/core/crypto/kdf.dart
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';

class Kdf {
  static Future<Uint8List> hkdf(List<int> secret,
      {required List<int> salt, required String info}) async {
    final out = await Hkdf(hmac: Hmac.sha256(), outputLength: 32).deriveKey(
      secretKey: SecretKey(secret),
      nonce: salt,
      info: info.codeUnits,
    );
    return Uint8List.fromList(await out.extractBytes());
  }

  static Future<Uint8List> argon2id(String passphrase,
      {required List<int> salt,
      required int memoryKiB,
      required int iterations,
      required int parallelism}) async {
    final algo = Argon2id(
      memory: memoryKiB,
      iterations: iterations,
      parallelism: parallelism,
      hashLength: 32,
    );
    final key = await algo.deriveKeyFromPassword(password: passphrase, nonce: salt);
    return Uint8List.fromList(await key.extractBytes());
  }
}
```

Also create:

- `recovery_code.dart`: generate 32 random bytes (`Random.secure()`), encode and decode RFC 4648 Base32 by hand (about 30 lines, no package), with grouping, case-insensitive decode, and tolerance for spaces and dashes.
- `vault_file_crypto.dart`: `encryptFile` and `decryptToStream` implementing the blob format above. Read with a helper that loops until a chunk is full or EOF (a single `read` is not guaranteed to fill the buffer). Write to `<target>.tmp`, flush, close, then rename. On any error delete the temp file and rethrow. Use a one-chunk read-ahead so each chunk knows whether it is the last. When decrypting, a chunk is "last" when the file position equals the file length after reading it.

**Required tests** (use tiny Argon2 parameters through an injected `KdfParams.test`, so tests run fast):

- Seal and open round-trip for 0, 1, 1,000 and 1 MiB inputs; wrong key fails; flipped bit fails; wrong AAD fails; two seals of the same input differ.
- Blob: sizes 0, 1, 65,535, 65,536, 65,537 and about 5 MiB round-trip exactly.
- Blob tamper cases that **must throw**: modified byte in a chunk; chunks swapped; chunk removed from the middle; file truncated at a chunk boundary; extra bytes appended; header changed; blob renamed with a different `fileId`.
- Base32: round-trip 100 random keys; lowercase and spaced input decode; invalid characters rejected.
- A failed encryption leaves no `.tmp` file behind.

**Done when:** all of the above pass and analyze is clean. **Tell Task B that Phase 1 is merged.**

---

## Phase 2: Vault repository (pure Dart)

Create `lib/features/vault/` with these classes (no widget imports):

- `VaultHeader`: parse and write `vault.header`; reject unknown `version`.
- `VaultSession`: holds the VMK in memory (`Uint8List?`). `lock()` overwrites it with zeros, drops the reference, and clears the in-memory index. Be honest in a comment that Dart cannot guarantee memory wiping; this is best effort.
- `VaultRepository`:

| Method | Requirements |
|---|---|
| `create(passphrase)` | Generate VMK, salt, recovery key; write header; create an empty index; return the recovery code once |
| `unlockWithPassphrase(p)` | Derive KEK in an isolate, open the wrap, load the index; wrong passphrase gives a clean error |
| `unlockWithRecoveryCode(code)` | Same via the recovery wrap |
| `unlockWithVmk(bytes)` | Used by the biometric path |
| `addFile(File source, {folderId})` | Encrypt to `data/<uuid>.bin`, **verify by decrypting the first and last chunks**, update the index atomically |
| `readBytes(id, {maxBytes})` | Decrypt into memory, refuse above the cap |
| `exportTo(id, File target)` | Decrypt to a temp file, then rename |
| `rename`, `move`, `createFolder`, `delete` | Index updates; delete removes the blob and then the index entry |
| `changePassphrase(old, new)` | Rewrap the VMK only; **never** re-encrypt files |
| `regenerateRecoveryCode()` | New recovery wrap; return the new code once |
| `wipeTemp()` | Delete `vault_tmp` |

Index rules: write `index.enc.tmp`, rename the current index to `index.enc.bak`, then rename the tmp to `index.enc`. On load, if `index.enc` fails to authenticate, try `.bak`. Delete leftover `.tmp` files on unlock. Blobs that exist on disk but not in the index are listed as "unrecognised" and never auto-deleted.

**Required tests** (temp directory, `KdfParams.test`): create then unlock with passphrase and with recovery code; wrong passphrase and wrong recovery code fail; add, read and export give identical bytes; delete removes the blob; change passphrase keeps every file readable and the old passphrase stops working; header tampering is detected; `lock()` makes every operation throw; a simulated crash between blob write and index write leaves a consistent vault; corrupt `index.enc` falls back to `.bak`.

**Done when:** tests pass and analyze is clean.

---

## Phase 3: Key protection, biometrics, auto-lock, screen security

```bash
flutter pub add flutter_secure_storage
```

1. **Biometric wrap.** Store the VMK (base64) in `FlutterSecureStorage` using the biometric Android options so the Keystore key requires fingerprint authentication:

```dart
final bioStorage = FlutterSecureStorage(
  aOptions: AndroidOptions.biometric(
    enforceBiometrics: true,
    biometricType: AndroidBiometricType.strongBiometricOnly,
    biometricPromptTitle: 'Unlock vault',
    biometricPromptNegativeButton: 'Use passphrase',
  ),
);
```

   Match the exact option names to the installed version of the package (read its README and let the analyzer guide you). Per the package docs, biometric enforcement needs a recent Android version (API 28 or higher). On older devices hide the biometric toggle and use the passphrase only.
2. **Failure handling.** If the read throws (user cancelled, key invalidated because fingerprints changed, no enrolled biometrics), fall back to the passphrase screen. After a successful passphrase unlock, offer to re-enable biometrics, which writes a fresh copy of the VMK.
3. **Rate limiting.** Count failed passphrase attempts in secure storage (non-biometric options). Delay after 3 failures: 1 s, 2 s, 4 s, and so on up to 5 minutes. Reset on success. State in a comment that this slows UI guessing only; offline guessing is limited by Argon2id and the passphrase strength.
4. **Passphrase rule.** At least 10 characters, with a visible strength hint and a recommendation of 14 or more. No extra package.
5. **Auto-lock.** A `WidgetsBindingObserver`: on `AppLifecycleState.paused` start a timer (setting: immediately, 30 s, 1 min, 5 min; default 30 s); on `resumed`, if the timer has elapsed, lock. Also lock when the screen turns off, and always call `wipeTemp()` on lock.
6. **Screen security** with a tiny platform channel. `MainActivity.kt` (keep your own package line):

```kotlin
import android.view.WindowManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "all_rounder/secure_screen")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "enable" -> { window.addFlags(WindowManager.LayoutParams.FLAG_SECURE); result.success(null) }
                    "disable" -> { window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE); result.success(null) }
                    else -> result.notImplemented()
                }
            }
    }
}
```

   On the Dart side wrap the calls in try/catch (`MissingPluginException` on iOS, tests and desktop) and enable on vault screen `initState`, disable on `dispose`.
7. **Manifest:** add `<uses-permission android:name="android.permission.USE_BIOMETRIC"/>` and set `android:allowBackup="false"` on `<application>` (Android's own backup could otherwise restore the vault without its biometric key and confuse the user).

**Tests:** unit-test the rate-limit schedule and the lock timer logic with a fake clock; wrap secure storage behind an interface so a fake can be used in tests.

**Done when:** on a real phone, fingerprint unlock works, cancelling falls back to the passphrase, a screenshot attempt on a vault screen is blocked, and backgrounding the app locks it after the chosen delay.

---

## Phase 4: Vault UI

Create `lib/features/vault/ui/`:

- `VaultGateScreen`: decides between Setup and Unlock based on whether `vault.header` exists.
- `VaultSetupScreen`: passphrase and confirm fields, the strength hint, the plain warning about lost keys, then `RecoveryKeyScreen` (shows the code, a copy button that clears the clipboard after 60 seconds, a confirmation step).
- `VaultUnlockScreen`: fingerprint button (prompts automatically once), passphrase field, "Use recovery key", clear errors, and the lockout countdown.
- `VaultHomeScreen`: folders and files like the file manager (list, sort by name or date, breadcrumb), "+" menu (Add files, New folder), a Lock button, and a settings sheet (auto-lock delay, biometric toggle, change passphrase, new recovery key).
- Opening a file: images in a zoomable in-memory viewer; every other type gets **Export / Share** with a clear note that this creates a temporary readable copy.

Rules: never put the passphrase in a route argument or log; dispose every controller; check `mounted` after every `await`; labelled icon buttons for TalkBack; busy indicators while Argon2id and encryption run; the screens are inside `FLAG_SECURE`.

**Done when:** analyze is clean and widget tests cover setup validation, wrong-passphrase error, lockout message, and that the lock button returns to the unlock screen.

---

## Phase 5: File manager integration

1. Add a **Vault** tile on the Files home that opens `VaultGateScreen`.
2. Add **Move to vault** to the file-manager selection bar. Flow: unlock (if locked), confirm dialog, encrypt each item, verify, permanently delete the original (not trash), show a summary. Folders are added file by file preserving structure.
3. In the vault, **Restore to files** exports to a chosen folder in the normal file manager (using the existing `FileService.importFile`).
4. Make sure vault contents never reach search, the notes index, the recent list or storage totals. Report the vault as a single "Vault: N MB" line in storage usage.

**Done when:** the full round trip works: move a note and an image into the vault, lock, unlock, restore both, and confirm contents are identical.

---

## Phase 6: Backup source for Task B

Implement `VaultBackupSource` (see the contract in section 1):

- `listItems()` returns `vault.header`, `index.enc` and every `data/*.bin`, with size, modified time and the **SHA-256 of the file bytes** (streamed through `crypto`'s `sha256`, cached by path, size and mtime so unchanged files are not re-hashed).
- Works while the vault is locked, because it reads ciphertext only.
- `restoreItem(id, bytes)` writes to a temp file, then renames. Reject any `id` that is not `vault/vault.header`, `vault/index.enc` or `vault/data/<uuid>.bin`, and reject path tricks.
- After a restore, the vault asks the user to unlock with the passphrase or recovery key. The biometric copy does not exist on the new phone, so offer to re-enable it after unlock.

**Tests:** list returns the right ids and matching hashes; restore into an empty directory produces a vault that unlocks with the passphrase and opens every file; invalid ids are rejected.

---

## Phase 7: Verification

```bash
flutter analyze
flutter test
flutter run
flutter build apk --release
```

### Manual test matrix (real Android phone)

| Case | Expected |
|---|---|
| Create a vault, save the recovery key | Header, index and empty `data/` created |
| Add 5 files (text, 5 MB image, 50 MB video, empty file, non-Latin filename) | All listed with correct names and sizes |
| Browse app storage with a file manager or `adb` | Only `.bin` blobs with random names; no readable content |
| Lock, then unlock by fingerprint | Works |
| Cancel the fingerprint prompt | Passphrase screen appears |
| Add a new fingerprint in system settings, then unlock | Biometric fails safely; passphrase works; biometric can be re-enabled |
| 5 wrong passphrases | Increasing delays, no crash |
| Forgot passphrase, use recovery key | Unlock works; prompted to set a new passphrase |
| Change passphrase | Old fails, new works, files intact |
| Move to vault from the file manager | Original gone, not in trash |
| Share a file from the vault | Temp copy removed afterwards; `vault_tmp` empty after lock |
| Screenshot or recent-apps on a vault screen | Blocked or blank |
| Background the app past the auto-lock delay | Returns to the unlock screen |
| Kill the app during a large add | Next launch is consistent; no half-written visible file |
| Flip one byte in a `.bin` file | That file fails with a clear message; others unaffected |
| Airplane mode | Everything works |
| Web or desktop run | Friendly "not supported" message, no exception |

## Known pitfalls

| Pitfall | What to do |
|---|---|
| Argon2id on the UI thread freezes the app | Always `Isolate.run` |
| Reading a whole large file into memory | Chunked streaming only; memory cap for in-app viewing |
| `RandomAccessFile.read` returning fewer bytes than asked | Use the fill-loop helper |
| Trash keeping plaintext | "Move to vault" deletes permanently |
| Biometric key invalidated by new fingerprints | Passphrase and recovery key are the real fallbacks |
| Android auto-backup restoring data without keys | `allowBackup="false"` |
| Clipboard retaining the recovery key | Auto-clear after 60 seconds |
| Package API names differ by version | Trust the analyzer and the installed README over this document's snippets |

## Out of scope for this task

Plausible-deniability or decoy vaults, multiple vaults, sharing vault files with other people, cloud key escrow, a custom Cryptomator-format reader, and secure-wipe guarantees. Add later as separate reviewed tasks.

## Definition of done

- [ ] All phases complete, one commit per phase
- [ ] `flutter analyze`: no issues
- [ ] `flutter test`: all passing, including every Phase 1 and 2 case
- [ ] `flutter build apk --release`: succeeds
- [ ] Manual matrix passed on a real Android device
- [ ] No custom crypto; only the primitives named in section 2
- [ ] No keys, passphrases or filenames in logs
- [ ] No `// ignore` comments added to hide warnings
- [ ] Task B informed when Phase 1 and Phase 6 are merged
- [ ] A short report of what changed, what was tested, and any deviation from this plan
