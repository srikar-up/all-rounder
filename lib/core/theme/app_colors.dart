import 'package:flutter/material.dart';

/// Tactile Bento Design System Tokens
/// Defined in design_system_positioning_ux_walkthrough_plan.md and prototype
class AppColors {
  // Canvas & Surfaces
  static const Color canvasLight = Color(0xFFFAF8F5); // Warm Alabaster canvas
  static const Color canvasDark = Color(0xFF0F1015);  // Deep Obsidian night
  
  static const Color surfaceLight = Color(0xFFFFFFFF); // Elevated Pure White card
  static const Color surfaceDark = Color(0xFF181A22);  // Night elevated card
  
  static const Color surfaceSubtleLight = Color(0xFFF1EFEA); // Inactive pill / search fill
  static const Color surfaceSubtleDark = Color(0xFF222530);  // Dark inactive pill
  
  static const Color borderLight = Color(0x0F141416); // Subtle 6% border
  static const Color borderDark = Color(0x1FFFFFFF);  // Subtle dark border

  // Inks & Typography
  static const Color inkPrimaryLight = Color(0xFF141416);   // Deep obsidian ink
  static const Color inkPrimaryDark = Color(0xFFF5F6FA);    // Off-white crisp ink
  static const Color inkSecondaryLight = Color(0xFF6E717A); // Warm neutral subtitle
  static const Color inkSecondaryDark = Color(0xFF9CA0AB);  // Muted night subtitle

  // Brand Accent
  static const Color iris = Color(0xFF6246EA);      // Royal Iris primary accent
  static const Color irisLight = Color(0xFF7C66F5); // Light Iris for dark mode
  static const Color irisSubtle = Color(0xFFEAE6FD); // Tinted pill background

  // Tactile Bento Colors (Section 3.1)
  static const Color bentoMarigold = Color(0xFFFDBE58);   // Morning Focus / Projects
  static const Color marigoldSubtle = Color(0xFFFFF4DC);  // Warm soft marigold tint
  static const Color marigoldDark = Color(0xFFB57700);    // High-contrast gold accent
  static const Color bentoCoral = Color(0xFFFF6B57);      // Alarms / Urgent / Exams
  static const Color bentoCoralSubtle = Color(0xFFFFE6E2); // Soft Coral badge
  static const Color bentoPeriwinkle = Color(0xFFB4D2FF); // Timetable / Balance / Inbox
  static const Color bentoLavender = Color(0xFFB19CFF);   // Daily Note / Hero banner
  static const Color bentoEmerald = Color(0xFF3CC162);    // Fitness Quota / Habits
  static const Color bentoEmeraldSubtle = Color(0xFFE3F7E9);
  static const Color bentoPink = Color(0xFFFF9CE9);       // Quick Capture

  // Dock & Capsule
  static const Color dockBgLight = Color(0xFF141416); // Floating Obsidian capsule dock
  static const Color dockBgDark = Color(0xFF1E202B);  // Floating Dark capsule dock

  // Legacy mappings for backwards compatibility
  static const Color primary = iris;
  static const Color primaryLight = irisLight;
  static const Color bgLight = canvasLight;
  static const Color bgDark = canvasDark;
  static const Color textLight = inkPrimaryLight;
  static const Color textDark = inkPrimaryDark;
  static const Color textMutedLight = inkSecondaryLight;
  static const Color textMutedDark = inkSecondaryDark;
  static const Color success = bentoEmerald;
  static const Color warning = bentoMarigold;
  static const Color error = bentoCoral;
  static const Color purple = bentoLavender;
  static const Color cyan = bentoPeriwinkle;
  static const Color rose = bentoPink;
}
