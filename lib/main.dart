import 'package:flutter/material.dart';
import 'core/services/preferences_service.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_theme.dart';
import 'features/files/models/file_item.dart';
import 'features/files/screens/file_manager_screen.dart';
import 'features/files/screens/html_viewer_screen.dart';
import 'features/files/state/files_notifier.dart';
import 'features/health/screens/health_dashboard_screen.dart';
import 'features/health/state/health_notifier.dart';
import 'features/notes/screens/note_editor_screen.dart';
import 'features/notes/screens/notes_list_screen.dart';
import 'features/notes/state/notes_notifier.dart';
import 'features/onboarding/walkthrough_screen.dart';
import 'features/settings/screens/settings_screen.dart';
import 'features/time/screens/time_screen.dart';
import 'features/time/state/time_notifier.dart';
import 'features/vault/screens/vault_screen.dart';
import 'features/vault/state/vault_notifier.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppPreferencesService.instance.initialize();
  runApp(const AllRounderApp());
}

class AllRounderApp extends StatefulWidget {
  final bool? initialHasCompletedOnboarding;

  const AllRounderApp({
    super.key,
    this.initialHasCompletedOnboarding,
  });

  @override
  State<AllRounderApp> createState() => _AllRounderAppState();
}

class _AllRounderAppState extends State<AllRounderApp> {
  bool _isDarkMode = false;
  bool _hasCompletedOnboarding = false;

  late final NotesNotifier _notesNotifier;
  late final FilesNotifier _filesNotifier;
  late final TimeNotifier _timeNotifier;
  late final HealthNotifier _healthNotifier;
  late final VaultNotifier _vaultNotifier;

  @override
  void initState() {
    super.initState();
    _hasCompletedOnboarding = widget.initialHasCompletedOnboarding ??
        AppPreferencesService.instance.hasCompletedOnboarding;
    _notesNotifier = NotesNotifier();
    _filesNotifier = FilesNotifier();
    _timeNotifier = TimeNotifier();
    _healthNotifier = HealthNotifier();
    _vaultNotifier = VaultNotifier();
  }

  @override
  void dispose() {
    _notesNotifier.dispose();
    _filesNotifier.dispose();
    _timeNotifier.dispose();
    _healthNotifier.dispose();
    _vaultNotifier.dispose();
    super.dispose();
  }

  void _toggleTheme(bool dark) {
    setState(() {
      _isDarkMode = dark;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'All-Rounder',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme(),
      darkTheme: AppTheme.darkTheme(),
      themeMode: _isDarkMode ? ThemeMode.dark : ThemeMode.light,
      home: _hasCompletedOnboarding
          ? AppMainShell(
              notesNotifier: _notesNotifier,
              filesNotifier: _filesNotifier,
              timeNotifier: _timeNotifier,
              healthNotifier: _healthNotifier,
              vaultNotifier: _vaultNotifier,
              isDarkMode: _isDarkMode,
              onThemeChanged: _toggleTheme,
              onRelaunchWalkthrough: () {
                setState(() => _hasCompletedOnboarding = false);
              },
            )
          : WalkthroughScreen(
              onFinishOnboarding: () {
                setState(() => _hasCompletedOnboarding = true);
              },
            ),
    );
  }
}

class AppMainShell extends StatefulWidget {
  final NotesNotifier notesNotifier;
  final FilesNotifier filesNotifier;
  final TimeNotifier timeNotifier;
  final HealthNotifier healthNotifier;
  final VaultNotifier vaultNotifier;
  final bool isDarkMode;
  final ValueChanged<bool> onThemeChanged;
  final VoidCallback? onRelaunchWalkthrough;

  const AppMainShell({
    super.key,
    required this.notesNotifier,
    required this.filesNotifier,
    required this.timeNotifier,
    required this.healthNotifier,
    required this.vaultNotifier,
    required this.isDarkMode,
    required this.onThemeChanged,
    this.onRelaunchWalkthrough,
  });

  @override
  State<AppMainShell> createState() => _AppMainShellState();
}

class _AppMainShellState extends State<AppMainShell> {
  int _currentIndex = 0;

  void _openSettings() {
    setState(() => _currentIndex = 4);
  }

  void _openFileManager() {
    setState(() => _currentIndex = 1);
  }

  void _showQuickCaptureModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(22),
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: widget.isDarkMode ? AppColors.surfaceDark : Colors.white,
          borderRadius: BorderRadius.circular(32),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(40),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.irisSubtle,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text(
                    'CREATE OR IMPORT',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.iris,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => Navigator.pop(ctx),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: widget.isDarkMode ? AppColors.surfaceSubtleDark : AppColors.surfaceSubtleLight,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close_rounded, size: 16),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'Add to Your Workspace',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 16),
            // 2x2 Bento Action Grid matching Prototype Modal 1
            Row(
              children: [
                // 1. Markdown Note
                Expanded(
                  child: _buildQuickOption(
                    title: 'Markdown Note',
                    subtitle: 'Plain .md file',
                    icon: Icons.description_rounded,
                    color: const Color(0xFF6246EA),
                    bgTint: const Color(0xFFEAE6FD),
                    onTap: () {
                      Navigator.pop(ctx);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => NoteEditorScreen(
                            notesNotifier: widget.notesNotifier,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 10),
                // 2. HTML Magazine Document
                Expanded(
                  child: _buildQuickOption(
                    title: 'HTML Document',
                    subtitle: 'Custom CSS .html',
                    icon: Icons.code_rounded,
                    color: const Color(0xFFD98200),
                    bgTint: const Color(0xFFFFF4DC),
                    onTap: () {
                      Navigator.pop(ctx);
                      final htmlDocs = widget.filesNotifier.htmlDocuments;
                      if (htmlDocs.isNotEmpty) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => HtmlViewerScreen(
                              fileItem: htmlDocs.first,
                              filesNotifier: widget.filesNotifier,
                            ),
                          ),
                        );
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                // 3. Add Image / File
                Expanded(
                  child: _buildQuickOption(
                    title: 'Add Image / File',
                    subtitle: 'Save to any folder',
                    icon: Icons.add_photo_alternate_rounded,
                    color: const Color(0xFFFF6B57),
                    bgTint: const Color(0xFFFFE6E2),
                    onTap: () {
                      Navigator.pop(ctx);
                      _openFileManager();
                    },
                  ),
                ),
                const SizedBox(width: 10),
                // 4. New Media Folder
                Expanded(
                  child: _buildQuickOption(
                    title: 'New Media Folder',
                    subtitle: 'Photos, PDFs & docs',
                    icon: Icons.create_new_folder_rounded,
                    color: const Color(0xFF289E48),
                    bgTint: const Color(0xFFE3F9E9),
                    onTap: () {
                      Navigator.pop(ctx);
                      _openFileManager();
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickOption({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required Color bgTint,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: widget.isDarkMode ? color.withAlpha(35) : bgTint,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: color.withAlpha(widget.isDarkMode ? 70 : 35),
            width: 1.2,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: Colors.white, size: 20),
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: widget.isDarkMode ? Colors.white : AppColors.inkPrimaryLight,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                color: widget.isDarkMode ? Colors.white60 : AppColors.inkSecondaryLight,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListenableBuilder(
      listenable: Listenable.merge([
        widget.notesNotifier,
        widget.filesNotifier,
        widget.timeNotifier,
        widget.healthNotifier,
        widget.vaultNotifier,
      ]),
      builder: (context, _) {
        final pages = [
          NotesListScreen(
            notesNotifier: widget.notesNotifier,
            filesNotifier: widget.filesNotifier,
            onOpenSettings: _openSettings,
            onOpenFileManager: _openFileManager,
          ),
          FileManagerScreen(
            filesNotifier: widget.filesNotifier,
            onBackToHub: () => setState(() => _currentIndex = 0),
            onOpenSettings: _openSettings,
          ),
          TimeScreen(
            timeNotifier: widget.timeNotifier,
            notesNotifier: widget.notesNotifier,
            onOpenSettings: _openSettings,
          ),
          HealthDashboardScreen(
            healthNotifier: widget.healthNotifier,
            onOpenSettings: _openSettings,
          ),
          SettingsScreen(
            isDarkMode: widget.isDarkMode,
            onThemeChanged: widget.onThemeChanged,
            notesNotifier: widget.notesNotifier,
            timeNotifier: widget.timeNotifier,
            vaultNotifier: widget.vaultNotifier,
            onRelaunchWalkthrough: widget.onRelaunchWalkthrough,
          ),
        ];

        return Scaffold(
          extendBody: true,
          body: Stack(
            children: [
              // Screen content
              IndexedStack(
                index: _currentIndex,
                children: pages,
              ),

              // Floating Stadium Capsule Navigation Dock (Prototype Layout)
              Positioned(
                left: 20,
                right: 20,
                bottom: 20,
                child: SafeArea(
                  child: Container(
                    height: 68,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.dockBgDark : AppColors.dockBgLight,
                      borderRadius: BorderRadius.circular(999),
                      boxShadow: [
                        BoxShadow(
                          color: (isDark ? Colors.black : AppColors.inkPrimaryLight).withAlpha(65),
                          blurRadius: 36,
                          offset: const Offset(0, 16),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Nav 1: Home / Notes (Active: Solid White Circle)
                        _buildDockCircleItem(
                          index: 0,
                          icon: Icons.home_rounded,
                          tooltip: 'Notes',
                          isDark: isDark,
                        ),

                        // Nav 2: Folders, Images & HTML System
                        _buildDockCircleItem(
                          index: 1,
                          icon: Icons.folder_open_rounded,
                          tooltip: 'Files & Folders',
                          isDark: isDark,
                        ),

                        // Center: Multi-Format Quick Capture Button
                        GestureDetector(
                          onTap: _showQuickCaptureModal,
                          child: Container(
                            width: 48,
                            height: 48,
                            decoration: const BoxDecoration(
                              color: AppColors.iris,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Color(0x556246EA),
                                  blurRadius: 16,
                                  offset: Offset(0, 4),
                                ),
                              ],
                            ),
                            child: const Icon(Icons.add_rounded, color: Colors.white, size: 24),
                          ),
                        ),

                        // Nav 3: Schedule & Linked Alarms
                        _buildDockCircleItem(
                          index: 2,
                          icon: Icons.calendar_month_rounded,
                          tooltip: 'Schedule',
                          isDark: isDark,
                        ),

                        // Nav 4: Biometric Vault & Settings
                        _buildDockCircleItem(
                          index: 4,
                          icon: Icons.tune_rounded,
                          tooltip: 'Settings',
                          isDark: isDark,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDockCircleItem({
    required int index,
    required IconData icon,
    required String tooltip,
    required bool isDark,
  }) {
    final isSelected = _currentIndex == index;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => _currentIndex = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          shape: BoxShape.circle,
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withAlpha(25),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Icon(
          icon,
          size: 22,
          color: isSelected
              ? AppColors.inkPrimaryLight
              : Colors.white.withAlpha(160),
        ),
      ),
    );
  }
}
