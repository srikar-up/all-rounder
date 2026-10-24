# HTML Rendering System: Implementation Plan (Agent Prompt)

**Project:** All-Rounder (`srikar-up/all-rounder`, Flutter, Android first)
**Goal:** Render user-written HTML/CSS notes inside the app, offline and safely, with no browser and no runtime errors.

> Execute this file phase by phase. Do not skip ahead. After every phase run `flutter analyze` and `flutter test`; both must be clean before you continue. Commit after each phase.

---

## 0. Context the agent must know

- The repo is a fresh Flutter app. Its `pubspec.yaml` currently has no dependencies beyond `flutter` and `cupertino_icons`. The UI is built, but there is no rendering, storage or state layer yet. **Read `lib/` first** and follow whatever structure, theme and state approach already exists. If something here conflicts with the existing code, keep the existing pattern and tell me.
- Follow `plan.md` in the repo root and any rules in `.agents/skills/gravitas` if they apply.
- Target platforms: **Android (primary) and iOS**. The repo also has web, Windows, macOS and Linux folders, but `webview_flutter` does not run there, so the code must degrade gracefully, never crash.
- Product rules: offline-first, private, no network calls from rendered notes, no analytics.

## 1. Architecture decision

| Option | Verdict |
|---|---|
| **`webview_flutter` with sanitized HTML** | **Use this.** Full HTML/CSS fidelity, which is what "magazine-style notes" needs. |
| `flutter_widget_from_html` (native widgets) | Not chosen. Limited CSS support, so pages will not match what the user designed. |
| Open in the system browser | Rejected. It breaks the "no browser" goal and the privacy model. |

**Security model (three independent layers, so one mistake can't expose the user):**

1. **Sanitize** the HTML (remove scripts, event handlers, remote loads, forms, iframes).
2. **Content-Security-Policy** meta tag that allows only inline styles and `data:` images/fonts.
3. **WebView settings:** JavaScript disabled, all navigation intercepted.

Images are **inlined as `data:` URIs** from the note's attachment folder. This avoids Android file-access settings entirely and keeps `file://` access off.

## 2. File layout

```
lib/features/html_render/
  html_sanitizer.dart        # pure Dart, no Flutter imports
  image_inliner.dart         # reads attachments, path-traversal safe
  html_document_builder.dart # wraps body in a full page with CSP and theme CSS
  html_render_pipeline.dart  # runs the above in a background isolate
  html_note_view.dart        # the WebView widget
test/html_render/
  html_sanitizer_test.dart
  image_inliner_test.dart
  html_document_builder_test.dart
  html_note_view_test.dart
test/fixtures/
  magazine_sample.html
  malicious_sample.html
```

---

## Phase 1: Dependencies and platform check

```bash
flutter pub add webview_flutter html url_launcher path
flutter pub get
flutter analyze
```

- Do **not** add any other package.
- Do **not** add the `INTERNET` permission to the main `AndroidManifest.xml`. Rendered notes never use the network. (Flutter's debug manifest adds it automatically for hot reload, which is fine.)
- If the Android build complains about `minSdkVersion`, raise it only to the value the error message states.
- Open links with `launchUrl` directly. Do not call `canLaunchUrl`, which on Android 11+ would need extra `<queries>` manifest entries.

**Done when:** `flutter pub get` and `flutter analyze` pass with zero issues and the app still launches.

---

## Phase 2: Sanitizer (pure Dart, test-first)

Write the tests in the checklist below first, then implement.

```dart
// lib/features/html_render/html_sanitizer.dart
import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;

class SanitizedHtml {
  const SanitizedHtml({
    required this.document,
    required this.styles,
    required this.title,
  });
  final Document document;
  final List<String> styles;
  final String title;
}

class HtmlSanitizer {
  static const _blockedTags = <String>{
    'script', 'noscript', 'iframe', 'frame', 'frameset', 'object', 'embed',
    'applet', 'base', 'form', 'input', 'button', 'textarea', 'select',
    'link', 'meta', 'audio', 'video', 'source', 'track', 'canvas',
  };

  static const _urlAttrs = <String>{
    'href', 'src', 'xlink:href', 'action', 'formaction', 'poster',
    'background', 'data', 'srcset', 'ping',
  };

  static final _scheme = RegExp(r'^[a-z][a-z0-9+.\-]*:');

  static SanitizedHtml sanitize(String raw) {
    final doc = html_parser.parse(raw);
    final title = doc.querySelector('title')?.text.trim() ?? '';

    final styles = <String>[];
    for (final s in doc.querySelectorAll('style').toList()) {
      styles.add(sanitizeCss(s.text));
      s.remove();
    }

    for (final el in doc.querySelectorAll('*').toList()) {
      final tag = (el.localName ?? '').toLowerCase();
      if (_blockedTags.contains(tag)) {
        el.remove();
        continue;
      }
      _cleanAttributes(el);
    }
    return SanitizedHtml(document: doc, styles: styles, title: title);
  }

  static void _cleanAttributes(Element el) {
    for (final key in el.attributes.keys.toList()) {
      final name = key.toString().toLowerCase();
      final value = el.attributes[key] ?? '';
      if (name.startsWith('on')) {
        el.attributes.remove(key);
      } else if (name == 'style') {
        el.attributes[key] = sanitizeCss(value);
      } else if (_urlAttrs.contains(name) && !_isSafeUrl(name, value)) {
        el.attributes.remove(key);
      }
    }
  }

  static bool _isSafeUrl(String attr, String value) {
    // Strip whitespace/control characters so "java\nscript:" can't sneak by.
    final v = value
        .replaceAll(RegExp(r'[\u0000-\u0020\u007f]'), '')
        .toLowerCase();
    if (v.isEmpty) return false;
    if (const {'srcset', 'ping', 'action', 'formaction', 'poster',
        'background', 'data'}.contains(attr)) {
      return false;
    }
    if (v.startsWith('#')) return true;
    if (v.startsWith('data:image/')) return true;
    if (attr == 'href' || attr == 'xlink:href') {
      return v.startsWith('http:') || v.startsWith('https:') ||
          v.startsWith('mailto:') || v.startsWith('tel:');
    }
    // src: only relative paths (resolved later by the inliner).
    if (v.startsWith('//')) return false;
    return !_scheme.hasMatch(v);
  }

  static String sanitizeCss(String css) {
    var out = css.replaceAll(
        RegExp(r'@import[^;{]*;?', caseSensitive: false), '');
    out = out.replaceAll(
        RegExp(r'expression\s*\(', caseSensitive: false), 'blocked(');
    out = out.replaceAll(
        RegExp(r'''url\(\s*(?!['"]?\s*data:(image|font)/)[^)]*\)''',
            caseSensitive: false),
        'none');
    return out;
  }
}
```

**Required test cases** (each must assert the dangerous part is gone and the safe content survives):

- `<script>alert(1)</script>`, `<img src=x onerror=alert(1)>`, `<body onload=...>`
- `<a href="javascript:alert(1)">`, `<a href=" JaVaScRiPt:alert(1)">`, `<a href="java&#10;script:...">`
- `<iframe>`, `<object>`, `<embed>`, `<base href>`, `<form action>`, `<meta http-equiv="refresh">`, `<link rel="stylesheet" href="http://...">`
- `<style>@import url(http://evil);</style>` and `style="background:url(http://evil)"`
- `<img src="http://example.com/a.png">` (remote image removed) and `<img src="//example.com/a.png">`
- `<svg onload=...>` (handler removed, SVG kept)
- Safe content kept: headings, paragraphs, tables, lists, `<a href="https://...">`, `<a href="#section">`, `<img src="images/a.png">`, `<style>` with normal CSS, `data:image/png;base64,...`
- Malformed HTML, empty string, and non-Latin text (Hindi, Punjabi, Arabic, emoji) round-trip unchanged.

**Done when:** all of these tests pass and analyze is clean.

---

## Phase 3: Image inliner and document builder

```dart
// lib/features/html_render/image_inliner.dart
import 'dart:convert';
import 'dart:io';
import 'package:html/dom.dart';
import 'package:path/path.dart' as p;

class ImageInliner {
  static const maxImageBytes = 2 * 1024 * 1024;
  static const maxTotalBytes = 10 * 1024 * 1024;
  static const _mime = <String, String>{
    '.png': 'image/png', '.jpg': 'image/jpeg', '.jpeg': 'image/jpeg',
    '.gif': 'image/gif', '.webp': 'image/webp', '.svg': 'image/svg+xml',
  };

  static Future<void> inline(Document doc, String baseDir) async {
    var total = 0;
    for (final img in doc.querySelectorAll('img').toList()) {
      final src = img.attributes['src'];
      if (src == null || src.isEmpty) continue;
      if (src.toLowerCase().startsWith('data:')) continue;
      try {
        final rel = Uri.decodeComponent(Uri.parse(src).path);
        final resolved = p.normalize(p.join(baseDir, rel));
        // Path-traversal guard: must stay inside the attachments folder.
        if (!p.isWithin(baseDir, resolved)) {
          _fail(img);
          continue;
        }
        final mime = _mime[p.extension(resolved).toLowerCase()];
        final file = File(resolved);
        if (mime == null || !await file.exists()) {
          _fail(img);
          continue;
        }
        final len = await file.length();
        if (len > maxImageBytes || total + len > maxTotalBytes) {
          _fail(img);
          continue;
        }
        total += len;
        final bytes = await file.readAsBytes();
        img.attributes['src'] = 'data:$mime;base64,${base64Encode(bytes)}';
      } catch (_) {
        _fail(img);
      }
    }
  }

  static void _fail(Element img) {
    img.attributes.remove('src');
    img.attributes['alt'] = img.attributes['alt'] ?? 'Image unavailable';
  }
}
```

```dart
// lib/features/html_render/html_document_builder.dart
import 'dart:convert';
import 'html_sanitizer.dart';

class HtmlDocumentBuilder {
  static const csp = "default-src 'none'; img-src data:; "
      "style-src 'unsafe-inline'; font-src data:; "
      "base-uri 'none'; form-action 'none'";

  static String build({
    required SanitizedHtml sanitized,
    required bool dark,
    required bool applyAppTheme,
  }) {
    final title = const HtmlEscape().convert(sanitized.title);
    final base = applyAppTheme ? _themeCss(dark) : _minimalCss;
    final userStyles = sanitized.styles.map((c) => '<style>$c</style>').join();
    final body = sanitized.document.body?.innerHtml ?? '';
    return '<!DOCTYPE html><html lang="en"><head>'
        '<meta charset="utf-8">'
        '<meta http-equiv="Content-Security-Policy" content="$csp">'
        '<meta name="viewport" '
        'content="width=device-width, initial-scale=1, viewport-fit=cover">'
        '<meta name="color-scheme" content="${dark ? 'dark' : 'light'}">'
        '<title>$title</title><style>$base</style>$userStyles'
        '</head><body>$body</body></html>';
  }

  static const _minimalCss =
      'body{margin:16px;font-family:sans-serif;word-wrap:break-word}'
      'img,svg,table{max-width:100%}';

  // Replace these values with the app's real theme tokens from lib/ if they exist.
  static String _themeCss(bool dark) {
    final bg = dark ? '#0F1117' : '#FFFFFF';
    final surface = dark ? '#1A1D27' : '#F3F4F8';
    final text = dark ? '#E6E8EF' : '#1E2330';
    const primary = '#4F46E5';
    return 'body{margin:16px;background:$bg;color:$text;'
        'font:16px/1.6 sans-serif;word-wrap:break-word}'
        'a{color:$primary}img,svg,video{max-width:100%;height:auto}'
        'table{border-collapse:collapse;max-width:100%}'
        'td,th{border:1px solid $surface;padding:6px 10px}'
        'pre,code{background:$surface;border-radius:6px}'
        'pre{padding:12px;overflow-x:auto}';
  }
}
```

User styles come **after** the base CSS, so users can override the defaults.

```dart
// lib/features/html_render/html_render_pipeline.dart
import 'dart:isolate';
import 'html_document_builder.dart';
import 'html_sanitizer.dart';
import 'image_inliner.dart';

class HtmlRenderPipeline {
  static const maxInputChars = 2000000;

  static Future<String> render({
    required String rawHtml,
    required String attachmentsDir,
    required bool dark,
    required bool applyAppTheme,
  }) {
    if (rawHtml.length > maxInputChars) {
      return Future.value(
          '<!DOCTYPE html><html><body><p>This note is too large to preview.</p></body></html>');
    }
    // Heavy parsing and file reads stay off the UI thread.
    return Isolate.run(() async {
      final s = HtmlSanitizer.sanitize(rawHtml);
      await ImageInliner.inline(s.document, attachmentsDir);
      return HtmlDocumentBuilder.build(
          sanitized: s, dark: dark, applyAppTheme: applyAppTheme);
    });
  }
}
```

**Tests:** inliner (existing image becomes a data URI; missing file, wrong extension, oversize file, `../../x.png` and `/etc/passwd` all fail safely without throwing; URL-encoded filenames work) and builder (CSP meta present, title escaped, dark and light differ, user styles come after base CSS).

**Done when:** all tests pass and analyze is clean.

---

## Phase 4: The WebView widget

```dart
// lib/features/html_render/html_note_view.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'html_render_pipeline.dart';

class HtmlNoteView extends StatefulWidget {
  const HtmlNoteView({
    super.key,
    required this.rawHtml,
    required this.attachmentsDir,
    this.applyAppTheme = true,
  });

  final String rawHtml;
  final String attachmentsDir;
  final bool applyAppTheme;

  @override
  State<HtmlNoteView> createState() => _HtmlNoteViewState();
}

class _HtmlNoteViewState extends State<HtmlNoteView> {
  WebViewController? _controller;
  Timer? _debounce;
  int _renderToken = 0;
  String? _error;

  bool get _supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  @override
  void initState() {
    super.initState();
    if (_supported) {
      _controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.disabled)
        ..setNavigationDelegate(
          NavigationDelegate(onNavigationRequest: _onNavigation),
        );
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _schedule(immediate: true); // also re-renders when the theme changes
  }

  @override
  void didUpdateWidget(HtmlNoteView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.rawHtml != widget.rawHtml ||
        oldWidget.attachmentsDir != widget.attachmentsDir ||
        oldWidget.applyAppTheme != widget.applyAppTheme) {
      _schedule();
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _schedule({bool immediate = false}) {
    _debounce?.cancel();
    _debounce = Timer(
      immediate ? Duration.zero : const Duration(milliseconds: 400),
      _render,
    );
  }

  Future<void> _render() async {
    final controller = _controller;
    if (controller == null || !mounted) return;
    final token = ++_renderToken;
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final bg = theme.colorScheme.surface;
    try {
      final html = await HtmlRenderPipeline.render(
        rawHtml: widget.rawHtml,
        attachmentsDir: widget.attachmentsDir,
        dark: dark,
        applyAppTheme: widget.applyAppTheme,
      );
      if (!mounted || token != _renderToken) return; // a newer render won
      await controller.setBackgroundColor(bg);
      await controller.loadHtmlString(html);
      if (mounted && _error != null) setState(() => _error = null);
    } catch (_) {
      if (mounted && token == _renderToken) {
        setState(() => _error = 'Could not render this note.');
      }
    }
  }

  NavigationDecision _onNavigation(NavigationRequest request) {
    final url = request.url;
    // The initial load and same-page anchors (#section) stay in the view.
    if (url.startsWith('about:blank')) return NavigationDecision.navigate;
    final uri = Uri.tryParse(url);
    const external = {'http', 'https', 'mailto', 'tel'};
    if (uri != null && external.contains(uri.scheme)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _confirmAndOpen(uri);
      });
    }
    return NavigationDecision.prevent;
  }

  Future<void> _confirmAndOpen(Uri uri) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Open link?'),
        content: Text(uri.toString()),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Open')),
        ],
      ),
    );
    if (ok == true) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_supported) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('HTML preview is available on Android and iOS.'),
        ),
      );
    }
    if (_error != null) return Center(child: Text(_error!));
    return SafeArea(
      top: false,
      child: WebViewWidget(controller: _controller!),
    );
  }
}
```

**Rules the agent must keep:**

- JavaScript stays **disabled**. Never call `setJavaScriptMode(unrestricted)` or add JavaScript channels.
- Never call `loadRequest` with a remote URL.
- Use **one** WebView at a time (the note preview screen). Note lists must show plain-text snippets, never WebViews.
- Keep the controller in the State and never recreate it per rebuild.

**Done when:** analyze is clean and the widget test passes (see Phase 6).

---

## Phase 5: Integrate into the app

1. Add a note type for HTML (for example the `.html` file extension, or `type: html` in the existing note model, whichever fits the current code).
2. In the note screen for HTML notes, add an **Edit | Preview** toggle. Edit is a monospace text field; Preview is `HtmlNoteView`.
3. `attachmentsDir` is the note's own attachment folder, which must exist (create it if missing).
4. Add a **"New HTML note"** action that starts from a small magazine-style template (title, byline, a pull-quote, two paragraphs, one image placeholder).
5. Add a toggle **"Use app theme"**. It maps to `applyAppTheme`; turn it off for pages with fully custom styling.
6. Save the raw HTML as written. The sanitizer runs only at render time, so the saved file is never altered.

**Done when:** an HTML note can be created, edited, previewed, saved and reopened, in both light and dark theme.

---

## Phase 6: Verification (no "it should work")

### Commands

```bash
flutter analyze
flutter test
flutter run            # on a real Android device or emulator
flutter build apk --release
```

All four must succeed with zero warnings from this feature.

### Widget test note

`WebViewWidget` is a platform view and does not render in `flutter test`. Test the pure-Dart layers thoroughly, and for the widget only assert that: it builds without throwing in the test environment (where it falls back to the "not supported" message), and that the fallback text appears. Do not try to drive the real WebView in unit tests.

### Manual test matrix (on a real Android phone)

| Case | Expected |
|---|---|
| `magazine_sample.html` (headings, columns, custom fonts via data URI, local images) | Renders like a clean page; images appear |
| `malicious_sample.html` (scripts, handlers, iframes, remote images, `javascript:` links) | Nothing executes; no network request; no crash |
| Tap an `https://` link | Confirmation dialog, then opens in the system browser |
| Tap a `#section` link | Scrolls in place |
| Dark and light theme switch while viewing | Page re-renders with matching background |
| Type quickly in the editor | Preview updates after a short pause; no flicker storms; no errors |
| Image missing or too large | "Image unavailable" alt text; no crash |
| Hindi, Punjabi and emoji text | Displays correctly |
| Rotate the phone, background and return the app | Content still shown |
| Run on web or desktop | Friendly "not supported" message, no exception |
| Airplane mode | Identical rendering |

---

## Known pitfalls (read before debugging)

| Pitfall | What to do |
|---|---|
| **Safe-area/inset changes on newer Android System WebView (version 144+)** are reported in the Flutter issue tracker (flutter/flutter#182208). | Keep `viewport-fit=cover` in the page and `SafeArea` in Flutter; check content is not hidden under system bars on a current phone. |
| WebViews inside scrolling lists are slow and glitchy. | Previews only on the detail screen. |
| CSS escapes such as `\75rl(` can slip past the regex CSS filter. | This is why the CSP layer exists. Do not remove the CSP meta tag. |
| `loadHtmlString` navigation callbacks differ slightly between Android and iOS. | The `about:blank` allow-rule handles both. If a link misbehaves, log `request.url` and adjust the rule. |
| Very old Android System WebView builds lack modern CSS. | Treat as a known limitation; show a small hint only if a user reports it. |
| Hot reload does not reset the WebView. | Use a hot restart when testing controller changes. |

## Out of scope for this task

JavaScript in notes, remote images or fonts, `<video>`/`<audio>`, forms, background-image from local files, full-text indexing of HTML, and exporting HTML to PDF. Add these later as separate, individually reviewed tasks.

## Definition of done

- [ ] All phases complete, one commit per phase
- [ ] `flutter analyze`: no issues
- [ ] `flutter test`: all passing, including every sanitizer case in Phase 2
- [ ] `flutter build apk --release`: succeeds
- [ ] Manual matrix passed on a real Android device
- [ ] No `INTERNET` permission added to the main manifest
- [ ] No `// ignore` comments added to hide warnings
- [ ] A short report of what changed, what was tested, and any deviation from this plan
