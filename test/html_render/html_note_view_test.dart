import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:all_rounder/features/html_render/html_note_view.dart';

void main() {
  group('HtmlNoteView Tests (Phase 4 & 6)', () {
    testWidgets('builds without throwing in test environment and displays fallback message',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: HtmlNoteView(
              rawHtml: '<h1>Test Note</h1><p>Content</p>',
              attachmentsDir: '/mock/attachments',
            ),
          ),
        ),
      );

      // In the flutter_test headless environment, defaultTargetPlatform is not a real Android/iOS device
      // or kIsWeb is simulated, so it safely renders the graceful fallback text.
      expect(find.text('HTML preview is available on Android and iOS.'), findsOneWidget);
    });
  });
}
