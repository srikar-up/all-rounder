import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../models/daily_quota.dart';
import '../models/health_status.dart';
import '../services/health_source.dart';
import '../services/quota_calculator.dart';

class QuotaProgressWidget extends StatefulWidget {
  final HealthSource healthSource;
  final VoidCallback? onOpenSettings;

  const QuotaProgressWidget({
    super.key,
    required this.healthSource,
    this.onOpenSettings,
  });

  @override
  State<QuotaProgressWidget> createState() => _QuotaProgressWidgetState();
}

class _QuotaProgressWidgetState extends State<QuotaProgressWidget> {
  DailyQuota _quota = const DailyQuota();
  QuotaProgress? _progress;
  HealthStatus _status = HealthStatus.needsPermission;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _isLoading = true);
    final quota = await DailyQuota.load();
    final status = await widget.healthSource.status();

    QuotaProgress? progress;
    if (status == HealthStatus.ready) {
      progress = await QuotaCalculator.calculate(
        healthSource: widget.healthSource,
        quota: quota,
      );
    }

    if (mounted) {
      setState(() {
        _quota = quota;
        _status = status;
        _progress = progress;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? Colors.transparent : AppColors.borderLight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF252834) : AppColors.bentoEmeraldSubtle,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.directions_run_rounded,
                      color: AppColors.bentoEmerald,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Daily Exercise Quota',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: isDark ? AppColors.inkPrimaryDark : AppColors.inkPrimaryLight,
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.refresh_rounded, size: 20),
                tooltip: 'Refresh fitness data',
                onPressed: _refresh,
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 12.0),
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                ),
              ),
            )
          else if (_status != HealthStatus.ready)
            _buildStatusPrompt(context, isDark)
          else if (_progress != null)
            _buildQuotaMetrics(context, isDark, _progress!),
        ],
      ),
    );
  }

  Widget _buildStatusPrompt(BuildContext context, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF252834) : const Color(0xFFFFF4DC),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline_rounded,
            color: _status == HealthStatus.notInstalled
                ? AppColors.bentoCoral
                : AppColors.bentoMarigold,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _status.description,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: isDark ? AppColors.inkPrimaryDark : AppColors.inkPrimaryLight,
              ),
            ),
          ),
          TextButton(
            onPressed: () async {
              if (_status == HealthStatus.notInstalled) {
                await widget.healthSource.openInstallPage();
              } else if (_status == HealthStatus.needsPermission) {
                final granted = await widget.healthSource.requestPermissions();
                if (granted) _refresh();
              } else if (widget.onOpenSettings != null) {
                widget.onOpenSettings!();
              }
            },
            child: Text(
              _status == HealthStatus.notInstalled
                  ? 'Install'
                  : (_status == HealthStatus.needsPermission ? 'Allow' : 'Details'),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuotaMetrics(
    BuildContext context,
    bool isDark,
    QuotaProgress progress,
  ) {
    return Column(
      children: [
        _buildMetricBar(
          label: 'Steps',
          current: progress.steps,
          goal: progress.stepsGoal,
          fraction: progress.stepsFraction,
          color: AppColors.bentoEmerald,
          icon: Icons.directions_walk_rounded,
          unit: 'steps',
          isDark: isDark,
        ),
        const SizedBox(height: 14),
        _buildMetricBar(
          label: 'Active Minutes',
          current: progress.exerciseMinutes,
          goal: progress.exerciseMinutesGoal,
          fraction: progress.exerciseMinutesFraction,
          color: AppColors.iris,
          icon: Icons.timer_outlined,
          unit: 'min',
          isDark: isDark,
        ),
      ],
    );
  }

  Widget _buildMetricBar({
    required String label,
    required int current,
    required int goal,
    required double fraction,
    required Color color,
    required IconData icon,
    required String unit,
    required bool isDark,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: color),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.inkSecondaryDark : AppColors.inkSecondaryLight,
                  ),
                ),
              ],
            ),
            Text(
              '$current / $goal $unit',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: isDark ? AppColors.inkPrimaryDark : AppColors.inkPrimaryLight,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: fraction,
            minHeight: 8,
            backgroundColor: isDark ? const Color(0xFF252834) : const Color(0xFFE5E2DC),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}
