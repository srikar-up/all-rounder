import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:all_rounder/main.dart';
import 'package:all_rounder/services/vault/vault_storage_service.dart';
import 'package:all_rounder/features/vault/state/vault_notifier.dart';

void main() {
  testWidgets('All-Rounder launches and renders exact Bento UI matching prototype',
      (WidgetTester tester) async {
    // Set screen size to standard modern mobile viewport (390 x 844)
    tester.view.physicalSize = const Size(390 * 2, 844 * 2);
    tester.view.devicePixelRatio = 2.0;

    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const AllRounderApp(initialHasCompletedOnboarding: true));
    await tester.pumpAndSettle();

    // 1. Verify Notes screen Bento headers matching Prototype
    expect(find.text('laddu!'), findsOneWidget);
    expect(find.text('LA'), findsOneWidget);
    expect(find.text('Morning Focus &\nPlan'), findsOneWidget);
    expect(find.text('+Add Media'), findsOneWidget);
    expect(find.text('Folders & File Spaces'), findsOneWidget);
    expect(find.text('Open File Manager'), findsOneWidget);
    expect(find.text('Whiteboard & Photos'), findsOneWidget);
    expect(find.text('HTML Documents'), findsOneWidget);
    expect(find.text('Pinned Notes'), findsOneWidget);
    expect(find.text('Quantum Wave\nInteractive Sheet'), findsOneWidget);

    // 2. Navigate to Folders & Media tab using Dock Icon
    await tester.tap(find.byTooltip('Files & Folders'));
    await tester.pumpAndSettle();

    // Verify Dedicated File Manager System
    expect(find.text('On-Device File System'), findsOneWidget);
    expect(find.text('Folders, Images, Files & HTML'), findsOneWidget);
    expect(find.text('4 Folders'), findsOneWidget);
    expect(find.text('Standalone Images in Folder'), findsOneWidget);
    expect(find.text('HTML Document System (.html)'), findsOneWidget);
    expect(find.text('Quantum Wave Interactive Sheet.html'), findsOneWidget);

    // 3. Test opening the HTML Magazine Viewer
    await tester.tap(find.text('Quantum Wave Interactive Sheet.html'));
    await tester.pumpAndSettle();
    expect(find.text('🎨 Rendered Magazine View'), findsOneWidget);
    expect(find.text('💻 Edit HTML / CSS Source'), findsOneWidget);
    expect(find.text('PHYS-301 · VISUAL ZINE'), findsOneWidget);

    // Go back from HTML Viewer
    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await tester.pumpAndSettle();

    // 4. Navigate to Schedule tab using Dock Icon
    await tester.tap(find.byTooltip('Schedule'));
    await tester.pumpAndSettle();

    // Verify Schedule screen headers matching Prototype
    expect(find.text('Your Plan'), findsOneWidget);
    expect(find.text('⏰ Alarms & Reminders'), findsOneWidget);
    expect(find.text('ACTIVE ALARMS · ZERO OVERFLOW'), findsOneWidget);
    expect(find.text('Prep for Physics Lecture'), findsOneWidget);
    expect(find.text('Physics Lecture: Wave Mechanics'), findsOneWidget);

    // 5. Navigate to Settings tab
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    expect(find.text('Data & Privacy'), findsOneWidget);
    expect(find.text('Local-First Architecture'), findsOneWidget);
    expect(find.text('Privacy Guarantee'), findsOneWidget);
    expect(find.text('100% Local-First'), findsOneWidget);
    expect(find.text('Your files live on this phone'), findsOneWidget);
    expect(find.text('Appearance'), findsOneWidget);
    expect(find.text('On-Device Notes Folder'), findsOneWidget);
    expect(find.text('Export Full Backup (.ZIP)'), findsOneWidget);
    expect(find.text('Encrypted Drive Backup'), findsOneWidget);
  });

  testWidgets('First-launch Walkthrough gates app and completes 3-step Bento onboarding',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(390 * 2, 844 * 2);
    tester.view.devicePixelRatio = 2.0;

    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    // Start with onboarding NOT completed
    await tester.pumpWidget(const AllRounderApp(initialHasCompletedOnboarding: false));
    await tester.pumpAndSettle();

    // STEP 1: Positioning & Core Promise
    expect(find.text('Your private\nsecond brain.'), findsOneWidget);
    expect(find.text('🔒 100% On-Device · Zero Cloud'), findsOneWidget);
    expect(find.text('Choose Your Bento Folders'), findsOneWidget);

    // Advance to Step 2
    await tester.tap(find.text('Choose Your Bento Folders'));
    await tester.pumpAndSettle();

    // STEP 2: Personalize Bento Spaces
    expect(find.text('Pick your Bento spaces'), findsOneWidget);
    expect(find.text('Lectures'), findsOneWidget);
    expect(find.text('Media & Scans'), findsOneWidget);
    expect(find.text('HTML Zines'), findsOneWidget);
    expect(find.text('Fitness Log'), findsOneWidget);

    // Advance to Step 3
    await tester.tap(find.text('Security & Magic Link'));
    await tester.pumpAndSettle();

    // STEP 3: Vault Quick Setup & Link Graph Demo
    expect(find.text('Link Notes & Arm Your Vault'), findsOneWidget);
    expect(find.text('Your 12-Word Recovery Key'), findsOneWidget);
    expect(find.text('Biometric Authentication'), findsOneWidget);

    // Interact with the Magic Link demo
    await tester.tap(find.text('Tap to Link to 08:30 Alarm'));
    await tester.pumpAndSettle();
    expect(find.text('Linked to 08:30 Alarm ✓'), findsOneWidget);

    // Confirm recovery key
    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();

    // Enter All-Rounder
    await tester.tap(find.text('Enter All-Rounder'));
    await tester.pumpAndSettle();

    // Must transition smoothly into Bento Home Hub
    expect(find.text('laddu!'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Quick Capture modal shows 4 options matching Prototype',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(390 * 2, 844 * 2);
    tester.view.devicePixelRatio = 2.0;

    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const AllRounderApp(initialHasCompletedOnboarding: true));
    await tester.pumpAndSettle();

    // Tap Center Add Button in Dock
    await tester.tap(find.byIcon(Icons.add_rounded));
    await tester.pumpAndSettle();

    expect(find.text('CREATE OR IMPORT'), findsOneWidget);
    expect(find.text('Add to Your Workspace'), findsOneWidget);
    expect(find.text('Markdown Note'), findsOneWidget);
    expect(find.text('HTML Document'), findsOneWidget);
    expect(find.text('Add Image / File'), findsOneWidget);
    expect(find.text('New Media Folder'), findsOneWidget);
  });

  testWidgets('Renders without overflow on narrow 360dp screen in both Walkthrough and Hub',
      (WidgetTester tester) async {
    // Constrain to narrow 360dp phone width
    tester.view.physicalSize = const Size(360 * 2, 740 * 2);
    tester.view.devicePixelRatio = 2.0;

    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    // Test walkthrough on 360dp screen
    await tester.pumpWidget(const AllRounderApp(initialHasCompletedOnboarding: false));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    // Advance to Step 3 on 360dp screen
    await tester.tap(find.text('Choose Your Bento Folders'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Security & Magic Link'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    // Skip to App
    await tester.tap(find.text('Skip to App →'));
    await tester.pumpAndSettle();

    // Verify Notes screen has no overflow exception
    expect(find.text('laddu!'), findsOneWidget);
    expect(tester.takeException(), isNull);

    // Navigate to Schedule
    await tester.tap(find.byTooltip('Schedule'));
    await tester.pumpAndSettle();

    // Verify linked note badge is rendered without error
    expect(find.text('Physics Lecture: Wave Mechanics'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('Cryptomator vault engine encrypts, stores, decrypts to memory and shreds safely',
      () async {
    final vaultService = VaultStorageService.instance;
    await vaultService.initialize();

    const sampleText = 'TOP_SECRET_CONFIDENTIAL_PAYLOAD_2026';
    final sampleBytes = Uint8List.fromList(utf8.encode(sampleText));

    // 1. Ingestion: Encrypt arbitrary binary/document file
    final encryptedFile = await vaultService.encryptAndStoreBytes(
      bytes: sampleBytes,
      originalName: 'Secret_Research_Doc.pdf',
      mimeType: 'application/pdf',
    );

    expect(encryptedFile.originalName, equals('Secret_Research_Doc.pdf'));
    expect(encryptedFile.obfuscatedPath.endsWith('.c9r'), isTrue);
    expect(encryptedFile.obfuscatedPath.contains('Secret_Research_Doc'), isFalse);
    expect(encryptedFile.fileSizeBytes, equals(sampleBytes.length));

    // 2. In-Memory Decryption: Zero-leak buffer
    final decryptedBytes = await vaultService.decryptToMemory(encryptedFile.id);
    final decryptedText = utf8.decode(decryptedBytes);
    expect(decryptedText, equals(sampleText));

    // 3. VaultNotifier state integration
    final notifier = VaultNotifier();
    await notifier.initialize();
    expect(notifier.encryptedFiles.isNotEmpty, isTrue);

    // 4. Secure Shredding: Multi-pass erase
    final initialCount = vaultService.files.length;
    await vaultService.shredFile(encryptedFile.id);
    expect(vaultService.files.length, equals(initialCount - 1));
  });
}
