# All-Rounder: Design System, Positioning & UI/UX Master Plan

> **From "Generated Material 3 Slop" to a Warm, Tactile Bento Interface.**  
> This document diagnoses the exact visual and UX failures in the current build, establishes a clear product positioning strategy, defines a strict design system modeled on your two target reference screens, and specifies the **Standalone Image/File Folders** and **HTML Document System**.

---

## 1. Forensic Visual Audit: Why the Current Screens Look Like "AI Slop"

Your current build has solid architectural bones (`plan.md`), but the UI suffers from the classic symptoms of raw, unstyled LLM-generated Flutter code:

| Screen | Current "Slop" Symptoms | How the Target Style Fixes It |
| :--- | :--- | :--- |
| **Screen 1: Notes (`image_c82781.png`)** | • **Stock Material 3 FilterChips** with harsh `1px` black borders stacked in two colliding rows (`All`, `Inbox` + `#v1`, `#ideas`).<br>• **Monotone gray cards (`#EBEEF3`)** stacked vertically with zero visual hierarchy.<br>• **No visual folders for standalone images/files or HTML docs:** Everything looks like a flat text box.<br>• **Cluttered chrome:** Stock M3 bottom bar + oversized rectangular `New Note` FAB blocking the bottom note card. | • **Single borderless pill rail:** Active tab uses a solid Royal Iris (`#6246EA`) capsule; inactive tabs sit cleanly on the warm canvas.<br>• **2-Column Asymmetric Bento Grid + Notched Folder Cards:** Pinned notes, HTML magazine docs, and standalone image/file folders become rich, color-coded tactile cards (Marigold `#FDBE58`, Iris `#6246EA`, Coral `#FF6B57`, Periwinkle `#B4D2FF`) with `28px` corners.<br>• **Floating Capsule Dock:** A detached dark obsidian stadium dock (`border-radius: 999px`) replaces the stock bottom bar. |
| **Screen 2: Time & Schedule (`image_c8793b.png`)** | • **Literal Flutter Layout Overflow (`RIGHT OVERFLOWED BY 69 PIXELS`):** The `Linked Note:` row inside the alarm card is an unconstrained `Row` without `Flexible` or `TextOverflow.ellipsis`.<br>• **Context bug:** The FAB says `+ Add Class` while viewing the `Alarms & Reminders` tab.<br>• **Dated underline `TabBar`** and giant gray alarm boxes that waste vertical space. | • **Vertical Capsule Date Strip:** 7-day pill selector (`Sun 22` – `Sat 28`) where the active day (`Wed 25`) is a solid dark obsidian vertical pill (`#141416`) with a top status dot.<br>• **Overflow-Proof Link Pills:** Linked `.md` notes, `.html` docs, or image folders render inside a constrained, clickable capsule badge (`maxLines: 1`, `TextOverflow.ellipsis`) that opens the item on tap.<br>• **Bento Time Blocks:** Timetable classes appear as 2-column vibrant Bento cards (`Yoga Group` / `Physics Lecture` style). |
| **Screen 3: Settings (`image_c8799d.png`)** | • **Developer spec leaking into the UI:** Section headers literally read `LOCAL STORAGE (PLAN SECTION 6)`, `app_storage/notes/*.md (Plain files are truth)`, `Drift / SQLite Index`, and `Minimal Notion dark palette (#121316)`.<br>• **Broken toggle styling:** The Google Drive switch has a double-nested track artifact. | • **Human Trust Copywriting:** Never expose database engines, hex codes, or markdown spec numbers to users. Translate them into reassuring benefits (*"On-Device Storage · 100% offline in your phone's folder"*).<br>• **Visual Privacy Summary Card:** A clean Bento status banner showing local `.md`, `.html`, and media file counts, vault lock status, and 1-tap `.zip` export. |

---

## 2. Simple Product Positioning

When an app combines Notes, HTML Documents, Media Folders, Timetable, Alarms, Health, and a Vault, the biggest UX risk is **positioning confusion**—if you explain six tools at once, it feels like bloatware.

### 2.1 The Core Positioning Framework

* **Category Anchor:** Personal Day OS (Local-First Multi-Format Workspace)
* **Target Persona:** Students, makers, and privacy-conscious professionals tired of juggling Notion (too slow/online), Google Keep (too messy), and stock gallery/clock apps that don't know what project they belong to.
* **One-Sentence Hero Pitch:**  
  > **"Your notes, HTML docs, media folders, and daily schedule—linked together, 100% on your phone."**
* **Three Simple Pillars (How the user understands the app in 5 seconds):**
  1. **Multi-Format Workspace (`MD` + `HTML` + `Folders`):** Write fast Markdown notes, craft magazine-style `.html` pages, or drop standalone photos and PDFs directly into color-coded Bento folders.
  2. **Connected to Your Day:** Link any note, HTML sheet, or photo folder to an 8:30 AM class, alarm, or daily workout goal in one tap.
  3. **Yours Alone:** Zero accounts, zero cloud spying, biometric vault included.

---

## 3. The "Tactile Bento" Design System

This design system synthesizes your two target references:
1. **Target Reference 1 (`image_c8815b.png`):** Warm cream canvas, vertical capsule day selector, 2-column Bento plan cards (Marigold + Periwinkle + Lavender) with translucent inner pills, and a floating dark obsidian bottom capsule dock with a circular active button.
2. **Target Reference 2 (`image_c88441.jpg`):** Personal greeting header (`Good morning, Anna Lane!`), solid purple pill tabs, 2-column saturated subject/folder cards (`Culture`, `History`, `Math`, `Literature`) with frosted top-left icon containers and subtle side notches, plus clean date-badge agenda rows.

### 3.1 Color Tokens (Light & Dark Mode)

**Rule #1: Banish default gray cards (`#EBEEF3`) and `1px` black borders.**  
Cards either use a **Semantic Bento Fill** (for featured/pinned notes, HTML docs, media folders, and active time blocks) or a **Pure Elevated Surface (`#FFFFFF`)** resting on a **Warm Alabaster Canvas (`#FAF8F5`)**.

| Token Name | Light Mode Hex | Dark Mode Hex | Usage |
| :--- | :--- | :--- | :--- |
| `bg.canvas` | `#FAF8F5` | `#0F1015` | Main app scaffold background (warm alabaster, never sterile `#FFFFFF`) |
| `bg.surface` | `#FFFFFF` | `#181A22` | Standard list cards, search input, top circular icon buttons |
| `bg.subtle` | `#F1EFEA` | `#222530` | Inactive filter pills, secondary containers |
| `ink.primary` | `#141416` | `#F5F6FA` | Greeting titles, card headings, active vertical date pill fill |
| `ink.secondary` | `#6E717A` | `#9CA0AB` | Subtitles, timestamps, body previews |
| `brand.iris` | `#6246EA` | `#7C66F5` | Primary accent, active pill tab, `HTML Docs` / `Lectures` cards |
| `bento.marigold` | `#FDBE58` | `#E5A93C` | `Pinned HTML Zines` / `Projects` Bento cards (Dark ink `#141416` on top) |
| `bento.coral` | `#FF6B57` | `#E85D4A` | `Image & Media Folders` / `Urgent` Bento cards (White ink on top) |
| `bento.periwinkle` | `#B4D2FF` | `#3A5A8C` | `Markdown Notes` / `PDF Handouts` Bento cards (Dark ink `#141416` on top) |
| `bento.lavender` | `#B19CFF` | `#5E4B9E` | `Daily Workspace` hero banner |
| `bento.emerald` | `#3CC162` | `#2E9E4F` | `Health Quota` / `Synced Folders` Bento cards (White ink on top) |
| `dock.surface` | `#141416` | `#1E202B` | Floating bottom capsule navigation bar |

---

## 4. Core Component Specifications & Flutter Fixes

### 4.1 Component 1: The Personal Header Bar
Replaces the robotic `All-Rounder Notes` app bar.
* **Left:** User avatar circle (tapping opens humanized Settings) + 2-line stacked greeting (`Good morning · Fri, 23 Oct` and `Anna Lane!`).
* **Right:** Two `40x40px` circular buttons:
  1. **Global Search (`🔍`):** Instant search across `.md` notes, `.html` pages, image filenames, and schedule.
  2. **Folders & Media Shortcut (`📁`):** 1-tap jump to the standalone Folder & File Manager.

### 4.2 Component 2: Standalone Folders for Images, PDFs & Non-MD Files
Users frequently need to store lecture whiteboard photos, diagram PNGs, syllabus PDFs, or audio clips **without** wrapping them inside a Markdown `.md` file.
* **On-Device Folder Structure (`app_storage/spaces/<folder_name>/`):**
  * Supports any file type directly inside folders: `.png`, `.jpg`, `.webp`, `.pdf`, `.html`, `.md`, `.zip`.
  * Each folder renders as a **Notched Tactile Bento Card** (modeled on Target Image 2) showing a top-left frosted icon box, file count badge (`8 Images`, `3 .HTML`), and folder title.
* **Visual Image Gallery Grid:**
  * Inside any folder, standalone images display in a **3-column visual thumbnail grid** (`BorderRadius.circular(18)`) with file type badges (`PNG`, `JPG`) and a 1-tap **Lightbox Viewer** (pinch-to-zoom, share, or link directly to an alarm/timetable slot).

### 4.3 Component 3: The HTML Document System (`.html` Magazine & Custom CSS Pages)
Alongside standard `.md` notes, All-Rounder treats `.html` files as first-class citizens for users who want magazine-style layouts, custom CSS grids, interactive formula cards, or rich study sheets.
* **Sandboxed Local Execution:**
  * Stored as plain `.html` files on device (`app_storage/spaces/<folder>/doc.html`).
  * Rendered inside a local sandboxed container (`WebView` / `flutter_inappwebview` or local HTML renderer) with external network requests blocked by default for 100% offline privacy.
* **Dual-Mode Viewer & Editor Modal:**
  * **Tab 1 (`🎨 Rendered Magazine View`):** Displays the styled HTML/CSS document full-bleed inside a `24px` rounded frame.
  * **Tab 2 (`💻 Edit HTML / CSS Source`):** Monospace (`JetBrains Mono`) code editor allowing the user to edit `<style>` rules and HTML markup live, plus link local folder images (`<img src="folder/image.png">`).
* **Distinct Visual Badge:** HTML documents always display a `🌐 HTML Doc` capsule pill so users can immediately distinguish them from `📝 .MD Note` and `🖼️ Image File` cards.

### 4.4 Component 4: Overflow-Proof Alarm & Agenda Card (Fixing the 69px Overflow Bug)
Why did `image_c8793b.png` overflow by 69 pixels? Because the linked note text was placed inside an unconstrained inner `Row` next to a `Switch` and `IconButton`.

**The Mandatory Flutter Layout Pattern:**
```dart
// NEVER put an unconstrained Row inside another Row without Expanded/Flexible.
Container(
  padding: const EdgeInsets.all(18),
  decoration: BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(24),
  ),
  child: Row(
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: const Color(0xFFEAE6FD),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.notifications_active_rounded, color: Color(0xFF6246EA)),
      ),
      const SizedBox(width: 14),
      // Middle Column MUST be wrapped in Expanded so it never overflows!
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('08:30 AM', style: AppTextStyles.timeTitle),
            const SizedBox(height: 2),
            Text(
              'Prep for Physics Lecture',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.bodySnippet,
            ),
            const SizedBox(height: 8),
            // Constrained Clickable Link Pill (Supports .MD, .HTML, or Image Folders!)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF4DC),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.link_rounded, size: 14, color: Color(0xFF9A5B00)),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      'Quantum Wave Sheet.html + 2 imgs',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.linkPill,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      const SizedBox(width: 12),
      Switch.adaptive(value: true, onChanged: (_) {}),
    ],
  ),
)
```

### 4.5 Component 5: Multi-Format Quick Capture Sheet (`+` Button in Floating Dock)
Tapping the center `+` button in the floating capsule dock opens a **2x2 Bento Quick-Action Sheet**:
1. **📝 Markdown Note (`.md`):** Fast plain-text note with checklists and `[[WikiLinks]]`.
2. **🌐 HTML Document (`.html`):** Magazine-style page with custom CSS and visual grid templates.
3. **🖼️ Add Image / File:** Pick photos from camera/gallery or PDFs and drop them directly into any folder.
4. **📁 New Media Folder:** Create a color-coded Bento folder for organizing standalone images, files, and docs.