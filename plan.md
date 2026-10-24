# All-Rounder

*One private Android app for your notes, your time, your health and your files.*

**Product Vision & Build Plan · Final Draft · October 2026**

---

> Notes first. Everything else orbits them: alarms, timetable, photos, fitness and a locked vault, all linked together and all yours.

---

## 1. Vision

Most people run their day across five apps that don't talk to each other: notes, alarms, a timetable, a fitness tracker and a cloud drive. **All-Rounder** puts them in one place and connects them. A lecture slot links to its notes. A note links to its photos. A reminder links back to the note that created it.

**Three promises**

1. **Private by design.** No accounts, no tracking, no servers of ours. Data lives on the phone; the cloud is an optional backup.
2. **Notes at the centre.** The most-used feature gets the most care.
3. **Fast and clean.** A calm, well-made tool, not a pile of generated screens.

**Non-goals (for now):** iOS, a web version, real-time collaboration, our own sync server, social features.

---

## 2. Feature Map

Features are grouped by release tier. Anything not in v1 is deliberately deferred so the core ships well.

### v1: Core (must ship)

| Area | Feature |
|---|---|
| **Notes** | Create, edit, pin, archive, trash with restore, tags, folders, full-text search |
| **Markdown** | Full rendering: tables, code with highlighting, checklists, maths, wiki links `[[Note]]` |
| **Files** | File manager for notes and attachments; move, rename, duplicate, export |
| **Time** | Alarms, reminders (one-time, repeating, note-linked), timetable with CSV/ICS import |
| **Links** | One link graph joining notes, alarms, timetable slots, reminders and photos, with backlinks |
| **Health** | Daily exercise quota dashboard from Health Connect |
| **Vault** | Encrypted storage unlocked by fingerprint, with recovery key and auto-lock |
| **Backup** | Optional encrypted Drive backup and a one-tap restore |
| **UI** | Light and dark themes, minimal Notion-style layout |

### v1.x: Complements (high value, low risk)

These were added because each one strengthens the core idea of linked, private, fast notes.

| Feature | Why it helps |
|---|---|
| **Quick capture** (home-screen widget, Quick Settings tile, share-to-app) | Capture speed decides whether people keep using a notes app |
| **Daily note and templates** | One tap to today's page; reusable layouts for lectures, meetings, journals |
| **Tasks inside notes** | Checklist items with due dates that feed reminders |
| **Calendar view** | Timetable, reminders and daily notes on one screen |
| **Backlinks and graph view** | Makes the interconnection visible and useful |
| **Version history** | Per-note snapshots so edits can be undone safely |
| **Full export and import** (ZIP of `.md` files and attachments) | Proves there is no lock-in |
| **App lock** | Optional biometric lock for the whole app, separate from the vault |
| **Home-screen widgets** | Next alarm, today's timetable, quota progress |
| **Focus timer** | Pomodoro tied to a timetable slot or note, logged on the daily note |

### Later: Ambitious

| Feature | Notes |
|---|---|
| **HTML/CSS notes** | Sandboxed WebView, JavaScript off, no network; magazine-style pages |
| **Voice notes with on-device transcription** | Works offline, nothing leaves the phone |
| **Scan to note (OCR)** | Also enables photo-based timetable import |
| **Habit tracker** | Daily habits linked to health data and the daily note |
| **Weekly review page** | Auto-generated summary of notes, tasks and activity |
| **Google Calendar sync** | Optional, one-way first |
| **Cryptomator-format compatibility** | Optional; the official Android app already exists |

---

## 3. Health: Google Fit Is Going Away

The original plan used the Google Fit API. That must change.

- Google Fit APIs are deprecated and supported only until the end of 2026.
- Use **Health Connect**, an on-device store. No OAuth, no account, data stays on the phone.
- Android 14+ includes it. On Android 9 to 13 it is a Play Store install, so handle the "not installed" case.
- Google lists **no replacement for the Goals API**, so store the daily quota in the app and compare it with Health Connect steps and exercise sessions.
- By default an app reads only the last 30 days of other apps' data; request the history permission for longer trends.
- Health Connect data is per-device, which suits a local-first app.
- Skip the Google Health cloud API; it needs Google sign-in and review.
- Treat "permission revoked" as a visible state in the UI, since it otherwise looks like a user who stopped moving.

---

## 4. Privacy and Accounts

- **No Firebase and no login.** The app opens straight to the user's notes.
- Google Sign-In appears only if the user turns on Drive backup.
- Request the narrowest Drive scope (`drive.appdata` or `drive.file`) so the app sees only its own files.
- No analytics SDKs. Crash reports are opt-in, local, and shareable by the user manually.
- Block screenshots and the recents preview inside the vault (`FLAG_SECURE`).
- Clear the clipboard after copying anything from the vault.

---

## 5. The Vault

The vault is the trust feature, so the design comes before the interface.

| Topic | Decision |
|---|---|
| **Cipher** | AES-256-GCM or XChaCha20-Poly1305, one master key per vault |
| **Key protection** | Master key wrapped by Android Keystore; unlocking requires BiometricPrompt with a crypto object |
| **Fallback** | Passphrase, derived with Argon2id |
| **Recovery key** | Generated at setup and shown once. Without it, a changed fingerprint set or a forgotten passphrase means permanent data loss |
| **Auto-lock** | Locks on app background, screen off, or after a timeout |
| **Backup** | Only ciphertext and encrypted filenames go to Drive; Drive never sees plain content |
| **Spec first** | Write the file-format spec and test vectors before building the UI |

**Important:** biometric-bound keys can be invalidated when fingerprints are added or removed. The recovery key is not optional.

---

## 6. Notes Architecture

**Plain files are the source of truth.** Each note is a `.md` file in app storage. A SQLite database (Drift) indexes titles, tags, links and search, and can be rebuilt from the files at any time.

This gives an honest file manager, no lock-in, and easy recovery.

```
app_storage/
  notes/
    2026/10/23-lecture-physics.md
    inbox/quick-capture-001.md
  attachments/
    <note-id>/image-001.jpg
  vault/            # encrypted blobs only
  index.db          # rebuildable search and link index
  trash/
```

- **Images** are copied into the note's attachment folder. Live links to Drive paths break when files move or go offline, so importing from Drive is an explicit action.
- **HTML notes** (later) run in a sandboxed WebView with JavaScript off by default and no network access.
- Use UTF-8 throughout and test with non-Latin scripts from the start.

---

## 7. Link Graph

One table joins every item type:

```
links(from_type, from_id, to_type, to_id, created_at)
```

Notes, alarms, timetable slots, reminders and photos all use it. This is simpler than a custom relation for each feature pair and powers backlinks, the graph view and "everything related to this" panels.

---

## 8. Alarms and Timetable

Alarms are the riskiest part of the app because Android restricts background work.

- Request the **exact-alarm permission** (Android 12+).
- **Reschedule after reboot** with a boot receiver.
- Handle **battery optimisation** on aggressive manufacturers and test on real devices.
- Keep alarm scheduling in a thin Kotlin platform channel if plugins prove unreliable.
- Timetable import: **CSV and ICS** first; photo/PDF with OCR later.

---

## 9. Look and Feel

A minimal blend of Notion and the Streamlit dashboard: calm, spacious, clearly organised.

| Token | Light | Dark |
|---|---|---|
| Primary | `#4F46E5` | Same indigo accent |
| Background | `#FFFFFF` | Deep neutral |
| Surface | `#F3F4F8` | Slightly lighter neutral |
| Text | `#1E2330` | Soft off-white |
| Font | Sans-serif | Sans-serif |

To avoid the generated look: one type scale, one spacing scale, real empty states, consistent components, and sensible motion. Dark mode ships in the first release. Support large text and screen readers from day one.

---

## 10. Technology

| Layer | Choice |
|---|---|
| **Framework** | Flutter, with small Kotlin platform channels where needed |
| **State** | Riverpod |
| **Database** | Drift (SQLite) |
| **Markdown** | `flutter_markdown_plus` or `markdown_widget` |
| **Security** | `local_auth`, `flutter_secure_storage`, plus native Keystore code for the vault |
| **Health** | Health Connect |
| **Backup** | Google Drive API, optional |
| **Testing** | Unit, widget and integration tests; real-device alarm tests |

---

## 11. Roadmap

| Phase | Scope | Result |
|---|---|---|
| **0 · Foundation** | Design tokens, app shell, file and database layer, CI | Working skeleton |
| **1 · Notes (MVP)** | Markdown notes, folders, tags, search, trash, file manager, theme | Usable notes app |
| **2 · Capture** | Quick capture, share target, daily note, templates, export/import | Fast to use daily |
| **3 · Time** | Alarms, reminders, timetable import, calendar view, linking | Notes meet the schedule |
| **4 · Health** | Health Connect, daily quota dashboard, widgets | Fitness at a glance |
| **5 · Vault** | Encryption, biometrics, recovery key, encrypted Drive backup and restore | Private and safe |
| **6 · Polish** | Version history, backlinks graph, app lock, accessibility, performance pass | Ready to share |
| **7 · Later** | HTML notes, voice, OCR, habits, weekly review | Ambitious extras |

Ship after Phase 2 as a private beta. Each later phase is a release.

---

## 12. How We Build

**Do**

- Keep the interface simple and reachable.
- Make it reliable and fast.
- Follow the roadmap and avoid micro-managing.
- Use agentic coding guided by a short written spec for each phase.

**Don't**

- Ship something that looks like generated filler.
- Leave known bugs.
- Try to build everything at once.
- Fix by hand what a test would catch.

> **Ship fast, but test the risky parts.** Move quickly on interface and low-risk features. Write automated tests for the vault, alarms and backup, because a bug there can lose real data.

**Working loop per phase**

1. Write a one-page spec: goal, screens, data, edge cases, done criteria.
2. Let the agent build against the spec.
3. Run tests and a short manual check on a real device.
4. Fix, tag a release, update the roadmap.

---

## 13. Quality Targets

| Area | Target |
|---|---|
| **Cold start** | Under 1.5 seconds to the notes list on a mid-range phone |
| **Search** | Results in under 200 ms for 10,000 notes |
| **Alarms** | 100% fire correctly after reboot and across time-zone or clock changes in tests |
| **Vault** | Round-trip encrypt, back up, restore and decrypt verified by automated tests |
| **Data safety** | No note lost on crash; writes are atomic |
| **Accessibility** | Usable with TalkBack and at large font sizes |

---

## 14. Risks

| Risk | Mitigation |
|---|---|
| Alarms killed by manufacturer battery rules | Real-device tests, in-app setup guide, exact-alarm permission |
| Lost vault access | Recovery key shown at setup, clear warnings |
| Health Connect missing or permission revoked | Visible states and a guided fix flow |
| Scope creep | Tiered feature map; nothing from "Later" before Phase 6 |
| Drive scope review delays | Use `drive.appdata` or `drive.file` only |
| Index corruption | Rebuild the index from the `.md` files |

---

## 15. Next Steps

1. Confirm the feature tiers and phase order.
2. Write the Phase 0 spec: folder layout, schema and design tokens.
3. Draft the vault format spec with test vectors.
4. Build the Phase 1 notes MVP and ship the first private beta after Phase 2.
