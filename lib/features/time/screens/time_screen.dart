import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../notes/state/notes_notifier.dart';
import '../../notes/screens/note_editor_screen.dart';
import '../models/time_models.dart';
import '../state/time_notifier.dart';

class TimeScreen extends StatefulWidget {
  final TimeNotifier timeNotifier;
  final NotesNotifier notesNotifier;
  final VoidCallback? onOpenSettings;

  const TimeScreen({
    super.key,
    required this.timeNotifier,
    required this.notesNotifier,
    this.onOpenSettings,
  });

  @override
  State<TimeScreen> createState() => _TimeScreenState();
}

class _TimeScreenState extends State<TimeScreen> with SingleTickerProviderStateMixin {
  int _selectedSubTab = 0; // 0 = Alarms & Reminders, 1 = Class Timetable
  int _selectedDayIndex = 3; // Default to Wed (index 3, matching Image 2: Wed 25!)

  final List<Map<String, dynamic>> _weekDays = [
    {'day': 'Sun', 'date': '22', 'dot': Colors.transparent},
    {'day': 'Mon', 'date': '23', 'dot': AppColors.iris},
    {'day': 'Tue', 'date': '24', 'dot': Colors.transparent},
    {'day': 'Wed', 'date': '25', 'dot': AppColors.bentoMarigold}, // Active in Image 2
    {'day': 'Thu', 'date': '26', 'dot': Colors.transparent},
    {'day': 'Fri', 'date': '27', 'dot': AppColors.bentoCoral},
    {'day': 'Sat', 'date': '28', 'dot': AppColors.bentoEmerald},
  ];

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
            // 1. TOP HEADER (Avatar LA + Schedule & Linked Alarms / Your Plan + Search + Sliders matching Image 2)
            Row(
              children: [
                GestureDetector(
                  onTap: () {
                    if (widget.onOpenSettings != null) {
                      widget.onOpenSettings!();
                    }
                  },
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
                        'Schedule & Linked Alarms',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isDark ? AppColors.inkSecondaryDark : AppColors.inkSecondaryLight,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        'Your Plan',
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
                _buildCircleButton(
                  icon: Icons.search_rounded,
                  tooltip: 'Search',
                  isDark: isDark,
                  onTap: () {},
                ),
                const SizedBox(width: 10),
                _buildCircleButton(
                  icon: Icons.tune_rounded,
                  tooltip: 'Settings',
                  isDark: isDark,
                  onTap: () {
                    if (widget.onOpenSettings != null) {
                      widget.onOpenSettings!();
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 2. VERTICAL CAPSULE DATE STRIP (Sun 22 - Sat 28 matching Image 2 exactly)
            SizedBox(
              height: 72,
              child: Row(
                children: List.generate(7, (i) {
                  final item = _weekDays[i];
                  final isSelected = _selectedDayIndex == i;

                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: GestureDetector(
                        onTap: () => setState(() => _selectedDayIndex = i),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          height: 72,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.inkPrimaryLight // Solid Obsidian Black for Active (Wed 25)
                                : (isDark ? AppColors.surfaceDark : Colors.white),
                            borderRadius: BorderRadius.circular(999),
                            border: isSelected || isDark
                                ? null
                                : Border.all(
                                    color: const Color(0xFFE8E6E1),
                                    width: 1.5,
                                  ),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: Colors.black.withAlpha(40),
                                      blurRadius: 14,
                                      offset: const Offset(0, 5),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Top Status Dot
                              Container(
                                width: 5,
                                height: 5,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isSelected ? AppColors.bentoMarigold : (item['dot'] as Color),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                item['day'] as String,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: isSelected
                                      ? Colors.white.withAlpha(190)
                                      : (isDark ? AppColors.inkSecondaryDark : AppColors.inkSecondaryLight),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                item['date'] as String,
                                maxLines: 1,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w900,
                                  color: isSelected
                                      ? Colors.white
                                      : (isDark ? AppColors.inkPrimaryDark : AppColors.inkPrimaryLight),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(height: 18),

            // 3. SEGMENTED SUB-TAB CAPSULE SWITCHER (Alarms & Reminders vs Class Timetable)
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceSubtleDark : AppColors.surfaceSubtleLight,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedSubTab = 0),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(vertical: 9),
                        decoration: BoxDecoration(
                          color: _selectedSubTab == 0 ? AppColors.iris : Colors.transparent,
                          borderRadius: BorderRadius.circular(999),
                          boxShadow: _selectedSubTab == 0
                              ? [
                                  BoxShadow(
                                    color: AppColors.iris.withAlpha(60),
                                    blurRadius: 10,
                                    offset: const Offset(0, 3),
                                  ),
                                ]
                              : null,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '⏰ Alarms & Reminders',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: _selectedSubTab == 0
                                    ? Colors.white
                                    : (isDark ? AppColors.inkSecondaryDark : AppColors.inkSecondaryLight),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedSubTab = 1),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(vertical: 9),
                        decoration: BoxDecoration(
                          color: _selectedSubTab == 1 ? AppColors.iris : Colors.transparent,
                          borderRadius: BorderRadius.circular(999),
                          boxShadow: _selectedSubTab == 1
                              ? [
                                  BoxShadow(
                                    color: AppColors.iris.withAlpha(60),
                                    blurRadius: 10,
                                    offset: const Offset(0, 3),
                                  ),
                                ]
                              : null,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '🗓️ Class Timetable',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: _selectedSubTab == 1
                                    ? Colors.white
                                    : (isDark ? AppColors.inkSecondaryDark : AppColors.inkSecondaryLight),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // 4. SUB-TAB CONTENT
            if (_selectedSubTab == 0) ...[
              // Section Header: ACTIVE ALARMS · ZERO OVERFLOW
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'ACTIVE ALARMS · ZERO OVERFLOW',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                      color: isDark ? AppColors.inkSecondaryDark : AppColors.inkSecondaryLight,
                    ),
                  ),
                  const Text(
                    'Exact Alarm Ready ✓',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: AppColors.iris,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // ALARM 1: 06:30 (Morning routine)
              _buildAlarmCard(
                time: '06:30',
                title: 'Wake Up & Morning Routine',
                badgeColor: const Color(0xFFFFF4DC),
                iconColor: const Color(0xFFD98200),
                icon: Icons.wb_sunny_rounded,
                isEnabled: true,
                isDark: isDark,
              ),

              // ALARM 2: 08:30 (In 50m + Constrained Link Pill)
              _buildAlarmCard(
                time: '08:30',
                timeBadge: 'In 50m',
                title: 'Prep for Physics Lecture',
                badgeColor: const Color(0xFFEAE6FD),
                iconColor: AppColors.iris,
                icon: Icons.notifications_active_rounded,
                linkText: 'Physics Lecture: Wave Mechanics',
                linkBgColor: const Color(0xFFFFF4DC),
                linkTextColor: const Color(0xFF9A5B00),
                isEnabled: true,
                isDark: isDark,
                onLinkTap: () {
                  final note = widget.notesNotifier.getNoteById('note_1');
                  if (note != null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => NoteEditorScreen(
                          note: note,
                          notesNotifier: widget.notesNotifier,
                        ),
                      ),
                    );
                  }
                },
              ),

              // ALARM 3: 18:00 (Daily Exercise Quota Check)
              _buildAlarmCard(
                time: '18:00',
                title: 'Daily Exercise Quota Check',
                badgeColor: const Color(0xFFE3F9E9),
                iconColor: const Color(0xFF289E48),
                icon: Icons.monitor_heart_rounded,
                linkText: 'Daily Fitness Log & Quota',
                linkBgColor: const Color(0xFFE3F9E9),
                linkTextColor: const Color(0xFF1A7F37),
                isEnabled: true,
                isDark: isDark,
                onLinkTap: () {
                  final note = widget.notesNotifier.getNoteById('note_3');
                  if (note != null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => NoteEditorScreen(
                          note: note,
                          notesNotifier: widget.notesNotifier,
                        ),
                      ),
                    );
                  }
                },
              ),
            ] else ...[
              // TIMETABLE VIEW (Bento Class Cards matching prototype)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Wednesday Slots',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: isDark ? AppColors.inkPrimaryDark : AppColors.inkPrimaryLight,
                    ),
                  ),
                  const Text(
                    'CSV / ICS Imported',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.iris,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  // Class 1 (Marigold)
                  Expanded(
                    child: Container(
                      height: 175,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.bentoMarigold,
                        borderRadius: BorderRadius.circular(26),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.white.withAlpha(140),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: const Text(
                                  '09:00 - 10:30',
                                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800),
                                ),
                              ),
                              const SizedBox(height: 10),
                              const Text(
                                'Wave Mechanics',
                                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, height: 1.15),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Room A5 · Hall 2',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF4A3805)),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.black.withAlpha(20),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: const Text(
                              '🔗 1 Lecture Note',
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Class 2 (Periwinkle)
                  Expanded(
                    child: Container(
                      height: 175,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.bentoPeriwinkle,
                        borderRadius: BorderRadius.circular(26),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.white.withAlpha(140),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: const Text(
                                  '14:00 - 15:30',
                                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800),
                                ),
                              ),
                              const SizedBox(height: 10),
                              const Text(
                                'Systems Design',
                                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, height: 1.15),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Lab B2 · CS Wing',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF2C3E5A)),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.black.withAlpha(20),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: const Text(
                              '🔗 Drift Schema Note',
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCircleButton({
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
            color: Colors.black.withAlpha(isDark ? 35 : 12),
            blurRadius: 10,
            offset: const Offset(0, 3),
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

  Widget _buildAlarmCard({
    required String time,
    String? timeBadge,
    required String title,
    required Color badgeColor,
    required Color iconColor,
    required IconData icon,
    String? linkText,
    Color? linkBgColor,
    Color? linkTextColor,
    required bool isEnabled,
    required bool isDark,
    VoidCallback? onLinkTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: isDark ? null : Border.all(
          color: AppColors.borderLight,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(isDark ? 25 : 8),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Left Icon Badge
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: isDark ? badgeColor.withAlpha(40) : badgeColor,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(width: 14),

          // Middle Column (Wrapped in Expanded with Ellipsis - GUARANTEED ZERO OVERFLOW)
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      time,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.4,
                        color: isDark ? AppColors.inkPrimaryDark : AppColors.inkPrimaryLight,
                      ),
                    ),
                    if (timeBadge != null) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.irisSubtle,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          timeBadge,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: AppColors.iris,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.inkSecondaryDark : AppColors.inkSecondaryLight,
                  ),
                ),
                if (linkText != null) ...[
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: onLinkTap,
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 180),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.surfaceSubtleDark : (linkBgColor ?? AppColors.surfaceSubtleLight),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.link_rounded,
                            size: 12,
                            color: isDark ? AppColors.irisLight : (linkTextColor ?? AppColors.iris),
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              linkText,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: isDark ? AppColors.irisLight : (linkTextColor ?? AppColors.iris),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),

          // Right Switch (Iris purple track with white circular thumb matching Screenshot 1)
          Transform.scale(
            scale: 0.85,
            child: Switch(
              value: isEnabled,
              activeTrackColor: AppColors.iris,
              activeColor: Colors.white,
              inactiveTrackColor: isDark ? const Color(0xFF2A2D3A) : const Color(0xFFD8D5CE),
              inactiveThumbColor: Colors.white,
              trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
              onChanged: (val) {},
            ),
          ),
        ],
      ),
    );
  }
}
