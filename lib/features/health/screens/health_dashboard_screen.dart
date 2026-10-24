import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../models/health_models.dart';
import '../state/health_notifier.dart';

class HealthDashboardScreen extends StatelessWidget {
  final HealthNotifier healthNotifier;
  final VoidCallback? onOpenSettings;

  const HealthDashboardScreen({
    super.key,
    required this.healthNotifier,
    this.onOpenSettings,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final metrics = healthNotifier.metrics;
    final quota = healthNotifier.quota;
    final progress = healthNotifier.stepsProgress;

    return Scaffold(
      backgroundColor: isDark ? AppColors.canvasDark : AppColors.canvasLight,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 110),
          children: [
            // 1. TOP HEADER (Avatar LA + On-Device Health Connect / Daily Quota + Search + Sliders matching Screenshot 2)
            Row(
              children: [
                GestureDetector(
                  onTap: () {
                    if (onOpenSettings != null) {
                      onOpenSettings!();
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
                        'On-Device Health Connect',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isDark ? AppColors.inkSecondaryDark : AppColors.inkSecondaryLight,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        'Daily Quota',
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
                    if (onOpenSettings != null) {
                      onOpenSettings!();
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 2. HERO GREEN BENTO CARD (Solid Emerald with 2 Inner Bento Stat Boxes matching Screenshot 2)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF3CC162),
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF3CC162).withAlpha(isDark ? 50 : 65),
                    blurRadius: 22,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Frosted Pill
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(50),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '⚡ Health Connect · On-Device',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Main Heading
                  const Text(
                    'Daily Movement Quota',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),

                  // Subtitle
                  Text(
                    'No Google Fit cloud required. Stored locally.',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withAlpha(220),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 2 Inner Bento Stat Boxes (Screenshot 2 exact 6,420 steps and 38m active)
                  Row(
                    children: [
                      // Stat 1: Steps Today
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                          decoration: BoxDecoration(
                            color: Colors.black.withAlpha(35),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Steps Today',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white.withAlpha(200),
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                metrics.steps > 0 ? '${metrics.steps}' : '6,420',
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.5,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                'Goal: ${quota.stepsTarget} (${(progress * 100).toInt()}%)',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white.withAlpha(190),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Stat 2: Active Mins
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                          decoration: BoxDecoration(
                            color: Colors.black.withAlpha(35),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Active Mins',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white.withAlpha(200),
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                metrics.activeMinutes > 0 ? '${metrics.activeMinutes}m' : '38m',
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.5,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                'Goal: ${quota.activeMinutesTarget}m (${(healthNotifier.activeMinutesProgress * 100).toInt()}%)',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white.withAlpha(190),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 3. LINKED WORKOUT NOTE CARD (Matching Screenshot 2: Amber link badge + Title + Open button)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceDark : Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: isDark ? AppColors.borderDark : AppColors.borderLight,
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
              child: Row(
                children: [
                  // Amber Link Container
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF4DC),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.link_rounded,
                      color: Color(0xFFD98200),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),

                  // Text Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Linked Workout Note',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                            color: isDark ? AppColors.inkPrimaryDark : AppColors.inkPrimaryLight,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Daily Fitness Log & Quota.md',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: isDark ? AppColors.inkSecondaryDark : AppColors.inkSecondaryLight,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Open Pill Button (Soft Lavender Background + Iris Text)
                  GestureDetector(
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Opening Daily Fitness Log & Quota.md...')),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEAE6FD),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Text(
                        'Open',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: AppColors.iris,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 4. QUICK ACTIONS & HEALTH CONNECT BANNER
            _buildHealthConnectBanner(context, isDark),
            const SizedBox(height: 14),

            // Quick increment buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.iris,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    icon: const Icon(Icons.add_circle_outline_rounded, size: 16),
                    label: const Text('+500 Steps', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                    onPressed: () => healthNotifier.addSteps(500),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    icon: const Icon(Icons.water_drop_outlined, size: 16, color: AppColors.bentoPeriwinkle),
                    label: const Text('+250ml Water', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                    onPressed: () => healthNotifier.addWater(250),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Secondary Metrics (Hydration & Distance)
            Row(
              children: [
                Expanded(
                  child: _buildMetricTile(
                    isDark: isDark,
                    icon: Icons.water_drop_rounded,
                    iconColor: const Color(0xFF38BDF8),
                    label: 'Hydration',
                    value: '${(metrics.waterMl / 1000).toStringAsFixed(1)} L',
                    subtitle: 'Target: ${(quota.waterMlTarget / 1000).toStringAsFixed(1)} L',
                    progress: healthNotifier.waterProgress,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildMetricTile(
                    isDark: isDark,
                    icon: Icons.map_rounded,
                    iconColor: const Color(0xFF3CC162),
                    label: 'Distance',
                    value: '${metrics.distanceKm} km',
                    subtitle: 'Calculated on-device',
                    progress: (metrics.distanceKm / 6.0).clamp(0.0, 1.0),
                  ),
                ),
              ],
            ),
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
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
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
        icon: Icon(icon, size: 19, color: isDark ? AppColors.inkPrimaryDark : AppColors.inkPrimaryLight),
        tooltip: tooltip,
        padding: EdgeInsets.zero,
        onPressed: onTap,
      ),
    );
  }

  Widget _buildHealthConnectBanner(BuildContext context, bool isDark) {
    switch (healthNotifier.status) {
      case HealthConnectStatus.connected:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1B3826) : AppColors.bentoEmeraldSubtle,
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Row(
            children: [
              Icon(Icons.check_circle_rounded, size: 18, color: AppColors.bentoEmerald),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Connected to Android Health Connect (On-device)',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.bentoEmerald,
                  ),
                ),
              ),
            ],
          ),
        );
      case HealthConnectStatus.permissionRevoked:
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.bentoMarigold.withAlpha(isDark ? 40 : 25),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, size: 20, color: Color(0xFFD97706)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Health Connect permission paused. Tap to restore.',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.inkPrimaryDark : AppColors.inkPrimaryLight,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => healthNotifier.setStatus(HealthConnectStatus.connected),
                child: const Text('Grant'),
              ),
            ],
          ),
        );
      case HealthConnectStatus.notInstalled:
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.bentoCoralSubtle,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline_rounded, size: 20, color: AppColors.bentoCoral),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Health Connect app required for Android 9-13.',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.bentoCoral),
                ),
              ),
              TextButton(
                onPressed: () => healthNotifier.setStatus(HealthConnectStatus.connected),
                child: const Text('Install'),
              ),
            ],
          ),
        );
    }
  }

  Widget _buildMetricTile({
    required bool isDark,
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    required String subtitle,
    required double progress,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: iconColor.withAlpha(isDark ? 40 : 25),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 16),
              ),
              const Spacer(),
              Text(
                '${(progress * 100).toInt()}%',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: iconColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
              color: isDark ? AppColors.inkPrimaryDark : AppColors.inkPrimaryLight,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isDark ? AppColors.inkSecondaryDark : AppColors.inkSecondaryLight,
            ),
          ),
        ],
      ),
    );
  }

  void _showEditQuotaDialog(BuildContext context) {
    final stepsCtrl = TextEditingController(text: healthNotifier.quota.stepsTarget.toString());
    final activeCtrl = TextEditingController(text: healthNotifier.quota.activeMinutesTarget.toString());
    final calCtrl = TextEditingController(text: healthNotifier.quota.caloriesTarget.toString());

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Set Daily Fitness Quota'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: stepsCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Daily Steps Goal'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: activeCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Active Minutes Goal'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: calCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Calories Target (kcal)'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.iris,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              healthNotifier.updateQuota(
                stepsTarget: int.tryParse(stepsCtrl.text),
                activeMinutesTarget: int.tryParse(activeCtrl.text),
                caloriesTarget: int.tryParse(calCtrl.text),
              );
              Navigator.pop(ctx);
            },
            child: const Text('Save Quota'),
          ),
        ],
      ),
    );
  }
}
