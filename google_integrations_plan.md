# Google Integrations: Implementation Plan (Agent Prompt) · Task B

**Project:** All-Rounder (`srikar-up/all-rounder`, Flutter, Android first)
**Goal:** (1) Optional Google Drive backup and restore that keeps the user's data private, and (2) a fitness connection that powers the daily exercise quota. One "Connected Services" screen shows and controls both.

> This is **Task B of two**. Task A is `vault_plan.md` (the encrypted vault). The two can be built in parallel; read section 1 first.
> Execute phase by phase. After every phase run `flutter analyze` and `flutter test`; both must be clean. Commit after each phase.

---

## 0. Context the agent must know

- Read `lib/` first and follow its existing theme, navigation and state approach. If this plan conflicts with existing code, keep the existing pattern and report it.
- Follow `plan.md` and any rules in `.agents/skills/gravitas` if they apply.
- **Google Fit is being shut down.** The Google Fit APIs are deprecated and only supported until the end of 2026, and the `health` Flutter package removed Fit support in version 11. **Do not integrate Google Fit.** Use **Health Connect** instead. It stores data on the device and needs no Google sign-in.
- Privacy promise of the app: no accounts, no tracking, no servers of ours. Google sign-in appears **only** when the user turns on Drive backup. Nothing is uploaded until the user taps "Back up now".
- Drive backup needs the network, so this task adds the `INTERNET` permission to the main manifest. This is a change from `html_rendering_plan.md`, which said not to add it. HTML notes still cannot reach the network, because their WebView has JavaScript off and a Content-Security-Policy.

## 1. Parallel work contract (read before starting)

| Item | Owner | Rule |
|---|---|---|
| `lib/core/crypto/` (`AeadBox`, `Kdf`, `RecoveryCode`) | Task A, Phase 1 | Task B uses it only **after** Task A reports Phase 1 merged. Until then do Phases 1 to 4 and 6 here. Do not change its API. |
| `lib/core/backup/backup_source.dart` | Whoever starts first creates it **exactly as in `vault_plan.md` section 1** | Do not edit after creation without agreement. |
| `VaultBackupSource` | Task A, Phase 6 | Task B plugs it into the backup engine in Phase 7. Use a fake until then. |
| `MainActivity.kt` | Task A | Must extend `FlutterFragmentActivity` (Task A does this; the health plugin needs it too). If Task A has not merged yet, make only that one-line change. |
| `AndroidManifest.xml` | Shared | Task B adds `INTERNET` and the Health Connect entries; Task A adds `USE_BIOMETRIC` and `allowBackup`. Small separate commits; rebase carefully. |
| `pubspec.yaml` | Shared | Each task adds only its own packages; on conflict keep both sets. |

---

## 2. Design summary

**Drive backup (one-way backup plus restore, not two-way sync)**

- Scope: only `https://www.googleapis.com/auth/drive.appdata`. This gives the app a hidden folder in the user's Drive that only this app can read, and it cannot see anything else. Google classes it as a non-sensitive scope; confirm that in the OAuth consent screen's scope list.
- What is uploaded:

| Source | Content on Drive | Encryption |
|---|---|---|
| **Vault** | Header, encrypted index and encrypted blobs, exactly as on disk | Already encrypted by Task A; uploaded unchanged |
| **Notes and attachments** (toggle, on by default) | Each file sealed with a **Backup Key** before upload | XChaCha20-Poly1305 through `AeadBox` |

- **Backup Key:** 32 random bytes, created at first backup setup, kept in `flutter_secure_storage` (default options, no biometric prompt, so backups can run without interruption), and shown **once** as a Base32 recovery code the user must save. Restoring on a new phone requires typing this code. Lost key means the notes backup cannot be read.
- **Remote file names** reveal nothing:
  - Vault items: `v-` plus the item id with `/` replaced by `~` (ids are already random).
  - Notes items: `n-` plus the first 32 hex characters of SHA-256 of the relative path, and one `n-manifest` file (sealed with the Backup Key) mapping those names to real paths, sizes and modified times.
- The app never deletes remote files automatically in v1. Removing the cloud backup is an explicit action.

**Health**

- `health` package reading from Health Connect: today's steps and today's exercise minutes against a goal stored in the app. There is no replacement for the Fit Goals API, so the goal is the app's own setting.
- Health Connect is a separate app on Android 13 and below, and built in from Android 14. Handle "not installed", "update needed", "permission denied" and "permission revoked" as visible states.

---

## Phase 0: Google Cloud and Play setup (done by the human, not the agent)

The agent cannot do these steps. It should print this checklist and wait for confirmation before testing sign-in.

1. Create a Google Cloud project and enable the **Google Drive API**.
2. Configure the **OAuth consent screen**. Add the `drive.appdata` scope.
   - While the app's publishing status is **Testing**, add your Google account as a test user. Note that in Testing mode Google expires authorizations after about 7 days, so expect to reconnect weekly until the app is published.
3. Create an **Android OAuth client** with the app's package name and the **SHA-1** of the debug keystore. Add a second one for the release keystore (and for the Play App Signing key if you publish on Play).
4. If sign-in later reports a configuration error on Android, also create a **Web application** OAuth client and pass its client id as `serverClientId` to `GoogleSignIn.instance.initialize(...)`. Follow the installed `google_sign_in` README for the current Android setup.
5. For Play release: declare Health Connect permissions in Play Console and provide a privacy policy URL.

---

## Phase 1: Dependencies and Android setup

```bash
flutter pub add google_sign_in googleapis http health permission_handler shared_preferences flutter_secure_storage crypto
flutter pub get
flutter analyze
```

- Skip any package that Task A already added. Add nothing else.
- `google_sign_in` is version 7 or newer. Its API changed in 7.0: you must call `GoogleSignIn.instance.initialize()` asynchronously once before anything else, sign-in (`authenticate`) and authorization of scopes (`authorizationClient`) are now separate steps. Do not copy older tutorials that use `GoogleSignIn().signIn()`.
- Manifest additions (keep it minimal; copy the exact current text from the installed `health` package README, since this can change):

```xml
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.ACTIVITY_RECOGNITION"/>
<uses-permission android:name="android.permission.health.READ_STEPS"/>
<uses-permission android:name="android.permission.health.READ_EXERCISE"/>

<queries>
  <package android:name="com.google.android.apps.healthdata"/>
  <intent><action android:name="androidx.health.ACTION_SHOW_PERMISSIONS_RATIONALE"/></intent>
</queries>

<!-- inside the existing MainActivity <activity> element -->
<intent-filter>
  <action android:name="androidx.health.ACTION_SHOW_PERMISSIONS_RATIONALE"/>
</intent-filter>

<!-- inside <application> -->
<activity-alias
    android:name="ViewPermissionUsageActivity"
    android:exported="true"
    android:targetActivity=".MainActivity"
    android:permission="android.permission.START_VIEW_PERMISSION_USAGE">
  <intent-filter>
    <action android:name="android.intent.action.VIEW_PERMISSION_USAGE"/>
    <category android:name="android.intent.category.HEALTH_PERMISSIONS"/>
  </intent-filter>
</activity-alias>
```

- Confirm `MainActivity` extends `FlutterFragmentActivity`.
- If the Android build asks for a higher `minSdkVersion`, raise it only to the value in the error message.

**Done when:** pub get, analyze and `flutter build apk --debug` succeed and the app still launches.

---

## Phase 2: Google account and Drive client

### 2.1 Account service

```dart
// lib/features/google/google_account_service.dart  (sketch; match the installed
// google_sign_in 7.x signatures, the analyzer is the source of truth)
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;

class GoogleAccountService {
  static const driveScopes = <String>[
    'https://www.googleapis.com/auth/drive.appdata',
  ];

  GoogleSignInAccount? _user;
  bool _initialized = false;
  GoogleSignInAccount? get user => _user;

  Future<void> init() async {
    if (_initialized) return;
    await GoogleSignIn.instance.initialize(); // add serverClientId only if required
    _initialized = true;
    // Silent restore of a previous session; returns null if none or unsupported.
    final pending = GoogleSignIn.instance.attemptLightweightAuthentication();
    _user = pending == null ? null : await pending;
  }

  /// Call from a button handler (needs a user gesture).
  Future<bool> connect() async {
    await init();
    try {
      _user = await GoogleSignIn.instance.authenticate(scopeHint: driveScopes);
      final auth = _user!.authorizationClient;
      final existing = await auth.authorizationForScopes(driveScopes);
      if (existing == null) await auth.authorizeScopes(driveScopes);
      return true;
    } on GoogleSignInException {
      return false; // cancelled or failed: show a friendly message, never crash
    }
  }

  /// Fresh headers for each batch of requests (access tokens expire after ~1 hour).
  Future<Map<String, String>?> headers() async {
    final u = _user;
    if (u == null) return null;
    return u.authorizationClient.authorizationHeaders(driveScopes);
  }

  Future<void> disconnect({bool revoke = false}) async {
    if (revoke) {
      await GoogleSignIn.instance.disconnect();
    } else {
      await GoogleSignIn.instance.signOut();
    }
    _user = null;
  }
}

class GoogleAuthClient extends http.BaseClient {
  GoogleAuthClient(this._headers);
  final Map<String, String> _headers;
  final http.Client _inner = http.Client();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.addAll(_headers);
    return _inner.send(request);
  }

  @override
  void close() {
    _inner.close();
    super.close();
  }
}
```

Rules: never log tokens or headers; every sign-in failure maps to a short user-facing message; the whole feature is skipped on web and desktop.

### 2.2 Remote store abstraction (so everything above it is testable)

```dart
abstract class RemoteStore {
  Future<Map<String, RemoteFile>> list();          // name -> file (newest wins on duplicates)
  Future<void> upload(String name, Stream<List<int>> bytes, int length,
      {String? existingId, Map<String, String>? properties});
  Future<Stream<List<int>>> download(String id);
  Future<void> delete(String id);
}
class RemoteFile {
  const RemoteFile({required this.id, required this.name, required this.size,
      required this.modified, required this.properties});
  final String id, name;
  final int size;
  final DateTime modified;
  final Map<String, String> properties;
}
```

### 2.3 Drive implementation (`DriveRemoteStore implements RemoteStore`)

Key points that cause real errors if missed:

- Every call uses the **appDataFolder** space:
  - list: `files.list(spaces: 'appDataFolder', q: "trashed = false", pageSize: 1000, pageToken: ..., $fields: 'nextPageToken, files(id, name, size, modifiedTime, appProperties)')`. **Loop on `nextPageToken`** until it is null.
  - create: set `file.parents = ['appDataFolder']`.
  - update: **do not set `parents`** on the metadata (Drive rejects it); pass the existing id to `files.update`.
- Upload with `drive.Media(stream, length)` and `uploadOptions: drive.ResumableUploadOptions()` for files above about 5 MB.
- Download with `downloadOptions: drive.DownloadOptions.fullMedia` and cast the result to `drive.Media`; stream it to a temp file, never into memory for vault blobs.
- Create a `GoogleAuthClient` per operation batch, close it in `finally`. On a 401, fetch fresh headers and retry **once**; if it fails again, report "Reconnect Google" to the UI.
- Retry helper with exponential backoff and jitter for: HTTP 429, any 5xx, 403 rate-limit reasons, `SocketException`, `TimeoutException`. Maximum 5 attempts. Do **not** retry 400, 404 or 403 `storageQuotaExceeded` (show the quota message instead).
- If the Drive API is not enabled in Cloud Console, Drive returns 403 "accessNotConfigured": map it to a developer-facing hint in debug builds and a generic "Backup is not available" message to users.

**Tests:** an in-memory `FakeRemoteStore` used by everything above; the retry helper with a fake clock (retries on 429 and 503, stops on 404, gives up after 5 attempts, never retries quota errors); duplicate-name handling (newest wins).

**Done when:** tests pass and, with Phase 0 complete, a debug build on a real phone can connect and perform one test upload and list.

---

## Phase 3: Backup engine

```dart
class BackupReport {
  int uploaded = 0, skipped = 0;
  final List<String> failed = [];   // opaque ids only, never filenames in logs
  bool cancelled = false;
}
class BackupProgress {
  const BackupProgress(this.done, this.total);
  final int done, total;
}
```

`BackupEngine(remote, sources, {backupCipher})`:

1. For each `BackupSource`, call `listItems()`.
2. `remote.list()` once.
3. For each item decide **skip or upload**:
   - Vault items: skip if the remote file's `sha256` property equals the item's `sha256`.
   - Notes items: skip if the manifest records the same size and modified time.
4. Upload one at a time (v1), updating a `Stream<BackupProgress>`. A single failure is recorded and the run continues.
5. For the notes source, read the file, seal it with `backupCipher` (AAD = remote name), and upload the bytes. Cap each notes file at 25 MB in memory; larger files are skipped and listed as "too large for backup" (vault blobs are streamed unmodified and are not limited by this cap).
6. Upload the updated `n-manifest` **last**, so an interrupted run never points to missing files.
7. Record "last successful backup" (time and counts) in `shared_preferences` **only if** nothing failed.
8. A cancel flag is checked between items.

**Restore** (`RestoreEngine`):

1. List remote. Vault files (`v-`): download to a temp file, verify the stored `sha256`, then `source.restoreItem`.
2. Notes: ask for the Backup Key code, decrypt `n-manifest`, then for each entry download, `open`, and write.
3. **Never overwrite** an existing local file with different content: save the restored copy as `name (restored).ext` and report it.
4. Restore the vault header and index only if no local `vault/` exists; otherwise ask the user.
5. Verify before finishing: every manifest entry is present locally.

**Tests (fake remote, fake sources, temp directories):** first backup uploads everything; second backup skips everything; one changed file uploads once; interrupted backup (fake fails on the third upload) records failure and does not update "last backup"; manifest uploaded last; cancel stops cleanly; restore into an empty directory reproduces every file byte for byte; restore does not overwrite a different local file; wrong Backup Key fails with a clear message; too-large notes file is skipped and reported; remote names contain no plaintext path for notes.

**Done when:** tests pass and analyze is clean.

---

## Phase 4: Health Connect service and daily quota

Wrap the plugin behind an interface so tests never touch the platform:

```dart
enum HealthStatus { unsupported, notInstalled, updateRequired, needsPermission, ready, error }

abstract class HealthSource {
  Future<HealthStatus> status();
  Future<bool> requestPermissions();
  Future<void> openInstallPage();                      // Health Connect on Play Store
  Future<int> stepsBetween(DateTime start, DateTime end);
  Future<List<({DateTime start, DateTime end})>> workoutSpans(DateTime start, DateTime end);
}
```

`HealthPluginSource implements HealthSource` using the `health` package. Follow the installed version's README for exact names; the analyzer is the source of truth. Typical flow:

```dart
final health = Health();
await health.configure();                                   // if the installed version requires it
final types = [HealthDataType.STEPS, HealthDataType.WORKOUT];
final access = [HealthDataAccess.READ, HealthDataAccess.READ];
final granted = await health.hasPermissions(types, permissions: access);   // can be null
if (granted != true) {
  await Permission.activityRecognition.request();
  await health.requestAuthorization(types, permissions: access);
}
final steps = await health.getTotalStepsInInterval(startOfDay, now);       // int?
// workouts: health.getHealthDataFromTypes(types: [HealthDataType.WORKOUT], startTime: ..., endTime: ...)
//           use each point's dateFrom / dateTo
```

Map the Health Connect SDK status (available, unavailable, update required) to `HealthStatus`. Return `unsupported` on iOS (for now), web and desktop, and never throw to the UI: catch `PlatformException` and return `error`.

### Quota logic (pure Dart, tested)

```dart
Duration mergedDuration(List<({DateTime start, DateTime end})> spans, DateTime from, DateTime to) {
  final clipped = <({DateTime start, DateTime end})>[];
  for (final s in spans) {
    final a = s.start.isBefore(from) ? from : s.start;
    final b = s.end.isAfter(to) ? to : s.end;
    if (b.isAfter(a)) clipped.add((start: a, end: b));
  }
  if (clipped.isEmpty) return Duration.zero;
  clipped.sort((x, y) => x.start.compareTo(y.start));
  var total = Duration.zero;
  var curStart = clipped.first.start;
  var curEnd = clipped.first.end;
  for (final s in clipped.skip(1)) {
    if (s.start.isAfter(curEnd)) {
      total += curEnd.difference(curStart);
      curStart = s.start;
      curEnd = s.end;
    } else if (s.end.isAfter(curEnd)) {
      curEnd = s.end;
    }
  }
  return total + curEnd.difference(curStart);
}
```

This stops two apps that both record the same workout from counting it twice.

- `DailyQuota { stepsGoal (default 8000), exerciseMinutesGoal (default 30) }`, editable in settings, stored in `shared_preferences` (or the app's existing settings store).
- `QuotaProgress` has the values and `fraction = (value / goal).clamp(0, 1)` for each metric, and `isComplete` when both goals are met (guard against a zero goal).
- "Today" is the **local** calendar day from local midnight to now. The progress resets at midnight; refresh on app resume and on pull-to-refresh. No background polling in v1.
- By default Health Connect only lets an app read the previous 30 days. Today's numbers need nothing extra; add the history permission only if a later feature charts older trends.

**Tests (fake `HealthSource`):** merged duration for empty, single, overlapping, adjacent, nested and midnight-crossing spans; fractions and completion; zero-goal guard; status mapping; "permission revoked later" turns `ready` into `needsPermission`.

**Done when:** tests pass; on a real phone with Health Connect installed, granting permission shows real steps for today.

---

## Phase 5: Notes backup source and backup cipher (needs Task A Phase 1)

1. `NotesBackupSource implements BackupSource` built on the file manager's `FileService`. It lists `notes/`, `attachments/` and user folders, and **excludes** `vault/`, `.trash/` and hidden entries. Ids are relative paths. `restoreItem` writes atomically and refuses any id outside the allowed roots (reuse `Sandbox.resolve`).
2. `BackupCipher` wraps `AeadBox.seal/open` with the Backup Key and AAD = `"ARBK1|" + remoteName`.
3. `BackupKeyStore`: create, load, and delete the Backup Key; show the code once using `RecoveryCode`; allow "Show again" only after the user passes the app's normal authentication if it has one.

**Tests:** the notes source excludes the vault and trash; path tricks rejected; seal and open round-trip; wrong key or wrong remote name fails.

---

## Phase 6: UI

Create `lib/features/google/ui/`, using the app's existing theme tokens.

**Connected Services screen** (reached from Settings and from the Files home)

| Card | Shows | Actions |
|---|---|---|
| **Google Drive backup** | Not connected / Connected as (email) / Reconnect needed; last backup time and counts | Connect, Back up now, Restore, Backup key, Disconnect, Delete cloud backup |
| **Health Connect** | Status text from `HealthStatus` with plain-language help | Install, Grant permission, Open Health Connect settings, Edit goals |

**Backup screen:** an explanation of exactly what is uploaded (vault stays encrypted; notes are encrypted with your Backup Key), a toggle "Include notes and attachments", progress bar with Cancel, and a result summary (uploaded, skipped, failed, too large).

**Backup setup flow (first time):** explain, create the Backup Key, show the recovery code once with a copy button that clears the clipboard after 60 seconds, require the user to confirm they saved it, then run the first backup.

**Quota widget** for the home screen and notes sidebar: two progress rings (steps and exercise minutes) with numbers, a clear state when Health Connect is not ready (tap to fix), and last refreshed time.

Rules: every network action is triggered by a user tap; show "Connect Google" only after explaining that it is optional; confirm before "Delete cloud backup" (it removes every backup file in the app's hidden Drive folder); check `mounted` after every `await`; dispose controllers; labelled icon buttons; no tokens or filenames in logs or error text.

**Done when:** analyze is clean and widget tests cover: not-connected state, connected state, backup in progress and cancelled, health states (not installed, needs permission, ready), and goal editing validation.

---

## Phase 7: Vault integration (needs Task A Phase 6)

1. Add `VaultBackupSource` to the engine's source list.
2. End-to-end test on a real phone: create a vault with 3 files, back up, wipe the app data (or use a second device), restore, unlock the vault with the passphrase, and confirm every file is byte-identical.
3. Confirm the vault backs up while locked (no unlock needed), and that Drive contains only `v-...` ciphertext objects for the vault.

---

## Phase 8: Verification

```bash
flutter analyze
flutter test
flutter run
flutter build apk --release
```

### Manual test matrix (real Android phone)

| Case | Expected |
|---|---|
| Fresh install, never connect Google | No network calls; no sign-in prompts anywhere |
| Connect Google | Account sheet, then "Connected as ...", no crash |
| Cancel the Google sheet | Friendly message, app unchanged |
| First backup of 20 notes, 5 images and a vault | Progress shown, summary correct, last-backup time set |
| Drive web UI | The app's files are not visible in normal Drive; only in "Manage apps" storage |
| Second backup right away | Everything skipped |
| Edit one note, back up | Exactly one upload plus the manifest |
| Airplane mode mid-backup | Clean failure, retry works, "last backup" not advanced |
| Cancel during backup | Stops between files; no partial manifest |
| Restore on a clean install | All files and the vault return; vault unlocks |
| Restore with a wrong Backup Key | Clear error, nothing written |
| Local file differs from the backup | Restored copy named `... (restored)`; original untouched |
| Disconnect (sign out only) | Local data untouched; backup stays on Drive |
| Delete cloud backup | Confirmation, then backup files gone |
| Health Connect not installed | Card explains and offers install |
| Deny, then grant, permission | State updates without restarting the app |
| Revoke permission in system settings, return to app | Card shows "needs permission" |
| Walk 200 steps, pull to refresh | Count increases |
| Two apps record the same workout | Minutes are not double counted |
| Cross midnight | Progress resets to zero for the new day |
| iOS, web or desktop run | Health shows "unavailable", no exception |
| Token expiry (leave open over an hour, then back up) | Silent refresh or a clear "Reconnect" prompt |

## Known pitfalls

| Pitfall | What to do |
|---|---|
| OAuth app in **Testing** mode loses authorization after about 7 days | Expected; reconnect, or publish the consent screen |
| Sign-in error because the SHA-1 does not match | Add the SHA-1 of each keystore actually used (debug, release, Play signing) |
| `parents` set on a Drive update | Only set it on create |
| Listing without `spaces: 'appDataFolder'` | Returns nothing useful |
| Only reading the first page of results | Always loop on `nextPageToken` |
| Old `GoogleSignIn().signIn()` tutorials | Do not use; v7 uses `initialize`, `authenticate` and `authorizationClient` |
| Health plugin crashing without a fragment activity | `MainActivity` must extend `FlutterFragmentActivity` |
| Health Connect only returns 30 days of other apps' data | Fine for "today"; request the history permission only when needed |
| Sending whole large files through memory | Stream vault blobs; cap notes files at 25 MB |
| Logging tokens or file names | Never |
| Backing up while the notes folder is being edited | Read each file once; skip files that change size during the read and report them |

## Out of scope for this task

Automatic background backups (WorkManager), Wi-Fi-only or charging-only conditions, two-way sync, version history on Drive, Google Calendar sync, iOS HealthKit, history charts beyond today, and any Google Fit integration. Add later as separate reviewed tasks.

## Definition of done

- [ ] All phases complete, one commit per phase
- [ ] `flutter analyze`: no issues
- [ ] `flutter test`: all passing
- [ ] `flutter build apk --release`: succeeds
- [ ] Manual matrix passed on a real Android device (Phase 7 once Task A's Phase 6 is merged)
- [ ] Only the `drive.appdata` scope is requested
- [ ] No tokens, file names or keys in logs
- [ ] `INTERNET` added deliberately; HTML notes still cannot use the network
- [ ] No `// ignore` comments added to hide warnings
- [ ] Task A informed when the backup engine is ready for `VaultBackupSource`
- [ ] A short report of what changed, what was tested, and any deviation from this plan
