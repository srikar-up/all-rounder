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
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Open'),
          ),
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
