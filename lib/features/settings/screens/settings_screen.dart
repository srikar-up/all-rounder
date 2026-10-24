import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../notes/state/notes_notifier.dart';
import '../../time/state/time_notifier.dart';
import '../../vault/state/vault_notifier.dart';
import '../../vault/screens/vault_screen.dart';
import '../../link_graph/screens/link_graph_screen.dart';

class SettingsScreen extends StatefulWidget {
  final bool isDarkMode;
  final ValueChanged<bool> onThemeChanged;
  final NotesNotifier notesNotifier;
  final TimeNotifier timeNotifier;
  final VaultNotifier vaultNotifier;
  final VoidCallback? onRelaunchWalkthrough;

  const SettingsScreen({
    super.key,
    required this.isDarkMode,
    required this.onThemeChanged,
    required this.notesNotifier,
    required this.timeNotifier,
    required this.vaultNotifier,
    this.onRelaunchWalkthrough,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _driveBackupEnabled = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.canvasDark : AppColors.canvasLight,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 110),
          children: [
            // 1. TOP HEADER (Avatar LA + Local-First Architecture / Data & Privacy + Search + Sliders matching Screenshot 3)
            Row(
              children: [
                GestureDetector(
                  onTap: () {},
                  child: Stack(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: AppColors.bentoMarigold,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withAlpha(isDark ? 30 : 15),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: const Text(
                          'LA',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            color: AppColors.inkPrimaryLight,
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: const Color(0xFF3CC162),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isDark ? AppColors.canvasDark : AppColors.canvasLight,
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),

                // Subtitle + Title
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Local-First Architecture',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isDark ? AppColors.inkSecondaryDark : AppColors.inkSecondaryLight,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        'Data & Privacy',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.6,
                          color: isDark ? AppColors.inkPrimaryDark : AppColors.inkPrimaryLight,
                        ),
                      ),
                    ],
                  ),
                ),

                // Search & Filter Circle Buttons
                _buildTopCircleButton(
                  icon: Icons.search_rounded,
                  tooltip: 'Search',
                  isDark: isDark,
                  onTap: () {},
                ),
                const SizedBox(width: 10),
                _buildTopCircleButton(
                  icon: Icons.tune_rounded,
                  tooltip: 'Settings',
                  isDark: isDark,
                  onTap: () {},
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 2. HERO ROYAL IRIS BENTO CARD (Matching Screenshot 3)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.iris,
                borderRadius: BorderRadius.circular(26),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.iris.withAlpha(isDark ? 60 : 75),
                    blurRadius: 22,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Row: Privacy Guarantee pill + 100% Local-First
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(45),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Text(
                          'Privacy Guarantee',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const Text(
                        '100% Local-First',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Main Title
                  const Text(
                    'Your files live on this phone',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.4,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 3),

                  // Subtitle
                  Text(
                    'No accounts or tracking servers. Your notes are standard Markdown files you own forever.',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.35,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withAlpha(210),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 3. WHITE DIVIDED CONTAINER CARD (4 exact rows from Screenshot 3)
            Container(
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceDark : Colors.white,
                borderRadius: BorderRadius.circular(26),
                border: isDark ? null : Border.all(
                  color: AppColors.borderLight,
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(isDark ? 25 : 8),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // ROW 1: Appearance
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF4DC),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(
                            Icons.wb_sunny_outlined,
                            color: Color(0xFFD98200),
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Appearance',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.2,
                                  color: isDark ? AppColors.inkPrimaryDark : AppColors.inkPrimaryLight,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Warm Alabaster / Deep Obsidian',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: isDark ? AppColors.inkSecondaryDark : AppColors.inkSecondaryLight,
                                ),
                              ),
                            ],
                          ),
                        ),
                        GestureDetector(
                          onTap: () => widget.onThemeChanged(!widget.isDarkMode),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF252834) : const Color(0xFFF1EFEA),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              'Switch Theme',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w800,
                                color: isDark ? Colors.white : AppColors.inkPrimaryLight,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Divider(
                    height: 1,
                    indent: 74,
                    color: isDark ? AppColors.dividerDark : const Color(0xFFF1EFEA),
                  ),

                  // ROW 2: On-Device Notes Folder
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: const Color(0xFFEAE6FD),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(
                            Icons.folder_outlined,
                            color: AppColors.iris,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'On-Device Notes Folder',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.2,
                                  color: isDark ? AppColors.inkPrimaryDark : AppColors.inkPrimaryLight,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${widget.notesNotifier.allNotes.length} Markdown notes · 6 schedule links',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: isDark ? AppColors.inkSecondaryDark : AppColors.inkSecondaryLight,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Text(
                          'Synced',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF3CC162),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Divider(
                    height: 1,
                    indent: 74,
                    color: isDark ? AppColors.dividerDark : const Color(0xFFF1EFEA),
                  ),

                  // ROW 3: Export Full Backup (.ZIP)
                  InkWell(
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Exporting all markdown notes & photos to backup ZIP...')),
                      );
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: const Color(0xFFE3F9E9),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(
                              Icons.download_rounded,
                              color: Color(0xFF289E48),
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Export Full Backup (.ZIP)',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.2,
                                    color: isDark ? AppColors.inkPrimaryDark : AppColors.inkPrimaryLight,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'All notes & photos, zero lock-in',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: isDark ? AppColors.inkSecondaryDark : AppColors.inkSecondaryLight,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.chevron_right_rounded,
                            size: 20,
                            color: isDark ? AppColors.inkSecondaryDark : AppColors.inkSecondaryLight,
                          ),
                        ],
                      ),
                    ),
                  ),
                  Divider(
                    height: 1,
                    indent: 74,
                    color: isDark ? AppColors.dividerDark : const Color(0xFFF1EFEA),
                  ),

                  // ROW 4: Encrypted Drive Backup
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: const Color(0xFFEBF3FF),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(
                            Icons.cloud_outlined,
                            color: Color(0xFF2B6CB0),
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Encrypted Drive Backup',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.2,
                                  color: isDark ? AppColors.inkPrimaryDark : AppColors.inkPrimaryLight,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Optional · Private app folder only',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: isDark ? AppColors.inkSecondaryDark : AppColors.inkSecondaryLight,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Transform.scale(
                          scale: 0.85,
                          child: Switch(
                            value: _driveBackupEnabled,
                            activeTrackColor: AppColors.iris,
                            activeColor: Colors.white,
                            inactiveTrackColor: isDark ? const Color(0xFF2A2D3A) : const Color(0xFFD8D5CE),
                            inactiveThumbColor: Colors.white,
                            trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
                            onChanged: (val) {
                              setState(() => _driveBackupEnabled = val);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    val
                                        ? 'Drive backup active · Scoped strictly to private app folder.'
                                        : 'Drive backup disabled. 100% on-device storage.',
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // 4. SECONDARY SECTION: LINK GRAPH & BIOMETRIC VAULT LINK
            Container(
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceDark : Colors.white,
                borderRadius: BorderRadius.circular(26),
                border: isDark ? null : Border.all(
                  color: AppColors.borderLight,
                  width: 1.5,
                ),
              ),
              child: Column(
                children: [
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.bentoEmeraldSubtle,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.hub_outlined, color: AppColors.bentoEmerald, size: 20),
                    ),
                    title: const Text('Knowledge Link Graph', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                    subtitle: const Text('Inspect relations between notes & schedule', style: TextStyle(fontSize: 12)),
                    trailing: const Icon(Icons.chevron_right_rounded, size: 20),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => LinkGraphScreen(
                            notesNotifier: widget.notesNotifier,
                            timeNotifier: widget.timeNotifier,
                          ),
                        ),
                      );
                    },
                  ),
                  Divider(
                    height: 1,
                    indent: 60,
                    color: isDark ? AppColors.dividerDark : const Color(0xFFF1EFEA),
                  ),
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.irisSubtle,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.shield_rounded, color: AppColors.iris, size: 20),
                    ),
                    title: const Text('Biometric Hardware Vault', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                    subtitle: const Text('AES-256-GCM · Keystore protected secrets', style: TextStyle(fontSize: 12)),
                    trailing: const Icon(Icons.chevron_right_rounded, size: 20),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => VaultScreen(
                            vaultNotifier: widget.vaultNotifier,
                          ),
                        ),
                      );
                    },
                  ),
                  if (widget.onRelaunchWalkthrough != null) ...[
                    Divider(height: 1, indent: 60, color: isDark ? AppColors.dividerDark : const Color(0xFFF1EFEA)),
                    ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.marigoldSubtle,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.explore_rounded, color: AppColors.marigoldDark, size: 20),
                      ),
                      title: const Text('Relaunch First-Launch Primer', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                      subtitle: const Text('Revisit private second brain setup & bento spaces', style: TextStyle(fontSize: 12)),
                      trailing: const Icon(Icons.chevron_right_rounded, size: 20),
                      onTap: widget.onRelaunchWalkthrough,
                    ),
                  ],
                ],
              ),
            ),
          const SizedBox(height: 30),

          // Footer
          Center(
            child: Text(
              'All-Rounder v1.0.0\nYour personal day OS · 100% on your phone',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: isDark ? AppColors.inkSecondaryDark : AppColors.inkSecondaryLight,
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    ),
  );
}

  Widget _buildTopCircleButton({
    required IconData icon,
    required String tooltip,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(isDark ? 30 : 12),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: IconButton(
        icon: Icon(
          icon,
          size: 19,
          color: isDark ? AppColors.inkPrimaryDark : AppColors.inkPrimaryLight,
        ),
        tooltip: tooltip,
        padding: EdgeInsets.zero,
        onPressed: onTap,
      ),
    );
  }

  Widget _buildPromiseRow(String title, String desc, bool isDark) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 2),
          child: Icon(Icons.check_circle_rounded, size: 15, color: AppColors.bentoEmerald),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: TextStyle(
                fontSize: 13,
                height: 1.35,
                color: isDark ? AppColors.inkSecondaryDark : AppColors.inkSecondaryLight,
              ),
              children: [
                TextSpan(
                  text: '$title: ',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: isDark ? AppColors.inkPrimaryDark : AppColors.inkPrimaryLight,
                  ),
                ),
                TextSpan(text: desc),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
